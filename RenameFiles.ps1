#requires -version 7.0
<#
.SYNOPSIS
    Cross-platform file renaming utility for cleaning up filenames
.DESCRIPTION
    Renames files created today by replacing spaces with dashes and removing numeric suffixes
.EXAMPLE
    .\RenameFiles.ps1 -Path C:\Users\Downloads
.EXAMPLE
    .\RenameFiles.ps1 -Monitor -Path C:\Users\Downloads
.EXAMPLE
    .\RenameFiles.ps1 -Path C:\Users\Downloads -WhatIf
.NOTES
    If you get execution policy errors, run:
    pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 [parameters]
    
    Or run the setup wizard first:
    pwsh -ExecutionPolicy Bypass -File .\Setup-RenameFiles.ps1
#>

#region PowerShell 7+ version check
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7.0 or higher. Please install PowerShell 7+ from https://aka.ms/pwsh and run with 'pwsh'."
    Write-Host "Download from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Yellow
    exit 1
}
#endregion

#region Execution Policy Check
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($executionPolicy -eq 'Restricted' -or $executionPolicy -eq 'AllSigned') {
    Write-Warning "PowerShell execution policy is restrictive: $executionPolicy"
    Write-Host "To fix this, run one of these commands:" -ForegroundColor Yellow
    Write-Host "1. Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Green
    Write-Host "2. Or run with: pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 [parameters]" -ForegroundColor Green
    Write-Host "3. Or run the setup wizard: pwsh -ExecutionPolicy Bypass -File .\Setup-RenameFiles.ps1" -ForegroundColor Green
    Write-Host ""
}
#endregion

param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Path,
    [switch]$Background,
    [switch]$RegisterStartup,
    [switch]$UnregisterStartup,
    [switch]$Monitor,
    [ValidateSet('INFO','DEBUG','VERBOSE')]
    [string]$LogLevel = 'INFO',
    [string]$LogFile,
    [ValidateSet('US', 'ISO', 'European')]
    [string]$DateFormat,
    [string[]]$Extensions,
    [switch]$IncludeSubdirectories,
    [int]$MaxRetries = 3,
    [int]$MonitorInterval = 5,
    [switch]$Setup,
    [switch]$WhatIf
)

# Handle setup wizard
if ($Setup) {
    $setupScript = Join-Path $PSScriptRoot "Setup-RenameFiles.ps1"
    if (Test-Path $setupScript) {
        & $setupScript
        exit 0
    } else {
        Write-Error "Setup script not found: $setupScript"
        exit 1
    }
}

# Load configuration if it exists
$configPath = Join-Path $PSScriptRoot "RenameFiles-Config.json"
$config = $null
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        Write-Verbose "Loaded configuration from: $configPath"
    } catch {
        Write-Warning "Failed to load configuration: $($_.Exception.Message)"
    }
}

# Set defaults from config or fallback defaults
if (-not $Path) {
    $Path = if ($config -and $config.WatchPath) { 
        $config.WatchPath 
    } else { 
        (Get-Location).Path 
    }
}

if (-not $DateFormat) {
    $DateFormat = if ($config -and $config.DateFormat) { 
        $config.DateFormat 
    } else { 
        'US' 
    }
}

if (-not $Extensions) {
    $Extensions = if ($config -and $config.Extensions) { 
        $config.Extensions 
    } else { 
        @('*') 
    }
}

if (-not $PSBoundParameters.ContainsKey('IncludeSubdirectories')) {
    $IncludeSubdirectories = if ($config -and $config.PSObject.Properties['IncludeSubdirectories']) { 
        $config.IncludeSubdirectories 
    } else { 
        $true 
    }
}

# Import module
try {
    Import-Module "$PSScriptRoot/RenameFiles/RenameFiles.psd1" -Force
} catch {
    Write-Error "Failed to import RenameFiles module: $($_.Exception.Message)"
    Write-Host "Make sure the RenameFiles directory and module files exist." -ForegroundColor Yellow
    exit 1
}

