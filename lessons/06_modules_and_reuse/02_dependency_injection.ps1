#Requires -Version 7.4

# This lesson shows dependency injection with a scriptblock seam: the function
# receives its data source as a parameter instead of calling the network
# directly, so tests can supply deterministic offline data.

Set-StrictMode -Version Latest

function Get-RemoteTask {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Request)

    # & invokes the injected seam. In production this would call an API; here
    # a caller passes offline data, keeping the function testable.
    foreach ($task in @(& $Request)) {
        $done = $task.PSObject.Properties['Done']
        # Validate the shape at the boundary: reject a truthy string like
        # 'false' instead of trusting it as a Boolean.
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
