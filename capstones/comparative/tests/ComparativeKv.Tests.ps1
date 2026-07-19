#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '../../tests/CapstoneTestSupport.ps1')
    . (Join-Path -Path $PSScriptRoot -ChildPath 'ComparativeKv.TestSupport.ps1')
    $script:target = Get-CapstoneTestTarget -Capstone Comparative
}

AfterAll {
    Remove-Module -Name $script:target.ModuleName -Force -ErrorAction SilentlyContinue
}

Describe 'Comparative capstone boundary' -Tag Smoke {
    It 'imports the selected PowerShell 7.4 manifest with the exact export surface' {
        $manifest = Test-ModuleManifest -Path $script:target.ModulePath -ErrorAction Stop
        $manifest.PowerShellVersion | Should -BeGreaterOrEqual ([version] '7.4')
        $dependency = @($manifest.RequiredModules | Where-Object Name -eq 'SimplySql')
        $dependency.Count | Should -Be 1
        $dependency[0].Version | Should -Be ([version] '2.2.0.106')

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

    It 'parses every selected implementation script' {
        $implementationRoot = Split-Path -Path $script:target.ModulePath -Parent
        foreach ($path in Get-ChildItem -LiteralPath $implementationRoot -File) {
            if ($path.Extension -notin '.ps1', '.psm1') {
                continue
            }
            $tokens = $null
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $path.FullName,
                [ref] $tokens,
                [ref] $errors
            ) | Out-Null
            @($errors).Count | Should -Be 0
        }
    }

    It 'keeps the starter guided and the solution runnable' {
        if ($script:target.Implementation -eq 'starter') {
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
        else {
            $databasePath = Join-Path -Path $TestDrive -ChildPath 'solution-smoke.db'
            $result = Invoke-TestCli -ScriptPath $script:target.ScriptPath -Arguments @(
                '--db', $databasePath, 'list'
            )
            $result.ExitCode | Should -Be 0
            Assert-TestSemanticEqual -Actual $result.Parsed -Expected @{
                ok = $true
                result = @{ entries = @(); global_revision = 0 }
            }
        }
    }
}

Describe 'Comparative fixture runner: unknown-property rejection' -Tag Smoke {
    # SCENARIOS.md section 1 requires that unknown fixture keys or generator
    # kinds fail the runner rather than being ignored. These cases prove the
    # allowed-property validation added to ComparativeKv.TestSupport.ps1 fails
    # loudly for every relevant node kind rather than silently skipping an
    # unrecognized property. They build synthetic in-memory nodes instead of
    # editing the frozen spec/fixtures so the fixture data itself stays exact.
    It 'rejects an unknown property alongside otherwise-allowed properties' {
        {
            Assert-TestKnownProperty `
                -InputObject @{ kind = 'sequential_scenarios'; spec_version = '1.0.0'; bogus = 1 } `
                -AllowedProperty @('kind', 'spec_version', 'scenarios') `
                -Context 'synthetic fixture node'
        } | Should -Throw -ExpectedMessage "*Unknown fixture property 'bogus'*"
    }

    It 'accepts a node containing only allowed properties' {
        {
            Assert-TestKnownProperty `
                -InputObject @{ kind = 'sequential_scenarios'; spec_version = '1.0.0' } `
                -AllowedProperty @('kind', 'spec_version', 'scenarios') `
                -Context 'synthetic fixture node'
        } | Should -Not -Throw
    }

    It 'rejects an unknown property on a nested_arrays generator descriptor' {
        {
            New-TestFixtureValue -Descriptor @{
                kind = 'nested_arrays'
                leaf = 1
                depth = 2
                unexpected = 'value'
            }
        } | Should -Throw -ExpectedMessage "*Unknown fixture property 'unexpected'*"
    }

    It 'rejects an unknown property on an ascii_string_total_bytes generator descriptor' {
        {
            New-TestFixtureValue -Descriptor @{
                kind = 'ascii_string_total_bytes'
                character = 'a'
                total_bytes = 4
                unexpected = 'value'
            } -AsJson
        } | Should -Throw -ExpectedMessage "*Unknown fixture property 'unexpected'*"
    }

    It 'rejects an unknown property on a repeat_suffix key_generator descriptor' {
        {
            Get-TestCaseKey -Case @{
                id = 'synthetic'
                key_generator = @{
                    kind = 'repeat_suffix'
                    prefix = 'p'
                    character = 'a'
                    count = 3
                    unexpected = 'value'
                }
            }
        } | Should -Throw -ExpectedMessage "*Unknown fixture property 'unexpected'*"
    }

    It 'rejects an unknown property on an expect fixture node' {
        {
            Assert-TestCliExpectation `
                -Result ([pscustomobject]@{ ExitCode = 0; Stderr = '' }) `
                -Expectation @{ exit = 0; stderr = ''; unexpected = 'value' }
        } | Should -Throw -ExpectedMessage "*Unknown fixture property 'unexpected'*"
    }

    It 'rejects an unknown property on a run_assert assert node' {
        {
            Assert-TestRunStructure `
                -Result ([pscustomobject]@{ Parsed = [pscustomobject]@{ result = @{ entries = @() } } }) `
                -Assertions @{ entry_count = 0; unexpected = 'value' }
        } | Should -Throw -ExpectedMessage "*Unknown fixture property 'unexpected'*"
    }

    It 'rejects an unknown property on a parallel assert node' {
        {
            Assert-TestParallelResults `
                -Results @([pscustomobject]@{ ExitCode = 0; Parsed = [pscustomobject]@{ ok = $true } }) `
                -Assertions @{ success_count = 0; unexpected = 'value' } `
                -ScriptPath 'unused'
        } | Should -Throw -ExpectedMessage "*Unknown fixture property 'unexpected'*"
    }
}

Describe 'Milestone 1: domain and restricted JSON fixtures' -Tag M1 {
    It 'runs every accepted and rejected key fixture plus binary ordering' {
        Invoke-TestKeyFixture `
            -ScriptPath $script:target.ScriptPath `
            -ParentPath $TestDrive
    }

    It 'runs every accepted restricted JSON fixture' {
        Invoke-TestAcceptedValueFixture `
            -ScriptPath $script:target.ScriptPath `
            -ParentPath $TestDrive
    }

    It 'runs every rejected restricted JSON fixture without creating storage' {
        Invoke-TestRejectedValueFixture `
            -ScriptPath $script:target.ScriptPath `
            -ParentPath $TestDrive
    }

    It 'validates only surviving duplicate members in last-member source order' {
        $databasePath = Join-Path -Path $TestDrive -ChildPath 'duplicate-validation.db'
        $accepted = Invoke-TestCli -ScriptPath $script:target.ScriptPath -Arguments @(
            '--db',
            $databasePath,
            'set',
            'duplicate',
            '--value-json',
            '{"a":1.5,"a":1}',
            '--expect',
            'absent'
        )
        $accepted.ExitCode | Should -Be 0
        Assert-TestSemanticEqual -Actual $accepted.Parsed.result.value -Expected @{ a = 1 }

        $rejected = Invoke-TestCli -ScriptPath $script:target.ScriptPath -Arguments @(
            '--db',
            $databasePath,
            'set',
            'ordered-defects',
            '--value-json',
            '{"a":1.5,"b":"\uD800","a":1}'
        )
        $rejected.ExitCode | Should -Be 2
        Assert-TestSemanticEqual -Actual $rejected.Parsed.error -Expected @{
            category = 'invalid_value'
            details = @{ reason = 'unpaired_surrogate' }
        }
    }
}

Describe 'Milestone 2: exact CLI fixture' -Tag M2 {
    It 'runs every invalid CLI and validation-precedence step' {
        Invoke-TestSequentialFixture `
            -ScriptPath $script:target.ScriptPath `
            -ParentPath $TestDrive `
            -RelativePath 'scenarios/invalid.json'
    }
}

Describe 'Milestones 3 and 4: ordinary lifecycle fixture' -Tag M3, M4 {
    It 'runs every normal sequential scenario' {
        Invoke-TestSequentialFixture `
            -ScriptPath $script:target.ScriptPath `
            -ParentPath $TestDrive `
            -RelativePath 'scenarios/normal.json'
    }
}

Describe 'Milestone 3: schema initialization and migration fixture' -Tag M3 {
    It 'runs every migration, rollback, and schema-rejection scenario' {
        Invoke-TestSequentialFixture `
            -ScriptPath $script:target.ScriptPath `
            -ParentPath $TestDrive `
            -RelativePath 'scenarios/migration.json'
    }
}

Describe 'Milestone 4: boundary and revision fixture' -Tag M4 {
    It 'runs every boundary reference and mutation scenario' {
        Invoke-TestSequentialFixture `
            -ScriptPath $script:target.ScriptPath `
            -ParentPath $TestDrive `
            -RelativePath 'scenarios/boundary.json'
    }
}

Describe 'Milestone 5: independent-process conformance fixture' -Tag M5 {
    It 'runs every required repeat with barriers, lock helpers, and cleanup' {
        Invoke-TestMultiprocessFixture `
            -ScriptPath $script:target.ScriptPath `
            -ParentPath $TestDrive
    }
}
