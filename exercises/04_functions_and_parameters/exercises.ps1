#Requires -Version 7.4

Set-StrictMode -Version Latest

function ConvertTo-Label {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory)]
        [string] $Text,
        [ValidateSet('Upper', 'Lower')]
        [string] $Case = 'Upper'
    )
    process {
        # TODO: Emit a PSCustomObject with Input and Output properties.
        throw 'TODO: implement ConvertTo-Label.'
    }
}
'TODO: call ConvertTo-Label with splatting and with an object that has a Text property.'
