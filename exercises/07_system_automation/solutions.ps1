#Requires -Version 7.4

Set-StrictMode -Version Latest

function Assert-NativeExitCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int] $ExitCode,
        [int[]] $SuccessExitCode = @(0)
    )
    if ($ExitCode -notin $SuccessExitCode) {
        throw "Native command exited with code $ExitCode."
    }
    $ExitCode
}

function Set-DesiredContent {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string] $LiteralPath, [Parameter(Mandatory)][string] $Content)
    $existing = if (Test-Path -LiteralPath $LiteralPath) { Get-Content -LiteralPath $LiteralPath -Raw } else { $null }
    $changed = $existing -ne $Content
    if ($changed -and $PSCmdlet.ShouldProcess($LiteralPath, 'set desired content')) {
        Set-Content -LiteralPath $LiteralPath -Value $Content -Encoding utf8 -NoNewline
    }
    [pscustomobject]@{ Path = $LiteralPath; Changed = $changed }
}
$path = Join-Path $PSScriptRoot '.desired-content.txt'
try {
    $pwshPath = (Get-Command -Name pwsh -CommandType Application -All |
            Select-Object -First 1).Source
    & $pwshPath -NoProfile -Command 'exit 0'
    $nativeExitCode = Assert-NativeExitCode -ExitCode $LASTEXITCODE
    if ($nativeExitCode -ne 0) { throw 'Native exit-code check failed.' }
    $nativeFailureRejected = try {
        Assert-NativeExitCode -ExitCode 7
        $false
    }
    catch {
        $true
    }
    if (-not $nativeFailureRejected) { throw 'Native failure check failed.' }

    $first = Set-DesiredContent -LiteralPath $path -Content 'desired'
    $second = Set-DesiredContent -LiteralPath $path -Content 'desired'
    if (-not $first.Changed -or $second.Changed) { throw 'Idempotency check failed.' }
    'All checks passed.'
}
finally { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
