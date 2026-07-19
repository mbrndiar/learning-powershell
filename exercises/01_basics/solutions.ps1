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
function Get-ElapsedDuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][DateTimeOffset] $Start,
        [Parameter(Mandatory)][DateTimeOffset] $End
    )
    $End - $Start
}
if ((Get-Greeting -Name 'Ada') -ne 'Hello, Ada') { throw 'Greeting check failed.' }
if ((Get-Greeting -Name '003') -ne 'Hello, 003') { throw 'Identifier-like greeting check failed.' }

$start = [DateTimeOffset]::Parse(
    '2026-03-29T00:30:00+00:00',
    [Globalization.CultureInfo]::InvariantCulture
)
$later = [DateTimeOffset]::Parse(
    '2026-03-29T03:00:00+02:00',
    [Globalization.CultureInfo]::InvariantCulture
)
$sameInstant = [DateTimeOffset]::Parse(
    '2026-03-29T01:30:00+01:00',
    [Globalization.CultureInfo]::InvariantCulture
)
if ((Get-ElapsedDuration -Start $start -End $later).TotalMinutes -ne 30) {
    throw 'Positive duration check failed.'
}
if ((Get-ElapsedDuration -Start $start -End $sameInstant) -ne [TimeSpan]::Zero) {
    throw 'Equivalent-instant check failed.'
}
if ((Get-ElapsedDuration -Start $later -End $start).TotalMinutes -ne -30) {
    throw 'Negative duration check failed.'
}
'All checks passed.'
