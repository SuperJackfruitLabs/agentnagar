#!/usr/bin/env bash
# Smoke-tests the packages scripts/package.sh wrote to dist/.
#
#   scripts/smoke_package.sh [TARGET...]
#
# With no target, every package of this version found in dist/ is tested.
# A package is run wherever this machine can run it: Linux on a Linux host
# of its architecture, Windows on Windows or under Wine, macOS on a Mac. It
# runs headless with --quit-after and must load the extension, build a
# style pack, log no error and quit cleanly. Every package also has its
# contents checked: the executable, the pack and the extension, each for
# the right architecture, and the licence files beside the executable (in
# an APK, inside it under assets/licenses/). The APK is verified with apksigner and aapt from
# the Android SDK's build-tools.
set -euo pipefail
# shellcheck source=package.sh
source "$(dirname "${BASH_SOURCE[0]}")/package.sh"

FRAMES=120
FAILED=0
SUMMARY=()

ok() {
    echo "smoke: $1: ok: $2"
    SUMMARY+=("$1: $2")
}

fail() {
    echo "smoke: $1: FAIL: $2" >&2
    SUMMARY+=("$1: FAIL: $2")
    FAILED=1
}

# Runs a command for at most $1 seconds.
with_timeout() {
    local secs="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$secs" "$@"
    else
        perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
    fi
}

# The log of a headless run must show a style pack built, and no error.
# The client builds one only once the extension has loaded (without it
# the client stops at its build hint, a "city: " line), so the pack is
# the proof of both. The extension's own "Initialize godot-rust" line is
# printed to stdout, which a Windows --log-file never holds.
check_boot_log() {
    local t="$1" log="$2" bad
    if ! grep -q "Loading resource: res://styles/" "$log"; then
        if grep -q "Initialize godot-rust" "$log"; then
            fail "$t" "no style pack was built (log: $log)"
        else
            fail "$t" "the extension did not load and no style pack was built (log: $log)"
        fi
        return 1
    fi
    bad="$(grep -E "^(ERROR|SCRIPT ERROR|USER ERROR|USER SCRIPT ERROR)|^city: |Can't open dynamic library|GDExtension dynamic library not found" "$log" | head -n 5 || true)"
    if [[ -n "$bad" ]]; then
        fail "$t" "the run logged errors (log: $log): $bad"
        return 1
    fi
}

# run_boot TARGET LOG CMD...: runs the client headless and checks its log.
run_boot() {
    local t="$1" log="$2" status=0
    shift 2
    with_timeout 600 "$@" --headless --verbose --quit-after "$FRAMES" >"$log" 2>&1 || status=$?
    if [[ $status -ne 0 ]]; then
        fail "$t" "exited with $status (log: $log)"
        return 1
    fi
    check_boot_log "$t" "$log"
}

need_files() {
    local t="$1" f
    shift
    for f in "$@"; do
        if [[ ! -e "$f" ]]; then
            fail "$t" "missing ${f#"$STAGE_DIR/smoke/"}"
            return 1
        fi
    done
}

# The licence files a package's folder must hold (package.sh notices).
licence_files() { # licence_files DIR
    local entry
    while IFS= read -r entry; do echo "$1/${entry%%:*}"; done < <(notices)
}

# Where an APK holds the licence files: res://licenses/ is assets/licenses/.
apk_licence_files() {
    local entry
    while IFS= read -r entry; do echo "assets/licenses/${entry%%:*}"; done < <(notices)
}

unpack() { # unpack TARGET PACKAGE: prints the folder it unpacked into
    local t="$1" pkg="$2" dir="$STAGE_DIR/smoke/$1"
    rm -rf "$dir"
    mkdir -p "$dir"
    case "$pkg" in
        *.tar.gz) tar -xzf "$pkg" -C "$dir" ;;
        *.zip)
            if command -v unzip >/dev/null 2>&1; then
                unzip -q "$pkg" -d "$dir"
            elif command -v 7z >/dev/null 2>&1; then
                7z x -bd -y -o"$dir" "$pkg" >/dev/null
            else
                "$(command -v python3 || command -v python)" -m zipfile -e "$pkg" "$dir"
            fi
            ;;
    esac
    echo "$dir"
}

# The highest glibc symbol version a Linux library needs.
glibc_needed() {
    objdump -T "$1" 2>/dev/null | grep -oE 'GLIBC_[0-9.]+' | sort -V | tail -n1 || true
}

