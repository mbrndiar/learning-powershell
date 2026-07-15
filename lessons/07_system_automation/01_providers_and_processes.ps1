#Requires -Version 7.4

Set-StrictMode -Version Latest

function Assert-NativeExitCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int] $ExitCode,
        [int[]] $SuccessExitCode = @(0)
    )

    if ($ExitCode -notin $SuccessExitCode) {
        throw [System.InvalidOperationException]::new(
            "Native command exited with code $ExitCode."
        )
    }
    $ExitCode
}

$pathSeparator = [System.IO.Path]::PathSeparator
$samplePath = $env:PATH -split [regex]::Escape([string] $pathSeparator) | Select-Object -First 1
$pwshPath = (Get-Process -Id $PID).Path

# Native commands receive explicit argument values; check their exit code.
& $pwshPath -NoProfile -Command 'exit 0'
$successExitCode = Assert-NativeExitCode -ExitCode $LASTEXITCODE

$previousNativePreference = $PSNativeCommandUseErrorActionPreference
$PSNativeCommandUseErrorActionPreference = $false
try {
    & $pwshPath -NoProfile -Command 'exit 7'
    $failureMessage = try {
        Assert-NativeExitCode -ExitCode $LASTEXITCODE
    }
    catch {
        $_.Exception.Message
    }
}
finally {
    $PSNativeCommandUseErrorActionPreference = $previousNativePreference
}

[pscustomobject]@{
    Providers = @(Get-PSProvider).Name -join ', '
    CurrentPath = (Get-Location).Path
    PathEntry = $samplePath
    ProcessCount = @(Get-Process).Count
    SuccessExitCode = $successExitCode
    FailureMessage = $failureMessage
}
