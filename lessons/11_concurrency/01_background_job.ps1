#Requires -Version 7.4

# This lesson shows a background job and the serialization boundary it creates.
# The mental model: objects crossing back from a job are deserialized snapshots
# (property data only), so live behavior such as instance methods is gone.

Set-StrictMode -Version Latest

$job = Start-Job -ScriptBlock { Get-Process -Id ([Environment]::ProcessId) }
# finally attempts job cleanup even if Receive-Job throws.
try {
    $job | Wait-Job | Out-Null
    $received = Receive-Job -Job $job
    [pscustomobject]@{
        ProcessName = $received.ProcessName
        # The type name is prefixed "Deserialized." and live methods like
        # Kill() are absent: only serialized property data survives the boundary.
        ReceivedType = $received.PSObject.TypeNames[0]
        HasLiveKillMethod = $null -ne $received.PSObject.Methods['Kill']
    }
}
finally {
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
}
