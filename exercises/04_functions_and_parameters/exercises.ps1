Set-StrictMode -Version Latest

function ConvertTo-Label {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [string] $Text,
        [ValidateSet('Upper', 'Lower')]
        [string] $Case = 'Upper'
    )
    process {
        # TODO: Emit a PSCustomObject with Input and Output properties.
        throw 'TODO: implement ConvertTo-Label.'
    }
}
'TODO: use a splatted parameter hashtable to call ConvertTo-Label.'
