# Muguet for Android

Native port of GTA V for Android devices running on **Vulkan** and **WebAssembly (AOT/JIT)** with touch controls and multiplayer.

---

## Requirements

### Android Device
- **Architecture**: 64-bit ARM (`arm64-v8a`)
- **OS**: Android 8.0 (Oreo, API 26) or higher (Android 10+ recommended)
- **GPU**: Vulkan 1.1+ support (Adreno 5xx/6xx/7xx, Mali G-series, Immortalis, etc.)
- **RAM**: Minimum 4 GB RAM (6 GB – 8 GB strongly recommended)
- **Storage**: ~15 GB free space for game assets

### Build Requirements
- **Rust Toolchain**: `rustup` with target `aarch64-linux-android`:
  ```bash
  rustup target add aarch64-linux-android
  ```
- **Android NDK**: NDK r25b or newer (set `ANDROID_NDK_HOME`)
- **Android SDK & Build Tools**: API 34
- **Java**: JDK 17 (or openjdk-17)

---

## Quick Start (Building the APK)

### On Linux / macOS / WSL:
```bash
# 1. Standard build (with launcher importer)
./make-android.sh --apk

# 2. Build with game.zip baked into APK:
./make-android.sh path/to/game.zip --apk

# 3. Build and automatically install to connected phone:
./make-android.sh path/to/game.zip --install
```

### On Windows (PowerShell):
```powershell
# 1. Standard build
.\make-android.ps1

# 2. Build and bake game code:
.\make-android.ps1 -Zip path\to\game.zip

# 3. Build and install to phone:
.\make-android.ps1 -Zip path\to\game.zip -Install
```

### Building with Android Studio:
1. Build the Rust native library:
   ```bash
   cargo build --release --lib --target aarch64-linux-android
   ```
2. Copy `target/aarch64-linux-android/release/libmuguet.so` into:
   ```
   android/app/src/main/jniLibs/arm64-v8a/
   ```
3. Open the `android` folder in **Android Studio**.
4. Click **Run** or **Build > Build APK**.

---

## Game Assets Setup

Because game files are proprietary, you provide your own game copy as a `.zip` (the same folder holding `data/` and `b/<build>/` with `game.wasm` and `shaders/` from the web port).

You have two easy ways to load them onto Android:

### Method 1: In-App Importer (Easiest)
1. Transfer your `game.zip` anywhere on your phone (Downloads, Internal Storage, etc.).
2. Launch **Muguet** on your phone.
3. Tap **"Import game.zip"**.
4. Select your file using Android's Document Picker. Muguet will extract and configure the files automatically.

### Method 2: Push via ADB
```bash
adb push game_folder/ /sdcard/Android/data/ch.cclerc.muguet/files/game/
```

---

## Android Touch Controls

Muguet on Android includes built-in on-screen mobile controls:
- **Left Virtual Joystick**: Movement (Walking, Running, Sprinting by pushing outward).
- **Right Screen Drag**: Camera pan and look aiming.
- **Action Buttons**:
  - **On Foot**: `FIRE`, `AIM` (toggle latch), `JUMP`, `ENTER` / `EXIT`, `RELOAD`, `ACTION`, `DUCK`, `COVER`, `WEAPON` (weapon wheel), `SNACK`, `ARMOR`.
  - **In Vehicle**: `GAS`, `BRAKE`, `H.BRAKE` (handbrake), `EXIT`, `HORN`, `SHOOT` (drive-by), `RADIO`.
- **Gamepads**: Bluetooth and USB controllers (Xbox, DualShock/DualSense) are supported natively.

---

## Performance Presets

| Preset | Resolution Scale | Texture Quality | Target FPS | Best For |
| :--- | :--- | :--- | :--- | :--- |
| **Battery** | 35% | Normal | 30 FPS | Mid-range devices, low battery usage |
| **Balanced** | 50% | Normal | 60 FPS | Standard Snapdragon 7xx / 8xx |
| **Quality** | 75% | High | 60 FPS | Snapdragon 8 Gen 1/2/3, Dimensity 9000+ |
| **Max** | 100% | Very High | 60 FPS | High-end gaming phones / Tablets |
| **Custom** | 25% – 100% | Configurable | Uncapped / 90 / 120 | Manual tuning |

---

## Multiplayer

Host or join games with other players on Android, iOS, or macOS:
- UDP Port: **47520**
- One player taps **"Host Server"** in the launcher.
- Other players enter the host's IP address and tap **"PLAY GAME"**.
