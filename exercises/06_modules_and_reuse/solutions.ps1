#Requires -Version 7.4

# Reference solution for Module 6. The scriptblock Source is a dependency seam:
# invoking it with & keeps the function testable, and validating Done as a real
# Boolean rejects a truthy string before it can be misread as completed.

Set-StrictMode -Version Latest

function Get-OpenItem {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Source)
    foreach ($item in @(& $Source)) {
        $done = $item.PSObject.Properties['Done']
        if ($null -eq $done -or $done.Value -isnot [bool]) {
            throw 'Source results require a Boolean Done property.'
        }
        if (-not $done.Value) { $item }
    }
}
function Get-DataFileValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)][string] $Name
    )
    $data = Import-PowerShellDataFile -LiteralPath $LiteralPath -ErrorAction Stop
    if (-not $data.ContainsKey($Name)) {
        throw "Data file does not contain key '$Name'."
    }
    $data[$Name]
}

$normalSource = {
    @(
        [pscustomobject]@{ Name = 'A'; Done = $false }
        [pscustomobject]@{ Name = 'B'; Done = $true }
    )
}
$normalResult = @(Get-OpenItem -Source $normalSource)
if ($normalResult.Count -ne 1 -or $normalResult[0].Name -ne 'A') {
    throw 'Normal dependency seam check failed.'
}
if (@(Get-OpenItem -Source { @() }).Count -ne 0) {
    throw 'Zero-result source check failed.'
}
$manyResult = @(
    Get-OpenItem -Source {
        @(
            [pscustomobject]@{ Name = 'A'; Done = $false }
            [pscustomobject]@{ Name = 'B'; Done = $false }
            [pscustomobject]@{ Name = 'C'; Done = $true }
        )
    }
)
if ($manyResult.Count -ne 2 -or ($manyResult.Name -join ',') -ne 'A,B') {
    throw 'Many-result source check failed.'
}

$missingDoneRejected = try {
    Get-OpenItem -Source { [pscustomobject]@{ Name = 'Missing' } }
    $false
}
catch {
    $true
}
if (-not $missingDoneRejected) { throw 'Missing Done check failed.' }

$nonBooleanRejected = try {
    Get-OpenItem -Source { [pscustomobject]@{ Name = 'Invalid'; Done = 'false' } }
    $false
}
catch {
    $true
}
if (-not $nonBooleanRejected) { throw 'Non-Boolean Done check failed.' }

$sourceFailure = try {
    Get-OpenItem -Source { throw 'source failed' }
    $null
}
catch {
    $_.Exception.Message
}
if ($sourceFailure -ne 'source failed') { throw 'Source failure was not preserved.' }

$directory = Join-Path $PSScriptRoot ('.exercise-data-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $directory -Force
try {
    $dataPath = Join-Path $directory '[configuration].psd1'
    @'
@{
    Mode = 'offline'
    RetryCount = 0
}
'@ | Set-Content -LiteralPath $dataPath -Encoding utf8

    if ((Get-DataFileValue -LiteralPath $dataPath -Name 'Mode') -ne 'offline') {
        throw 'Normal data-file value check failed.'
    }
    if ((Get-DataFileValue -LiteralPath $dataPath -Name 'RetryCount') -ne 0) {
        throw 'Falsey data-file value check failed.'
    }
    $missingKeyRejected = try {
        Get-DataFileValue -LiteralPath $dataPath -Name 'Missing'
        $false
    }
    catch {
        $true
    }
    if (-not $missingKeyRejected) { throw 'Missing data-file key check failed.' }
}
finally {
    Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
}
'All checks passed.'
