@echo off
rem muguet - make-android-app.bat
rem 1-Click Android App Builder for Windows

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0make-android-app.ps1" %*
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo If access was denied, run this directly in PowerShell:
    echo     .\make-android-app.ps1
    echo.
)
pause
