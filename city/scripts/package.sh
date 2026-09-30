#!/usr/bin/env bash
# Packages the city client for each target: builds the city-godot extension,
# lays the library out under godot/bin/ (the paths godot/city.gdextension
# lists), exports the project with the target's preset from
# godot/export_presets.cfg and writes the package to dist/. Every package
# carries the licence (LICENSE.txt) and the third-party notices
# (THIRD-PARTY-NOTICES.txt) beside its executable, and its pack carries them
# at res://licenses/ for the About screen. Each package is then smoke-tested
# (scripts/smoke_package.sh).
#
#   scripts/package.sh [--dry-run] [--no-smoke] [TARGET...]
#   scripts/package.sh --list
#
# Targets: linux-x86_64 linux-arm64 windows-x86_64 macos-universal
#          android-arm64 web ios
#
# With no target, every target whose tools are present here is packaged,
# and every other one is named with what it needs. A target named on the
# command line whose tools are missing is an error. Nothing is installed.
#
# Environment:
#   GODOT            the Godot 4.6 editor command (default: godot)
#   GODOT_TEMPLATES  the export templates directory (default: found from
#                    the editor's version in the usual places)
#   CITY_VERSION     the version in package names (default: git describe)
#   ANDROID_HOME, ANDROID_NDK_HOME
#                    the Android SDK and NDK (default: ~/Android/Sdk and its
#                    newest ndk/)
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER, _PASSWORD
#                    the APK's signing key. Without them a debug keystore is
#                    made under target/android/ and used.
#   APPLE_TEAM_ID    the team written into the iOS Xcode project
set -euo pipefail

CITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "$CITY_DIR/.." && pwd)"
GODOT_DIR="${GODOT_DIR_OVERRIDE:-$CITY_DIR/godot}"
DIST_DIR="$CITY_DIR/dist"
STAGE_DIR="$DIST_DIR/.stage"
TARGETS=(linux-x86_64 linux-arm64 windows-x86_64 macos-universal android-arm64 web ios)
APP=agentnagar-city
ANDROID_API=24
# The oldest glibc a cross-built Linux library links against.
GLIBC=2.28

say() { echo "package: $*"; }
warn() { echo "package: warning: $*" >&2; }
die() {
    echo "package: $*" >&2
    exit 1
}

usage() {
    sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
}

# ---- What each target is (pure; scripts/test_package.sh checks these) ----

is_target() {
    local t
    for t in "${TARGETS[@]}"; do
        [[ "$t" == "$1" ]] && return 0
    done
    return 1
}

# The preset in godot/export_presets.cfg.
preset_name() {
    case "$1" in
        linux-x86_64) echo "Linux x86_64" ;;
        linux-arm64) echo "Linux arm64" ;;
        windows-x86_64) echo "Windows x86_64" ;;
        macos-universal) echo "macOS universal" ;;
        android-arm64) echo "Android arm64" ;;
        web) echo "Web" ;;
        ios) echo "iOS" ;;
    esac
}

# Where the library goes, relative to godot/. godot/city.gdextension lists
# it as res://<this> (ios only while it exports).
lib_path() {
    case "$1" in
        linux-x86_64) echo "bin/libcity_godot.linux.x86_64.so" ;;
        linux-arm64) echo "bin/libcity_godot.linux.arm64.so" ;;
        windows-x86_64) echo "bin/city_godot.windows.x86_64.dll" ;;
        macos-universal) echo "bin/libcity_godot.macos.universal.dylib" ;;
        android-arm64) echo "bin/libcity_godot.android.arm64.so" ;;
        web) echo "bin/city_godot.web.wasm32.wasm" ;;
        ios) echo "bin/libcity_godot.ios.arm64.dylib" ;;
    esac
}

# Library lines godot/city.gdextension does not carry, added while the
# target exports: iOS, whose build has only run on CI so far.
extra_library_lines() {
    local lib
    lib="res://$(lib_path "$1")"
    case "$1" in
        ios) printf 'ios.debug = "%s"\nios.release = "%s"\n' "$lib" "$lib" ;;
    esac
}

