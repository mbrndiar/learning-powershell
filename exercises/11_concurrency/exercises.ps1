Set-StrictMode -Version Latest

function Get-ParallelSquare {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int[]] $Number)
    # TODO: Use ForEach-Object -Parallel with a throttle limit.
    # TODO: Emit objects ordered by Number with Number and Square properties.
    throw 'TODO: implement Get-ParallelSquare.'
}
'TODO functions are intentionally incomplete.'
