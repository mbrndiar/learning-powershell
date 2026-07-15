#Requires -Version 7.4

Set-StrictMode -Version Latest

$directory = Join-Path $PSScriptRoot ('.scratch-module-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $directory -Force
try {
    $modulePath = Join-Path $directory 'Greeting.psm1'
    $manifestPath = Join-Path $directory 'Greeting.psd1'
    @'
function ConvertTo-GreetingName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Name)
    $Name.Trim()
}

function Get-Greeting {
    <#
    .SYNOPSIS
    Returns a greeting object for one person.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if ([string]::IsNullOrWhiteSpace($_)) { throw 'Name cannot be blank.' }
            $true
        })]
        [string] $Name
    )
    $normalizedName = ConvertTo-GreetingName -Name $Name
    [pscustomobject]@{ Message = "Hello, $normalizedName" }
}
Export-ModuleMember -Function Get-Greeting
'@ | Set-Content -LiteralPath $modulePath -Encoding utf8
    New-ModuleManifest -Path $manifestPath -RootModule 'Greeting.psm1' `
        -ModuleVersion '1.0.0' -Guid ([guid]::NewGuid()) `
        -PowerShellVersion '7.4' -FunctionsToExport 'Get-Greeting'
    Import-Module -Name $manifestPath -Force

    $greeting = Get-Greeting -Name ' Ada '
    $exported = @(Get-Command -Module Greeting).Name
    $privateCommand = Get-Command -Name ConvertTo-GreetingName -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Message = $greeting.Message
        ExportedCommands = $exported -join ', '
        PrivateHelperVisible = $null -ne $privateCommand
        Synopsis = (Get-Help Get-Greeting).Synopsis
    }
}
finally {
    Remove-Module -Name Greeting -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
}