# The Rust target triple (universal2-apple-darwin is both darwin triples).
rust_triple() {
    case "$1" in
        linux-x86_64) echo x86_64-unknown-linux-gnu ;;
        linux-arm64) echo aarch64-unknown-linux-gnu ;;
        windows-x86_64) if [[ "$(host_os)" == windows ]]; then echo x86_64-pc-windows-msvc; else echo x86_64-pc-windows-gnu; fi ;;
        macos-universal) echo universal2-apple-darwin ;;
        android-arm64) echo aarch64-linux-android ;;
        web) echo wasm32-unknown-emscripten ;;
        ios) echo aarch64-apple-ios ;;
    esac
}

# The rustup targets a build needs.
rustup_targets() {
    case "$1" in
        macos-universal) echo "x86_64-apple-darwin aarch64-apple-darwin" ;;
        web) echo "" ;; # built from source with nightly's rust-src
        *) rust_triple "$1" ;;
    esac
}

# The file cargo writes.
cargo_lib_name() {
    case "$1" in
        linux-* | android-*) echo libcity_godot.so ;;
        windows-*) echo city_godot.dll ;;
        macos-* | ios) echo libcity_godot.dylib ;;
        web) echo city_godot.wasm ;;
    esac
}

# The Godot export template file the target needs.
template_file() {
    case "$1" in
        linux-x86_64) echo linux_release.x86_64 ;;
        linux-arm64) echo linux_release.arm64 ;;
        windows-x86_64) echo windows_release_x86_64.exe ;;
        macos-universal) echo macos.zip ;;
        android-arm64) echo android_release.apk ;;
        web) echo web_dlink_release.zip ;;
        ios) echo ios.zip ;;
    esac
}

# What Godot is asked to write, inside the target's stage folder.
export_file() {
    case "$1" in
        linux-x86_64) echo "$APP.x86_64" ;;
        linux-arm64) echo "$APP.arm64" ;;
        windows-x86_64) echo "$APP.exe" ;;
        macos-universal) echo "$APP.zip" ;; # Godot zips the .app itself
        android-arm64) echo "$APP.apk" ;;
        web) echo "index.html" ;;
        ios) echo "$APP.ipa" ;; # with export_project_only: the .xcodeproj beside it
    esac
}

# What the export must have written, inside the stage folder.
expected_output() {
    case "$1" in
        ios) echo "$APP.xcodeproj" ;;
        *) export_file "$1" ;;
    esac
}

package_name() {
    local t="$1" v="$2"
    case "$t" in
        linux-*) echo "$APP-$v-$t.tar.gz" ;;
        android-*) echo "$APP-$v-$t.apk" ;;
        *) echo "$APP-$v-$t.zip" ;;
    esac
}

host_os() {
    case "$(uname -s)" in
        Linux) echo linux ;;
        Darwin) echo macos ;;
        MINGW* | MSYS* | CYGWIN* | Windows_NT) echo windows ;;
        *) uname -s ;;
    esac
}

host_arch() {
    case "$(uname -m)" in
        x86_64 | amd64 | AMD64) echo x86_64 ;;
        aarch64 | arm64) echo arm64 ;;
        *) uname -m ;;
    esac
}

# The target this host is: the one whose library the editor itself loads.
host_target() {
    case "$(host_os)-$(host_arch)" in
        linux-x86_64) echo linux-x86_64 ;;
        linux-arm64) echo linux-arm64 ;;
        windows-x86_64) echo windows-x86_64 ;;
        macos-*) echo macos-universal ;;
    esac
}

# The host's target when its library must be built so the editor can open
# the project to export TARGETS (it is not among them and not built yet);
# nothing otherwise.
editor_library_target() {
    local host t
    host="$(host_target)"
    [[ -n "$host" ]] || return 0
    for t in "$@"; do
        [[ "$t" == "$host" ]] && return 0
    done
    [[ -f "$GODOT_DIR/$(lib_path "$host")" ]] || echo "$host"
}

