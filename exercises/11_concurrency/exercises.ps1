Set-StrictMode -Version Latest

function Get-ParallelSquare {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][int[]] $Number)
    # TODO: Use ForEach-Object -Parallel with a throttle limit.
    # TODO: Emit objects ordered by Number with Number and Square properties.
    throw 'TODO: implement Get-ParallelSquare.'
}
# TODO: Add Pester tests for ordering and empty input.
'TODO functions and tests are intentionally incomplete.'
