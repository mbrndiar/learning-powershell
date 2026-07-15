Set-StrictMode -Version Latest

function Get-ParallelSquare {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][int[]] $Number)
    $Number | ForEach-Object -Parallel {
        [pscustomobject]@{ Number = $_; Square = $_ * $_ }
    } -ThrottleLimit 2 | Sort-Object Number
}

Describe 'Get-ParallelSquare' {
    Context 'with bounded parallel work' {
        It 'returns deterministic ordered squares' {
            $result = @(Get-ParallelSquare -Number @(3, 1, 2))
            $result.Number | Should -Be @(1, 2, 3)
            $result.Square | Should -Be @(1, 4, 9)
        }
        It 'returns no values for empty input' {
            @(Get-ParallelSquare -Number @()).Count | Should -Be 0
        }
    }
}
