#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

Set-StrictMode -Version Latest

function Get-ParallelSquare {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][int[]] $Number,
        [ValidateNotNullOrWhiteSpace()][string] $LabelPrefix = 'item'
    )
    $Number | ForEach-Object -Parallel {
        [pscustomobject]@{
            Number = $_
            Label = "$using:LabelPrefix-$_"
            Square = $_ * $_
        }
    } -ThrottleLimit 2 | Sort-Object Number
}

Describe 'Get-ParallelSquare' {
    Context 'with bounded parallel work' {
        It 'returns deterministic ordered squares' {
            $result = @(Get-ParallelSquare -Number @(3, 1, 2) -LabelPrefix 'value')
            $result.Number | Should -Be @(1, 2, 3)
            $result.Label | Should -Be @('value-1', 'value-2', 'value-3')
            $result.Square | Should -Be @(1, 4, 9)
        }
        It 'returns no values for empty input' {
            @(Get-ParallelSquare -Number @()).Count | Should -Be 0
        }
    }
}
