#Requires -Version 7.4

Set-StrictMode -Version Latest

function Get-RemoteTask {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Request)

    foreach ($task in @(& $Request)) {
        $done = $task.PSObject.Properties['Done']
        if ($null -eq $done -or $done.Value -isnot [bool]) {
            throw 'Request results require a Boolean Done property.'
        }
        if ($done.Value) { $task }
    }
}

$offlineRequest = {
    @(
        [pscustomobject]@{ Name = 'Read'; Done = $true }
        [pscustomobject]@{ Name = 'Build'; Done = $false }
    )
}
Get-RemoteTask -Request $offlineRequest
