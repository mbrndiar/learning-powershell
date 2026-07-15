Set-StrictMode -Version Latest

$work = 1..4 | ForEach-Object {
    [pscustomobject]@{ Index = $_; Value = $_ * $_ }
}

$work | ForEach-Object -Parallel {
    [pscustomobject]@{ Index = $_.Index; Value = $_.Value }
} -ThrottleLimit 2 | Sort-Object Index
