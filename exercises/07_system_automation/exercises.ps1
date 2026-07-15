Set-StrictMode -Version Latest

function Set-DesiredContent {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string] $LiteralPath, [Parameter(Mandatory)][string] $Content)
    # TODO: Write only when content differs and ShouldProcess approves.
    # TODO: Return an object with Path and Changed.
    throw 'TODO: implement Set-DesiredContent.'
}
'TODO functions are intentionally incomplete.'
