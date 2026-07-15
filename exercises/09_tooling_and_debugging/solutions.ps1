Set-StrictMode -Version Latest

function Get-NormalizedName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $Name)
    $trimmed = $Name.Trim()
    if ($trimmed.Length -eq 0) { throw 'Name must contain non-whitespace text.' }
    $trimmed.Substring(0, 1).ToUpperInvariant() + $trimmed.Substring(1).ToLowerInvariant()
}

Describe 'Get-NormalizedName' {
    Context 'with user-provided text' {
        It 'trims and normalizes mixed case' {
            Get-NormalizedName -Name ' aDA ' | Should -Be 'Ada'
        }
        It 'rejects whitespace-only text' {
            { Get-NormalizedName -Name '   ' } | Should -Throw '*non-whitespace*'
        }
    }
}
