#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

# This lesson runs a real code-coverage measurement as a DIAGNOSTIC. The mental
# model: coverage reports which commands executed while the tests ran; it does
# NOT prove the assertions were meaningful, that every case was considered, or
# that concurrent code is safe. A missed line is a prompt to investigate, not a
# score to chase, so this workflow sets no numeric threshold.
#
# New-PesterConfiguration exposes the CodeCoverage section on both supported
# majors (5.5 and 6). Only the version-independent properties are used here
# (Enabled, Path, OutputPath, OutputFormat) so the same workflow runs on either.
# The coverage report is written to a disposable path and removed in finally so
# generated output is never committed.

Set-StrictMode -Version Latest

# A gitignored, per-run scratch directory keeps every generated artifact out of
# the repository and off shared temp locations; finally deletes it.
$workspace = Join-Path $PSScriptRoot ".scratch-coverage-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $workspace | Out-Null
try {
    # A tiny, real "code under test" with two branches. The test below exercises
    # only the non-negative branch on purpose, so coverage will report a missed
    # line and demonstrate what the diagnostic can and cannot tell us.
    $sourcePath = Join-Path $workspace 'Classify-Number.ps1'
    Set-Content -LiteralPath $sourcePath -Encoding utf8 -Value @'
function Get-NumberSign {
    [CmdletBinding()]
    param([Parameter(Mandatory)][int] $Value)
    if ($Value -ge 0) {
        'nonnegative'
    }
    else {
        'negative'
    }
}
'@

    $testPath = Join-Path $workspace 'Classify-Number.Tests.ps1'
    Set-Content -LiteralPath $testPath -Encoding utf8 -Value @'
BeforeAll { . (Join-Path $PSScriptRoot 'Classify-Number.ps1') }
Describe 'Get-NumberSign' {
    It 'labels a non-negative number' {
        Get-NumberSign -Value 1 | Should -Be 'nonnegative'
    }
}
'@

    $coverageOutput = Join-Path $workspace 'coverage.xml'

    # Build the runner configuration explicitly instead of relying on ambient
    # defaults. These properties exist on both Pester 5.5 and 6.
    $configuration = New-PesterConfiguration
    $configuration.Run.Path = $testPath
    $configuration.Run.PassThru = $true
    $configuration.CodeCoverage.Enabled = $true
    $configuration.CodeCoverage.Path = $sourcePath
    $configuration.CodeCoverage.OutputPath = $coverageOutput
    $configuration.CodeCoverage.OutputFormat = 'JaCoCo'
    # No CoveragePercentTarget is set: coverage is a signal to read, not a gate.
    $configuration.Output.Verbosity = 'None'

    $result = Invoke-Pester -Configuration $configuration
    $coverage = $result.CodeCoverage

    # Missed command line numbers turn "66% covered" into an actionable list:
    # which branch was never executed, so you can decide whether it needs a test.
    $missedLines = @($coverage.CommandsMissed | ForEach-Object { $_.Line }) -join ', '

    [pscustomobject]@{
        TestsPassed = $result.PassedCount
        CommandsAnalyzed = $coverage.CommandsAnalyzedCount
        CommandsExecuted = $coverage.CommandsExecutedCount
        CommandsMissed = $coverage.CommandsMissedCount
        CoveragePercent = [math]::Round($coverage.CoveragePercent, 1)
        MissedLines = $missedLines
        ReportLifecycle = 'Disposable output is removed by the enclosing finally block.'
        Interpretation = 'Coverage is a diagnostic: a missed line invites a test, not a threshold to satisfy.'
    }
}
finally {
    # Remove the disposable report and scratch code so nothing generated is left
    # behind to be committed or re-discovered by a later test run.
    Remove-Item -LiteralPath $workspace -Recurse -Force -ErrorAction Stop
}
