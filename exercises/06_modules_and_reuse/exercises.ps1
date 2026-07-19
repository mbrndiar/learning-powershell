#Requires -Version 7.4

# Starter for Module 6. One function invokes an injected offline source; the
# other reads a general .psd1 through the safe data-file parser. Implement only
# TODO bodies and preserve both explicit boundaries.

Set-StrictMode -Version Latest

function Get-OpenItem {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Source)
    # TODO: Invoke Source and emit items where Done is false.
    throw 'TODO: implement Get-OpenItem.'
}
function Get-DataFileValue {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)][string] $Name
    )
    # TODO: Safely import LiteralPath and return Name, throwing if it is absent.
    throw 'TODO: implement Get-DataFileValue.'
}
'TODO bodies are intentionally incomplete.'
