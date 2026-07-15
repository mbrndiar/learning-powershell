#Requires -Version 7.4

# Starter for Module 4. ConvertTo-Label must work both when Text is piped as a
# value and when it arrives as a property of a piped object. Emit one object
# per item from the process block so the command composes in a pipeline.

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
