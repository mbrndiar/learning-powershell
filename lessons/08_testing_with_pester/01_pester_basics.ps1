#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

# This lesson introduces Pester structure: Describe/Context group related
# behavior, It states one expected behavior, and Should asserts it. Test names
# are the specification, so they read as sentences.

Set-StrictMode -Version Latest

function Get-Total {
    [CmdletBinding()]
    param([int[]] $Number)
    ($Number | Measure-Object -Sum).Sum
}

Describe 'Get-Total' {
    Context 'with valid collections' {
        It 'adds supplied numbers' {
            Get-Total -Number @(2, 3) | Should -Be 5
        }
        It 'returns zero for an empty array' {
            Get-Total -Number @() | Should -Be 0
        }
    }
}
