#Requires -Version 7.4

Set-StrictMode -Version Latest

function Get-Greeting {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Name)
    "Hello, $Name"
}
function Get-NumberKind {
    [CmdletBinding()]
    param([int] $Number)
    if ($Number -gt 0) { 'positive' } elseif ($Number -lt 0) { 'negative' } else { 'zero' }
}
if ((Get-Greeting -Name 'Ada') -ne 'Hello, Ada') { throw 'Greeting check failed.' }
if ((Get-NumberKind -Number -1) -ne 'negative') { throw 'Number check failed.' }
'All checks passed.'
