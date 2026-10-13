#!/bin/sh
# muguet - make-android.sh
# Android Build & Packaging Script for Muguet

set -eu
cd "$(dirname "$0")"

ZIP=""
MODE=""
DEVICE=""
for a in "$@"; do
  case "$a" in
    *.zip|*.wasm) ZIP="$a" ;;
    --install|--apk) MODE="$a" ;;
    *) DEVICE="$a" ;;
  esac
done

TARGET="aarch64-linux-android"
HEAP_GB=6
export MUGUET_HEAP_GB="${MUGUET_HEAP_GB:-$HEAP_GB}"

echo "============================================="
echo " Building Muguet for Android ($TARGET)"
echo "============================================="

# 1. Build host tool if game zip provided for patching/precompilation
if [ -n "$ZIP" ]; then
  echo "[1/4] Building host patch tool..."
  cargo build --release --bin muguet
  mkdir -p target/android-game
  case "$ZIP" in
    *.zip)
      ENTRY="$(unzip -Z1 "$ZIP" 2>/dev/null | grep -E '(^|/)b/[^/]+/game\.wasm$' | head -1 || true)"
      if [ -n "$ENTRY" ]; then
        unzip -p "$ZIP" "$ENTRY" > target/android-game/game.wasm
      else
        echo "Note: No b/<build>/game.wasm in zip, searching for any game.wasm..."
        ENTRY="$(unzip -Z1 "$ZIP" 2>/dev/null | grep 'game\.wasm$' | head -1 || true)"
        [ -n "$ENTRY" ] || { echo "Error: $ZIP has no game.wasm"; exit 1; }
        unzip -p "$ZIP" "$ENTRY" > target/android-game/game.wasm
      fi
      ;;
    *) cp "$ZIP" target/android-game/game.wasm ;;
  esac

  echo "[2/4] Patching game.wasm with multiplayer hooks..."
  ./target/release/muguet --patch target/android-game/game.wasm target/android-game/game.patched.wasm
  mv target/android-game/game.patched.wasm target/android-game/game.wasm

  if command -v wasm-opt >/dev/null 2>&1; then
    echo "Optimizing with wasm-opt -O3..."
    wasm-opt target/android-game/game.wasm -O3 -g --enable-memory64 --enable-threads --enable-bulk-memory --enable-mutable-globals \
      --enable-sign-ext --enable-nontrapping-float-to-int --enable-simd --enable-multivalue --enable-reference-types --enable-multimemory \
      -o target/android-game/game.opt.wasm && mv target/android-game/game.opt.wasm target/android-game/game.wasm
  fi

  echo "Precompiling for Android AArch64..."
  ./target/release/muguet --precompile-android target/android-game/game.wasm target/android-game/game.cwasm
  rm target/android-game/game.wasm
  export MUGUET_GAME_CODE="$PWD/target/android-game/game.cwasm"
else
  echo "[1/4] No game zip provided: building engine with JIT/dynamic loader support"
  unset MUGUET_GAME_CODE || true
fi

# 2. Build Rust native library for Android
echo "[3/4] Compiling native library for $TARGET..."
cargo build --release --lib --target "$TARGET"

# Copy libmuguet.so to Android jniLibs
mkdir -p android/app/src/main/jniLibs/arm64-v8a
cp "target/$TARGET/release/libmuguet.so" android/app/src/main/jniLibs/arm64-v8a/

# 3. Assemble APK using Gradle
echo "[4/4] Assembling APK..."
mkdir -p build
(
  cd android
  if [ -f "./gradlew" ]; then
    ./gradlew assembleRelease
  elif command -v gradle >/dev/null 2>&1; then
    gradle assembleRelease
  else
    echo "Warning: Gradle not found in PATH or project. Built libmuguet.so in android/app/src/main/jniLibs/arm64-v8a/"
    echo "Open the 'android' folder in Android Studio to build and run the APK."
    exit 0
  fi
)

APK="$(find android/app/build/outputs/apk/release -name "*.apk" 2>/dev/null | head -1 || true)"
if [ -n "$APK" ]; then
  cp "$APK" build/Muguet.apk
  echo "SUCCESS: Built build/Muguet.apk ($(du -h build/Muguet.apk | cut -f1))"
fi

# 4. Install via ADB if requested
if [ "$MODE" = "--install" ]; then
  echo "Installing to connected Android device..."
  ADB_ARGS=""
  if [ -n "$DEVICE" ]; then
    ADB_ARGS="-s $DEVICE"
  fi
  adb $ADB_ARGS install -r build/Muguet.apk
  echo "Installed on device! Launching Muguet..."
  adb $ADB_ARGS shell am start -n ch.cclerc.muguet/.LauncherActivity
fi
