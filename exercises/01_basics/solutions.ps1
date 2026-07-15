#Requires -Version 7.4

# Reference solution for Module 1. The inline "if (...) { throw }" lines are
# runnable self-checks: running this file to completion (ending in "All checks
# passed.") proves the implementations meet the contract.

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
