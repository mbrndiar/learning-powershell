#Requires -Version 7.4

# Thin CLI over the TaskManager module: it maps a verb (-Action) to one
# exported command and forwards -WhatIf/-Confirm so previews and prompts work
# end to end from the command line.

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

# Snapshot which parameters the caller actually bound, so we can reject
# arguments that do not belong to the selected action (a hand-rolled
# equivalent of parameter sets across the -Action verbs).
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
# Forward this run's WhatIf preference to the state-changing commands, and
# forward -Confirm only when the caller set it explicitly (so the commands'
# own ConfirmImpact defaults still apply otherwise).
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
