#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '../../tests/CapstoneTestSupport.ps1')
    $script:target = Get-CapstoneTestTarget -Capstone Comparative
}

AfterAll {
    Remove-Module -Name $script:target.ModuleName -Force -ErrorAction SilentlyContinue
}

Describe 'Comparative capstone scaffold' -Tag Smoke {
    It 'imports the selected PowerShell 7.4 manifest with the exact export surface' {
        $manifest = Test-ModuleManifest -Path $script:target.ModulePath -ErrorAction Stop
        $manifest.PowerShellVersion | Should -BeGreaterOrEqual ([version] '7.4')

        Remove-Module -Name $script:target.ModuleName -Force -ErrorAction SilentlyContinue
        $module = Import-Module -Name $script:target.ModulePath -Force -PassThru -ErrorAction Stop
        $actual = @($module.ExportedFunctions.Keys | Sort-Object)
        $expected = @($script:target.ExportedFunctions | Sort-Object)
        ($actual -join '|') | Should -BeExactly ($expected -join '|')
    }

    It 'keeps starter and solution public signatures identical' {
        $starter = @(
            Get-CapstoneModuleSignature `
                -ModulePath $script:target.StarterModulePath `
                -ModuleName $script:target.ModuleName `
                -CommandName $script:target.ExportedFunctions
        ) | ConvertTo-Json -Depth 5
        $solution = @(
            Get-CapstoneModuleSignature `
                -ModulePath $script:target.SolutionModulePath `
                -ModuleName $script:target.ModuleName `
                -CommandName $script:target.ExportedFunctions
        ) | ConvertTo-Json -Depth 5

        $starter | Should -BeExactly $solution
    }

    It 'publishes help for every exported command' {
        Import-Module -Name $script:target.ModulePath -Force -ErrorAction Stop
        foreach ($commandName in $script:target.ExportedFunctions) {
            $help = Get-Help -Name $commandName -Full
            $help.Description.Text | Should -Not -BeNullOrEmpty
            @($help.Examples.Example).Count | Should -BeGreaterThan 0
            @($help.Parameters.Parameter).Count | Should -BeGreaterThan 0
        }
    }

    It 'fails unfinished behavior with the intentional scaffold error' {
        Import-Module -Name $script:target.ModulePath -Force -ErrorAction Stop
        $caught = $null
        try {
            Set-ConfigurationEntry `
                -DatabasePath (Join-Path -Path $TestDrive -ChildPath 'store.db') `
                -Key 'app/mode' `
                -ValueJson '"safe"' `
                -Expect absent `
                -Confirm:$false
        }
        catch {
            $caught = $_
        }

        $caught | Should -Not -BeNullOrEmpty
        $caught.FullyQualifiedErrorId | Should -Match '^CapstoneNotImplemented,'
    }

    It 'parses the selected CLI skeleton' {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $script:target.ScriptPath,
            [ref] $tokens,
            [ref] $errors
        ) | Out-Null

        @($errors).Count | Should -Be 0
    }

    It 'binds shared CLI-shaped arguments before failing intentionally' {
        $caught = $null
        try {
            & $script:target.ScriptPath `
                '--db' `
                (Join-Path -Path $TestDrive -ChildPath 'store.db') `
                'set' `
                'app/mode' `
                '--value-json' `
                '"safe"'
        }
        catch {
            $caught = $_
        }

        $caught | Should -Not -BeNullOrEmpty
        $caught.FullyQualifiedErrorId | Should -Match '^CapstoneNotImplemented,'
    }
}
