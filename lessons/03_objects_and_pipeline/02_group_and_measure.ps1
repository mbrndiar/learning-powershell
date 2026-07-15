Set-StrictMode -Version Latest

$tasks = @(
    [pscustomobject]@{ Team = 'A'; Minutes = 10 }
    [pscustomobject]@{ Team = 'B'; Minutes = 20 }
    [pscustomobject]@{ Team = 'A'; Minutes = 30 }
)

$summary = $tasks | Group-Object Team | ForEach-Object {
    [pscustomobject]@{
        Team = $_.Name
        Count = $_.Count
        Minutes = ($_.Group | Measure-Object Minutes -Sum).Sum
    }
}

$summary | Sort-Object Team
