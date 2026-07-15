#Requires -Version 7.4

# This lesson shows a safe, idempotent state change. The mental model: read
# current state, compare to the desired state, and change only what differs;
# guard the mutation with ShouldProcess so -WhatIf and -Confirm work.

Set-StrictMode -Version Latest

function Set-ExampleFile {
    # SupportsShouldProcess wires up -WhatIf/-Confirm for this command.
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string] $LiteralPath)

    $desired = "managed`n"
    $current = if (Test-Path -LiteralPath $LiteralPath) {
        Get-Content -LiteralPath $LiteralPath -Raw
    }
    # Only write when content differs; a converged file is left untouched.
    $changed = $current -ne $desired
    # ShouldProcess gates the actual side effect and returns $false under
    # -WhatIf, so the write is skipped while the preview still runs.
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
