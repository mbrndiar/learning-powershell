#Requires -Version 7.4

# This lesson persists structured data and shows the cardinality traps that
# bite at file boundaries: piping unrolls arrays (so JSON can collapse to an
# object), while -InputObject and -NoEnumerate preserve the array shape.

Set-StrictMode -Version Latest

$directory = Join-Path -Path $PSScriptRoot -ChildPath ('.scratch-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $directory -Force
# finally attempts scratch cleanup even when conversion or file I/O fails.
try {
    $jsonPath = Join-Path -Path $directory -ChildPath 'tasks.json'
    $csvPath = Join-Path -Path $directory -ChildPath 'tasks.csv'
    $tasks = @([pscustomobject]@{ Name = 'Read'; Done = $true })
    # Piping unrolls the single-element array, so ConvertTo-Json sees one
    # object and emits a JSON object (not an array).
    $pipelineJson = $tasks | ConvertTo-Json
    # -InputObject passes the array as one argument, keeping a top-level array
    # even for a single element: the stable shape to write.
    $stableJson = ConvertTo-Json -InputObject $tasks
    # Always set encoding explicitly for portable, predictable bytes.
    $stableJson | Set-Content -LiteralPath $jsonPath -Encoding utf8
    $tasks | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
    # -NoEnumerate keeps a one-element array as an array on read instead of
    # unrolling it to a scalar.
    $jsonTasks = Get-Content -LiteralPath $jsonPath -Raw |
        ConvertFrom-Json -NoEnumerate
    [pscustomobject]@{
        JsonRows = @($jsonTasks).Count
        JsonIsArray = $jsonTasks -is [array]
        PipelineJsonIsArray = $pipelineJson.TrimStart().StartsWith('[')
        InputObjectJsonIsArray = $stableJson.TrimStart().StartsWith('[')
        CsvRows = @(Import-Csv -LiteralPath $csvPath).Count
    }
}
finally {
    Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
}
