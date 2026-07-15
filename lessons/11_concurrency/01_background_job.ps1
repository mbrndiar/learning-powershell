#Requires -Version 7.4

Set-StrictMode -Version Latest

$job = Start-Job -ScriptBlock { Get-Process -Id ([Environment]::ProcessId) }
try {
    $job | Wait-Job | Out-Null
    $received = Receive-Job -Job $job
    [pscustomobject]@{
        ProcessName = $received.ProcessName
        ReceivedType = $received.PSObject.TypeNames[0]
        HasLiveKillMethod = $null -ne $received.PSObject.Methods['Kill']
    }
}
finally {
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
}
