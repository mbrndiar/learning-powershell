#Requires -Version 7.4

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
