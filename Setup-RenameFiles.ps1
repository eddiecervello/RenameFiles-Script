#requires -version 7.0
<#
.SYNOPSIS
    Initial setup wizard for RenameFiles utility
.DESCRIPTION
    Sets up RenameFiles with user-specified watch directory and execution preferences
.EXAMPLE
    .\Setup-RenameFiles.ps1
#>

param(
    [switch]$Force
)

# PowerShell 7+ version check
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7.0 or higher. Please install PowerShell 7+ from https://aka.ms/pwsh"
    exit 1
}

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "  RenameFiles Setup Wizard" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

# Check execution policy
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
Write-Host "Current PowerShell execution policy: $executionPolicy" -ForegroundColor Yellow

if ($executionPolicy -eq 'Restricted' -or $executionPolicy -eq 'AllSigned') {
    Write-Host ""
    Write-Host "WARNING: Current execution policy prevents running unsigned scripts." -ForegroundColor Red
    Write-Host "To fix this issue, you have several options:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Run this command to allow local scripts (RECOMMENDED):" -ForegroundColor Green
    Write-Host "   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Run scripts with bypass (for this session only):" -ForegroundColor Green
    Write-Host "   pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1" -ForegroundColor White
    Write-Host ""
    
    $response = Read-Host "Would you like to set the execution policy to RemoteSigned for CurrentUser? (y/N)"
    if ($response -match '^[Yy]') {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Host "✓ Execution policy updated successfully!" -ForegroundColor Green
        } catch {
            Write-Error "Failed to update execution policy: $($_.Exception.Message)"
            Write-Host "Please run as administrator or use the bypass method above." -ForegroundColor Yellow
        }
    }
    Write-Host ""
}

# Get watch directory
Write-Host "Setup Configuration" -ForegroundColor Cyan
Write-Host "-" * 20 -ForegroundColor Cyan

$defaultPath = "$env:USERPROFILE\Downloads"
if (-not $IsWindows) {
    $defaultPath = "$env:HOME/Downloads"
}

do {
    Write-Host ""
    Write-Host "Enter the directory to watch for file renaming:" -ForegroundColor Yellow
    Write-Host "Default: $defaultPath" -ForegroundColor Gray
    $watchPath = Read-Host "Path"
    
    if (-not $watchPath) {
        $watchPath = $defaultPath
    }
    
    # Validate path
    try {
        $resolvedPath = Resolve-Path $watchPath -ErrorAction Stop
        if (Test-Path $resolvedPath -PathType Container) {
            Write-Host "✓ Valid directory: $($resolvedPath.Path)" -ForegroundColor Green
            $watchPath = $resolvedPath.Path
            break
        } else {
            Write-Host "✗ Path is not a directory" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Path does not exist: $watchPath" -ForegroundColor Red
        $create = Read-Host "Create this directory? (y/N)"
        if ($create -match '^[Yy]') {
            try {
                New-Item -Path $watchPath -ItemType Directory -Force | Out-Null
                Write-Host "✓ Directory created: $watchPath" -ForegroundColor Green
                break
            } catch {
                Write-Host "✗ Failed to create directory: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
} while ($true)

# Get preferences
Write-Host ""
Write-Host "Configuration Options" -ForegroundColor Cyan
Write-Host "-" * 20 -ForegroundColor Cyan

$includeSubdirs = Read-Host "Include subdirectories? (Y/n)"
$includeSubdirs = $includeSubdirs -notmatch '^[Nn]'

$dateFormat = Read-Host "Date format for conflicts (US/ISO/European) [US]"
if (-not $dateFormat) { $dateFormat = "US" }
if ($dateFormat -notin @('US', 'ISO', 'European')) { $dateFormat = "US" }

$extensions = Read-Host "File extensions to process (comma-separated, * for all) [*]"
if (-not $extensions) { $extensions = "*" }

$autostart = $false
if ($IsWindows) {
    $autostart = Read-Host "Start automatically with Windows? (y/N)"
    $autostart = $autostart -match '^[Yy]'
}

# Create configuration file
$configPath = Join-Path $PSScriptRoot "RenameFiles-Config.json"
$config = @{
    WatchPath = $watchPath
    IncludeSubdirectories = $includeSubdirs
    DateFormat = $dateFormat
    Extensions = $extensions -split ',' | ForEach-Object { $_.Trim() }
    AutoStart = $autostart
    SetupDate = (Get-Date).ToString('o')
    Version = "1.0.0"
}

try {
    $config | ConvertTo-Json -Depth 3 | Set-Content -Path $configPath -Force
    Write-Host ""
    Write-Host "✓ Configuration saved to: $configPath" -ForegroundColor Green
} catch {
    Write-Error "Failed to save configuration: $($_.Exception.Message)"
    exit 1
}

# Setup auto-start if requested
if ($autostart -and $IsWindows) {
    try {
        $scriptPath = Join-Path $PSScriptRoot "RenameFiles.ps1"
        $startupArgs = "-Monitor -Path `"$watchPath`" -DateFormat $dateFormat"
        if ($includeSubdirs) { $startupArgs += " -IncludeSubdirectories" }
        if ($extensions -ne "*") { 
            $extList = ($config.Extensions | ForEach-Object { $_ }) -join ","
            $startupArgs += " -Extensions $extList"
        }
        
        # Call the register function from the main script
        & $scriptPath -RegisterStartup -Path $watchPath
        Write-Host "✓ Auto-start configured" -ForegroundColor Green
    } catch {
        Write-Warning "Failed to setup auto-start: $($_.Exception.Message)"
    }
}

# Show usage instructions
Write-Host ""
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Run once on current files:" -ForegroundColor White
Write-Host "   pwsh .\RenameFiles.ps1 -Path `"$watchPath`"" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Start monitoring mode:" -ForegroundColor White
Write-Host "   pwsh .\RenameFiles.ps1 -Monitor -Path `"$watchPath`"" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Test with dry-run:" -ForegroundColor White
Write-Host "   pwsh .\RenameFiles.ps1 -Path `"$watchPath`" -WhatIf" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Run in background:" -ForegroundColor White
Write-Host "   pwsh .\RenameFiles.ps1 -Background -Monitor -Path `"$watchPath`"" -ForegroundColor Gray
Write-Host ""

if ($executionPolicy -in @('Restricted', 'AllSigned')) {
    Write-Host "Note: If you still get execution policy errors, run:" -ForegroundColor Yellow
    Write-Host "pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 [parameters]" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Configuration file: $configPath" -ForegroundColor Cyan
Write-Host "Watch directory: $watchPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Setup completed successfully!" -ForegroundColor Green