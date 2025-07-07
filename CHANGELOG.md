# Changelog

## [2.0.0] - 2025-07-07
### Added
- Cross-platform PowerShell 7+ support (Windows, Linux, macOS)
- No hard-coded paths; defaults to current directory if -Path not supplied
- Modularized as RenameFiles module with public Rename-TodaysFiles cmdlet
- Supports -WhatIf for dry-run mode
- Emits JSON-lines logs (INFO/DEBUG)
- Robust error handling and idempotent renaming
- Pester test scaffolding (to be implemented)
- CI/CD pipeline (to be implemented)

### Changed
- Legacy script replaced with parameterized, production-safe version
