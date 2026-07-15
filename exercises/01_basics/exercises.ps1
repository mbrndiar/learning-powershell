Set-StrictMode -Version Latest

function Get-Greeting {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Name)
    # TODO: Return an interpolated greeting string.
    throw 'TODO: implement Get-Greeting.'
}

function Get-NumberKind {
    [CmdletBinding()]
    param([int] $Number)
    # TODO: Return 'positive', 'negative', or 'zero'.
    throw 'TODO: implement Get-NumberKind.'
}

'TODO functions are intentionally incomplete. Implement them, then add checks.'
