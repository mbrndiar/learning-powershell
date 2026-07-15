Set-StrictMode -Version Latest

function Get-Total {
    [CmdletBinding()]
    param([int[]] $Number)
    ($Number | Measure-Object -Sum).Sum
}

Describe 'Get-Total' {
    It 'adds supplied numbers' {
        Get-Total -Number @(2, 3) | Should -Be 5
    }
    It 'returns zero for an empty array' {
        Get-Total -Number @() | Should -Be 0
    }
}
