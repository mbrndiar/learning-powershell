#Requires -Version 7.4

# This lesson imports a general .psd1 data file without executing it, then
# builds a real module whose specialized manifest advertises metadata and
# exports while its .psm1 holds implementation code.

Set-StrictMode -Version Latest

$directory = Join-Path $PSScriptRoot ('.scratch-module-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $directory -Force
try {
    $dataPath = Join-Path $directory 'Configuration.psd1'
    $modulePath = Join-Path $directory 'Greeting.psm1'
    $manifestPath = Join-Path $directory 'Greeting.psd1'
    @'
@{
    Mode = 'offline'
    RetryCount = 2
    Features = @('Greeting', 'Audit')
}
'@ | Set-Content -LiteralPath $dataPath -Encoding utf8
    # Import-PowerShellDataFile parses the restricted data language. It does not
    # dot-source or otherwise execute this configuration file.
    $configuration = Import-PowerShellDataFile -LiteralPath $dataPath

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
    # A manifest is a specialized data file. Safe import exposes its fields,
    # while Test-ModuleManifest validates module-specific structure and paths.
    $manifestData = Import-PowerShellDataFile -LiteralPath $manifestPath
    $validatedManifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    if ($configuration['Mode'] -ne 'offline' -or
        $configuration['RetryCount'] -ne 2 -or
        $manifestData['RootModule'] -ne 'Greeting.psm1' -or
        @($manifestData['FunctionsToExport']) -notcontains 'Get-Greeting' -or
        $validatedManifest.Name -ne 'Greeting') {
        throw 'Data-file or manifest validation evidence failed.'
    }
    # -Force reloads the module so edits during development take effect.
    Import-Module -Name $manifestPath -Force

    $greeting = Get-Greeting -Name ' Ada '
    $exported = @(Get-Command -Module Greeting).Name
    # The private helper is not importable by callers, proving the boundary.
    $privateCommand = Get-Command -Name ConvertTo-GreetingName -ErrorAction SilentlyContinue
    [pscustomobject]@{
        ConfigurationMode = $configuration['Mode']
        ConfigurationFeatures = @($configuration['Features']) -join ', '
        ManifestRootModule = $manifestData['RootModule']
        ManifestVersion = $validatedManifest.Version.ToString()
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
