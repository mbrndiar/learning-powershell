Set-StrictMode -Version Latest

function Save-TaskJson {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string] $LiteralPath, [pscustomobject[]] $Task)
    if ($PSCmdlet.ShouldProcess($LiteralPath, 'write task JSON')) {
        $Task | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $LiteralPath -Encoding utf8
    }
    [pscustomobject]@{ Path = $LiteralPath; Count = @($Task).Count }
}
$path = Join-Path $PSScriptRoot '.exercise-tasks.json'
try {
    $result = Save-TaskJson -LiteralPath $path -Task @([pscustomobject]@{ Name = 'Read' })
    if ((Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).Name -ne 'Read') { throw 'JSON check failed.' }
    if ($result.Count -ne 1) { throw 'Result check failed.' }
    'All checks passed.'
}
finally { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
