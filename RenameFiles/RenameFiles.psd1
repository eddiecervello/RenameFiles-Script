@{
    # Module manifest for RenameFiles
    RootModule = 'RenameFiles.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'Eddie Cervello'
    CompanyName = 'Unknown'
    Copyright = '(c) 2024 Eddie Cervello. All rights reserved.'
    Description = 'PowerShell 7+ cross-platform file renaming utility for cleaning up filenames'
    PowerShellVersion = '7.0'
    
    # Functions to export from this module
    FunctionsToExport = @('Rename-TodaysFiles')
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Private data to pass to the module
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('Files', 'Rename', 'Cleanup', 'CrossPlatform', 'Monitoring')
            
            # A URL to the license for this module
            LicenseUri = ''
            
            # A URL to the main website for this project
            ProjectUri = ''
            
            # A URL to an icon representing this module
            IconUri = ''
            
            # Release notes
            ReleaseNotes = @'
Version 1.0.0
- Initial release
- Cross-platform file renaming
- Background monitoring support
- JSON-lines logging
- Configurable date format
- Dry-run support with -WhatIf
'@
        }
    }
}