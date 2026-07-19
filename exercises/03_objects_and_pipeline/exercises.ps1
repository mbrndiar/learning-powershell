#Requires -Version 7.4

# Starter for Module 3. Advanced-function syntax is supplied infrastructure
# taught in Module 4. Edit only TODO bodies and use an ordinary foreach over the
# Task array; pipeline parameter binding and process blocks are not prerequisites.

Set-StrictMode -Version Latest

function Get-CompletedTask {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([AllowEmptyCollection()][pscustomobject[]] $Task)
    # TODO: Validate every Done property and emit only original completed tasks.
    throw 'TODO: implement Get-CompletedTask.'
}
function Get-TaskSummary {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([AllowEmptyCollection()][pscustomobject[]] $Task)
    # TODO: Return a PSCustomObject with Count and CompletedCount.
    throw 'TODO: implement Get-TaskSummary.'
}
'TODO bodies are intentionally incomplete.'
