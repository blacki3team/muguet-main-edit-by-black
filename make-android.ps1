# muguet - make-android.ps1
# Android Build & Packaging Script for Windows PowerShell

param(
    [string]$Zip = "",
    [switch]$Install,
    [string]$Device = ""
)

# Project paths & workspace support
$ProjectDirs = @(
    "C:\Users\ULTRAPC\Desktop\muguet-main\muguet-main",
    "C:\Users\ULTRAPC\Desktop\muguet-main",
    $PSScriptRoot
)
foreach ($dir in $ProjectDirs) {
    if ($null -ne $dir -and (Test-Path "$dir\Cargo.toml")) {
        Set-Location $dir
        break
    }
}

# Auto-detect Cargo and Rust
if (Test-Path "$env:USERPROFILE\.cargo\bin") {
    $env:PATH = "$env:USERPROFILE\.cargo\bin;" + $env:PATH
}

# Auto-detect Adoptium JDK 17
if ($null -eq $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    $jdk = Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory -Filter "jdk-17*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $jdk) {
        $env:JAVA_HOME = $jdk.FullName
        $env:PATH = "$($jdk.FullName)\bin;" + $env:PATH
    }
}

# Auto-find game.zip if not specified
if ($Zip -eq "") {
    $possibleZips = @(
        "C:\Users\ULTRAPC\Desktop\muguet-main\game.zip",
        "C:\Users\ULTRAPC\Desktop\muguet-main\muguet-main\game.zip",
        "$PSScriptRoot\game.zip",
        "$env:USERPROFILE\Downloads\game.zip"
    )
    foreach ($pz in $possibleZips) {
        if (Test-Path $pz) {
            $Zip = $pz
            Write-Host "Found game package at: $Zip" -ForegroundColor Cyan
            break
        }
    }
}

$ErrorActionPreference = "Stop"
$Target = "aarch64-linux-android"
$HeapGB = 6
$env:MUGUET_HEAP_GB = $HeapGB

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Building Muguet for Android ($Target)" -ForegroundColor Cyan
Write-Host " Workspace: $PWD" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Process game zip if provided
if ($Zip -ne "" -and (Test-Path $Zip)) {
    Write-Host "[1/4] Building host patch tool..." -ForegroundColor Yellow
    cargo build --release --bin muguet
    if ($LASTEXITCODE -ne 0) { throw "Cargo build failed" }

    New-Item -ItemType Directory -Force -Path "target\android-game" | Out-Null
    
    Write-Host "[2/4] Extracting and patching game.wasm..." -ForegroundColor Yellow
    # Extract game.wasm
    tar -xf $Zip -C "target\android-game" "*game.wasm" 2>$null
    $found = Get-ChildItem -Path "target\android-game" -Recurse -Filter "game.wasm" | Select-Object -First 1
    if ($null -ne $found) {
        Move-Item -Force $found.FullName "target\android-game\game.wasm"
    } else {
        throw "Could not find game.wasm inside $Zip"
    }

    # Patch with MP hooks
    .\target\release\muguet.exe --patch target\android-game\game.wasm target\android-game\game.patched.wasm
    Move-Item -Force target\android-game\game.patched.wasm target\android-game\game.wasm

    # Precompile for Android
    Write-Host "Precompiling for Android AArch64..." -ForegroundColor Yellow
    .\target\release\muguet.exe --precompile-android target\android-game\game.wasm target\android-game\game.cwasm
    Remove-Item -Force target\android-game\game.wasm
    $env:MUGUET_GAME_CODE = (Resolve-Path "target\android-game\game.cwasm").Path
} else {
    Write-Host "[1/4] No game zip provided: building with JIT runtime support" -ForegroundColor Gray
}

# 2. Build Android native shared library
Write-Host "[3/4] Compiling native shared library for $Target..." -ForegroundColor Yellow
cargo build --release --lib --target $Target
if ($LASTEXITCODE -ne 0) { throw "Native Android library build failed" }

# Copy into Android jniLibs
New-Item -ItemType Directory -Force -Path "android\app\src\main\jniLibs\arm64-v8a" | Out-Null
Copy-Item -Force "target\$Target\release\libmuguet.so" "android\app\src\main\jniLibs\arm64-v8a\"
Write-Host "Copied libmuguet.so to android/app/src/main/jniLibs/arm64-v8a/" -ForegroundColor Green

# 3. Assemble APK
Write-Host "[4/4] Assembling APK..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "build" | Out-Null
Push-Location android
try {
    if (Test-Path ".\gradlew.bat") {
        .\gradlew.bat assembleRelease
    } elseif (Get-Command "gradle" -ErrorAction SilentlyContinue) {
        gradle assembleRelease
    } else {
        Write-Host "Notice: Gradle wrapper not yet generated. You can open the 'android' folder directly in Android Studio to build the APK!" -ForegroundColor Yellow
    }
} finally {
    Pop-Location
}

$Apk = Get-ChildItem -Path "android\app\build\outputs\apk\release\*.apk" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $Apk) {
    Copy-Item -Force $Apk.FullName "build\gtav.apk"
    Write-Host "SUCCESS: Built build\gtav.apk" -ForegroundColor Green
}

# 4. Install via ADB if requested
if ($Install) {
    Write-Host "Installing to connected Android device..." -ForegroundColor Cyan
    $AdbArgs = @()
    if ($Device -ne "") { $AdbArgs += "-s", $Device }
    $AdbArgs += "install", "-r", "build\gtav.apk"
    & adb $AdbArgs
    & adb shell am start -n ch.cclerc.muguet/.LauncherActivity
}
