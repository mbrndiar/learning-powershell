#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

# Starter for Module 9. Get-NormalizedName must return text (no Write-Host) and
# reject whitespace-only input. Add Pester tests covering normal input and the
# whitespace-only failure so strict, debuggable behavior is pinned down.

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
