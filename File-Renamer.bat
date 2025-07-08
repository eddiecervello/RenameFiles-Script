@echo off
setlocal
cd /d "%~dp0"
PowerShell -NoProfile -ExecutionPolicy RemoteSigned -File ".\RenameFiles.ps1"
