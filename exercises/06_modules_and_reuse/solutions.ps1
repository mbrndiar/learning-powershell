#Requires -Version 7.4

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
$source = { @([pscustomobject]@{ Name = 'A'; Done = $false }, [pscustomobject]@{ Name = 'B'; Done = $true }) }
$result = @(Get-OpenItem -Source $source)
if ($result.Count -ne 1 -or $result[0].Name -ne 'A') { throw 'Dependency seam check failed.' }
$invalidRejected = try {
    Get-OpenItem -Source { [pscustomobject]@{ Name = 'Invalid'; Done = 'false' } }
    $false
}
catch {
    $true
}
if (-not $invalidRejected) { throw 'Boolean contract check failed.' }
'All checks passed.'
