Set-StrictMode -Version Latest

$pathSeparator = [System.IO.Path]::PathSeparator
$samplePath = $env:PATH -split [regex]::Escape([string] $pathSeparator) | Select-Object -First 1
$pwshPath = (Get-Process -Id $PID).Path

# Native commands receive explicit argument values; check their exit code.
& $pwshPath -NoProfile -Command 'exit 0'
$nativeExitCode = $LASTEXITCODE

[pscustomobject]@{
    Providers = @(Get-PSProvider).Name -join ', '
    CurrentPath = (Get-Location).Path
    PathEntry = $samplePath
    ProcessCount = @(Get-Process).Count
    NativeExitCode = $nativeExitCode
}
