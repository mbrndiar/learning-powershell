#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

Set-StrictMode -Version Latest

function Get-Initial {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([string] $Name)
    # TODO: Return the uppercase first character, or $null for empty input.
    throw 'TODO: implement Get-Initial.'
}
# TODO: Add a Describe block with at least two It cases.
'TODO functions and tests are intentionally incomplete.'
