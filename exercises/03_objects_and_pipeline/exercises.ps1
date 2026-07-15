Set-StrictMode -Version Latest

function Get-CompletedTask {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)][pscustomobject] $Task)
    process {
        # TODO: Emit only tasks whose Done property is true.
        throw 'TODO: implement Get-CompletedTask.'
    }
}
function Get-TaskSummary {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([pscustomobject[]] $Task)
    # TODO: Return a PSCustomObject with Count and CompletedCount.
    throw 'TODO: implement Get-TaskSummary.'
}
'TODO functions are intentionally incomplete.'
