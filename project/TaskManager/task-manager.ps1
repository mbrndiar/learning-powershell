#Requires -Version 7.4

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('List', 'Add', 'Complete', 'Remove')]
    [string] $Action,

    [string] $Title,

    [string] $Id,

    [string] $DataPath = (Join-Path -Path $PSScriptRoot -ChildPath 'tasks.json')
)

Set-StrictMode -Version Latest
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'TaskManager.psd1') -Force

$scriptArguments = @{} + $PSBoundParameters
function Assert-ParameterNotBound {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]] $Name)

    foreach ($parameterName in $Name) {
        if ($scriptArguments.ContainsKey($parameterName)) {
            throw "$Action does not accept -$parameterName."
        }
    }
}

$common = @{ LiteralPath = $DataPath }
$stateChange = @{
    LiteralPath = $DataPath
    WhatIf = $WhatIfPreference
}
if ($scriptArguments.ContainsKey('Confirm')) {
    $stateChange.Confirm = [bool] $scriptArguments['Confirm']
}

switch ($Action) {
    'List' {
        Assert-ParameterNotBound -Name Title, Id
        Get-Task @common
    }
    'Add' {
        Assert-ParameterNotBound -Name Id
        if ([string]::IsNullOrWhiteSpace($Title)) { throw 'Add requires -Title.' }
        Add-Task @stateChange -Title $Title
    }
    'Complete' {
        Assert-ParameterNotBound -Name Title
        if ([string]::IsNullOrWhiteSpace($Id)) { throw 'Complete requires -Id.' }
        Set-Task @stateChange -Id $Id -Done $true
    }
    'Remove' {
        Assert-ParameterNotBound -Name Title
        if ([string]::IsNullOrWhiteSpace($Id)) { throw 'Remove requires -Id.' }
        Remove-Task @stateChange -Id $Id
    }
}
