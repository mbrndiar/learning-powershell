#Requires -Version 7.4

Set-StrictMode -Version Latest

$work = 1..4 | ForEach-Object {
    [pscustomobject]@{ Index = $_; Value = $_ * $_ }
}
$labelPrefix = 'item'

$work | ForEach-Object -Parallel {
    [pscustomobject]@{
        Index = $_.Index
        Label = "$using:labelPrefix-$($_.Index)"
        Value = $_.Value
    }
} -ThrottleLimit 2 | Sort-Object Index
