#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

Set-StrictMode -Version Latest

function Get-FirstLine {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $LiteralPath)
    Get-Content -LiteralPath $LiteralPath -TotalCount 1 -ErrorAction Stop
}

Describe 'Get-FirstLine' {
    BeforeEach {
        $script:path = Join-Path $TestDrive 'example.txt'
        Set-Content -LiteralPath $script:path -Value @('first', 'second') -Encoding utf8
    }
    It 'returns only the first line' {
        Get-FirstLine -LiteralPath $script:path | Should -Be 'first'
    }
    It 'can isolate the file boundary with a mock' {
        Mock -CommandName Get-Content -MockWith { 'mocked first line' }
        Get-FirstLine -LiteralPath 'not-a-real-file.txt' | Should -Be 'mocked first line'
    }
}