# Builds the editor's own library natively (on a Mac, for this Mac's
# architecture only: the editor needs to load it, nothing ships it).
build_editor_library() {
    local host="$1"
    cd "$CITY_DIR"
    cargo build -p city-godot --release
    mkdir -p "$GODOT_DIR/bin"
    cp "target/release/$(cargo_lib_name "$host")" "$GODOT_DIR/$(lib_path "$host")"
    say "the editor's own library at godot/$(lib_path "$host")"
}

# How the extension is built for a target on this host.
build_method() {
    local t="$1" os arch
    os="$(host_os)"
    arch="$(host_arch)"
    case "$t" in
        # Every Linux library through zig, pinned to glibc $GLIBC, so a
        # package built on a new distro still loads on older ones; without
        # zig, this machine's own Linux target is built natively (it then
        # needs this machine's glibc).
        linux-*)
            if [[ "$os" == linux && "linux-$arch" == "$t" ]] && ! { command -v cargo-zigbuild >/dev/null 2>&1 && command -v zig >/dev/null 2>&1; }; then
                echo cargo
            else
                echo zigbuild
            fi ;;
        windows-x86_64) if [[ "$os" == windows ]]; then echo cargo; else echo zigbuild; fi ;;
        macos-universal) if [[ "$os" == macos ]]; then echo lipo; else echo zigbuild; fi ;;
        android-arm64) echo ndk ;;
        web) echo emscripten ;;
        ios) if [[ "$os" == macos ]]; then echo xcode; else echo unavailable; fi ;;
    esac
}

# Where the built library lands, relative to the city workspace.
built_lib() {
    local t="$1"
    if [[ "$(build_method "$t")" == cargo ]]; then
        echo "target/release/$(cargo_lib_name "$t")"
    else
        echo "target/$(rust_triple "$t")/release/$(cargo_lib_name "$t")"
    fi
}

# A path as the Godot binary expects it (Windows paths under Git Bash).
native_path() {
    if [[ "$(host_os)" == windows ]] && command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1"
    else
        echo "$1"
    fi
}

version() {
    if [[ -n "${CITY_VERSION:-}" ]]; then
        echo "$CITY_VERSION"
    else
        git -C "$CITY_DIR" describe --tags --always --dirty 2>/dev/null | tr '/' '-' || echo dev
    fi
}

# ---- Prerequisites ----

read -ra GODOT_CMD <<<"${GODOT:-godot}"
MISSING=()
_godot_version=""
_templates=""

need() { MISSING+=("$1"); }

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || need "$1: $2"
}

godot_version() {
    if [[ -z "$_godot_version" ]] && command -v "${GODOT_CMD[0]}" >/dev/null 2>&1; then
        _godot_version="$("${GODOT_CMD[@]}" --version 2>/dev/null | tail -n1 || true)"
    fi
    echo "$_godot_version"
}

# The export templates folder for the editor's version, e.g. 4.6.3.stable.
templates_dir() {
    if [[ -n "${GODOT_TEMPLATES:-}" ]]; then
        echo "$GODOT_TEMPLATES"
        return
    fi
    if [[ -z "$_templates" ]]; then
        local v d
        v="$(godot_version | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?\.(stable|rc[0-9]*|beta[0-9]*|alpha[0-9]*|dev[0-9]*)' || true)"
        [[ -n "$v" ]] || return 0
        for d in \
            "$HOME/.var/app/org.godotengine.Godot/data/godot/export_templates/$v" \
            "${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$v" \
            "$HOME/Library/Application Support/Godot/export_templates/$v" \
            "${APPDATA:-/nonexistent}/Godot/export_templates/$v"; do
            if [[ -d "$d" ]]; then
                _templates="$d"
                break
            fi
        done
        [[ -n "$_templates" ]] || _templates="(no export_templates/$v folder found)"
    fi
    echo "$_templates"
}

rust_target_installed() {
    command -v rustup >/dev/null 2>&1 || return 0 # no rustup: let cargo say
    rustup target list --installed 2>/dev/null | grep -qx "$1"
}

