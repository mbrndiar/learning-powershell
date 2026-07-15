Set-StrictMode -Version Latest

$directory = Join-Path $PSScriptRoot ('.scratch-module-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $directory -Force
try {
    $modulePath = Join-Path $directory 'Greeting.psm1'
    @'
function Get-Greeting {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Name)
    [pscustomobject]@{ Message = "Hello, $Name" }
}
Export-ModuleMember -Function Get-Greeting
'@ | Set-Content -LiteralPath $modulePath -Encoding utf8
    Import-Module -Name $modulePath -Force
    Get-Greeting -Name 'Ada'
}
finally {
    Remove-Module -Name Greeting -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
}
