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

$common = @{ LiteralPath = $DataPath }
$stateChange = @{
    LiteralPath = $DataPath
    WhatIf = $WhatIfPreference
    Confirm = $false
}
if ($PSBoundParameters.ContainsKey('Confirm')) {
    $stateChange.Confirm = [bool] $PSBoundParameters['Confirm']
}

switch ($Action) {
    'List' { Get-Task @common }
    'Add' {
        if ([string]::IsNullOrWhiteSpace($Title)) { throw 'Add requires -Title.' }
        Add-Task @stateChange -Title $Title
    }
    'Complete' {
        if ([string]::IsNullOrWhiteSpace($Id)) { throw 'Complete requires -Id.' }
        Set-Task @stateChange -Id $Id -Done $true
    }
    'Remove' {
        if ([string]::IsNullOrWhiteSpace($Id)) { throw 'Remove requires -Id.' }
        Remove-Task @stateChange -Id $Id
    }
}