android_sdk() {
    if [[ -n "${ANDROID_HOME:-}" ]]; then
        echo "$ANDROID_HOME"
    elif [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
        echo "$ANDROID_SDK_ROOT"
    elif [[ -d "$HOME/Android/Sdk" ]]; then
        echo "$HOME/Android/Sdk"
    elif [[ -d "$HOME/Library/Android/sdk" ]]; then
        echo "$HOME/Library/Android/sdk"
    fi
}

android_ndk() {
    if [[ -n "${ANDROID_NDK_HOME:-}" ]]; then
        echo "$ANDROID_NDK_HOME"
    elif [[ -n "${ANDROID_NDK_ROOT:-}" ]]; then
        echo "$ANDROID_NDK_ROOT"
    else
        local sdk
        sdk="$(android_sdk)"
        if [[ -n "$sdk" && -d "$sdk/ndk" ]]; then
            local newest
            newest="$(ls "$sdk/ndk" 2>/dev/null | sort -V | tail -n1)"
            [[ -n "$newest" ]] && echo "$sdk/ndk/$newest"
        fi
    fi
}

ndk_clang() {
    local tag bin
    case "$(host_os)" in
        linux) tag=linux-x86_64 ;;
        macos) tag=darwin-x86_64 ;; # the NDK ships it for both Mac architectures
        windows) tag=windows-x86_64 ;;
    esac
    bin="$(android_ndk)/toolchains/llvm/prebuilt/$tag/bin"
    if [[ "$(host_os)" == windows ]]; then
        echo "$bin/aarch64-linux-android$ANDROID_API-clang.cmd"
    else
        echo "$bin/aarch64-linux-android$ANDROID_API-clang"
    fi
}

# Fills MISSING with what the target lacks on this machine.
check_prereqs() {
    local t="$1" m tr tpl
    MISSING=()
    m="$(build_method "$t")"
    if [[ "$m" == unavailable ]]; then
        need "a macOS host with Xcode: iOS builds only there (the CI ios job)"
        return
    fi
    need_cmd cargo "Rust, from https://rustup.rs"
    if ! command -v "${GODOT_CMD[0]}" >/dev/null 2>&1; then
        need "${GODOT_CMD[0]}: the Godot 4.6 editor (set GODOT to its command)"
    else
        tpl="$(templates_dir)/$(template_file "$t")"
        [[ -f "$tpl" ]] || need "export template $tpl: install Godot $(godot_version | cut -d. -f1-4)'s export templates (Editor > Manage Export Templates), or set GODOT_TEMPLATES"
    fi
    for tr in $(rustup_targets "$t"); do
        rust_target_installed "$tr" || need "Rust target $tr: rustup target add $tr"
    done
    case "$m" in
        zigbuild)
            need_cmd cargo-zigbuild "cargo install cargo-zigbuild"
            need_cmd zig "zig 0.15 (pip install ziglang==0.15.2, or https://ziglang.org/download)"
            # cargo-zigbuild 0.23 passes zig 0.16 a macOS export list it misreads.
            if [[ "$t" == macos-universal ]] && command -v zig >/dev/null 2>&1 &&
                [[ "$(zig version 2>/dev/null)" == 0.16* ]]; then
                need "zig 0.15 for macOS: zig $(zig version) cannot link it with cargo-zigbuild 0.23"
            fi
            ;;
        lipo)
            need_cmd lipo "Xcode's command line tools (xcode-select --install)"
            ;;
        ndk)
            if [[ -z "$(android_ndk)" ]]; then
                need "Android NDK: set ANDROID_NDK_HOME, or install one under \$ANDROID_HOME/ndk/ (sdkmanager 'ndk;<version>')"
            elif [[ ! -x "$(ndk_clang)" && ! -f "$(ndk_clang)" ]]; then
                need "NDK linker $(ndk_clang): an NDK r25 or newer"
            fi
            [[ -n "$(android_sdk)" ]] || need "Android SDK: set ANDROID_HOME (Godot signs the APK with its build-tools)"
            if [[ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]]; then
                need_cmd keytool "a JDK (keytool makes the local debug keystore), or set GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD"
            fi
            ;;
        emscripten)
            need_cmd emcc "emscripten, the version Godot's web templates were built with (emsdk install/activate; source emsdk_env.sh)"
            if command -v rustup >/dev/null 2>&1; then
                rustup toolchain list 2>/dev/null | grep -q '^nightly' || need "nightly Rust: rustup toolchain install nightly"
                rustup component list --toolchain nightly --installed 2>/dev/null | grep -q '^rust-src' ||
                    need "rust-src for nightly: rustup component add rust-src --toolchain nightly"
            else
                need "rustup, with a nightly toolchain and rust-src"
            fi
            ;;
        xcode)
            need_cmd xcodebuild "Xcode"
            ;;
    esac
}

