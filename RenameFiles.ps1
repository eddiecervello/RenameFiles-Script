#region PowerShell 7+ version check
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7.0 or higher. Please install PowerShell 7+ from https://aka.ms/pwsh and run with 'pwsh'."
    exit 1
}
#endregion

param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Path,
    [switch]$Background,
    [switch]$RegisterStartup,
    [switch]$UnregisterStartup,
    [switch]$Monitor
)

Import-Module "$PSScriptRoot/RenameFiles/RenameFiles.psm1" -Force

function Register-StartupTask {
    $startup = [Environment]::GetFolderPath('Startup')
    $shortcut = Join-Path $startup 'RenameFiles.lnk'
    $target = (Get-Command pwsh).Source
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\RenameFiles.ps1`" -Monitor"
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($shortcut)
    $sc.TargetPath = $target
    $sc.Arguments = $args
    $sc.WorkingDirectory = $PSScriptRoot
    $sc.Save()
    Write-Host "Registered startup task: $shortcut"
}

function Unregister-StartupTask {
    $startup = [Environment]::GetFolderPath('Startup')
    $shortcut = Join-Path $startup 'RenameFiles.lnk'
    if (Test-Path $shortcut) { Remove-Item $shortcut; Write-Host "Removed startup task: $shortcut" } else { Write-Host "No startup shortcut found." }
}

if ($RegisterStartup) { Register-StartupTask; exit }
if ($UnregisterStartup) { Unregister-StartupTask; exit }

if ($Background) {
    if ($IsWindows) {
        Start-Process pwsh -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $($MyInvocation.UnboundArguments -join ' ')" -WindowStyle Hidden
    } else {
        Start-Job -ScriptBlock { pwsh -NoProfile -ExecutionPolicy Bypass -File $using:PSCommandPath $using:Path }
    }
    Write-Host "Started in background."
    exit
}

if ($Monitor) {
    if ($IsWindows) {
        $fsw = New-Object IO.FileSystemWatcher ($Path ?? $PWD), '*.*'
        $fsw.IncludeSubdirectories = $true
        $onChange = Register-ObjectEvent $fsw Changed -Action { Rename-TodaysFiles -Path $Event.SourceEventArgs.FullPath }
        $onCreate = Register-ObjectEvent $fsw Created -Action { Rename-TodaysFiles -Path $Event.SourceEventArgs.FullPath }
        Write-Host "Monitoring $Path for changes. Press Ctrl+C to exit."
        while ($true) { Start-Sleep 3600 }
    } else {
        if (Get-Command inotifywait -ErrorAction SilentlyContinue) {
            Write-Host "Monitoring $Path for changes (Linux/macOS). Press Ctrl+C to exit."
            while ($true) {
                inotifywait -e create,modify,move "$Path" && pwsh -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Path $Path
            }
        } else {
            Write-Error "inotifywait not found. Please install inotify-tools."
        }
    }
    exit
}

Rename-TodaysFiles @PSBoundParameters
