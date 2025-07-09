@echo off
setlocal enabledelayedexpansion

REM Change to script directory
cd /d "%~dp0"

echo RenameFiles Script Runner
echo ========================
echo.

REM Check if PowerShell 7+ is available
pwsh --version >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: PowerShell 7+ not found. Please install from:
    echo https://github.com/PowerShell/PowerShell/releases
    echo.
    echo Trying with Windows PowerShell (limited compatibility)...
    powershell -ExecutionPolicy Bypass -File ".\RenameFiles.ps1" %*
) else (
    echo Using PowerShell 7+
    pwsh -ExecutionPolicy Bypass -File ".\RenameFiles.ps1" %*
)

if %errorlevel% neq 0 (
    echo.
    echo ================================
    echo Script execution failed!
    echo ================================
    echo.
    echo Common solutions:
    echo 1. Run setup wizard first:
    echo    pwsh -ExecutionPolicy Bypass -File .\Setup-RenameFiles.ps1
    echo.
    echo 2. Check if the path exists and is accessible
    echo.
    echo 3. Test with dry-run first:
    echo    pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Path "C:\Users\%USERNAME%\Downloads" -WhatIf
    echo.
    echo 4. Try manual execution:
    echo    pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Path "C:\Users\%USERNAME%\Downloads"
    echo.
    pause
) else (
    echo.
    echo ================================
    echo Script completed successfully!
    echo ================================
)