# ---- Building, exporting, packing ----

# Linker settings a target's library needs, as cargo environment settings:
# - macOS: room in the Mach-O header, so the export can add the code
#   signature every library in an app must carry;
# - Windows (MSVC): the C runtime linked in, so no redistributable is needed.
target_env() {
    case "$1" in
        macos-universal)
            echo "CARGO_TARGET_X86_64_APPLE_DARWIN_RUSTFLAGS=-C link-arg=-Wl,-headerpad_max_install_names"
            echo "CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS=-C link-arg=-Wl,-headerpad_max_install_names"
            ;;
        windows-x86_64)
            echo "CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUSTFLAGS=-C target-feature=+crt-static"
            ;;
    esac
}

build_extension() {
    local t="$1" triple line settings=()
    triple="$(rust_triple "$t")"
    while IFS= read -r line; do
        [[ -n "$line" ]] && settings+=("$line")
    done < <(target_env "$t")
    cd "$CITY_DIR"
    case "$(build_method "$t")" in
        cargo)
            env ${settings[@]+"${settings[@]}"} cargo build -p city-godot --release
            ;;
        zigbuild)
            case "$t" in
                linux-*) cargo zigbuild -p city-godot --release --target "$triple.$GLIBC" ;;
                *) env ${settings[@]+"${settings[@]}"} cargo zigbuild -p city-godot --release --target "$triple" ;;
            esac
            ;;
        lipo)
            env "${settings[@]}" cargo build -p city-godot --release --target x86_64-apple-darwin
            env "${settings[@]}" cargo build -p city-godot --release --target aarch64-apple-darwin
            mkdir -p "target/$triple/release"
            lipo -create -output "$(built_lib "$t")" \
                target/x86_64-apple-darwin/release/libcity_godot.dylib \
                target/aarch64-apple-darwin/release/libcity_godot.dylib
            ;;
        ndk)
            local clang env_triple
            clang="$(ndk_clang)"
            env_triple="$(echo "$triple" | tr 'a-z-' 'A-Z_')"
            env "CARGO_TARGET_${env_triple}_LINKER=$clang" \
                "CC_${triple//-/_}=$clang" \
                "AR_${triple//-/_}=$(dirname "$clang")/llvm-ar" \
                cargo build -p city-godot --release --target "$triple"
            ;;
        emscripten)
            # gdext's threaded web support: a side module, built with atomics.
            # Panics abort: unwinding would import wasm exception handling
            # (__cpp_exception), which Godot's web engine does not provide,
            # and the side module would then never load.
            RUSTFLAGS="-C link-args=-sSIDE_MODULE=2 -C link-args=-pthread -C target-feature=+atomics,+bulk-memory,+mutable-globals -Zlink-native-libraries=no -C panic=abort" \
                cargo +nightly build -Zbuild-std=std,panic_abort -p city-godot --release --target "$triple"
            ;;
        xcode)
            cargo build -p city-godot --release --target "$triple"
            ;;
    esac
    [[ -f "$(built_lib "$t")" ]] || die "$t: the build did not produce $(built_lib "$t")"
    mkdir -p "$GODOT_DIR/bin"
    cp "$(built_lib "$t")" "$GODOT_DIR/$(lib_path "$t")"
    say "$t: extension at godot/$(lib_path "$t")"
}

# Files changed for one export and put back afterwards (see restore).
BACKUPS=()

