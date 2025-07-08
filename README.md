# RenameFiles Script v2.0.0

> Cross-platform, production-safe file renamer for PowerShell 7+ (Windows, Linux, macOS)

## Overview

This PowerShell module renames all files created today in a specified directory tree, replacing spaces and patterns with dashes. If a file with the new name exists, a unique suffix is appended. Emits JSON-lines logs for observability.

## Features
- **Easy Setup**: Interactive setup wizard handles configuration
- **Cross-Platform**: PowerShell 7+ (Windows, Linux, macOS)
- **Security Hardened**: Path validation, input sanitization, safe execution
- **Flexible Configuration**: Custom date formats, file extensions, subdirectory options
- **Monitoring Mode**: Watch directories for new files and rename automatically
- **Background Execution**: Run as background service with proper job management
- **Comprehensive Logging**: JSON-lines logging with configurable levels
- **Dry-Run Testing**: `-WhatIf` support for safe testing
- **Error Recovery**: Retry logic with exponential backoff
- **Auto-Start Support**: Windows startup integration
- **Execution Policy Friendly**: Built-in handling for PowerShell restrictions

## Quick Start

### First Time Setup (Recommended)

If you're getting execution policy errors, run the setup wizard:

```powershell
# Windows (run as user)
pwsh -ExecutionPolicy Bypass -File .\Setup-RenameFiles.ps1

# Or double-click Run-RenameFiles.bat for automatic execution
```

The setup wizard will:
- Fix PowerShell execution policy issues
- Configure your preferred watch directory
- Set up file extension filters
- Configure auto-start options (Windows only)

### Manual Usage

```powershell
# Test first with dry-run (recommended)
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Path "C:\Users\YourName\Downloads" -WhatIf

# Run for real
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Path "C:\Users\YourName\Downloads"

# Monitor directory for changes
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Monitor -Path "C:\Users\YourName\Downloads"

# Run in background
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 -Background -Monitor -Path "C:\Users\YourName\Downloads"
```

### If You Get Execution Policy Errors

Option 1 (Recommended): Set execution policy once
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Option 2: Use bypass for each run
```powershell
pwsh -ExecutionPolicy Bypass -File .\RenameFiles.ps1 [parameters]
```

Option 3: Use the provided batch file
```cmd
Run-RenameFiles.bat -Path "C:\Users\YourName\Downloads"
```

## Module API

```powershell
Import-Module ./RenameFiles/RenameFiles.psm1
Rename-TodaysFiles -Path "/tmp" -WhatIf -LogLevel DEBUG
```

## Architecture

```plantuml
@startuml
actor User
User -> RenameFiles.ps1 : invoke (with params)
RenameFiles.ps1 -> RenameFiles.psm1 : Import-Module
RenameFiles.psm1 -> Rename-TodaysFiles : call
Rename-TodaysFiles -> FileSystem : scan, rename, log
@enduml
```

## Logging Example

```json
{"ts":"2025-07-07T12:00:00Z","level":"INFO","msg":"Renamed 'foo (1).txt' to 'foo-070725-1.txt'"}
```

## Changelog
See [CHANGELOG.md](CHANGELOG.md)

## License
MIT
