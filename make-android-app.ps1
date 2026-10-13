# muguet - make-android-app.ps1
# 1-Click Android App Builder & Environment Checker for Windows

param(
    [string]$Zip = "",
    [switch]$Install,
    [switch]$Setup
)

# Ensure Cargo/Rust bin is in PATH even if terminal was not restarted
if (Test-Path "$env:USERPROFILE\.cargo\bin") {
    $env:PATH = "$env:USERPROFILE\.cargo\bin;" + $env:PATH
}

Write-Host "=====================================================" -ForegroundColor Green
Write-Host "            MUGUET - ANDROID APP BUILDER             " -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host ""

# Step 1: Check Rust
$hasRust = $false
try {
    $rustVer = & rustc --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $null -ne $rustVer) {
        Write-Host "[OK] Rust is installed: $rustVer" -ForegroundColor Green
        $hasRust = $true
    }
} catch {}

if (-not $hasRust) {
    Write-Host "[!] Rust is not installed or not in PATH." -ForegroundColor Yellow
    Write-Host "    Install Rust with: winget install Rustlang.Rustup" -ForegroundColor Cyan
    Write-Host "    Or download from: https://rustup.rs" -ForegroundColor Cyan
}

# Step 2: Check Rust Android Target
if ($hasRust) {
    $targets = & rustup target list --installed 2>$null
    if ($targets -contains "aarch64-linux-android") {
        Write-Host "[OK] Android target (aarch64-linux-android) is installed." -ForegroundColor Green
    } else {
        Write-Host "[!] Target aarch64-linux-android is missing." -ForegroundColor Yellow
        Write-Host "    Installing target now..." -ForegroundColor Cyan
        & rustup target add aarch64-linux-android
    }
}

# Step 3: Check Android NDK & SDK
$hasNdk = $false
$ndkPath = $env:ANDROID_NDK_HOME
if ($null -eq $ndkPath -or -not (Test-Path $ndkPath)) {
    $ndkPath = $env:NDK_HOME
}
if ($null -eq $ndkPath -or -not (Test-Path $ndkPath)) {
    # Check default paths
    $defaultSdk = "$env:LOCALAPPDATA\Android\Sdk\ndk"
    if (Test-Path $defaultSdk) {
        $latestNdk = Get-ChildItem -Path $defaultSdk -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($null -ne $latestNdk) {
            $ndkPath = $latestNdk.FullName
            $env:ANDROID_NDK_HOME = $ndkPath
        }
    }
}

if ($null -ne $ndkPath -and (Test-Path $ndkPath)) {
    Write-Host "[OK] Android NDK found at: $ndkPath" -ForegroundColor Green
    $hasNdk = $true
} else {
    Write-Host "[!] Android NDK not detected." -ForegroundColor Yellow
    Write-Host "    You can install it via Android Studio (SDK Manager > SDK Tools > NDK)" -ForegroundColor Cyan
    Write-Host "    Or set: `$env:ANDROID_NDK_HOME = 'C:\path\to\ndk'" -ForegroundColor Cyan
}

# Step 4: Check ADB (Android Debug Bridge)
$hasAdb = $false
try {
    $adbVer = & adb version 2>$null
    if ($LASTEXITCODE -eq 0 -and $null -ne $adbVer) {
        Write-Host "[OK] ADB is available." -ForegroundColor Green
        $hasAdb = $true
    }
} catch {}

if ($hasAdb) {
    $devices = & adb devices | Select-String -Pattern "device$"
    if ($devices.Count -gt 0) {
        Write-Host "[OK] Connected Android device(s) found!" -ForegroundColor Green
    } else {
        Write-Host "[i] No Android device currently connected via USB." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "-----------------------------------------------------" -ForegroundColor Gray

# If requirements are met, run build
if ($hasRust -and $hasNdk) {
    Write-Host "Starting build process..." -ForegroundColor Cyan
    & powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\make-android.ps1" -Zip $Zip -Install:$Install
} else {
    Write-Host "BUILD OPTIONS:" -ForegroundColor White
    Write-Host ""
    Write-Host "Option 1: Build automatically in the cloud with GitHub Actions (Zero local setup!)" -ForegroundColor Yellow
    Write-Host "  1. Push this project to your GitHub repository." -ForegroundColor Gray
    Write-Host "  2. Go to the 'Actions' tab and select 'Build Android APK'." -ForegroundColor Gray
    Write-Host "  3. Download the built 'Muguet-Android-APK' directly!" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 2: Build using Android Studio" -ForegroundColor Yellow
    Write-Host "  1. Open Android Studio." -ForegroundColor Gray
    Write-Host "  2. Open the folder: $PSScriptRoot\android" -ForegroundColor Gray
    Write-Host "  3. Click 'Build > Build Bundle(s) / APK(s) > Build APK(s)'." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 3: Install local command-line tools" -ForegroundColor Yellow
    Write-Host "  Run: winget install Rustlang.Rustup" -ForegroundColor Gray
    Write-Host "  Run: winget install Google.AndroidStudio" -ForegroundColor Gray
    Write-Host ""
}
