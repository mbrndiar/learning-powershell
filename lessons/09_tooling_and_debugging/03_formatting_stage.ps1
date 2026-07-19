#Requires -Version 7.4

# This lesson makes formatting an explicit, executable lifecycle stage. The
# mental model: two different tools with two different jobs.
#   - PSScriptAnalyzer (Invoke-ScriptAnalyzer) DETECTS likely defects and style
#     violations. It reports diagnostics; it does not rewrite your file.
#   - Invoke-Formatter REWRITES layout (indentation, brace and operator spacing)
#     and returns candidate TEXT. The PowerShell extension's "Format Document"
#     uses the same formatting engine with its editor configuration.
# Formatting is never a blind in-place rewrite here: produce a candidate, review
# the diff, then write intentionally. Nothing in the course tree is mutated;
# the only file touched is a disposable per-run copy that finally removes.

Set-StrictMode -Version Latest

$analyzer = Get-Command -Name Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue
$formatter = Get-Command -Name Invoke-Formatter -ErrorAction SilentlyContinue
if ($null -eq $analyzer -or $null -eq $formatter) {
    Write-Warning 'PSScriptAnalyzer is not installed. See docs/SETUP.md.'
    return
}

# The repository's shared settings define analyzer policy but intentionally no
# layout rules. The separate CodeFormatting preset below demonstrates rewriting.
$settings = Join-Path $PSScriptRoot '../../PSScriptAnalyzerSettings.psd1'

# Deliberately misformatted sample text standing in for "one file".
$original = @(
    'function Get-Doubled {'
    '        param([int]$Value)'
    '  if ($Value -gt 0)   {'
    '            $Value * 2'
    '  }'
    '}'
) -join "`n"

$workspace = Join-Path $PSScriptRoot ".scratch-format-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $workspace | Out-Null
try {
    # Represent the target as a real, disposable file so the workflow mirrors
    # editing a checked-in file without touching a course file.
    $filePath = Join-Path $workspace 'sample.ps1'
    Set-Content -LiteralPath $filePath -Value $original -Encoding utf8

    # DETECT step: the analyzer reports diagnostics using the shared settings and
    # leaves the file unchanged.
    $findings = @(Invoke-ScriptAnalyzer -Path $filePath -Settings $settings)

    # REWRITE step: the shared settings focus on defect severity and enable no
    # layout rules, so formatting against them is intentionally conservative and
    # returns the text unchanged. That is a policy signal, not a bug.
    $repoCandidate = Invoke-Formatter -ScriptDefinition $original -Settings $settings

    # For contrast, the built-in CodeFormatting preset shows a concrete layout
    # candidate. An editor can be configured with equivalent rules, but its
    # workspace settings are a separate policy. Never accept the result blindly.
    $styleCandidate = Invoke-Formatter -ScriptDefinition $original -Settings CodeFormatting

    # PREVIEW step: compute the diff instead of overwriting. Reviewing this diff
    # is the safeguard: automated layout changes can still be wrong or noisy.
    $diff = @(Compare-Object -ReferenceObject ($original -split "`n") `
            -DifferenceObject ($styleCandidate -split "`n"))

    # INTENTIONAL WRITE step: only after reviewing the diff, and only to the
    # disposable copy. A real workflow would write back to the reviewed file and
    # commit the change as its own reviewable diff.
    Set-Content -LiteralPath $filePath -Value $styleCandidate -Encoding utf8
    $written = Get-Content -LiteralPath $filePath -Raw

    [pscustomobject]@{
        AnalyzerFindings = $findings.Count
        RepoSettingsChangedLayout = ($repoCandidate -ne $original)
        StyleRulesChangedLayout = ($styleCandidate -ne $original)
        PreviewDiffLines = $diff.Count
        IntentionalWriteApplied = ($written.TrimEnd() -eq $styleCandidate.TrimEnd())
        Guidance = 'Detect with the analyzer, format to a candidate, review the diff, then write intentionally.'
    }
}
finally {
    Remove-Item -LiteralPath $workspace -Recurse -Force -ErrorAction Stop
}
