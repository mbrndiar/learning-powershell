#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

Set-StrictMode -Version Latest

function Get-Initial {
    [CmdletBinding()]
    param([string] $Name)
    if ([string]::IsNullOrEmpty($Name)) { return $null }
    $Name.Substring(0, 1).ToUpperInvariant()
}
if ((Get-Initial -Name 'ada') -ne 'A') { throw 'Initial check failed.' }
if ($null -ne (Get-Initial -Name '')) { throw 'Empty input check failed.' }
Describe 'Get-Initial' {
    It 'returns an uppercase initial' { Get-Initial -Name 'ada' | Should -Be 'A' }
    It 'returns null for empty input' { Get-Initial -Name '' | Should -BeNullOrEmpty }
}
'All checks passed.'
