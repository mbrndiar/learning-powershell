#Requires -Version 7.4

# This lesson aggregates records with Group-Object and Measure-Object. The
# mental model: grouping buckets objects by a key, and measuring reduces a
# bucket to a single statistic instead of parsing text.

Set-StrictMode -Version Latest

$tasks = @(
    [pscustomobject]@{ Team = 'A'; Minutes = 10 }
    [pscustomobject]@{ Team = 'B'; Minutes = 20 }
    [pscustomobject]@{ Team = 'A'; Minutes = 30 }
)

# Group-Object yields one group per key, exposing .Name (the key) and .Group
# (its members). Measure-Object -Sum returns a measurement object whose .Sum
# property holds the total.
$summary = $tasks | Group-Object Team | ForEach-Object {
    [pscustomobject]@{
        Team = $_.Name
        Count = $_.Count
        Minutes = ($_.Group | Measure-Object Minutes -Sum).Sum
    }
}

$summary | Sort-Object Team