smoke_linux() {
    local t="$1" pkg="$2" arch="${1#linux-}" dir root exe pck lib machine
    dir="$(unpack "$t" "$pkg")"
    root="$dir/$APP-$VERSION-$t"
    exe="$root/$APP.$arch"
    pck="$root/$APP.pck"
    lib="$root/$(basename "$(lib_path "$t")")"
    need_files "$t" "$exe" "$pck" "$lib" $(licence_files "$root") || return 0
    machine="$([[ "$arch" == arm64 ]] && echo aarch64 || echo x86-64)"
    for f in "$exe" "$lib"; do
        if ! file -b "$f" | grep -q "$machine"; then
            fail "$t" "$(basename "$f") is not $machine: $(file -b "$f")"
            return 0
        fi
    done
    local needs
    needs="$(glibc_needed "$lib")"
    if [[ "$(host_os)" == linux && "$(host_arch)" == "$arch" ]]; then
        # A failed boot is recorded by run_boot; the other targets still run.
        if run_boot "$t" "$dir/run.log" "$exe"; then
            ok "$t" "ran headless for $FRAMES frames: extension loaded, style pack built, no errors (extension needs $needs)"
        fi
    else
        ok "$t" "contents checked: $machine executable, pack and extension (needs $needs); not run, this host is $(host_os)-$(host_arch)"
    fi
}

smoke_windows() {
    local t="$1" pkg="$2" dir root exe pck dll imports odd
    dir="$(unpack "$t" "$pkg")"
    root="$dir/$APP-$VERSION-$t"
    exe="$root/$APP.exe"
    pck="$root/$APP.pck"
    dll="$root/$(basename "$(lib_path "$t")")"
    need_files "$t" "$exe" "$pck" "$dll" $(licence_files "$root") || return 0
    if command -v file >/dev/null 2>&1; then
        for f in "$exe" "$dll"; do
            if ! file -b "$f" | grep -q "PE32+.*x86-64"; then
                fail "$t" "$(basename "$f") is not x86-64 PE32+: $(file -b "$f")"
                return 0
            fi
        done
    fi
    if command -v objdump >/dev/null 2>&1; then
        imports="$(objdump -p "$dll" | sed -n 's/.*DLL Name: //p' | tr '\n' ' ')"
        # Only Windows' own libraries: no MinGW or MSVC runtime to ship.
        odd="$(echo "$imports" | tr ' ' '\n' | grep -viE '^(kernel32|ntdll|ws2_32|userenv|advapi32|bcrypt|bcryptprimitives|ole32|oleaut32|shell32|user32|msvcrt|api-ms-win-.*)\.dll$' | grep -v '^$' || true)"
        if [[ -n "$odd" ]]; then
            fail "$t" "the extension needs libraries Windows does not ship: $odd"
            return 0
        fi
    fi
    if [[ "$(host_os)" == windows ]]; then
        # A Windows GUI program's output does not reach a Git Bash pipe, so
        # the engine writes its log to a file.
        local status=0
        with_timeout 600 "$exe" --headless --verbose --quit-after "$FRAMES" --log-file "$(native_path "$dir/godot.log")" >"$dir/run.log" 2>&1 || status=$?
        if [[ $status -ne 0 ]]; then
            fail "$t" "exited with $status (logs: $dir/run.log, $dir/godot.log)"
        elif check_boot_log "$t" "$dir/godot.log"; then
            ok "$t" "ran headless for $FRAMES frames: extension loaded, style pack built, no errors"
        fi
    elif command -v wine >/dev/null 2>&1; then
        if run_boot "$t" "$dir/run.log" wine "$exe"; then
            ok "$t" "ran headless under Wine for $FRAMES frames: extension loaded, style pack built, no errors"
        fi
    else
        ok "$t" "contents checked: x86-64 executable, pack and extension (imports only Windows DLLs); not run, Wine is not installed"
    fi
}

smoke_macos() {
    local t="$1" pkg="$2" dir app exe pck lib f slices py
    dir="$(unpack "$t" "$pkg")"
    app="$(find "$dir" -maxdepth 1 -name '*.app' | head -n1)"
    if [[ -z "$app" ]]; then
        fail "$t" "no .app in the package"
        return 0
    fi
    exe="$(find "$app/Contents/MacOS" -type f | head -n1)"
    pck="$(find "$app/Contents/Resources" -maxdepth 1 -name '*.pck' | head -n1)"
    lib="$app/Contents/Frameworks/$(basename "$(lib_path "$t")")"
    need_files "$t" "$exe" "$pck" "$lib" $(licence_files "$dir") || return 0
    # Both architectures, each signed (Apple Silicon runs no unsigned code).
    py="$(command -v python3 || command -v python || true)"
    if [[ -z "$py" ]]; then
        fail "$t" "python3 is needed to read the Mach-O files"
        return 0
    fi
    for f in "$exe" "$lib"; do
        slices="$("$py" "$CITY_DIR/scripts/macho_slices.py" "$f")"
        if [[ "$slices" != *"x86_64:signed"* || "$slices" != *"arm64:signed"* ]]; then
            fail "$t" "$(basename "$f") is not universal and signed (has: $slices)"
            return 0
        fi
    done
    if [[ "$(host_os)" == macos ]]; then
        codesign --verify --deep --strict "$app" || {
            fail "$t" "codesign --verify failed"
            return 0
        }
        if run_boot "$t" "$dir/run.log" "$exe"; then
            ok "$t" "codesign verified; ran headless for $FRAMES frames: extension loaded, style pack built, no errors"
        fi
    else
        ok "$t" "contents checked: the .app's executable and extension are universal (x86_64 + arm64) with every slice signed (ad hoc), and its pack is there; not run, this host is $(host_os)"
    fi
}

