#Requires -Version 7.4

# This lesson shows the static-analysis step of the feedback loop. The mental
# model: check for the analyzer's presence, degrade gracefully if it is
# missing, and run it with the repo's shared settings for consistent results.

Set-StrictMode -Version Latest

$analyzer = Get-Command -Name Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue
if ($null -eq $analyzer) {
    Write-Warning 'PSScriptAnalyzer is not installed. See docs/SETUP.md.'
}
else {
    # Point at the repo settings so local runs match what CI enforces.
    $settings = Join-Path $PSScriptRoot '../../PSScriptAnalyzerSettings.psd1'
    Invoke-ScriptAnalyzer -Path $PSScriptRoot -Settings $settings
}

'Feedback order: format and review the diff, focused script or test, analyzer, then Pester suite.'
