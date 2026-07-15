#Requires -Version 7.4

# This lesson shows the pipeline as object composition: commands pass objects
# with properties, not screen text. Filter, sort, and project the shape, and
# reserve any formatting for a final human-facing endpoint.

Set-StrictMode -Version Latest

$tasks = @(
    [pscustomobject]@{ Name = 'Read'; Minutes = 20; Done = $true }
    [pscustomobject]@{ Name = 'Build'; Minutes = 45; Done = $false }
    [pscustomobject]@{ Name = 'Test'; Minutes = 30; Done = $true }
)

# Where-Object Done is property-name shorthand: it keeps rows whose Done
# property is truthy. Each stage receives objects and passes objects on.
$completed = $tasks |
    Where-Object Done |
    Sort-Object Minutes -Descending |
    Select-Object Name, Minutes

$completed
# Inspect interactively: $completed | Get-Member
