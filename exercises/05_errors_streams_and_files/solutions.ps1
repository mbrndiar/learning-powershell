#Requires -Version 7.4

# Reference solution for Module 5. ConvertTo-Json -InputObject keeps stable
# array shape, while byte-stream mode copies binary values without decoding.

Set-StrictMode -Version Latest

function Save-TaskJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [AllowEmptyCollection()][pscustomobject[]] $Task
    )
    ConvertTo-Json -InputObject @($Task) -Depth 4 |
        Set-Content -LiteralPath $LiteralPath -Encoding utf8
    [pscustomobject]@{ Path = $LiteralPath; Count = @($Task).Count }
}
function Copy-BinaryFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $SourceLiteralPath,
        [Parameter(Mandatory)][string] $DestinationLiteralPath
    )
    $bytes = Get-Content -LiteralPath $SourceLiteralPath -AsByteStream -Raw -ErrorAction Stop
    if ($null -eq $bytes) { $bytes = [byte[]]@() }
    Set-Content -LiteralPath $DestinationLiteralPath -AsByteStream -Value $bytes -ErrorAction Stop
    [pscustomobject]@{
        SourcePath = $SourceLiteralPath
        DestinationPath = $DestinationLiteralPath
        Count = $bytes.Count
    }
}

$directory = Join-Path $PSScriptRoot ('.exercise-files-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $directory -Force
try {
    # Brackets prove that every file function treats the path literally.
    $jsonPath = Join-Path $directory '[tasks].json'
    $sourcePath = Join-Path $directory '[source].bin'
    $destinationPath = Join-Path $directory '[copy].bin'

    $result = Save-TaskJson -LiteralPath $jsonPath -Task @([pscustomobject]@{ Name = 'Read' })
    $stored = Get-Content -LiteralPath $jsonPath -Raw -Encoding utf8 |
        ConvertFrom-Json -NoEnumerate
    if ($stored -isnot [array] -or @($stored).Count -ne 1 -or $stored[0].Name -ne 'Read') {
        throw 'Single-task array check failed.'
    }
    if ($result.Count -ne 1 -or $result.Path -ne $jsonPath) {
        throw 'Single-task result or literal-path check failed.'
    }

    Save-TaskJson -LiteralPath $jsonPath -Task @() | Out-Null
    $empty = Get-Content -LiteralPath $jsonPath -Raw -Encoding utf8 |
        ConvertFrom-Json -NoEnumerate
    if ($empty -isnot [array] -or @($empty).Count -ne 0) { throw 'Empty array check failed.' }

    [byte[]] $expectedBytes = 0, 1, 10, 127, 128, 254, 255
    Set-Content -LiteralPath $sourcePath -AsByteStream -Value $expectedBytes
    $copyResult = Copy-BinaryFile -SourceLiteralPath $sourcePath -DestinationLiteralPath $destinationPath
    [byte[]] $actualBytes = Get-Content -LiteralPath $destinationPath -AsByteStream -Raw
    if ($actualBytes.Count -ne $expectedBytes.Count -or
        [Convert]::ToHexString($actualBytes) -ne [Convert]::ToHexString($expectedBytes)) {
        throw 'Binary byte equality check failed.'
    }
    if ($copyResult.Count -ne $expectedBytes.Count -or
        $copyResult.SourcePath -ne $sourcePath -or
        $copyResult.DestinationPath -ne $destinationPath) {
        throw 'Binary copy result check failed.'
    }
    'All checks passed.'
}
finally {
    Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
}
