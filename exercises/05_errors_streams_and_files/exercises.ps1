#Requires -Version 7.4

# Starter for Module 5. The goal is a stable top-level JSON array even for a
# single task, so use -InputObject (piping would unroll a one-element array).
# Write only after ShouldProcess approves, then still return the summary object.

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
