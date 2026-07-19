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
function Get-FirstSeenUniqueName {
    [CmdletBinding()]
    param([AllowEmptyCollection()][string[]] $Name)
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($candidate in $Name) {
        if ($seen.Add($candidate)) { $candidate }
    }
}

if ((Get-ScoreLabel -Score 0) -ne 'Retry' -or
    (Get-ScoreLabel -Score 59) -ne 'Retry' -or
    (Get-ScoreLabel -Score 60) -ne 'Pass' -or
    (Get-ScoreLabel -Score 100) -ne 'Pass') {
    throw 'Score boundary checks failed.'
}
foreach ($invalidScore in @(-1, 101)) {
    $rejected = try {
        Get-ScoreLabel -Score $invalidScore
        $false
    }
    catch {
        $true
    }
    if (-not $rejected) { throw "Score validation did not reject $invalidScore." }
}

$setting = @{ Enabled = $false; Retries = 0; Label = ''; Optional = $null }
if ((Get-SettingValue -Setting $setting -Name 'Enabled') -ne $false) {
    throw 'False setting check failed.'
}
if ((Get-SettingValue -Setting $setting -Name 'Retries') -ne 0) {
    throw 'Zero setting check failed.'
}
if ((Get-SettingValue -Setting $setting -Name 'Label') -ne '') {
    throw 'Empty-string setting check failed.'
}
if ($null -ne (Get-SettingValue -Setting $setting -Name 'Optional')) {
    throw 'Present-null setting check failed.'
}
if ($null -ne (Get-SettingValue -Setting $setting -Name 'Missing')) {
    throw 'Missing setting check failed.'
}

if (@(Get-FirstSeenUniqueName -Name @()).Count -ne 0) {
    throw 'Empty unique-name check failed.'
}
$uniqueNames = @(Get-FirstSeenUniqueName -Name @('Ada', 'ada', 'Lin', 'LIN', 'Sam'))
if (($uniqueNames -join ',') -ne 'Ada,Lin,Sam') {
    throw 'First-seen unique-name check failed.'
}
'All checks passed.'
