Set-StrictMode -Version Latest

function Save-TaskJson {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSShouldProcess', '',
        Justification = 'The learner adds the ShouldProcess call in this TODO starter.'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [AllowEmptyCollection()][pscustomobject[]] $Task
    )
    # TODO: Serialize Task as a stable top-level JSON array by using -InputObject.
    # TODO: Write UTF-8 JSON only after ShouldProcess approves.
    # TODO: Return a PSCustomObject describing the write.
    throw 'TODO: implement Save-TaskJson.'
}
'TODO functions are intentionally incomplete.'