smoke_android() {
    local t="$1" pkg="$2" sdk bt listing badging signer
    sdk="$(android_sdk)"
    bt="$(ls -d "$sdk"/build-tools/* 2>/dev/null | sort -V | tail -n1 || true)"
    if [[ -z "$bt" ]]; then
        fail "$t" "no Android build-tools to verify the APK with (set ANDROID_HOME)"
        return 0
    fi
    if ! signer="$("$bt/apksigner" verify --verbose --print-certs "$pkg" 2>&1)"; then
        fail "$t" "apksigner verify failed: $signer"
        return 0
    fi
    # aapt2: the old aapt cannot parse the manifests of current templates.
    local aapt=aapt2
    [[ -x "$bt/aapt2" ]] || aapt=aapt
    badging="$("$bt/$aapt" dump badging "$pkg" 2>&1)" || {
        fail "$t" "$aapt dump badging failed: $badging"
        return 0
    }
    if ! grep -q "package: name='org.superjackfruit.agentnagar.city'" <<<"$badging" ||
        ! grep -q "native-code: 'arm64-v8a'" <<<"$badging"; then
        fail "$t" "unexpected badging: $(grep -E '^(package|native-code)' <<<"$badging")"
        return 0
    fi
    listing="$(unzip -l "$pkg")"
    # An APK has no folder beside it: the licence files are the pack's copy,
    # which Godot stores under assets/.
    for f in "lib/arm64-v8a/$(basename "$(lib_path "$t")")" lib/arm64-v8a/libgodot_android.so $(apk_licence_files); do
        if ! grep -q " $f$" <<<"$listing"; then
            fail "$t" "the APK lacks $f"
            return 0
        fi
    done
    ok "$t" "apksigner verified ($(grep -m1 -oE 'Verified using v[0-9]+ scheme[^:]*: true' <<<"$signer" || echo signed); $(grep -m1 'certificate DN' <<<"$signer" | sed 's/.*DN: //')); $aapt dump badging: $(grep -oE "package: name='[^']*'" <<<"$badging"), native-code arm64-v8a; extension and engine in lib/arm64-v8a"
}

smoke_web() {
    local t="$1" pkg="$2" dir root
    dir="$(unpack "$t" "$pkg")"
    root="$dir/$APP-$VERSION-$t"
    local side="$root/$(basename "$(lib_path "$t")")"
    need_files "$t" "$root/index.html" "$root/index.wasm" "$root/index.pck" "$side" $(licence_files "$root") || return 0
    # Godot's web engine has no wasm exceptions: a side module that imports
    # them never finishes loading.
    if grep -qaE '__cpp_exception|_Unwind_RaiseException' "$side"; then
        fail "$t" "the extension imports wasm exception handling, which the engine lacks (build it with panic=abort)"
        return 0
    fi
    ok "$t" "contents checked: page, engine, pack and extension side module (no exception imports); not run (needs a browser)"
}

smoke_ios() {
    local t="$1" pkg="$2" dir root
    dir="$(unpack "$t" "$pkg")"
    root="$dir/$APP-$VERSION-$t"
    need_files "$t" "$root/$APP.xcodeproj/project.pbxproj" $(licence_files "$root") || return 0
    if command -v xcodebuild >/dev/null 2>&1; then
        xcodebuild -list -project "$root/$APP.xcodeproj" >/dev/null || {
            fail "$t" "xcodebuild cannot read the project"
            return 0
        }
    fi
    ok "$t" "contents checked: an Xcode project; not built or signed here"
}

smoke_main() {
    local targets=() t pkg
    VERSION="$(version)"
    for t in "$@"; do
        is_target "$t" || {
            echo "smoke: unknown target '$t' (targets: ${TARGETS[*]})" >&2
            return 2
        }
        targets+=("$t")
    done
    if [[ ${#targets[@]} -eq 0 ]]; then
        for t in "${TARGETS[@]}"; do
            [[ -e "$DIST_DIR/$(package_name "$t" "$VERSION")" ]] && targets+=("$t")
        done
        [[ ${#targets[@]} -gt 0 ]] || die "no packages of version $VERSION in $DIST_DIR (set CITY_VERSION?)"
    fi
    for t in "${targets[@]}"; do
        pkg="$DIST_DIR/$(package_name "$t" "$VERSION")"
        if [[ ! -e "$pkg" ]]; then
            fail "$t" "no package at $pkg"
            continue
        fi
        case "$t" in
            linux-*) smoke_linux "$t" "$pkg" ;;
            windows-*) smoke_windows "$t" "$pkg" ;;
            macos-*) smoke_macos "$t" "$pkg" ;;
            android-*) smoke_android "$t" "$pkg" ;;
            web) smoke_web "$t" "$pkg" ;;
            ios) smoke_ios "$t" "$pkg" ;;
        esac
    done
    echo "smoke: summary"
    printf '  %s\n' "${SUMMARY[@]}"
    return "$FAILED"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    smoke_main "$@"
fi
