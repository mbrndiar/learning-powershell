#Requires -Version 7.4

# This lesson shows ForEach-Object -Parallel. The mental model: each item runs
# in an isolated runspace, so outer variables must be captured with $using:,
# results arrive out of order, and a throttle bounds concurrent work.

Set-StrictMode -Version Latest

$work = 1..4 | ForEach-Object {
    [pscustomobject]@{ Index = $_; Value = $_ * $_ }
}
$labelPrefix = 'item'

# $using: makes the outer label value available inside each runspace.
# ThrottleLimit caps how many run at once, and Sort-Object restores deterministic
# order because parallel output is unordered.
$work | ForEach-Object -Parallel {
    [pscustomobject]@{
        Index = $_.Index
        Label = "$using:labelPrefix-$($_.Index)"
        Value = $_.Value
    }
} -ThrottleLimit 2 | Sort-Object Index
