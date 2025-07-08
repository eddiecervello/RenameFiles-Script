#region PowerShell 7+ version check
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7.0 or higher. Please install PowerShell 7+ from https://aka.ms/pwsh and run with 'pwsh'."
    exit 1
}
#endregion

param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Path = (Get-Location).Path,
    [switch]$Background,
    [switch]$RegisterStartup,
    [switch]$UnregisterStartup,
    [switch]$Monitor,
    [ValidateSet('INFO','DEBUG','VERBOSE')]
    [string]$LogLevel = 'INFO',
    [string]$LogFile,
    [ValidateSet('US', 'ISO', 'European')]
    [string]$DateFormat = 'US',
    [string[]]$Extensions = @('*'),
    [switch]$IncludeSubdirectories = $true,
    [int]$MaxRetries = 3,
    [int]$MonitorInterval = 5
)

# Import module
try {
    Import-Module "$PSScriptRoot/RenameFiles/RenameFiles.psd1" -Force
} catch {
    Write-Error "Failed to import RenameFiles module: $($_.Exception.Message)"
    exit 1
}

function Register-StartupTask {
    if (-not $IsWindows) {
        Write-Warning "Startup registration is only supported on Windows. Use your system's startup mechanisms on other platforms."
        return
    }
    
    try {
        $startup = [Environment]::GetFolderPath('Startup')
        $shortcut = Join-Path $startup 'RenameFiles.lnk'
        $target = (Get-Command pwsh).Source
        $args = "-NoProfile -ExecutionPolicy RemoteSigned -File `"$PSScriptRoot\RenameFiles.ps1`" -Monitor -Path `"$Path`""
        
        $ws = New-Object -ComObject WScript.Shell
        $sc = $ws.CreateShortcut($shortcut)
        $sc.TargetPath = $target
        $sc.Arguments = $args
        $sc.WorkingDirectory = $PSScriptRoot
        $sc.Description = "RenameFiles - Automatic file renaming utility"
        $sc.Save()
        
        Write-Host "Registered startup task: $shortcut" -ForegroundColor Green
        Write-Host "Target path: $Path" -ForegroundColor Green
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
        
        if (Test-Path $shortcut) { 
            Remove-Item $shortcut -Force
            Write-Host "Removed startup task: $shortcut" -ForegroundColor Green
        } else { 
            Write-Host "No startup shortcut found." -ForegroundColor Yellow
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
        if ($Extensions -ne @('*')) { $argList += @('-Extensions', ($Extensions -join ',')) }
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
                    $result = Rename-TodaysFiles -Path $using:Path -LogLevel $using:LogLevel -DateFormat $using:DateFormat -Extensions $using:Extensions -IncludeSubdirectories $using:IncludeSubdirectories -MaxRetries $using:MaxRetries -LogFile $using:LogFile
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
                        $result = Rename-TodaysFiles -Path $Path -LogLevel $LogLevel -DateFormat $DateFormat -Extensions $Extensions -IncludeSubdirectories $IncludeSubdirectories -MaxRetries $MaxRetries -LogFile $LogFile
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

# Validate path parameter
if (-not (Test-Path $Path -PathType Container)) {
    Write-Error "Path does not exist or is not a directory: $Path"
    exit 1
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

try {
    Write-Host "Starting file rename operation" -ForegroundColor Cyan
    $result = Rename-TodaysFiles @renameParams
    
    if ($result.TotalFiles -eq 0) {
        Write-Host "No files found to process" -ForegroundColor Yellow
    } else {
        Write-Host "Operation completed successfully" -ForegroundColor Green
    }
    
    exit 0
} catch {
    Write-Error "Error during file rename operation: $($_.Exception.Message)"
    exit 1
}
