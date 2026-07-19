#Requires -Version 7.4

# This lesson shows two things about background jobs the script itself owns:
#   1. The serialization boundary: objects crossing back from a job are
#      deserialized snapshots (property data only), so live behavior such as
#      instance methods is gone.
#   2. The cancellation/timeout lifecycle: bound the wait with Wait-Job
#      -Timeout, Stop-Job when it overruns, then Receive-Job and Remove-Job so
#      no job is left running. Cancellation here is cooperative job control, not
#      name-based process killing.

Set-StrictMode -Version Latest

# --- 1. Serialization boundary ---------------------------------------------
$snapshotJob = Start-Job -ScriptBlock { Get-Process -Id ([Environment]::ProcessId) }
# finally attempts job cleanup even if Receive-Job throws.
try {
    $snapshotJob | Wait-Job | Out-Null
    $received = Receive-Job -Job $snapshotJob
    $processName = $received.ProcessName
    # The type name is prefixed "Deserialized." and live methods like Kill() are
    # absent: only serialized property data survives the boundary.
    $receivedType = $received.PSObject.TypeNames[0]
    $hasLiveKill = $null -ne $received.PSObject.Methods['Kill']
}
finally {
    Remove-Job -Job $snapshotJob -Force -ErrorAction SilentlyContinue
}

# --- 2. Bounded wait, stop, and cleanup ------------------------------------
# This job intentionally overruns. Wait-Job -Timeout gives it a bounded chance
# to finish; because the sleep far exceeds the timeout, the timeout branch is
# deterministic. The script owns the $slowJob variable, so it can always stop
# and remove it, without searching for a process by name.
$slowJob = Start-Job -ScriptBlock { Start-Sleep -Seconds 30; 'completed' }
try {
    $slowJob | Wait-Job -Timeout 2 | Out-Null
    $timedOut = $slowJob.State -ne 'Completed'
    if ($timedOut) {
        # Cooperative stop of the job we started; it transitions to 'Stopped'.
        Stop-Job -Job $slowJob
    }
    # Drain whatever the job produced before it was stopped so nothing is lost
    # silently; a stopped-early job may legitimately yield no output.
    $partial = @(Receive-Job -Job $slowJob)
    $finalState = $slowJob.State
}
finally {
    # Always remove a job the script started, even on the cancellation path.
    Remove-Job -Job $slowJob -Force -ErrorAction SilentlyContinue
}

[pscustomobject]@{
    ProcessName = $processName
    ReceivedType = $receivedType
    HasLiveKillMethod = $hasLiveKill
    SlowJobTimedOut = $timedOut
    SlowJobFinalState = $finalState
    PartialOutputCount = $partial.Count
}