function Register-StartupTask {
    if (-not $IsWindows) {
        Write-Warning "Startup registration is only supported on Windows. Use your system's startup mechanisms on other platforms."
        return
    }
    
    try {
        # Validate path security
        if ($Path -match '\.\./|\.\.\\|\.\.' -or $Path -match '[<>:"|?*]') {
            throw "Invalid path contains dangerous characters: $Path"
        }
        
        $resolvedPath = Resolve-Path $Path -ErrorAction Stop
        if (-not (Test-Path $resolvedPath -PathType Container)) {
            throw "Path is not a valid directory: $Path"
        }
        
        $startup = [Environment]::GetFolderPath('Startup')
        $target = (Get-Command pwsh -ErrorAction Stop).Source
        
        # Create startup script instead of shortcut for better security
        $startupScript = Join-Path $startup 'RenameFiles-Startup.ps1'
        $generatedDate = Get-Date
        $scriptContent = @"
# RenameFiles Startup Script - Generated $generatedDate
# Validates path before execution
if (Test-Path "$resolvedPath" -PathType Container) {
    try {
        & "$target" -NoProfile -ExecutionPolicy RemoteSigned -File "$PSScriptRoot\RenameFiles.ps1" -Monitor -Path "$resolvedPath"
    } catch {
        Write-EventLog -LogName Application -Source "RenameFiles" -EntryType Error -EventId 1000 -Message "RenameFiles startup failed: `$(`$_.Exception.Message)"
    }
} else {
    Write-EventLog -LogName Application -Source "RenameFiles" -EntryType Warning -EventId 1001 -Message "RenameFiles startup skipped - path not found: $resolvedPath"
}
"@
        
        Set-Content -Path $startupScript -Value $scriptContent -Force
        
        Write-Host "Registered startup script: $startupScript" -ForegroundColor Green
        Write-Host "Target path: $resolvedPath" -ForegroundColor Green
        Write-Host "Note: Using startup script instead of shortcut for security" -ForegroundColor Yellow
    } catch {
        Write-Error "Failed to register startup task: $($_.Exception.Message)"
    }
}

function Unregister-StartupTask {
    if (-not $IsWindows) {
        Write-Warning "Startup registration is only supported on Windows."
        return
    }
    
    try {
        $startup = [Environment]::GetFolderPath('Startup')
        $shortcut = Join-Path $startup 'RenameFiles.lnk'
        $startupScript = Join-Path $startup 'RenameFiles-Startup.ps1'
        
        $removed = $false
        
        if (Test-Path $shortcut) { 
            Remove-Item $shortcut -Force
            Write-Host "Removed startup shortcut: $shortcut" -ForegroundColor Green
            $removed = $true
        }
        
        if (Test-Path $startupScript) {
            Remove-Item $startupScript -Force
            Write-Host "Removed startup script: $startupScript" -ForegroundColor Green
            $removed = $true
        }
        
        if (-not $removed) {
            Write-Host "No startup task found." -ForegroundColor Yellow
        }
    } catch {
        Write-Error "Failed to unregister startup task: $($_.Exception.Message)"
    }
}

if ($RegisterStartup) { Register-StartupTask; exit }
if ($UnregisterStartup) { Unregister-StartupTask; exit }

