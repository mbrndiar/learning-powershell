#Requires -Version 7.4

Set-StrictMode -Version Latest

function Set-ExampleFile {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string] $LiteralPath)

    $desired = "managed`n"
    $current = if (Test-Path -LiteralPath $LiteralPath) {
        Get-Content -LiteralPath $LiteralPath -Raw
    }
    $changed = $current -ne $desired
    if ($changed -and $PSCmdlet.ShouldProcess($LiteralPath, 'write desired content')) {
        Set-Content -LiteralPath $LiteralPath -Value $desired -Encoding utf8 -NoNewline
        $current = $desired
    }
    [pscustomobject]@{
        Path = $LiteralPath
        Changed = $changed
        Compliant = $current -eq $desired
    }
}

$path = Join-Path $PSScriptRoot ('.scratch-state-' + [guid]::NewGuid() + '.txt')
try { Set-ExampleFile -LiteralPath $path } finally { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
