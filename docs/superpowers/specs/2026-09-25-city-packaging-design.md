# Packaging the city client: design

Date: 2026-09-25. The goal is to build the Agentnagar Godot client (`city/godot`, with its Rust GDExtension `city-godot`) into releasable packages for every operating system the engine supports. Some of this work is local and some runs on CI.

## 1. Targets

| Target | Extension build | Export template | Package |
| --- | --- | --- | --- |
| Linux x86_64 | cargo (native) | linux_release.x86_64 | `.tar.gz` of the binary and the `.pck` file, plus an AppImage when `appimagetool` is available |
| Linux arm64 | cargo-zigbuild `aarch64-unknown-linux-gnu` | linux_release.arm64 | `.tar.gz` |
| Windows x86_64 | cargo-zigbuild `x86_64-pc-windows-gnu` | windows_release_x86_64 | `.zip` of the `.exe` and the `.pck` |
| macOS universal | cargo-zigbuild `x86_64-apple-darwin` and `aarch64-apple-darwin`, then `lipo` to one universal binary | macos.zip | `.zip` of the `.app`, unsigned locally, signed and notarised on CI when secrets exist |
| Android arm64 | cargo with the NDK linker, `aarch64-linux-android` | android_release.apk | `.apk` signed with a debug keystore locally, and a release keystore on CI |
| Web | nightly Rust and emscripten (gdext's threaded web support) | web_release | a zipped site. Best effort, and CI only while its toolchain is experimental |
| iOS | on CI with Xcode | ios.zip | an Xcode project (the `.xcodeproj`) |

## 2. Pieces

- **`city/godot/city.gdextension`** lists a library for every platform and architecture: `.so`, `.dll`, `.dylib` (universal) and the Android `.so`. Web and iOS are listed once their builds exist.
- **`city/godot/export_presets.cfg`** is checked in, with one preset per target. Presets exclude:
  - `tests/`;
  - `tools/`;
  - `evidence/`;
  - style source kits.
- **`city/scripts/package.sh [TARGET...]`** builds the extension for each target, lays the libraries out under `godot/bin/`, exports with `godot --headless --export-release PRESET`, and writes packages to `city/dist/`. It prints what each target needs when a tool is missing, and never installs anything system-wide.
- **Smoke tests.**
  - The Linux package is unpacked and run headless with `--quit-after`. It must boot, load the extension and quit cleanly.
  - The Windows package is run under Wine when Wine is present.
  - The APK is checked with `apksigner verify` and `aapt dump badging`.
- **`.github/workflows/package.yml`** is a CI matrix on ubuntu, windows and macos runners. It builds and exports natively, uploads packages as workflow artifacts, and runs only on tags and manual dispatch.
- **Documentation.** A packaging section in `city/README.md`.

## 3. Testing

The shell logic of `package.sh` (target parsing, library layout and preset names) is covered by `scripts/test_package.sh`, which needs no toolchains. The real proof is the smoke tests on the produced packages. Each target's result is recorded in the PR, with local and CI results kept separate.

## 4. Not in scope

Store listings, auto-update, and paid signing certificates. Signing hooks read CI secrets when present.
