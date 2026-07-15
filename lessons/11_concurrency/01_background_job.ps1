Set-StrictMode -Version Latest

$job = Start-Job -ScriptBlock { [pscustomobject]@{ Value = 21 * 2; Source = 'job' } }
try {
    $job | Wait-Job | Out-Null
    Receive-Job -Job $job
}
finally {
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
}
