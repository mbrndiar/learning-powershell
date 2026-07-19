#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

[CmdletBinding()]
param(
    [ValidateSet('All', 'Starter', 'Solution')]
    [string] $Implementation = 'Solution',

    [ValidateSet('All', 'Smoke', 'M1', 'M2', 'M3', 'M4', 'M5')]
    [string] $Tag = 'Smoke',

    [switch] $CI
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$implementations = if ($Implementation -eq 'All') {
    @('starter', 'solution')
}
else {
    @($Implementation.ToLowerInvariant())
}
$testPath = Join-Path -Path $PSScriptRoot -ChildPath 'tasks/tests'
$previousImplementation = $env:TASKS_IMPLEMENTATION
$failedCount = 0

try {
    foreach ($selectedImplementation in $implementations) {
        $env:TASKS_IMPLEMENTATION = $selectedImplementation
        $invokeParameters = @{
            Path = $testPath
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
        $failedCount += [int] $result.FailedBlocksCount
        $failedCount += [int] $result.FailedContainersCount
        if ($result.Result -ne 'Passed' -and
            $result.FailedCount -eq 0 -and
            $result.FailedBlocksCount -eq 0 -and
            $result.FailedContainersCount -eq 0) {
            $failedCount++
        }
    }
}
finally {
    if ($null -eq $previousImplementation) {
        Remove-Item -Path Env:TASKS_IMPLEMENTATION -ErrorAction SilentlyContinue
    }
    else {
        $env:TASKS_IMPLEMENTATION = $previousImplementation
    }
}

if ($failedCount -gt 0) {
    throw "The Tasks project test run reported $failedCount failure(s)."
}
