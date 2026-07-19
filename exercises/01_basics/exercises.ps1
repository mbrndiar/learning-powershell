#Requires -Version 7.4

# Starter for Module 1. The advanced-function declarations and typed parameter
# boundaries are supplied infrastructure taught in Module 4. Edit only the TODO
# bodies, return values on the success stream, and never use Write-Host.

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

function Get-ElapsedDuration {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][DateTimeOffset] $Start,
        [Parameter(Mandatory)][DateTimeOffset] $End
    )
    # TODO: Return the TimeSpan between the two unambiguous instants.
    throw 'TODO: implement Get-ElapsedDuration.'
}

'TODO bodies are intentionally incomplete. Implement them, then add checks.'
