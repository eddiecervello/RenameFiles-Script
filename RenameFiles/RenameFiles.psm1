using namespace System.IO

function Rename-TodaysFiles {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Position=0, Mandatory=$false)]
        [ValidateScript({
            # Security validation for path
            if ($_ -match '\.\./|\.\.\\'|\.\.' -or $_ -match '[<>:"|?*]') {
                throw "Path contains invalid or dangerous characters: $_"
            }
            $resolved = Resolve-Path $_ -ErrorAction Stop
            if (-not (Test-Path $resolved -PathType Container)) {
                throw "Path is not a valid directory: $_"
            }
            # Check if it's a system directory
            $systemPaths = @($env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)})
            foreach ($sysPath in $systemPaths) {
                if ($sysPath -and $resolved.Path.StartsWith($sysPath, [StringComparison]::OrdinalIgnoreCase)) {
                    Write-Warning "WARNING: Operating on system directory: $resolved"
                }
            }
            return $true
        })]
        [string]$Path = (Get-Location).Path,
        [switch]$WhatIf,
        [ValidateSet('INFO','DEBUG','VERBOSE')]
        [string]$LogLevel = 'INFO',
        [Parameter()]
        [ValidateSet('US', 'ISO', 'European')]
        [string]$DateFormat = 'US',
        [Parameter()]
        [ValidateScript({
            if ($_) {
                $logPath = [System.IO.Path]::GetDirectoryName($_)
                if ($logPath -match '\.\./|\.\.\\'|\.\.' -or $logPath -match '[<>:"|?*]') {
                    throw "Log file path contains invalid characters: $_"
                }
                if (-not (Test-Path $logPath -PathType Container)) {
                    throw "Log file directory does not exist: $logPath"
                }
            }
            return $true
        })]
        [string]$LogFile,
        [Parameter()]
        [ValidateScript({
            foreach ($ext in $_) {
                if ($ext -ne '*' -and $ext -notmatch '^\.[a-zA-Z0-9]+$') {
                    throw "Invalid file extension format: $ext"
                }
                if ($ext.Length -gt 10) {
                    throw "File extension too long: $ext"
                }
            }
            return $true
        })]
        [string[]]$Extensions = @('*'),
        [Parameter()]
        [ValidateRange(1, 10)]
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
            
            # Security check for filename
            if ($origName -match '\.\./|\.\.\\'|\.\.' -or $origName -match '[<>:"|?*]') {
                & $log 'DEBUG' "Skipping file with dangerous characters: $origName"
                $skippedFiles++
                return
            }
            
            # Limit filename length for security
            if ($origName.Length -gt 255) {
                & $log 'DEBUG' "Skipping file with name too long: $($origName.Substring(0, 50))..."
                $skippedFiles++
                return
            }
            
            # Clean up the filename with security considerations
            $cleanName = $origName
            $cleanName = $cleanName -replace '\s*\(\d+\)', ''  # Remove (1), (2), etc.
            $cleanName = $cleanName -replace '\s-\s', '-'     # Replace ' - ' with '-'
            $cleanName = $cleanName -replace '\s+', '-'       # Replace spaces with dashes
            $cleanName = $cleanName -replace '-+', '-'        # Replace multiple dashes with single
            $cleanName = $cleanName -replace '^-|-$', ''      # Remove leading/trailing dashes
            
            # Additional security: remove any remaining dangerous characters
            $cleanName = $cleanName -replace '[<>:"|?*]', '_'
            
            # Ensure the cleaned name is still valid
            if (-not $cleanName -or $cleanName.Length -eq 0) {
                & $log 'DEBUG' "Cleaned filename is empty, skipping: $origName"
                $skippedFiles++
                return
            }
            
            & $log 'VERBOSE' "Processing file: $origName"
            
            if ($cleanName -ne $origName) {
                $dir = $_.DirectoryName
                $base = [Path]::GetFileNameWithoutExtension($cleanName)
                $ext = [Path]::GetExtension($cleanName)
                
                # Generate unique filename with security validation
                $finalName = $cleanName
                $counter = 1
                
                # Security check for directory
                $dir = [System.IO.Path]::GetDirectoryName($origPath)
                if ($dir -match '\.\./|\.\.\\'|\.\.' -or $dir -match '[<>:"|?*]') {
                    & $log 'DEBUG' "Directory path contains dangerous characters, skipping: $dir"
                    $skippedFiles++
                    return
                }
                
                while (Test-Path (Join-Path $dir $finalName)) {
                    $finalName = "$base-$dateSuffix-$counter$ext"
                    $counter++
                    
                    # Prevent infinite loop and potential DoS
                    if ($counter -gt 100) {
                        & $log 'DEBUG' "Too many naming conflicts for '$origName', skipping" $_.Exception
                        $skippedFiles++
                        return
                    }
                    
                    # Additional security check on generated filename
                    if ($finalName.Length -gt 255) {
                        & $log 'DEBUG' "Generated filename too long for '$origName', skipping"
                        $skippedFiles++
                        return
                    }
                }
                
                # Final security validation of target path
                $targetPath = Join-Path $dir $finalName
                try {
                    $resolvedTarget = [System.IO.Path]::GetFullPath($targetPath)
                    $resolvedDir = [System.IO.Path]::GetFullPath($dir)
                    if (-not $resolvedTarget.StartsWith($resolvedDir, [StringComparison]::OrdinalIgnoreCase)) {
                        & $log 'DEBUG' "Target path outside directory, skipping: $origName"
                        $skippedFiles++
                        return
                    }
                } catch {
                    & $log 'DEBUG' "Invalid target path for '$origName', skipping: $($_.Exception.Message)"
                    $skippedFiles++
                    return
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
