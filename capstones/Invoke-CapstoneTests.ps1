#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

[CmdletBinding()]
param(
    [ValidateSet('All', 'Comparative', 'Idiomatic')]
    [string] $Capstone = 'All',

    [ValidateSet('All', 'Starter', 'Solution')]
    [string] $Implementation = 'Solution',

    [ValidateSet('All', 'Smoke', 'M1', 'M2', 'M3', 'M4', 'M5')]
    [string] $Tag = 'Smoke',

    [switch] $CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testPaths = switch ($Capstone) {
    'All' {
        Join-Path -Path $PSScriptRoot -ChildPath 'comparative/tests'
        Join-Path -Path $PSScriptRoot -ChildPath 'idiomatic/tests'
    }
    'Comparative' {
        Join-Path -Path $PSScriptRoot -ChildPath 'comparative/tests'
    }
    'Idiomatic' {
        Join-Path -Path $PSScriptRoot -ChildPath 'idiomatic/tests'
    }
}
$implementations = if ($Implementation -eq 'All') {
    @('starter', 'solution')
}
else {
    @($Implementation.ToLowerInvariant())
}

$previousImplementation = $env:CAPSTONE_IMPLEMENTATION
$failedCount = 0
try {
    foreach ($selectedImplementation in $implementations) {
        $env:CAPSTONE_IMPLEMENTATION = $selectedImplementation
        $invokeParameters = @{
            Path = @($testPaths)
            Output = 'Detailed'
            PassThru = $true
        }
        if ($Tag -ne 'All') {
            $invokeParameters.Tag = $Tag
        }
        if ($CI) {
            $invokeParameters.CI = $true
        }

        $result = Invoke-Pester @invokeParameters
        $failedCount += [int] $result.FailedCount
    }
}
finally {
    if ($null -eq $previousImplementation) {
        Remove-Item -Path Env:CAPSTONE_IMPLEMENTATION -ErrorAction SilentlyContinue
    }
    else {
        $env:CAPSTONE_IMPLEMENTATION = $previousImplementation
    }
}

if ($failedCount -gt 0) {
    exit 1
}
