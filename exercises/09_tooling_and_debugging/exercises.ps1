#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

Set-StrictMode -Version Latest

function Get-NormalizedName {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Name)
    # TODO: Trim Name and return title-like text without using Write-Host.
    throw 'TODO: implement Get-NormalizedName.'
}
# TODO: Add Pester tests for normal input and whitespace-only input.
'TODO functions and tests are intentionally incomplete.'
