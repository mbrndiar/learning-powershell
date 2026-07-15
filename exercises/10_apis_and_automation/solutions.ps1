Set-StrictMode -Version Latest

function Get-ActiveRecord {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Request)
    & $Request | ConvertFrom-Json | Where-Object Active
}
$request = { '[{"name":"Ada","active":true},{"name":"Lin","active":false}]' }
$result = @(Get-ActiveRecord -Request $request)
if ($result.Count -ne 1 -or $result[0].name -ne 'Ada') { throw 'API boundary check failed.' }
'All checks passed.'
