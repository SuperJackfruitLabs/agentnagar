Packages of the Agentnagar city client: the district simulated by the Rust
city core and shown live in six switchable visual styles. The world is
fixture data, not real agent state.

| File | For |
| --- | --- |
| `…-linux-x86_64.tar.gz`, `…-linux-x86_64.AppImage` | Linux on x86_64 (glibc 2.28 or newer) |
| `…-linux-arm64.tar.gz` | Linux on arm64 (glibc 2.28 or newer) |
| `…-windows-x86_64.zip` | Windows 10 and 11, x86_64 |
| `…-macos-universal.zip` | macOS on Apple silicon and Intel |
| `…-android-arm64.apk` | Android 7 (API 24) or newer, arm64 |
| `…-ios.zip` | an Xcode project, to build and sign for iOS yourself |
| `…-web.zip` | a static site (experimental), when its build succeeded |
| `SHA256SUMS` | the files' SHA-256 sums |

**Before you run them**

- None of these builds is signed with a paid certificate. Windows may
  show a SmartScreen warning. The macOS app is signed ad hoc, so
  Gatekeeper blocks it until you allow it in System Settings → Privacy &
  Security. The APK is signed with a debug key.
- The Android and iOS builds have no touch controls yet; use a keyboard
  or a game controller.
- The web build runs Godot's Compatibility renderer (WebGL 2). Serve it
  with `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp`.

**Licence and source**

Agentnagar is free software under the GNU Affero General Public License,
version 3 only; its source is at
https://github.com/SuperJackfruitLabs/agentnagar. Every package carries
`LICENSE.txt` and `THIRD-PARTY-NOTICES.txt` (the Godot engine, the Rust
crates and the fonts it contains) beside the executable; the APK carries
them inside, and every build shows them under About in the game menu.
