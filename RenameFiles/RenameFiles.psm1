using namespace System.IO

function Rename-TodaysFiles {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Position=0, Mandatory=$false)]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$Path = (Get-Location).Path,
        [switch]$WhatIf,
        [ValidateSet('INFO','DEBUG','VERBOSE')]
        [string]$LogLevel = 'INFO',
        [Parameter()]
        [ValidateSet('US', 'ISO', 'European')]
        [string]$DateFormat = 'US',
        [Parameter()]
        [string]$LogFile,
        [Parameter()]
        [string[]]$Extensions = @('*'),
        [Parameter()]
        [int]$MaxRetries = 3,
        [Parameter()]
        [switch]$IncludeSubdirectories = $true
    )
    # Initialize logging
    $currentDate = (Get-Date).Date
    $logLevels = @('INFO', 'DEBUG', 'VERBOSE')
    $currentLogIndex = $logLevels.IndexOf($LogLevel)
    
    $log = { 
        param($level, $msg, $error = $null) 
        $levelIndex = $logLevels.IndexOf($level)
        if ($levelIndex -le $currentLogIndex) { 
            $logEntry = @{ 
                ts = (Get-Date -Format o)
                level = $level
                msg = $msg
                path = $using:Path
            }
            if ($error) {
                $logEntry.error = $error.ToString()
            }
            $json = $logEntry | ConvertTo-Json -Compress
            
            # Write to console
            Write-Output $json
            
            # Write to log file if specified
            if ($using:LogFile) {
                Add-Content -Path $using:LogFile -Value $json
            }
        }
    }
    
    # Generate date suffix based on format
    $dateSuffix = switch ($DateFormat) {
        'US' { Get-Date -UFormat "%m%d%y" }
        'ISO' { Get-Date -Format "yyyyMMdd" }
        'European' { Get-Date -Format "ddMMyy" }
    }
    
    & $log 'INFO' "Starting file rename operation for files created today ($currentDate)"
    & $log 'INFO' "Target directory: $Path (Include subdirectories: $IncludeSubdirectories)"
    & $log 'INFO' "File extensions filter: $($Extensions -join ', ')"
    & $log 'INFO' "Date format: $DateFormat (suffix: $dateSuffix)"
    # Initialize counters
    $totalFiles = 0
    $renamedFiles = 0
    $skippedFiles = 0
    $errorFiles = 0
    
    try {
        # Get files based on parameters
        $getChildItemParams = @{
            Path = $Path
            File = $true
            ErrorAction = 'Stop'
        }
        
        if ($IncludeSubdirectories) {
            $getChildItemParams.Recurse = $true
        }
        
        $files = Get-ChildItem @getChildItemParams | Where-Object { 
            $_.CreationTime.Date -eq $currentDate -and 
            ($Extensions -contains '*' -or $Extensions -contains $_.Extension.ToLower())
        }
        
        $totalFiles = $files.Count
        & $log 'INFO' "Found $totalFiles files created today matching criteria"
        
        if ($totalFiles -eq 0) {
            & $log 'INFO' "No files found to rename"
            return
        }
        
        $files | ForEach-Object {
            $origName = $_.Name
            $origPath = $_.FullName
            
            # Clean up the filename
            $cleanName = $origName
            $cleanName = $cleanName -replace '\s*\(\d+\)', ''  # Remove (1), (2), etc.
            $cleanName = $cleanName -replace '\s-\s', '-'     # Replace ' - ' with '-'
            $cleanName = $cleanName -replace '\s+', '-'       # Replace spaces with dashes
            $cleanName = $cleanName -replace '-+', '-'        # Replace multiple dashes with single
            $cleanName = $cleanName -replace '^-|-$', ''      # Remove leading/trailing dashes
            
            & $log 'VERBOSE' "Processing file: $origName"
            
            if ($cleanName -ne $origName) {
                $dir = $_.DirectoryName
                $base = [Path]::GetFileNameWithoutExtension($cleanName)
                $ext = [Path]::GetExtension($cleanName)
                
                # Generate unique filename
                $finalName = $cleanName
                $counter = 1
                
                while (Test-Path (Join-Path $dir $finalName)) {
                    $finalName = "$base-$dateSuffix-$counter$ext"
                    $counter++
                    
                    # Prevent infinite loop
                    if ($counter -gt 1000) {
                        & $log 'DEBUG' "Too many naming conflicts for '$origName', skipping" $_.Exception
                        $skippedFiles++
                        return
                    }
                }
                
                if ($PSCmdlet.ShouldProcess($origPath, "Rename to $finalName")) {
                    $retryCount = 0
                    $success = $false
                    
                    while ($retryCount -lt $MaxRetries -and -not $success) {
                        try {
                            Rename-Item -Path $origPath -NewName $finalName -ErrorAction Stop
                            & $log 'INFO' "Renamed '$origName' to '$finalName'"
                            $renamedFiles++
                            $success = $true
                        } catch {
                            $retryCount++
                            & $log 'DEBUG' "Retry $retryCount failed for '$origName': $($_.Exception.Message)" $_.Exception
                            
                            if ($retryCount -lt $MaxRetries) {
                                Start-Sleep -Milliseconds 100
                            } else {
                                & $log 'DEBUG' "Failed to rename '$origName' after $MaxRetries attempts" $_.Exception
                                $errorFiles++
                            }
                        }
                    }
                }
            } else {
                & $log 'VERBOSE' "No changes needed for '$origName'"
                $skippedFiles++
            }
        }
    } catch {
        & $log 'DEBUG' "Error during file processing: $($_.Exception.Message)" $_.Exception
        $errorFiles++
    }
    
    # Generate final report
    & $log 'INFO' "Rename operation completed"
    & $log 'INFO' "Total files: $totalFiles, Renamed: $renamedFiles, Skipped: $skippedFiles, Errors: $errorFiles"
    
    # Return summary object
    return [PSCustomObject]@{
        TotalFiles = $totalFiles
        RenamedFiles = $renamedFiles
        SkippedFiles = $skippedFiles
        ErrorFiles = $errorFiles
        Path = $Path
        DateFormat = $DateFormat
        LogFile = $LogFile
    }
}

Export-ModuleMember -Function Rename-TodaysFiles
