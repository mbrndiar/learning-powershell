#Requires -Version 7.4

# This lesson builds a real module at runtime to show the public boundary: a
# manifest (.psd1) advertises metadata and exports, the implementation (.psm1)
# holds the code, and Export-ModuleMember keeps helpers private.

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
    # The manifest names the implementation and repeats the intended export
    # surface; only Get-Greeting is public, ConvertTo-GreetingName stays hidden.
    New-ModuleManifest -Path $manifestPath -RootModule 'Greeting.psm1' `
        -ModuleVersion '1.0.0' -Guid ([guid]::NewGuid()) `
        -PowerShellVersion '7.4' -FunctionsToExport 'Get-Greeting'
    # -Force reloads the module so edits during development take effect.
    Import-Module -Name $manifestPath -Force

    $greeting = Get-Greeting -Name ' Ada '
    $exported = @(Get-Command -Module Greeting).Name
    # The private helper is not importable by callers, proving the boundary.
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
