#Requires -Version 7.4

# Reference solution for Module 3. The important choice is treating Done as a
# strict contract: checking $done.Value -isnot [bool] rejects a truthy string
# like 'false', which would otherwise be counted as completed.

Set-StrictMode -Version Latest

function Get-CompletedTask {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][pscustomobject] $Task)
    process {
        $done = $Task.PSObject.Properties['Done']
        if ($null -eq $done -or $done.Value -isnot [bool]) {
            throw 'Task requires a Boolean Done property.'
        }
        if ($done.Value) { $Task }
    }
}
function Get-TaskSummary {
    [CmdletBinding()]
    param([pscustomobject[]] $Task)
    [pscustomobject]@{
        Count = @($Task).Count
        CompletedCount = @($Task | Get-CompletedTask).Count
    }
}
$tasks = @([pscustomobject]@{ Name = 'Read'; Done = $true }, [pscustomobject]@{ Name = 'Build'; Done = $false })
$summary = Get-TaskSummary -Task $tasks
if ($summary.CompletedCount -ne 1) { throw 'Summary check failed.' }
$invalidRejected = try {
    [pscustomobject]@{ Name = 'Invalid'; Done = 'false' } | Get-CompletedTask
    $false
}
catch {
    $true
}
if (-not $invalidRejected) { throw 'Boolean contract check failed.' }
'All checks passed.'
