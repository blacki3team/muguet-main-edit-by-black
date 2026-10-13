@echo off
rem muguet - make-android.bat
rem Android Build & Packaging Script for Windows CMD

powershell -ExecutionPolicy Bypass -File "%~dp0make-android.ps1" %*
