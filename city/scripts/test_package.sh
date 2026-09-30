#!/usr/bin/env bash
# Tests scripts/package.sh without any toolchain: its argument parsing and
# target choice (with stub tools on PATH), the library layout against
# godot/city.gdextension, and the preset names against
# godot/export_presets.cfg. Builds, exports and writes nothing.
set -euo pipefail
CITY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$CITY_DIR/scripts/package.sh"
GDEXT="$CITY_DIR/godot/city.gdextension"
PRESETS="$CITY_DIR/godot/export_presets.cfg"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0
check() { # check DESCRIPTION COMMAND...
    local what="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        echo "test_package: FAIL: $what" >&2
    fi
}
contains() { [[ "$1" == *"$2"* ]]; }
equals() { [[ "$1" == "$2" ]]; }

# The package.sh functions, in a subshell of their own.
fn() { bash -c 'source "$1"; shift; "$@"' _ "$PKG" "$@"; }

TARGETS=(linux-x86_64 linux-arm64 windows-x86_64 macos-universal android-arm64 web ios)

# ---- A PATH of stub tools: a Linux x86_64 host with everything but emcc ----

STUB="$WORK/bin"
mkdir -p "$STUB"
for tool in bash dirname sed grep sort tail head tr cut ls cat env mkdir rm; do
    ln -s "$(command -v "$tool")" "$STUB/$tool"
done
stub() { # stub NAME SCRIPT
    printf '#!/bin/sh\n%s\n' "$2" >"$STUB/$1"
    chmod +x "$STUB/$1"
}
stub uname 'case "$1" in -s) echo Linux ;; -m) echo x86_64 ;; *) echo Linux ;; esac'
stub godot 'echo 4.6.3.stable.test.0000000'
stub cargo 'exit 0'
stub cargo-zigbuild 'exit 0'
stub zig 'exit 0'
stub keytool 'exit 0'
stub rustup 'case "$1" in
    target) printf "%s\n" x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu x86_64-pc-windows-gnu x86_64-apple-darwin aarch64-apple-darwin aarch64-linux-android ;;
    toolchain) echo stable-x86_64-unknown-linux-gnu ;;
    component) echo ;;
esac'
TEMPLATES="$WORK/templates"
mkdir -p "$TEMPLATES"
for f in linux_release.x86_64 linux_release.arm64 windows_release_x86_64.exe macos.zip android_release.apk web_dlink_release.zip ios.zip; do
    : >"$TEMPLATES/$f"
done
NDK="$WORK/ndk"
mkdir -p "$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
stub_ndk="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang"
printf '#!/bin/sh\n' >"$stub_ndk"
chmod +x "$stub_ndk"

run_pkg() { # runs package.sh on the stub PATH; prints its output and status
    local status=0 out
    out="$(env -i HOME="$WORK/home" PATH="$STUB" CITY_VERSION=9.9.9 GODOT_TEMPLATES="$TEMPLATES" \
        ANDROID_HOME="$WORK/sdk" ANDROID_NDK_HOME="$NDK" bash "$PKG" "$@" 2>&1)" || status=$?
    printf '%s\nstatus=%s\n' "$out" "$status"
}

# ---- Argument parsing ----

out="$(run_pkg --help)"
check "--help prints usage" contains "$out" "Targets: linux-x86_64"
check "--help exits 0" contains "$out" "status=0"

out="$(run_pkg --list)"
check "--list names every target in order" equals "$out" "$(printf '%s\n' "${TARGETS[@]}")
status=0"

out="$(run_pkg bogus)"
check "an unknown target is refused" contains "$out" "unknown target 'bogus'"
check "an unknown target exits 2" contains "$out" "status=2"

out="$(run_pkg --frobnicate)"
check "an unknown option exits 2" contains "$out" "status=2"

