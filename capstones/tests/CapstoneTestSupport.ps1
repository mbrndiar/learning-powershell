#Requires -Version 7.4

Set-StrictMode -Version Latest

$script:CapstonesRoot = Split-Path -Path $PSScriptRoot -Parent

function Get-CapstoneTestTarget {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Comparative', 'Idiomatic')]
        [string] $Capstone
    )

    $implementation = $env:CAPSTONE_IMPLEMENTATION
    if ([string]::IsNullOrWhiteSpace($implementation)) {
        $implementation = 'solution'
    }
    $implementation = $implementation.ToLowerInvariant()
    if ($implementation -notin 'starter', 'solution') {
        throw [System.ArgumentException]::new(
            "CAPSTONE_IMPLEMENTATION must be 'starter' or 'solution'; received '$implementation'."
        )
    }

    $definition = switch ($Capstone) {
        'Comparative' {
            @{
                Directory = 'comparative'
                ModuleName = 'ComparativeKv'
                ScriptName = 'configuration-store.ps1'
                ExportedFunctions = @(
                    'Get-ConfigurationEntry'
                    'Get-ConfigurationStore'
                    'Remove-ConfigurationEntry'
                    'Set-ConfigurationEntry'
                )
            }
        }
        'Idiomatic' {
            @{
                Directory = 'idiomatic'
                ModuleName = 'ComplianceAudit'
                ScriptName = 'compliance-audit.ps1'
                ExportedFunctions = @(
                    'Export-ComplianceReport'
                    'Import-CompliancePolicy'
                    'Repair-Compliance'
                    'Test-Compliance'
                )
            }
        }
    }

    $implementationRoot = Join-Path -Path $script:CapstonesRoot -ChildPath (
        '{0}/{1}' -f $definition.Directory, $implementation
    )
    [pscustomobject]@{
        Capstone = $Capstone
        Implementation = $implementation
        ModuleName = $definition.ModuleName
        ModulePath = Join-Path -Path $implementationRoot -ChildPath (
            '{0}.psd1' -f $definition.ModuleName
        )
        ScriptPath = Join-Path -Path $implementationRoot -ChildPath $definition.ScriptName
        ExportedFunctions = @($definition.ExportedFunctions)
        StarterModulePath = Join-Path -Path $script:CapstonesRoot -ChildPath (
            '{0}/starter/{1}.psd1' -f $definition.Directory, $definition.ModuleName
        )
        SolutionModulePath = Join-Path -Path $script:CapstonesRoot -ChildPath (
            '{0}/solution/{1}.psd1' -f $definition.Directory, $definition.ModuleName
        )
    }
}

function Get-CapstoneModuleSignature {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $ModulePath,

        [Parameter(Mandatory)]
        [string] $ModuleName,

        [Parameter(Mandatory)]
        [string[]] $CommandName
    )

    Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
    try {
        Import-Module -Name $ModulePath -Force -ErrorAction Stop
        foreach ($name in ($CommandName | Sort-Object)) {
            [pscustomobject]@{
                Name = $name
                Syntax = @(
                    Get-Command -Name $name -Module $ModuleName -Syntax -ErrorAction Stop
                ) -join "`n"
            }
        }
    }
    finally {
        Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
    }
}
