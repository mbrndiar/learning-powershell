Set-StrictMode -Version Latest

$analyzer = Get-Command -Name Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue
if ($null -eq $analyzer) {
    Write-Warning 'PSScriptAnalyzer is not installed. See docs/SETUP.md.'
}
else {
    $settings = Join-Path $PSScriptRoot '../../PSScriptAnalyzerSettings.psd1'
    Invoke-ScriptAnalyzer -Path $PSScriptRoot -Settings $settings
}

'Feedback order: script or focused test, analyzer, then Pester suite.'
