#Requires -Version 7.4

# Starter for Module 5. Keep JSON cardinality stable and keep binary data out of
# the text/encoding path. Implement only the TODO bodies.

Set-StrictMode -Version Latest

function Save-TaskJson {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [AllowEmptyCollection()][pscustomobject[]] $Task
    )
    # TODO: Serialize Task as a stable top-level JSON array by using -InputObject.
    # TODO: Write UTF-8 JSON to the literal path.
    # TODO: Return a PSCustomObject describing the write.
    throw 'TODO: implement Save-TaskJson.'
}
function Copy-BinaryFile {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $SourceLiteralPath,
        [Parameter(Mandatory)][string] $DestinationLiteralPath
    )
    # TODO: Read one byte[] with -AsByteStream -Raw and write it unchanged.
    # TODO: Return SourcePath, DestinationPath, and Count.
    throw 'TODO: implement Copy-BinaryFile.'
}
'TODO bodies are intentionally incomplete.'
