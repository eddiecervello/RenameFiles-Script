# RenameFiles Script v2.0.0

> Cross-platform, production-safe file renamer for PowerShell 7+ (Windows, Linux, macOS)

## Overview

This PowerShell module renames all files created today in a specified directory tree, replacing spaces and patterns with dashes. If a file with the new name exists, a unique suffix is appended. Emits JSON-lines logs for observability.

## Features
- Simple CLI: `RenameFiles.ps1 [-Path <folder>] [-WhatIf] [-LogLevel INFO|DEBUG]`
- Cross-platform: PowerShell 7+ (pwsh) on Windows, Linux, macOS
- No hard-coded paths; defaults to current directory
- Safe, idempotent renaming with retry/back-off
- JSON-lines logging (INFO/DEBUG)
- Robust error handling
- Dry-run mode with `-WhatIf`

## Usage

```sh
# Rename files created today in current directory (dry-run)
pwsh ./RenameFiles.ps1 -WhatIf

# Rename files in a specific folder (real run)
pwsh ./RenameFiles.ps1 -Path /path/to/dir
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