backup() {
    local f="$1"
    mkdir -p "$STAGE_DIR/backup"
    cp "$f" "$STAGE_DIR/backup/$(basename "$f")"
    BACKUPS+=("$f")
}

restore() {
    local f
    for f in ${BACKUPS[@]+"${BACKUPS[@]}"}; do
        cp "$STAGE_DIR/backup/$(basename "$f")" "$f"
    done
    BACKUPS=()
}

# Leaves the project as it was: changed files back, the staged fixture and
# licences gone.
cleanup() {
    restore
    rm -rf "$GODOT_DIR/fixtures" "$GODOT_DIR/licenses"
}

# The package carries the district fixture (core/paths.gd reads it from
# res://fixtures in an exported build).
stage_fixture() {
    mkdir -p "$GODOT_DIR/fixtures/district"
    cp "$CITY_DIR/fixtures/district/manifest.json" "$CITY_DIR/fixtures/district/feed.jsonl" "$GODOT_DIR/fixtures/district/"
    # The sample panels its displays show (CityWorld.panel_json).
    cp -R "$CITY_DIR/fixtures/district/panels" "$GODOT_DIR/fixtures/district/"
}

# set_version PROJECT VERSION: the version the About screen shows
# (application/config/version), written into project.godot for an export.
set_version() {
    local f="$1" v="$2"
    awk -v v="$v" '/^config\/version=/ { next } { print } /^\[application\]$/ { print "config/version=\"" v "\"" }' "$f" >"$f.tmp"
    mv "$f.tmp" "$f"
}

# The licence files every package carries, as "name in the package:file in
# the repository". THIRD-PARTY-NOTICES.txt is written by
# scripts/third_party_notices.py.
notices() {
    echo "LICENSE.txt:LICENSE"
    echo "THIRD-PARTY-NOTICES.txt:THIRD-PARTY-NOTICES.txt"
}

# add_notices DIR: copies the licence files into DIR (beside the executable).
add_notices() {
    local dir="$1" entry
    while IFS= read -r entry; do
        [[ -f "$ROOT_DIR/${entry#*:}" ]] || die "the repository has no ${entry#*:} to put in the package"
        cp "$ROOT_DIR/${entry#*:}" "$dir/${entry%%:*}"
    done < <(notices)
}

# The pack carries the licence files too, at res://licenses/ (the About
# screen shows them; an APK has nowhere else to put them).
stage_licences() {
    mkdir -p "$GODOT_DIR/licenses"
    add_notices "$GODOT_DIR/licenses"
}

