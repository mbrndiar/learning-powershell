Set-StrictMode -Version Latest

function Save-TaskJson {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string] $LiteralPath, [pscustomobject[]] $Task)
    # TODO: Serialize Task as UTF-8 JSON only after ShouldProcess approves.
    # TODO: Return a PSCustomObject describing the write.
    throw 'TODO: implement Save-TaskJson.'
}
'TODO functions are intentionally incomplete.'
