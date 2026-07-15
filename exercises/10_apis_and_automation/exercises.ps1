Set-StrictMode -Version Latest

function Get-ActiveRecord {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Request)
    # TODO: Invoke Request, parse its JSON, and emit records where Active is true.
    throw 'TODO: implement Get-ActiveRecord.'
}
# TODO: Add Pester tests for active filtering and invalid JSON.
'TODO functions and tests are intentionally incomplete.'
