# Muguet
A native Android/iOS/macOS port of GTA V, with multiplayer

## How does this work ?
this whole port relies on the WebAssembly compilation of the game. in a browser, that `game.wasm` runs inside the JS engine, behind WebGPU, Web Audio, web workers...
Muguet throws that layer away and runs the same `game.wasm` as a regular native app, with [wasmtime](https://wasmtime.dev) for the code and [wgpu](https://wgpu.rs) (Vulkan on Android, Metal on Apple) for the graphics

On Android and macOS, the game code is JIT/AOT compiled to native arm64 with Wasmtime Cranelift. On iOS, the game code is precompiled when building the app and baked into the binary.

On top of that, Muguet adds a small UDP multiplayer (for other people who have the same port to play with you).

## Game files
Because I care about me not getting sued, you will need your own copy as a `.zip` : the folder holding `data/` and `b/<build>/` (with `game.wasm` and `shaders/`)

It's basically the same source as the web port.

Muguet itself will then ask for that zip.

## Requirements
- Rust toolchain
- macOS, Linux, or Windows for building

For Android:
- A device running Android 8.0+ with Vulkan 1.1 support (64-bit ARM / `arm64-v8a`)
- `rustup target add aarch64-linux-android`
- Android NDK and SDK (or Android Studio)

For iOS:
- `rustup` with `rustup toolchain install 1.98.1` and `rustup target add aarch64-apple-ios --toolchain 1.98.1`
- `xcodegen` (`brew install xcodegen`)
- an Apple developer account
- a device on iOS 15 or later, ideally 8 GB of RAM

## Building

### Android:
```bash
# Linux / macOS:
./make-android.sh game.zip --apk

# Windows (PowerShell):
.\make-android.ps1 -Zip game.zip

# Or build and install directly to phone via adb:
./make-android.sh game.zip --install
```
See [android/README.md](android/README.md) for full Android documentation.

### macOS:
```bash
./make-app.sh
```
gives `build/Muguet.app`

### iOS:
```bash
TEAM=<your team id> ./make-ios.sh game.zip --install
```
`--ipa` makes `build/Muguet.ipa` instead. With a free account, add `FREE=1` (+ a `BUNDLE_ID` of your own)

Please install this app with AltStore. This probably won't work well with Sideloadly (or even SideStore, as per [this issue])(https://github.com/SideStore/SideStore/issues/1616)

The app also works with a paid developer account.

## Multiplayer
One player hosts from the launcher (or runs `muguet-server` on any machine), the others join with that address. UDP port 47520

## Limitations
- iOS needs the increased memory limit entitlement
- Story missions are single player only

## Credits
- [divyanshugarg36](https://github.com/divyanshugarg36) for lots of iOS fixes and improvements
- [Kagander](https://github.com/Kagander) for fixing the minimap
- [inj-src](https://github.com/inj-src) for decoding bc textures on all cores
- [Dbhardwaj99](https://github.com/Dbhardwaj99) for reporting real free disk space
- [dre4moff](https://github.com/dre4moff) for releasing controller input when the app loses focus

Contributions are welcome !
