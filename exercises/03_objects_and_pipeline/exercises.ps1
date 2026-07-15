Set-StrictMode -Version Latest

function Get-CompletedTask {
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][pscustomobject] $Task)
    process {
        # TODO: Emit only tasks whose Done property is true.
        throw 'TODO: implement Get-CompletedTask.'
    }
}
function Get-TaskSummary {
    [CmdletBinding()]
    param([pscustomobject[]] $Task)
    # TODO: Return a PSCustomObject with Count and CompletedCount.
    throw 'TODO: implement Get-TaskSummary.'
}
'TODO functions are intentionally incomplete.'
