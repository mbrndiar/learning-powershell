Set-StrictMode -Version Latest

function Get-CompletedTask {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][pscustomobject] $Task)
    process { if ($Task.Done) { $Task } }
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
'All checks passed.'
