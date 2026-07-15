#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

# This lesson shows two isolation tools: TestDrive: is temporary storage scoped
# to the test container (not reset automatically per It), and Mock replaces a
# command so a test can exercise a boundary without real filesystem access.

Set-StrictMode -Version Latest

function Get-FirstLine {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $LiteralPath)
    Get-Content -LiteralPath $LiteralPath -TotalCount 1 -ErrorAction Stop
}

Describe 'Get-FirstLine' {
    BeforeEach {
        # $script: scope shares the path from BeforeEach into each It block.
        $script:path = Join-Path $TestDrive 'example.txt'
        Set-Content -LiteralPath $script:path -Value @('first', 'second') -Encoding utf8
    }
    It 'returns only the first line' {
        Get-FirstLine -LiteralPath $script:path | Should -Be 'first'
    }
    It 'can isolate the file boundary with a mock' {
        # The mock replaces Get-Content, so no real file is read here.
        Mock -CommandName Get-Content -MockWith { 'mocked first line' }
        Get-FirstLine -LiteralPath 'not-a-real-file.txt' | Should -Be 'mocked first line'
    }
}