out="$(run_pkg --dry-run linux-x86_64 windows-x86_64)"
check "a dry run plans linux-x86_64 with zig, pinned to an old glibc" contains "$out" 'linux-x86_64: preset "Linux x86_64", build zigbuild x86_64-unknown-linux-gnu, library godot/bin/libcity_godot.linux.x86_64.so, package dist/agentnagar-city-9.9.9-linux-x86_64.tar.gz'
check "a dry run plans windows-x86_64 with zig" contains "$out" 'windows-x86_64: preset "Windows x86_64", build zigbuild x86_64-pc-windows-gnu, library godot/bin/city_godot.windows.x86_64.dll, package dist/agentnagar-city-9.9.9-windows-x86_64.zip'
check "a dry run plans only what was named" equals "$(grep -c ': preset ' <<<"$out")" 2

# With no target, everything buildable here is chosen and the rest named.
out="$(run_pkg --dry-run)"
for t in linux-x86_64 linux-arm64 windows-x86_64 macos-universal android-arm64; do
    check "the default includes $t" grep -q "^$t: preset " <<<"$out"
done
check "the default plans macOS as universal2" contains "$out" "build zigbuild universal2-apple-darwin"
check "the default plans Android with the NDK" contains "$out" "build ndk aarch64-linux-android"
check "the default skips web, naming emcc" contains "$out" "skipping web; it needs:
  - emcc"
check "the default skips web, naming nightly" contains "$out" "nightly Rust"
check "the default skips ios off a Mac" contains "$out" "skipping ios; it needs:
  - a macOS host with Xcode"

# A named target whose tools are missing fails, saying what it needs.
rm "$STUB/cargo-zigbuild" "$STUB/zig"
out="$(run_pkg linux-arm64)"
check "a named target without its tools exits 1" contains "$out" "status=1"
check "... and says it cannot be built" contains "$out" "linux-arm64 cannot be built here; it needs:"
check "... naming cargo-zigbuild" contains "$out" "cargo-zigbuild: cargo install cargo-zigbuild"
check "... naming zig" contains "$out" "zig: zig 0.15"
out="$(run_pkg --dry-run)"
check "without zig the default drops the zig targets" equals "$(grep -c ': preset ' <<<"$out")" 2
rm "$TEMPLATES/android_release.apk"
out="$(run_pkg android-arm64)"
check "a missing export template is named" contains "$out" "export template $TEMPLATES/android_release.apk"
rm "$STUB/godot"
out="$(run_pkg linux-x86_64)"
check "a missing Godot is named" contains "$out" "godot: the Godot 4.6 editor (set GODOT to its command)"
check "... and exits 1" contains "$out" "status=1"

# ---- Library layout ----

