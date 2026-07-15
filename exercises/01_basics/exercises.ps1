#Requires -Version 7.4

# Starter for Module 1. Implement each function to RETURN a value (never
# Write-Host); the runner and your own checks read the returned objects.
# Replace each throw with your implementation and keep the TODO contract.

Set-StrictMode -Version Latest

function Get-Greeting {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Name)
    # TODO: Return an interpolated greeting string.
    throw 'TODO: implement Get-Greeting.'
}

function Get-NumberKind {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([int] $Number)
    # TODO: Return 'positive', 'negative', or 'zero'.
    throw 'TODO: implement Get-NumberKind.'
}

'TODO functions are intentionally incomplete. Implement them, then add checks.'
