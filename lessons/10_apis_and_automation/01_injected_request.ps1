#Requires -Version 7.4

# This lesson treats an API response as an untrusted boundary. The mental
# model: inject the request as a scriptblock seam (deterministic offline
# tests), parse the JSON, and validate each record's shape before using it.

Set-StrictMode -Version Latest

function Get-ApiTask {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Request)

    # @(...) forces an array so a single JSON object still enumerates once.
    $records = @((& $Request) | ConvertFrom-Json)
    foreach ($record in $records) {
        $done = $record.PSObject.Properties['Done']
        # Enforce the contract: the JSON boolean must arrive as [bool], not a
        # truthy string like "false".
        if ($null -eq $done -or $done.Value -isnot [bool]) {
            throw 'Each API task requires a Boolean Done property.'
        }
        if ($done.Value) { $record }
    }
}

$offlineRequest = { '[{"name":"Read","done":true},{"name":"Build","done":false}]' }
Get-ApiTask -Request $offlineRequest
