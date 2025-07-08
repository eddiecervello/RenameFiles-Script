@echo off
setlocal enabledelayedexpansion

REM Change to script directory
cd /d "%~dp0"

REM Check if PowerShell 7+ is available
pwsh --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell 7+ not found. Please install from:
    echo https://github.com/PowerShell/PowerShell/releases
    echo.
    echo Trying with Windows PowerShell...
    powershell -ExecutionPolicy Bypass -File ".\RenameFiles.ps1" %*
) else (
    echo Using PowerShell 7+
    pwsh -ExecutionPolicy Bypass -File ".\RenameFiles.ps1" %*
)

if %errorlevel% neq 0 (
    echo.
    echo Script execution failed. Common solutions:
    echo 1. Run setup wizard: pwsh -ExecutionPolicy Bypass -File .\Setup-RenameFiles.ps1
    echo 2. Check if path exists and is accessible
    echo 3. Run with -WhatIf to test first
    pause
)