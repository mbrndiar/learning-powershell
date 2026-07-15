Set-StrictMode -Version Latest

$directory = Join-Path -Path $PSScriptRoot -ChildPath ('.scratch-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $directory -Force
try {
    $jsonPath = Join-Path -Path $directory -ChildPath 'tasks.json'
    $csvPath = Join-Path -Path $directory -ChildPath 'tasks.csv'
    $tasks = @([pscustomobject]@{ Name = 'Read'; Done = $true })
    $tasks | ConvertTo-Json | Set-Content -LiteralPath $jsonPath -Encoding utf8
    $tasks | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
    [pscustomobject]@{
        JsonName = (Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json).Name
        CsvRows = @(Import-Csv -LiteralPath $csvPath).Count
    }
}
finally {
    Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
}