if ($Background) {
    try {
        # Build argument list for background process
        $argList = @(
            '-NoProfile',
            '-ExecutionPolicy', 'RemoteSigned',
            '-File', "`"$PSCommandPath`"",
            '-Path', "`"$Path`"",
            '-LogLevel', $LogLevel
        )
        
        if ($LogFile) { $argList += @('-LogFile', "`"$LogFile`"") }
        if ($DateFormat -ne 'US') { $argList += @('-DateFormat', $DateFormat) }
        if ($Extensions -ne @('*')) { 
            $extensionString = $Extensions -join ','
            $argList += @('-Extensions', $extensionString) 
        }
        if (-not $IncludeSubdirectories) { $argList += '-IncludeSubdirectories:$false' }
        if ($MaxRetries -ne 3) { $argList += @('-MaxRetries', $MaxRetries) }
        if ($Monitor) { $argList += '-Monitor' }
        
        if ($IsWindows) {
            $process = Start-Process pwsh -ArgumentList $argList -WindowStyle Hidden -PassThru
            Write-Host "Started in background (PID: $($process.Id))" -ForegroundColor Green
        } else {
            $job = Start-Job -ScriptBlock { 
                pwsh -NoProfile -ExecutionPolicy RemoteSigned -File $using:PSCommandPath @using:PSBoundParameters
            }
            Write-Host "Started background job (ID: $($job.Id))" -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to start background process: $($_.Exception.Message)"
    }
    exit
}

if ($Monitor) {
    Write-Host "Starting file monitoring mode" -ForegroundColor Cyan
    Write-Host "Path: $Path" -ForegroundColor Cyan
    Write-Host "Check interval: $MonitorInterval seconds" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to exit monitoring" -ForegroundColor Cyan
    
    if ($IsWindows) {
        try {
            $fsw = New-Object IO.FileSystemWatcher $Path, '*.*'
            $fsw.IncludeSubdirectories = $IncludeSubdirectories
            $fsw.EnableRaisingEvents = $true
            
            # Track last processing time to avoid rapid-fire triggers
            $lastRun = [DateTime]::MinValue
            
            $action = {
                $now = Get-Date
                if (($now - $script:lastRun).TotalSeconds -ge $using:MonitorInterval) {
                    Write-Host "File change detected, running rename operation..." -ForegroundColor Yellow
                    $renameParams = @{
                        Path = $using:Path
                        LogLevel = $using:LogLevel
                        DateFormat = $using:DateFormat
                        Extensions = $using:Extensions
                        IncludeSubdirectories = $using:IncludeSubdirectories
                        MaxRetries = $using:MaxRetries
                    }
                    if ($using:LogFile) { $renameParams.LogFile = $using:LogFile }
                    
                    $result = Rename-TodaysFiles @renameParams
                    if ($result.RenamedFiles -gt 0) {
                        Write-Host "Renamed $($result.RenamedFiles) files" -ForegroundColor Green
                    }
                    $script:lastRun = $now
                }
            }
            
            $onChange = Register-ObjectEvent $fsw Changed -Action $action
            $onCreate = Register-ObjectEvent $fsw Created -Action $action
            
            Write-Host "FileSystemWatcher started. Monitoring for file changes..." -ForegroundColor Green
            
            try {
                while ($true) { Start-Sleep 60 }
            } finally {
                $fsw.EnableRaisingEvents = $false
                Unregister-Event -SourceIdentifier $onChange.Name -ErrorAction SilentlyContinue
                Unregister-Event -SourceIdentifier $onCreate.Name -ErrorAction SilentlyContinue
                $fsw.Dispose()
            }
        } catch {
            Write-Error "Error in file monitoring: $($_.Exception.Message)"
        }
    } else {
        if (Get-Command inotifywait -ErrorAction SilentlyContinue) {
            Write-Host "Using inotifywait for file monitoring (Linux/macOS)" -ForegroundColor Green
            try {
                while ($true) {
                    $watchArgs = @('-e', 'create,modify,move', '--timeout', '60')
                    if ($IncludeSubdirectories) { $watchArgs += '-r' }
                    $watchArgs += $Path
                    
                    $null = & inotifywait @watchArgs 2>/dev/null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "File change detected, running rename operation..." -ForegroundColor Yellow
                        $renameParams = @{
                            Path = $Path
                            LogLevel = $LogLevel
                            DateFormat = $DateFormat
                            Extensions = $Extensions
                            IncludeSubdirectories = $IncludeSubdirectories
                            MaxRetries = $MaxRetries
                        }
                        if ($LogFile) { $renameParams.LogFile = $LogFile }
                        
                        $result = Rename-TodaysFiles @renameParams
                        if ($result.RenamedFiles -gt 0) {
                            Write-Host "Renamed $($result.RenamedFiles) files" -ForegroundColor Green
                        }
                        Start-Sleep $MonitorInterval
                    }
                }
            } catch {
                Write-Error "Error in inotifywait monitoring: $($_.Exception.Message)"
            }
        } else {
            Write-Error "inotifywait not found. Please install inotify-tools: apt-get install inotify-tools (Ubuntu/Debian) or brew install inotify-tools (macOS)"
            exit 1
        }
    }
    exit
}

# Security validation for path parameter
try {
    # Check for path traversal attempts
    if ($Path -match '\.\./|\.\.\\|\.\.' -or $Path -match '[<>:"|?*]') {
        Write-Error "Path contains invalid or dangerous characters: $Path"
        exit 1
    }
    
    # Resolve and validate path
    $resolvedPath = Resolve-Path $Path -ErrorAction Stop
    if (-not (Test-Path $resolvedPath -PathType Container)) {
        Write-Error "Path does not exist or is not a directory: $Path"
        exit 1
    }
    
    # Update Path to use resolved path
    $Path = $resolvedPath.Path
    
    # Additional security check - ensure path is not a system directory
    $systemPaths = @(
        $env:SystemRoot,
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        "$env:SystemRoot\System32",
        "$env:SystemRoot\SysWOW64"
    )
    
    foreach ($sysPath in $systemPaths) {
        if ($sysPath -and $Path.StartsWith($sysPath, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Warning "WARNING: Operating on system directory. Use with caution: $Path"
            break
        }
    }
    
} catch {
    Write-Error "Invalid path: $($_.Exception.Message)"
    exit 1
}

# Show first-run help if no config exists and no parameters provided
if (-not $config -and $args.Count -eq 0 -and -not $PSBoundParameters.Keys) {
    Write-Host "" 
    Write-Host "Welcome to RenameFiles!" -ForegroundColor Cyan
    Write-Host "" 
    Write-Host "This appears to be your first run. Here are your options:" -ForegroundColor Yellow
    Write-Host "" 
    Write-Host "1. Run the setup wizard (recommended):" -ForegroundColor Green
    Write-Host "   pwsh -ExecutionPolicy Bypass -File .\Setup-RenameFiles.ps1" -ForegroundColor White
    Write-Host "" 
    Write-Host "2. Or run directly with a path:" -ForegroundColor Green
    Write-Host "   pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Path 'C:\Users\$env:USERNAME\Downloads'" -ForegroundColor White
    Write-Host "" 
    Write-Host "3. Test first with dry-run:" -ForegroundColor Green
    Write-Host "   pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Path 'C:\Users\$env:USERNAME\Downloads' -WhatIf" -ForegroundColor White
    Write-Host "" 
    exit 0
}

# Build parameters for the main function
$renameParams = @{
    Path = $Path
    LogLevel = $LogLevel
    DateFormat = $DateFormat
    Extensions = $Extensions
    IncludeSubdirectories = $IncludeSubdirectories
    MaxRetries = $MaxRetries
}

if ($LogFile) {
    $renameParams.LogFile = $LogFile
}

if ($WhatIf) {
    $renameParams.WhatIf = $true
}

try {
    if ($WhatIf) {
        Write-Host "DRY RUN MODE - No files will be renamed" -ForegroundColor Yellow
    }
    Write-Host "Starting file rename operation" -ForegroundColor Cyan
    Write-Host "Path: $Path" -ForegroundColor Gray
    $extensionList = $Extensions -join ', '
    Write-Host "Extensions: $extensionList" -ForegroundColor Gray
    Write-Host "Date format: $DateFormat" -ForegroundColor Gray
    Write-Host "Include subdirectories: $IncludeSubdirectories" -ForegroundColor Gray
    Write-Host ""
    
    $result = Rename-TodaysFiles @renameParams
    
    if ($result.TotalFiles -eq 0) {
        Write-Host "No files found to process" -ForegroundColor Yellow
    } else {
        Write-Host "" 
        Write-Host "Operation completed successfully" -ForegroundColor Green
        Write-Host "Total files: $($result.TotalFiles)" -ForegroundColor Cyan
        Write-Host "Renamed: $($result.RenamedFiles)" -ForegroundColor Green
        Write-Host "Skipped: $($result.SkippedFiles)" -ForegroundColor Yellow
        if ($result.ErrorFiles -gt 0) {
            Write-Host "Errors: $($result.ErrorFiles)" -ForegroundColor Red
        }
    }
    
    exit 0
} catch {
    Write-Error "Error during file rename operation: $($_.Exception.Message)"
    Write-Host "Try running with -WhatIf first to test the operation." -ForegroundColor Yellow
    exit 1
}