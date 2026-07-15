#Requires -Version 7.4

# Reference solution for Module 2. The key choice in Get-SettingValue is
# ContainsKey: it distinguishes an absent key from one whose value is $null,
# which plain indexing cannot do.

Set-StrictMode -Version Latest

function Get-ScoreLabel {
    [CmdletBinding()]
    param([ValidateRange(0, 100)][int] $Score)
    if ($Score -ge 60) { 'Pass' } else { 'Retry' }
}
function Get-SettingValue {
    [CmdletBinding()]
    param([hashtable] $Setting, [string] $Name)
    if ($Setting.ContainsKey($Name)) { $Setting[$Name] } else { $null }
}
if ((Get-ScoreLabel -Score 60) -ne 'Pass') { throw 'Score check failed.' }
if ($null -ne (Get-SettingValue -Setting @{ Mode = 'safe' } -Name 'Missing')) { throw 'Lookup check failed.' }
'All checks passed.'
