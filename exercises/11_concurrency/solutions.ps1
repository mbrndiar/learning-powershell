Set-StrictMode -Version Latest

function Get-ParallelSquare {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int[]] $Number)
    $Number | ForEach-Object -Parallel {
        [pscustomobject]@{ Number = $_; Square = $_ * $_ }
    } -ThrottleLimit 2 | Sort-Object Number
}
$result = @(Get-ParallelSquare -Number @(3, 1, 2))
if (($result.Number -join ',') -ne '1,2,3' -or $result[2].Square -ne 9) { throw 'Parallel ordering check failed.' }
'All checks passed.'
