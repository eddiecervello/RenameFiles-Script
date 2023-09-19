## RenameFiles Script

### Overview

This PowerShell script automatically renames all files created on the current day in a specified directory and its subdirectories. If a file with the new name already exists, it appends a unique suffix to avoid conflicts.

### Files

- **RenameFiles.ps1**: The main PowerShell script that handles the file renaming.
- **File-Renamer.bat**: A batch file to quickly and easily run the PowerShell script from a shortcut.

### Usage

1. Update the `$folderPath` variable in `RenameFiles.ps1` to the folder you want to monitor.
2. Create a shortcut to `File-Renamer.bat` on your desktop for easy access.

### Script Breakdown

#### RenameFiles.ps1

```powershell
$folderPath = 'C:\Users\Downloads' # Specifies the folder to monitor
$currentDate = (Get-Date).Date # Gets the current date

# Retrieves all files created today in the specified folder and its subfolders
Get-ChildItem -Path $folderPath -Recurse | Where-Object { 
    !$_.PSIsContainer -and $_.CreationTime.Date -eq $currentDate
} | ForEach-Object {
    # Constructs the new name for each file by replacing spaces and certain patterns
    $newName = $_.Name -replace '\s*\(\d+\)', '' -replace '\s-\s', '-' -replace ' ', '-'
    
    if ($newName -ne $_.Name) {
        $newFullPath = Join-Path -Path $_.Directory -ChildPath $newName
        
        # Checks if a file with the new name already exists
        if (Test-Path -Path $newFullPath) {
            $currentDateSuffix = (Get-Date -UFormat "%m%d%y")
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($newName) + "-" + $currentDateSuffix
            $extension = [System.IO.Path]::GetExtension($newName)
            $counter = 1
            
            # Increments the counter until it finds a unique filename
            while (Test-Path -Path (Join-Path -Path $_.Directory -ChildPath ($baseName + $counter + $extension))) {
                $counter++
            }
            $newName = $baseName + "-" + $counter + $extension
        }
        
        # Renames the file with the new, unique name
        Rename-Item -Path $_.FullName -NewName $newName -ErrorAction SilentlyContinue
    }
}
```

#### File-Renamer.bat

```powershell
@echo off
# Runs the PowerShell script with elevated privileges
PowerShell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Documents\Scripts\RenameFiles.ps1"
```

### Notes

- The script only processes files created on the current date to avoid renaming older files.
- The batch file uses the -NoProfile and -ExecutionPolicy Bypass flags to run the PowerShell script without loading the user profile and bypassing the default execution policy, respectively.
