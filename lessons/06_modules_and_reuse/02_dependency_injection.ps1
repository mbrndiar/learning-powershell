Set-StrictMode -Version Latest

function Get-RemoteTask {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Request)

    $response = & $Request
    $response | Where-Object Done
}

$offlineRequest = {
    @(
        [pscustomobject]@{ Name = 'Read'; Done = $true }
        [pscustomobject]@{ Name = 'Build'; Done = $false }
    )
}
Get-RemoteTask -Request $offlineRequest
