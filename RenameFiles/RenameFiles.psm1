using namespace System.IO

function Rename-TodaysFiles {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Position=0, Mandatory=$false)]
        [string]$Path = (Get-Location).Path,
        [switch]$WhatIf,
        [ValidateSet('INFO','DEBUG')]
        [string]$LogLevel = 'INFO'
    )
    $currentDate = (Get-Date).Date
    $log = { param($level, $msg) if ($LogLevel -eq 'DEBUG' -or $level -eq 'INFO') { $out = @{ ts = (Get-Date -Format o); level = $level; msg = $msg }; $out | ConvertTo-Json -Compress | Write-Output } }
    & $log 'INFO' "Scanning $Path for files created today ($currentDate)"
    try {
        Get-ChildItem -Path $Path -Recurse -File -ErrorAction Stop | Where-Object { $_.CreationTime.Date -eq $currentDate } | ForEach-Object {
            $origName = $_.Name
            $newName = $origName -replace '\s*\(\d+\)', '' -replace '\s-\s', '-' -replace ' ', '-'
            if ($newName -ne $origName) {
                $dir = $_.DirectoryName
                $newFullPath = Join-Path -Path $dir -ChildPath $newName
                $suffix = (Get-Date -UFormat "%m%d%y")
                $base = [Path]::GetFileNameWithoutExtension($newName) + "-" + $suffix
                $ext = [Path]::GetExtension($newName)
                $counter = 1
                $finalName = $newName
                while (Test-Path (Join-Path $dir $finalName)) {
                    $finalName = "$base-$counter$ext"
                    $counter++
                }
                if ($PSCmdlet.ShouldProcess($_.FullName, "Rename to $finalName")) {
                    try {
                        Rename-Item -Path $_.FullName -NewName $finalName -ErrorAction Stop
                        & $log 'INFO' "Renamed '$origName' to '$finalName'"
                    } catch {
                        & $log 'DEBUG' "Failed to rename '$origName': $($_.Exception.Message)"
                    }
                }
            }
        }
    } catch {
        & $log 'DEBUG' "Error: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Rename-TodaysFiles