gdext_value() { sed -n "s/^$1 = \"\(.*\)\"$/\1/p" "$GDEXT"; }
keys_of() {
    case "$1" in
        linux-x86_64) echo linux.debug.x86_64 linux.release.x86_64 ;;
        linux-arm64) echo linux.debug.arm64 linux.release.arm64 ;;
        windows-x86_64) echo windows.debug.x86_64 windows.release.x86_64 ;;
        macos-universal) echo macos.debug macos.release ;;
        android-arm64) echo android.debug.arm64 android.release.arm64 ;;
        web) echo web.debug.wasm32 web.release.wasm32 ;;
        ios) echo ios.debug ios.release ;;
    esac
}
listed=()
for t in "${TARGETS[@]}"; do
    lib="$(fn lib_path "$t")"
    check "$t's library is under bin/" contains "$lib" "bin/"
    listed+=("$lib")
    for key in $(keys_of "$t"); do
        if [[ "$t" == ios ]]; then
            check "city.gdextension does not list $key until $t exports" equals "$(gdext_value "${key//./\\.}")" ""
            check "$t's export adds $key for res://$lib" grep -qx "$key = \"res://$lib\"" <<<"$(fn extra_library_lines "$t")"
        else
            check "city.gdextension lists $key as res://$lib" equals "$(gdext_value "${key//./\\.}")" "res://$lib"
        fi
    done
done
check "each target's library has its own name" equals "$(printf '%s\n' "${listed[@]}" | sort -u | wc -l)" "${#TARGETS[@]}"
while read -r path; do
    check "city.gdextension's $path is built by a target" grep -qx "${path#res://}" <<<"$(printf '%s\n' "${listed[@]}")"
done < <(sed -n 's/^[a-z0-9.]* = "\(res:\/\/.*\)"$/\1/p' "$GDEXT")
# The editor exports on the host: it loads the host's own library, so a job
# that exports only another platform must build that one too.
hostfn() { env PATH="$STUB" bash -c 'source "$1"; shift; "$@"' _ "$PKG" "$@"; }
check "a Linux x86_64 host is the linux-x86_64 target" equals "$(hostfn host_target)" "linux-x86_64"
EMPTY_GODOT="$WORK/empty-godot"
mkdir -p "$EMPTY_GODOT/bin"
editor_lib() { env PATH="$STUB" GODOT_DIR_OVERRIDE="$EMPTY_GODOT" bash -c 'source "$1"; shift; "$@"' _ "$PKG" editor_library_target "$@"; }
check "exporting only the web on Linux builds the editor's library" equals "$(editor_lib web)" "linux-x86_64"
check "exporting the host's own target needs nothing more" equals "$(editor_lib linux-x86_64 web)" ""
: >"$EMPTY_GODOT/$(fn lib_path linux-x86_64)"
check "an editor library already there is not rebuilt" equals "$(editor_lib web)" ""
# The smoke test's boot check (scripts/smoke_package.sh check_boot_log).
SMOKE="$CITY_DIR/scripts/smoke_package.sh"
boot_ok() { bash -c 'source "$1"; check_boot_log t "$2"' _ "$SMOKE" "$1" >/dev/null 2>&1; }
LOGS="$WORK/logs"
mkdir -p "$LOGS"
printf 'Initialize godot-rust (API v4.6)\nLoading resource: res://styles/anime_cel/pack.gd\n' >"$LOGS/linux.log"
check "a log where the extension says it loaded passes" boot_ok "$LOGS/linux.log"
printf 'Godot Engine v4.6.3\nLoading resource: res://styles/anime_cel/pack.gd\n' >"$LOGS/windows.log"
check "a Windows log file (the extension's stdout line never reaches it) passes on the style pack" boot_ok "$LOGS/windows.log"
printf 'Loading resource: res://styles/anime_cel/pack.gd\ncity: The city extension is not loaded\n' >"$LOGS/nolib.log"
check "a client reporting no extension fails" bash -c '! boot_ok "$1"' _ "$LOGS/nolib.log"
printf 'Initialize godot-rust\n' >"$LOGS/nopack.log"
check "a log with no style pack fails" bash -c '! boot_ok "$1"' _ "$LOGS/nopack.log"
check "build-godot.sh writes the Linux x86_64 library" grep -q "godot/$(fn lib_path linux-x86_64)" "$CITY_DIR/scripts/build-godot.sh"
check "a cross build's library is under target/<triple>/release" equals "$(fn built_lib windows-x86_64)" "target/x86_64-pc-windows-gnu/release/city_godot.dll"
check "an Android build's library" equals "$(fn built_lib android-arm64)" "target/aarch64-linux-android/release/libcity_godot.so"
check "a universal macOS library" equals "$(fn built_lib macos-universal)" "target/universal2-apple-darwin/release/libcity_godot.dylib"
check "macOS libraries leave header room for the export's signature" contains "$(fn target_env macos-universal)" "-headerpad_max_install_names"
check "the web build aborts on panic (the web engine has no wasm exceptions)" grep -q 'RUSTFLAGS=".*-C panic=abort"' "$PKG"
check "... with std built for it" grep -q -- '-Zbuild-std=std,panic_abort' "$PKG"

# ---- Presets ----

preset_field() { # preset_field NAME FIELD: a field of the preset with that name
    awk -v name="name=\"$1\"" -v field="$2=" '
        /^\[preset\.[0-9]+\]$/ { inside = 0 }
        $0 == name { inside = 1 }
        inside && index($0, field) == 1 { print substr($0, length(field) + 1); exit }
    ' "$PRESETS"
}
platform_of() {
    case "$1" in
        linux-*) echo '"Linux"' ;;
        windows-*) echo '"Windows Desktop"' ;;
        macos-*) echo '"macOS"' ;;
        android-*) echo '"Android"' ;;
        web) echo '"Web"' ;;
        ios) echo '"iOS"' ;;
    esac
}
check "one preset per target" equals "$(grep -c '^name=' "$PRESETS")" "${#TARGETS[@]}"
for t in "${TARGETS[@]}"; do
    name="$(fn preset_name "$t")"
    check "$t's preset \"$name\" exists once" equals "$(grep -cx "name=\"$name\"" "$PRESETS")" 1
    check "$t's preset is for $(platform_of "$t")" equals "$(preset_field "$name" platform)" "$(platform_of "$t")"
    exclude="$(preset_field "$name" exclude_filter)"
    for dir in tests tools evidence; do
        check "$t's preset leaves out $dir/" contains "$exclude" "$dir/*"
    done
    check "$t's preset keeps every style" bash -c '[[ "$1" != *styles* ]]' _ "$exclude"
    check "$t's preset carries the staged fixture" contains "$(preset_field "$name" include_filter)" "fixtures/*"
    check "$t's preset carries the fonts' licences" contains "$(preset_field "$name" include_filter)" "styles/*/assets/fonts/*-OFL.txt"
    check "$t's preset carries Sample station" contains "$(preset_field "$name" include_filter)" "sample_station/*"
    check "$t's preset carries the staged licence and notices" contains "$(preset_field "$name" include_filter)" "licenses/*"
    check "$t's preset keeps the licences" bash -c '[[ "$1" != *txt* ]]' _ "$exclude"
    check "$t's preset exports $(fn export_file "$t")" equals "$(preset_field "$name" export_path)" "\"../dist/$t/$(fn export_file "$t")\""
