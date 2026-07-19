#Requires -Version 7.4

# Reference solution for Module 3. The important choice is treating Done as a
# strict contract while using only an array parameter and ordinary foreach.
# Checking the property type rejects a truthy string such as 'false'.

Set-StrictMode -Version Latest

function Get-CompletedTask {
    [CmdletBinding()]
    param([AllowEmptyCollection()][pscustomobject[]] $Task)
    foreach ($item in $Task) {
        $done = $item.PSObject.Properties['Done']
        if ($null -eq $done -or $done.Value -isnot [bool]) {
            throw 'Task requires a Boolean Done property.'
        }
        if ($done.Value) { $item }
    }
}
function Get-TaskSummary {
    [CmdletBinding()]
    param([AllowEmptyCollection()][pscustomobject[]] $Task)
    $completed = @(Get-CompletedTask -Task $Task)
    [pscustomobject]@{
        Count = @($Task).Count
        CompletedCount = $completed.Count
    }
}

$emptyCompleted = @(Get-CompletedTask -Task @())
$emptySummary = Get-TaskSummary -Task @()
if ($emptyCompleted.Count -ne 0 -or
    $emptySummary.Count -ne 0 -or
    $emptySummary.CompletedCount -ne 0) {
    throw 'Empty-input checks failed.'
}

$tasks = @(
    [pscustomobject]@{ Name = 'Read'; Done = $true }
    [pscustomobject]@{ Name = 'Build'; Done = $false }
    [pscustomobject]@{ Name = 'Test'; Done = $true }
)
$completed = @(Get-CompletedTask -Task $tasks)
if ($completed.Count -ne 2 -or
    -not [object]::ReferenceEquals($completed[0], $tasks[0]) -or
    -not [object]::ReferenceEquals($completed[1], $tasks[2])) {
    throw 'Multiple-input or original-object check failed.'
}
$summary = Get-TaskSummary -Task $tasks
if ($summary.Count -ne 3 -or $summary.CompletedCount -ne 2) {
    throw 'Summary count checks failed.'
}

$missingRejected = try {
    Get-CompletedTask -Task @([pscustomobject]@{ Name = 'Missing' })
    $false
}
catch {
    $true
}
if (-not $missingRejected) { throw 'Missing Done check failed.' }

$nonBooleanRejected = try {
    Get-CompletedTask -Task @([pscustomobject]@{ Name = 'Invalid'; Done = 'false' })
    $false
}
catch {
    $true
}
if (-not $nonBooleanRejected) { throw 'Non-Boolean Done check failed.' }
'All checks passed.'
