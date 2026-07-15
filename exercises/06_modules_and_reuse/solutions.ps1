Set-StrictMode -Version Latest

function Get-OpenItem {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Source)
    & $Source | Where-Object { -not $_.Done }
}
$source = { @([pscustomobject]@{ Name = 'A'; Done = $false }, [pscustomobject]@{ Name = 'B'; Done = $true }) }
$result = @(Get-OpenItem -Source $source)
if ($result.Count -ne 1 -or $result[0].Name -ne 'A') { throw 'Dependency seam check failed.' }
'All checks passed.'
