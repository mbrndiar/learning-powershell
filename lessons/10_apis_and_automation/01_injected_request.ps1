Set-StrictMode -Version Latest

function Get-ApiTask {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Request)

    $json = & $Request
    $json | ConvertFrom-Json | Where-Object Done
}

$offlineRequest = { '[{"name":"Read","done":true},{"name":"Build","done":false}]' }
Get-ApiTask -Request $offlineRequest