# add_to_zip ZIP DIR NAME...: adds DIR/NAME... at the zip's top level.
add_to_zip() {
    local zipfile="$1" dir="$2"
    shift 2
    if command -v zip >/dev/null 2>&1; then
        (cd "$dir" && zip -qy "$zipfile" "$@")
    else
        local py
        py="$(command -v python3 || command -v python || true)"
        [[ -n "$py" ]] || die "no zip or python to add the licences to $zipfile"
        (cd "$dir" && "$py" -c 'import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "a", zipfile.ZIP_DEFLATED) as z:
    for name in sys.argv[2:]:
        z.write(name)' "$zipfile" "$@")
    fi
}

android_signing() {
    if [[ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]]; then
        say "android-arm64: signing with the release keystore in GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
        return
    fi
    local ks="$CITY_DIR/target/android/debug.keystore"
    if [[ ! -f "$ks" ]]; then
        mkdir -p "$(dirname "$ks")"
        keytool -genkeypair -keystore "$ks" -alias androiddebugkey -storepass android -keypass android \
            -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1 ||
            die "android-arm64: keytool could not make $ks"
    fi
    export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ks"
    export GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey
    export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
    say "android-arm64: signing with a local debug keystore ($ks); set GODOT_ANDROID_KEYSTORE_RELEASE_* for a release key"
}

export_target() {
    local t="$1" stage out log
    stage="$STAGE_DIR/$t/$APP-$VERSION-$t"
    rm -rf "$STAGE_DIR/$t"
    mkdir -p "$stage"
    out="$stage/$(export_file "$t")"
    log="$STAGE_DIR/$t/export.log"
    if [[ "$t" == ios ]]; then
        backup "$GODOT_DIR/city.gdextension"
        extra_library_lines "$t" >>"$GODOT_DIR/city.gdextension"
        local team="${APPLE_TEAM_ID:-}"
        if [[ -z "$team" ]]; then
            team=0000000000
            warn "ios: APPLE_TEAM_ID is not set; the Xcode project gets the placeholder team $team (set yours in Xcode)"
        fi
        backup "$GODOT_DIR/export_presets.cfg"
        sed -i.bak "s/^application\/app_store_team_id=.*/application\/app_store_team_id=\"$team\"/" "$GODOT_DIR/export_presets.cfg"
        rm -f "$GODOT_DIR/export_presets.cfg.bak"
    fi
    backup "$GODOT_DIR/project.godot"
    set_version "$GODOT_DIR/project.godot" "$VERSION"
    [[ "$t" == android-arm64 ]] && android_signing
    say "$t: exporting with preset \"$(preset_name "$t")\""
    local status=0
    "${GODOT_CMD[@]}" --headless --path "$(native_path "$GODOT_DIR")" --export-release "$(preset_name "$t")" "$(native_path "$out")" >"$log" 2>&1 || status=$?
    restore
    if [[ $status -ne 0 || ! -e "$stage/$(expected_output "$t")" ]]; then
        grep -E 'ERROR|error|Error' "$log" | head -n 20 >&2 || true
        die "$t: the export failed (exit $status); the whole log is $log"
    fi
    # Godot finishes some broken exports "with warnings" (an unsigned macOS
    # library, say), so any error it logs fails the target.
    if grep -qE '^(ERROR|SCRIPT ERROR|USER ERROR)' "$log"; then
        grep -E '^(ERROR|SCRIPT ERROR|USER ERROR)' "$log" | head -n 10 >&2
        die "$t: the export logged errors; the whole log is $log"
    fi
    add_notices "$stage"
    pack "$t" "$stage"
}

make_zip() { # make_zip OUT.zip DIR NAME: zips DIR/NAME as NAME/...
    local out="$1" dir="$2" name="$3"
    rm -f "$out"
    if command -v zip >/dev/null 2>&1; then
        (cd "$dir" && zip -qry "$out" "$name")
    elif command -v 7z >/dev/null 2>&1; then
        (cd "$dir" && 7z a -tzip -bd "$out" "$name" >/dev/null)
    else
        local py
        py="$(command -v python3 || command -v python || true)"
        [[ -n "$py" ]] || die "no zip, 7z or python to write $out"
        (cd "$dir" && "$py" -m zipfile -c "$out" "$name")
    fi
}

# Lays out an AppDir for appimagetool: AppRun, the desktop entry and icon.
make_appdir() { # make_appdir STAGE APPDIR
    local stage="$1" appdir="$2"
    rm -rf "$appdir"
    mkdir -p "$appdir/usr/bin"
    cp -R "$stage/." "$appdir/usr/bin/"
    cp "$CITY_DIR/packaging/linux/$APP.desktop" "$appdir/$APP.desktop"
    cp "$GODOT_DIR/icon.png" "$appdir/$APP.png"
    cat >"$appdir/AppRun" <<'EOF'
#!/bin/sh
here="$(dirname "$(readlink -f "$0")")"
# The engine loads agentnagar-city.pck from beside itself.
exec "$here/usr/bin/agentnagar-city.x86_64" "$@"
EOF
    chmod +x "$appdir/AppRun"
}

pack() {
    local t="$1" stage="$2" pkg name entry
    name="$(basename "$stage")"
    pkg="$DIST_DIR/$(package_name "$t" "$VERSION")"
    rm -f "$pkg"
    case "$t" in
        linux-*)
            tar -C "$(dirname "$stage")" -czf "$pkg" "$name"
            if [[ "$t" == linux-x86_64 ]]; then
                if command -v appimagetool >/dev/null 2>&1; then
                    local appdir="$STAGE_DIR/$t/AppDir"
                    make_appdir "$stage" "$appdir"
                    ARCH=x86_64 appimagetool --no-appstream "$appdir" "$DIST_DIR/$APP-$VERSION-$t.AppImage" >/dev/null
                    say "$t: $DIST_DIR/$APP-$VERSION-$t.AppImage"
                else
                    say "$t: no AppImage (appimagetool is not on PATH)"
                fi
            fi
            ;;
        macos-*)
            # Godot zips the .app; the licences go beside it.
            mv "$stage/$(export_file "$t")" "$pkg"
            local names=()
            while IFS= read -r entry; do names+=("${entry%%:*}"); done < <(notices)
            add_to_zip "$pkg" "$stage" "${names[@]}"
            ;;
        # An APK has only the pack's copy (res://licenses/).
        android-*) mv "$stage/$(export_file "$t")" "$pkg" ;;
        *) make_zip "$pkg" "$(dirname "$stage")" "$name" ;;
    esac
    say "$t: $pkg ($(du -h "$pkg" | cut -f1))"
}

