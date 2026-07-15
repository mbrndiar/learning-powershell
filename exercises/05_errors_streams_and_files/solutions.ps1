#Requires -Version 7.4

# Reference solution for Module 5. Two design choices matter: ConvertTo-Json
# -InputObject @($Task) keeps a stable top-level array (even for one task),
# and the write is gated by ShouldProcess while the summary is always returned.

Set-StrictMode -Version Latest

function Save-TaskJson {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [AllowEmptyCollection()][pscustomobject[]] $Task
    )
    if ($PSCmdlet.ShouldProcess($LiteralPath, 'write task JSON')) {
        ConvertTo-Json -InputObject @($Task) -Depth 4 |
            Set-Content -LiteralPath $LiteralPath -Encoding utf8
    }
    [pscustomobject]@{ Path = $LiteralPath; Count = @($Task).Count }
}
$path = Join-Path $PSScriptRoot '.exercise-tasks.json'
try {
    $result = Save-TaskJson -LiteralPath $path -Task @([pscustomobject]@{ Name = 'Read' })
    $stored = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -NoEnumerate
    if ($stored -isnot [array] -or @($stored).Count -ne 1 -or $stored[0].Name -ne 'Read') {
        throw 'Single-task array check failed.'
    }
    if ($result.Count -ne 1) { throw 'Result check failed.' }
    Save-TaskJson -LiteralPath $path -Task @() | Out-Null
    $empty = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -NoEnumerate
    if ($empty -isnot [array] -or @($empty).Count -ne 0) { throw 'Empty array check failed.' }
    'All checks passed.'
}
finally { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
