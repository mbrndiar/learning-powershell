#Requires -Version 7.4

Set-StrictMode -Version Latest

function Get-ApiTask {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Request)

    $records = @((& $Request) | ConvertFrom-Json)
    foreach ($record in $records) {
        $done = $record.PSObject.Properties['Done']
        if ($null -eq $done -or $done.Value -isnot [bool]) {
            throw 'Each API task requires a Boolean Done property.'
        }
        if ($done.Value) { $record }
    }
}

$offlineRequest = { '[{"name":"Read","done":true},{"name":"Build","done":false}]' }
Get-ApiTask -Request $offlineRequest
