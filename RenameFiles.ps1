#region PowerShell 7+ version check
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7.0 or higher. Please install PowerShell 7+ from https://aka.ms/pwsh and run with 'pwsh'."
    exit 1
}
#endregion

Import-Module "$PSScriptRoot/RenameFiles/RenameFiles.psm1" -Force

[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Path
)
Rename-TodaysFiles @PSBoundParameters