done
for fonts in "$CITY_DIR"/godot/styles/*/assets/fonts; do
    check "${fonts#"$CITY_DIR"/godot/}: a licence beside the fonts" compgen -G "$fonts/*-OFL.txt"
done
check "the Android package id is the one the smoke test checks" equals \
    "$(preset_field "Android arm64" package/unique_name)" '"org.superjackfruit.agentnagar.city"'
check "the macOS preset is universal" equals "$(preset_field "macOS universal" binary_format/architecture)" '"universal"'
check "packs stay beside the Linux binary" equals "$(preset_field "Linux x86_64" binary_format/embed_pck)" false
check "mobile and Apple Silicon textures are imported" grep -qx 'textures/vram_compression/import_etc2_astc=true' "$CITY_DIR/godot/project.godot"
check "the project names an icon (an Android export fails without one)" grep -qx 'config/icon="res://icon.png"' "$CITY_DIR/godot/project.godot"
check "... and the icon exists" test -f "$CITY_DIR/godot/icon.png"

# ---- Package names, the fixture and the AppDir ----

check "Linux packages are tarballs" equals "$(fn package_name linux-arm64 1.0)" agentnagar-city-1.0-linux-arm64.tar.gz
check "Windows packages are zips" equals "$(fn package_name windows-x86_64 1.0)" agentnagar-city-1.0-windows-x86_64.zip
check "macOS packages are zips" equals "$(fn package_name macos-universal 1.0)" agentnagar-city-1.0-macos-universal.zip
check "Android packages are APKs" equals "$(fn package_name android-arm64 1.0)" agentnagar-city-1.0-android-arm64.apk
check "an iOS export is judged by its Xcode project" equals "$(fn expected_output ios)" agentnagar-city.xcodeproj
check "the client reads the bundled fixture from res://fixtures" grep -q 'const BUNDLED := "res://fixtures"' "$CITY_DIR/godot/core/paths.gd"
check "package.sh stages the fixture at godot/fixtures/district" grep -q 'mkdir -p "$GODOT_DIR/fixtures/district"' "$PKG"
check "the staged fixture is not committed" grep -qx '/fixtures/' "$CITY_DIR/godot/.gitignore"
check "dist/ is not committed" grep -qx 'dist/' "$CITY_DIR/.gitignore"

# ---- The licence files ----

ROOT_DIR="$(cd "$CITY_DIR/.." && pwd)"
NOTICES="$ROOT_DIR/THIRD-PARTY-NOTICES.txt"
check "the repository has the AGPL as LICENSE" grep -q 'GNU AFFERO GENERAL PUBLIC LICENSE' "$ROOT_DIR/LICENSE"
check "the repository has the third-party notices" test -s "$NOTICES"
godot_version="$(sed -n 's/^  GODOT_VERSION: "\(.*\)"$/\1/p' "$ROOT_DIR/.github/workflows/package.yml")"
check "the notices name the Godot release the packages are built from ($godot_version)" \
    grep -q "^1. Godot Engine $godot_version-stable$" "$NOTICES"
check "... and the notices script pins the same release" \
    grep -q "^GODOT_TAG = '$godot_version-stable'$" "$CITY_DIR/scripts/third_party_notices.py"
for section in "2. godot-rust (gdext)" "3. Rust crates in the city-godot extension" "4. Fonts"; do
    check "the notices have \"$section\"" grep -qx "$section" "$NOTICES"
done
check "the notices carry the MPL-2.0 text for godot-rust" grep -q 'Mozilla Public License Version 2.0' "$NOTICES"
check "the notices name the Rust standard library the extension links" grep -q '^Rust standard library .*: LICENSE-MIT$' "$NOTICES"
emscripten_version="$(sed -n 's/^      EMSCRIPTEN_VERSION: "\(.*\)"$/\1/p' "$ROOT_DIR/.github/workflows/package.yml")"
check "the notices carry the licence of the Emscripten the web build uses ($emscripten_version)" \
    grep -q "^Emscripten $emscripten_version LICENSE$" "$NOTICES"
check "... and the notices script pins the same release" \
    grep -q "^EMSCRIPTEN = '$emscripten_version'$" "$CITY_DIR/scripts/third_party_notices.py"
check "... with the text itself, not only a link" grep -q 'University of Illinois/NCSA Open Source License' "$NOTICES"
for ofl in "$CITY_DIR"/godot/styles/*/assets/fonts/*-OFL.txt; do
    check "the notices cover the font licence $(basename "$ofl")" grep -q "^$(basename "$ofl" -OFL.txt): " "$NOTICES"
done
check "the notices name no local path" bash -c '! grep -qE "/home/|/Users/|[A-Z]:\\\\" "$1"' _ "$NOTICES"
notices_out="$WORK/notices"
mkdir -p "$notices_out"
fn add_notices "$notices_out"
check "a package gets LICENSE.txt (the AGPL)" cmp -s "$ROOT_DIR/LICENSE" "$notices_out/LICENSE.txt"
check "a package gets THIRD-PARTY-NOTICES.txt" cmp -s "$NOTICES" "$notices_out/THIRD-PARTY-NOTICES.txt"
LIC_GODOT="$WORK/licence-godot"
mkdir -p "$LIC_GODOT"
env GODOT_DIR_OVERRIDE="$LIC_GODOT" bash -c 'source "$1"; stage_licences' _ "$PKG"
check "package.sh stages the licences where the pack's res://licenses/ comes from" \
    test -f "$LIC_GODOT/licenses/LICENSE.txt" -a -f "$LIC_GODOT/licenses/THIRD-PARTY-NOTICES.txt"
env GODOT_DIR_OVERRIDE="$LIC_GODOT" bash -c 'source "$1"; cleanup' _ "$PKG"
check "... and takes them away after exporting" test ! -e "$LIC_GODOT/licenses"
# The version the About screen shows.
cp "$CITY_DIR/godot/project.godot" "$WORK/project.godot"
fn set_version "$WORK/project.godot" 9.9.9
check "an export writes its version into project.godot" grep -qx 'config/version="9.9.9"' "$WORK/project.godot"
check "... under [application]" bash -c 'awk "/^\\[/{s=\$0} /^config\\/version=/{print s}" "$1" | grep -qx "\\[application\\]"' _ "$WORK/project.godot"
fn set_version "$WORK/project.godot" 9.9.10
check "... once, replacing any earlier one" equals "$(grep -c '^config/version=' "$WORK/project.godot")" 1
check "... and the rest of project.godot is unchanged" equals "$(grep -v '^config/version=' "$WORK/project.godot")" "$(cat "$CITY_DIR/godot/project.godot")"
check "export_target sets the version and puts project.godot back" grep -q 'backup "$GODOT_DIR/project.godot"' "$PKG"
check "the About screen reads that setting" grep -q 'application/config/version' "$CITY_DIR/godot/core/ui/screens/about.gd"
check "package.sh stages them before exporting" grep -qx '    stage_licences' "$PKG"
check "the staged licences are not committed" grep -qx '/licenses/' "$CITY_DIR/godot/.gitignore"
check "every export puts the licences beside the executable" grep -qx '    add_notices "$stage"' "$PKG"
# The APK has no folder beside it: its only copy is the pack's, which Godot
# stores under assets/ (res://licenses/ is assets/licenses/).
check "the Android preset carries the staged licences into the APK" \
    contains "$(preset_field "Android arm64" include_filter)" "licenses/*"
check "... and does not exclude them" bash -c '[[ "$1" != *licenses* && "$1" != *txt* ]]' _ "$(preset_field "Android arm64" exclude_filter)"
apk_files="$(bash -c 'source "$1"; apk_licence_files' _ "$CITY_DIR/scripts/smoke_package.sh")"
check "the APK smoke test requires assets/licenses/LICENSE.txt" grep -qx 'assets/licenses/LICENSE.txt' <<<"$apk_files"
check "... and assets/licenses/THIRD-PARTY-NOTICES.txt" grep -qx 'assets/licenses/THIRD-PARTY-NOTICES.txt' <<<"$apk_files"
check "... in the APK's own listing" grep -q 'apk_licence_files)' "$CITY_DIR/scripts/smoke_package.sh"
# The macOS package is Godot's own zip of the .app, with the licences added.
mac="$WORK/mac"
mkdir -p "$mac/zipped/agentnagar-city.app/Contents/MacOS"
touch "$mac/zipped/agentnagar-city.app/Contents/MacOS/agentnagar-city"
fn make_zip "$mac/pkg.zip" "$mac/zipped" agentnagar-city.app
fn add_notices "$mac"
fn add_to_zip "$mac/pkg.zip" "$mac" LICENSE.txt THIRD-PARTY-NOTICES.txt
mac_names="$(python3 -c 'import sys, zipfile; print("\n".join(zipfile.ZipFile(sys.argv[1]).namelist()))' "$mac/pkg.zip")"
check "the macOS zip has LICENSE.txt beside the .app" grep -qx 'LICENSE.txt' <<<"$mac_names"
check "... and THIRD-PARTY-NOTICES.txt" grep -qx 'THIRD-PARTY-NOTICES.txt' <<<"$mac_names"
check "... and still the .app" grep -q '^agentnagar-city.app/Contents/MacOS/agentnagar-city$' <<<"$mac_names"

stage="$WORK/stage"
mkdir -p "$stage"
touch "$stage/agentnagar-city.x86_64" "$stage/agentnagar-city.pck" "$stage/libcity_godot.linux.x86_64.so"
fn add_notices "$stage"
fn make_appdir "$stage" "$WORK/AppDir"
check "the AppDir has an executable AppRun" test -x "$WORK/AppDir/AppRun"
check "the AppDir has the desktop entry" test -f "$WORK/AppDir/agentnagar-city.desktop"
check "the AppDir has the icon the entry names" test -f "$WORK/AppDir/$(sed -n 's/^Icon=//p' "$WORK/AppDir/agentnagar-city.desktop").png"
for f in agentnagar-city.x86_64 agentnagar-city.pck libcity_godot.linux.x86_64.so LICENSE.txt THIRD-PARTY-NOTICES.txt; do
    check "the AppDir carries $f" test -f "$WORK/AppDir/usr/bin/$f"
done
check "AppRun starts the binary beside its pack" grep -q 'usr/bin/agentnagar-city.x86_64' "$WORK/AppDir/AppRun"

echo "test_package: $PASSED passed, $FAILED failed"
[[ $FAILED -eq 0 ]]
