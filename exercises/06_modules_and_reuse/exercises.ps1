#Requires -Version 7.4

# Starter for Module 6. Get-OpenItem receives its data source as a scriptblock
# seam so tests can inject offline data. Invoke the seam, then validate each
# item's Done property is a real Boolean before deciding what to emit.

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
'TODO functions are intentionally incomplete.'
