Set-StrictMode -Version Latest

function Get-OptionalText {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    try {
        Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Warning "Optional input was not found: $Path"
        $null
    }
}

Write-Verbose 'Use -Verbose to see this diagnostic.' -Verbose
Get-OptionalText -Path (Join-Path -Path $PWD -ChildPath 'does-not-exist.txt')
