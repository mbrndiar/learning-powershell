Set-StrictMode -Version Latest

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
    $first = Set-DesiredContent -LiteralPath $path -Content 'desired'
    $second = Set-DesiredContent -LiteralPath $path -Content 'desired'
    if (-not $first.Changed -or $second.Changed) { throw 'Idempotency check failed.' }
    'All checks passed.'
}
finally { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
