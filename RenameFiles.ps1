#requires -Version 7.0
Import-Module "$PSScriptRoot/RenameFiles/RenameFiles.psm1" -Force

[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Path
)
Rename-TodaysFiles @PSBoundParameters