# ---- Main ----

main() {
    local dry=0 smoke=1 explicit=() t
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h | --help)
                usage
                return 0
                ;;
            --list)
                printf '%s\n' "${TARGETS[@]}"
                return 0
                ;;
            --dry-run) dry=1 ;;
            --no-smoke) smoke=0 ;;
            -*)
                echo "package: unknown option $1" >&2
                usage >&2
                return 2
                ;;
            *)
                if ! is_target "$1"; then
                    echo "package: unknown target '$1' (targets: ${TARGETS[*]})" >&2
                    return 2
                fi
                explicit+=("$1")
                ;;
        esac
        shift
    done

    VERSION="$(version)"
    local chosen=() skipped=0 failed=0
    if [[ ${#explicit[@]} -gt 0 ]]; then
        for t in "${explicit[@]}"; do
            check_prereqs "$t"
            if [[ ${#MISSING[@]} -gt 0 ]]; then
                echo "package: $t cannot be built here; it needs:" >&2
                printf '  - %s\n' "${MISSING[@]}" >&2
                failed=1
            fi
            chosen+=("$t")
        done
        if [[ $failed -eq 1 && $dry -eq 0 ]]; then
            return 1
        fi
    else
        for t in "${TARGETS[@]}"; do
            check_prereqs "$t"
            if [[ ${#MISSING[@]} -gt 0 ]]; then
                echo "package: skipping $t; it needs:"
                printf '  - %s\n' "${MISSING[@]}"
                skipped=$((skipped + 1))
            else
                chosen+=("$t")
            fi
        done
        [[ ${#chosen[@]} -gt 0 ]] || die "no target can be built on this machine"
    fi

    if [[ $dry -eq 1 ]]; then
        for t in "${chosen[@]}"; do
            echo "$t: preset \"$(preset_name "$t")\", build $(build_method "$t") $(rust_triple "$t"), library godot/$(lib_path "$t"), package dist/$(package_name "$t" "$VERSION")"
        done
        return 0
    fi

    mkdir -p "$DIST_DIR" "$STAGE_DIR"
    trap cleanup EXIT
    for t in "${chosen[@]}"; do
        say "$t: building the extension ($(build_method "$t") $(rust_triple "$t"))"
        build_extension "$t"
    done
    local editor
    editor="$(editor_library_target "${chosen[@]}")"
    if [[ -n "$editor" ]]; then
        say "building the editor's own library ($editor), which it loads to export"
        build_editor_library "$editor"
    fi
    stage_fixture
    stage_licences
    say "importing the project"
    "${GODOT_CMD[@]}" --headless --path "$(native_path "$GODOT_DIR")" --import --quit >"$STAGE_DIR/import.log" 2>&1 ||
        warn "the import pass exited non-zero; see $STAGE_DIR/import.log"
    for t in "${chosen[@]}"; do
        export_target "$t"
    done
    cleanup
    trap - EXIT
    if [[ $smoke -eq 1 ]]; then
        CITY_VERSION="$VERSION" "$CITY_DIR/scripts/smoke_package.sh" "${chosen[@]}"
    fi
    say "done: ${chosen[*]} in $DIST_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
