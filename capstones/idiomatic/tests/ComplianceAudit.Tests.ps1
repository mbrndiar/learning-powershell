#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '../../tests/CapstoneTestSupport.ps1')
    $script:target = Get-CapstoneTestTarget -Capstone Idiomatic
    $script:fixtureRoot = Join-Path -Path $PSScriptRoot -ChildPath 'fixtures'

    function Import-SelectedComplianceModule {
        Remove-Module -Name $script:target.ModuleName -Force -ErrorAction SilentlyContinue
        Import-Module -Name $script:target.ModulePath -Force -ErrorAction Stop
    }

    function Get-TestPolicyPath {
        param([Parameter(Mandatory)][string] $Name)

        Join-Path -Path $script:fixtureRoot -ChildPath "policies/$Name"
    }

    function Get-TestRoot {
        param([Parameter(Mandatory)][string] $Name)

        $path = Join-Path -Path $TestDrive -ChildPath $Name
        $null = New-Item -ItemType Directory -Path $path -Force
        $path
    }

    function Get-TestTarget {
        param(
            [Parameter(Mandatory)][string] $Name,
            [Parameter(Mandatory)][string] $RootPath
        )

        [pscustomobject]@{
            Name = $Name
            RootPath = $RootPath
        }
    }

    function Get-TestPolicyFile {
        param(
            [Parameter(Mandatory)][string] $Name,
            [Parameter(Mandatory)][object] $Policy
        )

        $path = Join-Path -Path $TestDrive -ChildPath $Name
        ConvertTo-Json -InputObject $Policy -Depth 8 |
            Set-Content -LiteralPath $path -Encoding utf8
        $path
    }

    function Get-ToolPolicyFile {
        param(
            [string] $Name = 'tool-policy.json',
            [int] $RuleCount = 1
        )

        $rules = for ($index = 1; $index -le $RuleCount; $index++) {
            [ordered]@{
                ruleId = "tool-$index"
                kind = 'ToolVersion'
                tool = 'pwsh'
                minimumVersion = '7.4.0'
                remediation = 'None'
            }
        }
        Get-TestPolicyFile -Name $Name -Policy ([ordered]@{
            schemaVersion = 1
            policyId = 'tool-policy'
            rules = @($rules)
        })
    }

    function Get-TestAdapter {
        param(
            [AllowNull()]
            [object] $State,
            [scriptblock] $ResolveRoot,
            [scriptblock] $ResolvePath,
            [scriptblock] $GetPathKind,
            [scriptblock] $ReadFile,
            [scriptblock] $WriteFile,
            [scriptblock] $CreateDirectory,
            [scriptblock] $GetToolVersion
        )

        if ($null -eq $ResolveRoot) {
            $ResolveRoot = {
                param($Path)
                $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
                if (-not $item.PSIsContainer) {
                    throw 'not a container'
                }
                [System.IO.Path]::GetFullPath($item.FullName)
            }
        }
        if ($null -eq $ResolvePath) {
            $ResolvePath = {
                param($RootPath, $RelativePath, $ForWrite)
                $null = $ForWrite
                $native = $RelativePath.Replace(
                    [char] '/',
                    [System.IO.Path]::DirectorySeparatorChar
                )
                $root = [System.IO.Path]::GetFullPath($RootPath)
                $candidate = [System.IO.Path]::GetFullPath(
                    [System.IO.Path]::Combine($root, $native)
                )
                $relative = [System.IO.Path]::GetRelativePath($root, $candidate)
                if (
                    [System.IO.Path]::IsPathRooted($relative) -or
                    $relative -eq '..' -or
                    $relative.StartsWith(
                        '..' + [System.IO.Path]::DirectorySeparatorChar,
                        [System.StringComparison]::Ordinal
                    )
                ) {
                    throw 'outside root'
                }
                $candidate
            }
        }
        if ($null -eq $GetPathKind) {
            $GetPathKind = {
                param($Path)
                if ([System.IO.Directory]::Exists($Path)) {
                    'Directory'
                }
                elseif ([System.IO.File]::Exists($Path)) {
                    'File'
                }
                else {
                    'Missing'
                }
            }
        }
        if ($null -eq $ReadFile) {
            $ReadFile = {
                param($Path)
                , [System.IO.File]::ReadAllBytes($Path)
            }
        }
        if ($null -eq $WriteFile) {
            $WriteFile = {
                param($Path, $Content)
                [System.IO.File]::WriteAllText(
                    $Path,
                    $Content,
                    [System.Text.UTF8Encoding]::new($false)
                )
            }
        }
        if ($null -eq $CreateDirectory) {
            $CreateDirectory = {
                param($Path)
                $null = [System.IO.Directory]::CreateDirectory($Path)
            }
        }
        if ($null -eq $GetToolVersion) {
            $GetToolVersion = {
                [pscustomobject]@{
                    ExitCode = 0
                    Output = '7.4.0'
                }
            }
        }

        [pscustomobject]@{
            State = $State
            ResolveRoot = $ResolveRoot
            ResolvePath = $ResolvePath
            GetPathKind = $GetPathKind
            ReadFile = $ReadFile
            WriteFile = $WriteFile
            CreateDirectory = $CreateDirectory
            GetToolVersion = $GetToolVersion
        }
    }

    function Get-CaughtError {
        param([Parameter(Mandatory)][scriptblock] $ScriptBlock)

        try {
            & $ScriptBlock
        }
        catch {
            return $_
        }
        throw 'Expected the script block to fail.'
    }

    function Invoke-TestChildProcess {
        param(
            [Parameter(Mandatory)]
            [string[]] $ArgumentList
        )

        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = (
            Get-Command -Name pwsh -CommandType Application -ErrorAction Stop |
                Select-Object -First 1
        ).Source
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in $ArgumentList) {
            $startInfo.ArgumentList.Add($argument)
        }
        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        try {
            $null = $process.Start()
            $standardOutput = $process.StandardOutput.ReadToEndAsync()
            $standardError = $process.StandardError.ReadToEndAsync()
            $process.WaitForExit()
            [pscustomobject]@{
                ExitCode = $process.ExitCode
                StandardOutput = $standardOutput.GetAwaiter().GetResult()
                StandardError = $standardError.GetAwaiter().GetResult()
            }
        }
        finally {
            $process.Dispose()
        }
    }
}

AfterAll {
    Remove-Module -Name $script:target.ModuleName -Force -ErrorAction SilentlyContinue
}

Describe 'Idiomatic capstone boundary' -Tag Smoke {
    BeforeEach {
        Import-SelectedComplianceModule
    }

    It 'imports the selected manifest with exactly four exported commands' {
        $manifest = Test-ModuleManifest -Path $script:target.ModulePath -ErrorAction Stop
        $manifest.Version | Should -Be ([version] '1.0.0')
        $manifest.PowerShellVersion | Should -BeGreaterOrEqual ([version] '7.4')
        @($manifest.RequiredModules).Count | Should -Be 0

        $module = Get-Module -Name $script:target.ModuleName
        $actual = @($module.ExportedFunctions.Keys | Sort-Object)
        $expected = @($script:target.ExportedFunctions | Sort-Object)
        ($actual -join '|') | Should -BeExactly ($expected -join '|')
        @($module.ExportedAliases.Keys).Count | Should -Be 0
        @($module.ExportedCmdlets.Keys).Count | Should -Be 0
        @($module.ExportedVariables.Keys).Count | Should -Be 0
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

    It 'publishes complete help without formatting or host-only output' {
        foreach ($commandName in $script:target.ExportedFunctions) {
            $help = Get-Help -Name $commandName -Full
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Description.Text | Should -Not -BeNullOrEmpty
            @($help.Examples.Example).Count | Should -BeGreaterThan 0
            @($help.Parameters.Parameter).Count | Should -BeGreaterThan 0
        }

        $moduleText = Get-Content -LiteralPath (
            Join-Path -Path (Split-Path $script:target.ModulePath) -ChildPath 'ComplianceAudit.psm1'
        ) -Raw
        $moduleText | Should -Not -Match '\bWrite-Host\b'
        $moduleText | Should -Not -Match '\bFormat-\w+'
    }

    It 'parses every script in the selected implementation' {
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
            $errorRecord = Get-CaughtError {
                Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'minimal.json')
            }
            $errorRecord.FullyQualifiedErrorId | Should -Match '^CapstoneNotImplemented,'
        }
        else {
            $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'minimal.json')
            $policy.PSObject.TypeNames[0] | Should -BeExactly 'ComplianceAudit.Policy'
            $policy.PolicyId | Should -BeExactly 'minimal'
        }
    }
}

Describe 'Milestone 1: finding model and checks' -Tag M1 {
    BeforeEach {
        Import-SelectedComplianceModule
    }

    It 'emits exact rich findings in target then policy order' {
        $rootA = Get-TestRoot -Name 'm1-a'
        $rootB = Get-TestRoot -Name 'm1-b'
        $null = New-Item -ItemType Directory -Path (Join-Path $rootA 'var/cache') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $rootA 'config') -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $rootB 'config') -Force
        Set-Content -LiteralPath (Join-Path $rootA 'config/app.conf') -Value 'mode=safe' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $rootB 'config/app.conf') -Value 'mode=unsafe' -Encoding utf8

        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'all-rules.json')
        $adapter = Get-TestAdapter -GetToolVersion {
            [pscustomobject]@{ ExitCode = 0; Output = '7.4.0' }
        }
        $targets = @(
            Get-TestTarget -Name fixture-a -RootPath $rootA
            Get-TestTarget -Name fixture-b -RootPath $rootB
        )
        $findings = @($targets | Test-Compliance -Policy $policy -Adapter $adapter)

        $findings.Count | Should -Be 6
        ($findings | ForEach-Object { "$($_.Target.Name):$($_.RuleId)" }) -join '|' |
            Should -BeExactly (
                'fixture-a:cache-directory|fixture-a:safe-mode|fixture-a:powershell-version|' +
                'fixture-b:cache-directory|fixture-b:safe-mode|fixture-b:powershell-version'
            )
        ($findings.Status -join '|') |
            Should -BeExactly 'Compliant|Compliant|Compliant|NonCompliant|NonCompliant|Compliant'
        foreach ($finding in $findings) {
            $finding.PSObject.TypeNames[0] | Should -BeExactly 'ComplianceAudit.Finding'
            ($finding.PSObject.Properties.Name -join '|') | Should -BeExactly (
                'PolicyId|Target|RuleId|RuleKind|Status|Observed|Expected|CanRemediate|Message'
            )
            ($finding.Target.PSObject.Properties.Name -join '|') |
                Should -BeExactly 'Name|RootPath'
        }
    }

    It 'keeps noncompliance on success and converts adapter exceptions to Error findings' {
        $root = Get-TestRoot -Name 'm1-adapter'
        $policy = Import-CompliancePolicy -Path (Get-ToolPolicyFile)
        $adapter = Get-TestAdapter -GetToolVersion {
            throw 'simulated adapter failure'
        }
        $mixed = @(
            Get-TestTarget -Name fixture -RootPath $root |
                Test-Compliance -Policy $policy -Adapter $adapter 2>&1
        )
        @($mixed | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count |
            Should -Be 0
        $finding = $mixed[0]
        $finding.Status | Should -BeExactly 'Error'
        $finding.CanRemediate | Should -BeFalse
        $finding.Observed | Should -BeNullOrEmpty
        $finding.Message | Should -Not -Match 'simulated adapter failure'
    }

    It 'filters repeated rule selections without changing policy order' {
        $root = Get-TestRoot -Name 'm1-filter'
        $null = New-Item -ItemType Directory -Path (Join-Path $root 'config') -Force
        Set-Content -LiteralPath (Join-Path $root 'config/app.conf') -Value 'mode=safe' -Encoding utf8
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'all-rules.json')

        $findings = @(
            Get-TestTarget -Name fixture -RootPath $root |
                Test-Compliance `
                    -Policy $policy `
                    -RuleId powershell-version, safe-mode, powershell-version
        )

        ($findings.RuleId -join '|') | Should -BeExactly 'safe-mode|powershell-version'
    }
}

Describe 'Milestone 2: module, policy, target, and containment boundary' -Tag M2 {
    BeforeEach {
        Import-SelectedComplianceModule
    }

    It 'rejects malformed policy fixtures with stable ErrorIds' {
        foreach (
            $name in @(
                'unknown-property.json'
                'duplicate-rule.json'
                'unsafe-path.json'
                'invalid-version.json'
            )
        ) {
            $errorRecord = Get-CaughtError {
                Import-CompliancePolicy -Path (Get-TestPolicyPath -Name $name)
            }
            $errorRecord.FullyQualifiedErrorId |
                Should -BeExactly 'CompliancePolicyInvalid,Import-CompliancePolicy'
        }

        $unsupported = Get-CaughtError {
            Import-CompliancePolicy -Path (
                Get-TestPolicyPath -Name 'unsupported-version.json'
            )
        }
        $unsupported.FullyQualifiedErrorId |
            Should -BeExactly 'CompliancePolicyUnsupported,Import-CompliancePolicy'

        $missing = Get-CaughtError {
            Import-CompliancePolicy -Path (Join-Path $TestDrive 'missing.json')
        }
        $missing.FullyQualifiedErrorId |
            Should -BeExactly 'CompliancePolicyReadFailed,Import-CompliancePolicy'
    }

    It 'rejects wrong types, trailing JSON values, nulls, and invalid configuration values' {
        $invalidDocuments = @(
            '{"schemaVersion":"1","policyId":"x","rules":[]}'
            '{"schemaVersion":1,"policyId":"x","rules":null}'
            '{"schemaVersion":1,"policyId":"x","rules":[null]}'
            '{"schemaVersion":1,"policyId":"x","rules":[{"ruleId":"x","kind":"FileSetting","relativePath":"a.conf","key":"mode","expectedValue":" unsafe ","remediation":"Set"}]}'
            '{"schemaVersion":1,"policyId":"x","rules":[{"ruleId":"x","kind":"DirectoryExists","relativePath":"a","remediation":"Create"}]} true'
        )
        for ($index = 0; $index -lt $invalidDocuments.Count; $index++) {
            $path = Join-Path $TestDrive "invalid-$index.json"
            Set-Content -LiteralPath $path -Value $invalidDocuments[$index] -Encoding utf8
            $errorRecord = Get-CaughtError { Import-CompliancePolicy -Path $path }
            $errorRecord.FullyQualifiedErrorId |
                Should -BeExactly 'CompliancePolicyInvalid,Import-CompliancePolicy'
        }
    }

    It 'uses ConvertFrom-Json last-member-wins behavior before shape validation' {
        $path = Join-Path $TestDrive 'duplicate-property.json'
        @'
{
  "schemaVersion": 1,
  "policyId": "discarded",
  "policyId": "surviving",
  "rules": [
    {
      "ruleId": "directory",
      "kind": "DirectoryExists",
      "relativePath": "discarded",
      "relativePath": "kept",
      "remediation": "Create"
    }
  ]
}
'@ | Set-Content -LiteralPath $path -Encoding utf8

        $policy = Import-CompliancePolicy -Path $path

        $policy.PolicyId | Should -BeExactly 'surviving'
        $policy.Rules[0].RelativePath | Should -BeExactly 'kept'
    }

    It 'rejects duplicate or missing targets and unknown selected rules' {
        $root = Get-TestRoot -Name 'm2-target'
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'minimal.json')
        $target = Get-TestTarget -Name duplicate -RootPath $root

        $duplicate = Get-CaughtError {
            @($target, $target) | Test-Compliance -Policy $policy
        }
        $duplicate.FullyQualifiedErrorId |
            Should -BeExactly 'ComplianceTargetInvalid,Test-Compliance'

        $missingRoot = Get-CaughtError {
            Get-TestTarget -Name missing -RootPath (Join-Path $TestDrive 'absent') |
                Test-Compliance -Policy $policy
        }
        $missingRoot.FullyQualifiedErrorId |
            Should -BeExactly 'ComplianceTargetInvalid,Test-Compliance'

        $unknownRule = Get-CaughtError {
            $target | Test-Compliance -Policy $policy -RuleId not-present
        }
        $unknownRule.FullyQualifiedErrorId |
            Should -BeExactly 'ComplianceRuleNotFound,Test-Compliance'
    }

    It 'accepts direct target arrays and ignores additional target note properties' {
        $rootA = Get-TestRoot -Name 'm2-direct-a'
        $rootB = Get-TestRoot -Name 'm2-direct-b'
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'minimal.json')
        $targets = @(
            [pscustomobject]@{ Name = 'a'; RootPath = $rootA; Ignored = 'one' }
            [pscustomobject]@{ Name = 'b'; RootPath = $rootB; Ignored = 'two' }
        )

        $findings = @(Test-Compliance -Target $targets -Policy $policy)

        ($findings.Target.Name -join '|') | Should -BeExactly 'a|b'
        $findings[0].Target.PSObject.Properties.Name | Should -Not -Contain 'Ignored'
    }

    It 'turns an injected containment failure into an Error finding before reads' {
        $root = Get-TestRoot -Name 'm2-containment'
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'minimal.json')
        $readCount = [System.Collections.Concurrent.ConcurrentDictionary[string, int]]::new()
        $readCount['value'] = 0
        $resolvePath = {
            param($RootPath, $RelativePath, $ForWrite)
            $null = $RootPath, $RelativePath, $ForWrite
            throw 'outside root'
        }
        $readFile = {
            param($Path)
            $null = $Path
            $readCount.AddOrUpdate(
                'value',
                1,
                { param($key, $value) $null = $key; $value + 1 }
            ) |
                Out-Null
            [byte[]]@()
        }.GetNewClosure()
        $adapter = Get-TestAdapter -ResolvePath $resolvePath -ReadFile $readFile

        $finding = Get-TestTarget -Name fixture -RootPath $root |
            Test-Compliance -Policy $policy -Adapter $adapter

        $finding.Status | Should -BeExactly 'Error'
        $readCount['value'] | Should -Be 0
    }

    It 'rejects incomplete adapter capability tables with the adapter ErrorId' {
        $root = Get-TestRoot -Name 'm2-adapter'
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'minimal.json')

        $errorRecord = Get-CaughtError {
            Get-TestTarget -Name fixture -RootPath $root |
                Test-Compliance -Policy $policy -Adapter ([pscustomobject]@{})
        }

        $errorRecord.FullyQualifiedErrorId |
            Should -BeExactly 'ComplianceAdapterFailed,Test-Compliance'
    }

    It 'does not follow a filesystem link that escapes the target root' {
        $root = Get-TestRoot -Name 'm2-link-root'
        $outside = Get-TestRoot -Name 'm2-link-outside'
        $link = Join-Path $root 'link'
        try {
            $null = New-Item -ItemType SymbolicLink -Path $link -Target $outside -ErrorAction Stop
        }
        catch {
            return
        }
        $policyPath = Get-TestPolicyFile -Name 'link-policy.json' -Policy ([ordered]@{
            schemaVersion = 1
            policyId = 'link-policy'
            rules = @(
                [ordered]@{
                    ruleId = 'linked-directory'
                    kind = 'DirectoryExists'
                    relativePath = 'link/child'
                    remediation = 'Create'
                }
            )
        })
        $policy = Import-CompliancePolicy -Path $policyPath

        $finding = Get-TestTarget -Name fixture -RootPath $root |
            Test-Compliance -Policy $policy

        $finding.Status | Should -BeExactly 'Error'
        Test-Path -LiteralPath (Join-Path $outside 'child') | Should -BeFalse
    }
}

Describe 'Milestone 3: safe idempotent remediation' -Tag M3 {
    BeforeEach {
        Import-SelectedComplianceModule
    }

    It 'honors WhatIf, then repairs a directory once and emits ordered result properties' {
        $root = Get-TestRoot -Name 'm3-directory'
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'minimal.json')
        $target = Get-TestTarget -Name fixture -RootPath $root
        $finding = $target | Test-Compliance -Policy $policy
        $preview = @(
            $finding |
                Repair-Compliance `
                    -Policy $policy `
                    -WhatIf 6>&1
        )

        @(
            $preview |
                Where-Object {
                    $_.PSObject.TypeNames -contains 'ComplianceAudit.RemediationResult'
                }
        ).Count | Should -Be 0
        Test-Path -LiteralPath (Join-Path $root 'var/cache') | Should -BeFalse

        $result = $finding | Repair-Compliance -Policy $policy -Confirm:$false
        $result.PSObject.TypeNames[0] |
            Should -BeExactly 'ComplianceAudit.RemediationResult'
        ($result.PSObject.Properties.Name -join '|') | Should -BeExactly (
            'PolicyId|Target|RuleId|Action|Changed|Before|After'
        )
        $result.Changed | Should -BeTrue
        $result.Before | Should -BeExactly 'Missing'
        $result.After | Should -BeExactly 'Present'

        $secondFinding = $target | Test-Compliance -Policy $policy
        @($secondFinding | Repair-Compliance -Policy $policy -Confirm:$false).Count |
            Should -Be 0
    }

    It 'passes the exact ShouldProcess target and action before mutation' {
        $root = Get-TestRoot -Name 'm3-should-process'
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'minimal.json')
        $finding = Get-TestTarget -Name exact-target -RootPath $root |
            Test-Compliance -Policy $policy
        Mock `
            -CommandName Test-ComplianceShouldProcess `
            -ModuleName ComplianceAudit `
            -MockWith { $false } `
            -ParameterFilter {
                $Target -ceq 'exact-target:var/cache' -and
                $Action -ceq 'Create required directory'
            }

        @($finding | Repair-Compliance -Policy $policy).Count | Should -Be 0
        Test-Path -LiteralPath (Join-Path $root 'var/cache') | Should -BeFalse
        Should -Invoke `
            -CommandName Test-ComplianceShouldProcess `
            -ModuleName ComplianceAudit `
            -Times 1 `
            -Exactly `
            -ParameterFilter {
                $Target -ceq 'exact-target:var/cache' -and
                $Action -ceq 'Create required directory'
            }
    }

    It 'preserves unrelated file lines, writes UTF-8 without BOM, and is idempotent' {
        $root = Get-TestRoot -Name 'm3-file'
        $null = New-Item -ItemType Directory -Path (Join-Path $root 'config') -Force
        $configPath = Join-Path $root 'config/app.conf'
        [System.IO.File]::WriteAllText(
            $configPath,
            "# retained`nmode=unsafe`nother=value",
            [System.Text.UTF8Encoding]::new($false)
        )
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'all-rules.json')
        $target = Get-TestTarget -Name fixture -RootPath $root
        $writeState = [System.Collections.Concurrent.ConcurrentDictionary[string, int]]::new()
        $writeState['count'] = 0
        $writeFile = {
            param($Path, $Content)
            $writeState.AddOrUpdate(
                'count',
                1,
                { param($key, $value) $null = $key; $value + 1 }
            ) | Out-Null
            [System.IO.File]::WriteAllText(
                $Path,
                $Content,
                [System.Text.UTF8Encoding]::new($false)
            )
        }.GetNewClosure()
        $adapter = Get-TestAdapter -WriteFile $writeFile
        $finding = $target |
            Test-Compliance -Policy $policy -RuleId safe-mode -Adapter $adapter

        $result = $finding |
            Repair-Compliance -Policy $policy -Adapter $adapter -Confirm:$false

        $result.RuleId | Should -BeExactly 'safe-mode'
        $writeState['count'] | Should -Be 1
        [System.IO.File]::ReadAllText($configPath) |
            Should -BeExactly "# retained`nmode=safe`nother=value"
        $bytes = [System.IO.File]::ReadAllBytes($configPath)
        ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) |
            Should -BeFalse

        $after = $target |
            Test-Compliance -Policy $policy -RuleId safe-mode -Adapter $adapter
        @(
            $after |
                Repair-Compliance -Policy $policy -Adapter $adapter -Confirm:$false
        ).Count | Should -Be 0
        $writeState['count'] | Should -Be 1
    }

    It 'creates a missing setting file only when its parent exists' {
        $root = Get-TestRoot -Name 'm3-missing-file'
        $null = New-Item -ItemType Directory -Path (Join-Path $root 'config') -Force
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'all-rules.json')
        $target = Get-TestTarget -Name fixture -RootPath $root
        $finding = $target | Test-Compliance -Policy $policy -RuleId safe-mode

        $null = $finding | Repair-Compliance -Policy $policy -Confirm:$false

        [System.IO.File]::ReadAllText((Join-Path $root 'config/app.conf')) |
            Should -BeExactly "mode=safe$([System.Environment]::NewLine)"
    }

    It 'never changes malformed configuration data' {
        $root = Get-TestRoot -Name 'm3-malformed'
        $null = New-Item -ItemType Directory -Path (Join-Path $root 'config') -Force
        $configPath = Join-Path $root 'config/app.conf'
        $original = "mode=safe`nmode=unsafe`n"
        [System.IO.File]::WriteAllText(
            $configPath,
            $original,
            [System.Text.UTF8Encoding]::new($false)
        )
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'all-rules.json')
        $finding = Get-TestTarget -Name fixture -RootPath $root |
            Test-Compliance -Policy $policy -RuleId safe-mode

        $finding.Status | Should -BeExactly 'Error'
        @($finding | Repair-Compliance -Policy $policy -Confirm:$false).Count | Should -Be 0
        [System.IO.File]::ReadAllText($configPath) | Should -BeExactly $original
    }

    It 'treats invalid UTF-8, oversized files, and path collisions as Error findings' {
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'all-rules.json')
        $roots = @(
            Get-TestRoot -Name 'm3-invalid-utf8'
            Get-TestRoot -Name 'm3-oversized'
            Get-TestRoot -Name 'm3-collision'
        )
        foreach ($root in $roots) {
            $null = New-Item -ItemType Directory -Path (Join-Path $root 'config') -Force
        }
        [System.IO.File]::WriteAllBytes(
            (Join-Path $roots[0] 'config/app.conf'),
            [byte[]]@(0xC3, 0x28)
        )
        [System.IO.File]::WriteAllBytes(
            (Join-Path $roots[1] 'config/app.conf'),
            [byte[]]::new((1MB + 1))
        )
        $null = New-Item `
            -ItemType Directory `
            -Path (Join-Path $roots[2] 'config/app.conf') `
            -Force

        for ($index = 0; $index -lt $roots.Count; $index++) {
            $finding = Get-TestTarget -Name "invalid-$index" -RootPath $roots[$index] |
                Test-Compliance -Policy $policy -RuleId safe-mode
            $finding.Status | Should -BeExactly 'Error'
            $finding.CanRemediate | Should -BeFalse
            @($finding | Repair-Compliance -Policy $policy -Confirm:$false).Count |
                Should -Be 0
        }
    }
}

Describe 'Milestone 4: reporting, streams, and tool probing' -Tag M4 {
    BeforeEach {
        Import-SelectedComplianceModule
    }

    It 'handles compliant, old, nonzero, malformed, and throwing tool probes as data' {
        $root = Get-TestRoot -Name 'm4-tool'
        $policy = Import-CompliancePolicy -Path (Get-ToolPolicyFile)
        $cases = @(
            @{ ExitCode = 0; Output = '7.4.0'; Expected = 'Compliant' }
            @{ ExitCode = 0; Output = '7.3.9'; Expected = 'NonCompliant' }
            @{ ExitCode = 9; Output = '7.4.0'; Expected = 'Error' }
            @{ ExitCode = 0; Output = 'not-a-version'; Expected = 'Error' }
        )
        foreach ($case in $cases) {
            $probeCase = $case
            $probe = {
                [pscustomobject]@{
                    ExitCode = $probeCase.ExitCode
                    Output = $probeCase.Output
                }
            }.GetNewClosure()
            $adapter = Get-TestAdapter -GetToolVersion $probe
            $finding = Get-TestTarget -Name fixture -RootPath $root |
                Test-Compliance -Policy $policy -Adapter $adapter
            $finding.Status | Should -BeExactly $case.Expected
            $finding.CanRemediate | Should -BeFalse
        }

        $throwing = Get-TestAdapter -GetToolVersion { throw 'probe failed' }
        $errorFinding = Get-TestTarget -Name fixture -RootPath $root |
            Test-Compliance -Policy $policy -Adapter $throwing
        $errorFinding.Status | Should -BeExactly 'Error'
    }

    It 'exports deterministic redacted JSON and CSV in received order' {
        $root = Get-TestRoot -Name 'm4-report'
        $null = New-Item -ItemType Directory -Path (Join-Path $root 'var/cache') -Force
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'minimal.json')
        $findings = @(
            Get-TestTarget -Name fixture-a -RootPath $root |
                Test-Compliance -Policy $policy
        )
        $jsonA = Join-Path $TestDrive 'report-a.json'
        $jsonB = Join-Path $TestDrive 'report-b.json'
        $csv = Join-Path $TestDrive 'report.csv'

        $findings | Export-ComplianceReport -Path $jsonA -Format Json
        $findings | Export-ComplianceReport -Path $jsonB -Format Json
        $findings | Export-ComplianceReport -Path $csv -Format Csv

        [System.IO.File]::ReadAllBytes($jsonA) |
            Should -Be ([System.IO.File]::ReadAllBytes($jsonB))
        $jsonText = [System.IO.File]::ReadAllText($jsonA)
        $jsonText | Should -Not -Match ([regex]::Escape($findings[0].Target.RootPath))
        $decoded = $jsonText | ConvertFrom-Json
        ($decoded.findings[0].PSObject.Properties.Name -join '|') | Should -BeExactly (
            'policyId|target|ruleId|ruleKind|status|observed|expected|canRemediate|message'
        )
        $expectedJson = Get-Content -LiteralPath (
            Join-Path $script:fixtureRoot 'reports/compliant-directory.json'
        ) -Raw | ConvertFrom-Json
        ($decoded | ConvertTo-Json -Depth 5) |
            Should -BeExactly ($expectedJson | ConvertTo-Json -Depth 5)

        $actualCsv = [System.IO.File]::ReadAllText($csv).Replace("`r`n", "`n").TrimEnd()
        $expectedCsv = Get-Content -LiteralPath (
            Join-Path $script:fixtureRoot 'reports/compliant-directory.csv'
        ) -Raw
        $actualCsv | Should -BeExactly $expectedCsv.Replace("`r`n", "`n").TrimEnd()
    }

    It 'writes empty reports and protects existing destinations through ShouldProcess' {
        $emptyJson = Join-Path $TestDrive 'empty.json'
        $emptyCsv = Join-Path $TestDrive 'empty.csv'
        Export-ComplianceReport -Path $emptyJson -Format Json
        Export-ComplianceReport -Path $emptyCsv -Format Csv

        @(([System.IO.File]::ReadAllText($emptyJson) | ConvertFrom-Json).findings).Count |
            Should -Be 0
        @([System.IO.File]::ReadAllLines($emptyCsv)).Count | Should -Be 1

        $exists = Get-CaughtError {
            Export-ComplianceReport -Path $emptyJson -Format Json
        }
        $exists.FullyQualifiedErrorId |
            Should -BeExactly 'ComplianceReportExists,Export-ComplianceReport'

        $previewPath = Join-Path $TestDrive 'preview.json'
        $information = @(
            Export-ComplianceReport `
                -Path $previewPath `
                -Format Json `
                -WhatIf 6>&1
        )
        Test-Path -LiteralPath $previewPath | Should -BeFalse
        $null = $information
    }

    It 'writes remediation adapter failures as non-terminating errors that Stop can promote' {
        $root = Get-TestRoot -Name 'm4-remediation-error'
        $policy = Import-CompliancePolicy -Path (Get-TestPolicyPath -Name 'minimal.json')
        $adapter = Get-TestAdapter -CreateDirectory { param($Path) throw "cannot create $Path" }
        $finding = Get-TestTarget -Name fixture -RootPath $root |
            Test-Compliance -Policy $policy -Adapter $adapter
        $mixed = @(
            $finding |
                Repair-Compliance `
                    -Policy $policy `
                    -Adapter $adapter `
                    -Confirm:$false `
                    -ErrorAction Continue 2>&1
        )
        @(
            $mixed |
                Where-Object {
                    $_.PSObject.TypeNames -contains 'ComplianceAudit.RemediationResult'
                }
        ).Count | Should -Be 0
        $remediationError = @(
            $mixed |
                Where-Object {
                    $_ -is [System.Management.Automation.ErrorRecord] -and
                    $_.FullyQualifiedErrorId -like 'ComplianceRemediationFailed,*'
                }
        )
        $remediationError.Count | Should -Be 1
        $remediationError[0].FullyQualifiedErrorId |
            Should -BeExactly 'ComplianceRemediationFailed,Repair-Compliance'

        $promoted = Get-CaughtError {
            $finding |
                Repair-Compliance `
                    -Policy $policy `
                    -Adapter $adapter `
                    -Confirm:$false `
                    -ErrorAction Stop
        }
        $promoted.FullyQualifiedErrorId |
            Should -BeExactly 'ComplianceRemediationFailed,Repair-Compliance'
    }

    It 'preserves WhatIf and terminating-error behavior in a child pwsh process' {
        $root = Get-TestRoot -Name 'm4-child'
        $policyPath = Get-TestPolicyPath -Name 'minimal.json'
        $moduleLiteral = $script:target.ModulePath.Replace("'", "''")
        $policyLiteral = $policyPath.Replace("'", "''")
        $rootLiteral = $root.Replace("'", "''")
        $commandText = @"
`$ErrorActionPreference = 'Stop'
Import-Module -Name '$moduleLiteral' -Force
`$policy = Import-CompliancePolicy -Path '$policyLiteral'
`$target = [pscustomobject]@{ Name = 'child'; RootPath = '$rootLiteral' }
`$finding = `$target | Test-Compliance -Policy `$policy
`$finding | Repair-Compliance -Policy `$policy -WhatIf
"@
        $encodedCommand = [Convert]::ToBase64String(
            [System.Text.Encoding]::Unicode.GetBytes($commandText)
        )

        $process = Invoke-TestChildProcess -ArgumentList @(
                '-NoProfile'
                '-EncodedCommand'
                $encodedCommand
            )

        $process.ExitCode | Should -Be 0 -Because $process.StandardError
        Test-Path -LiteralPath (Join-Path $root 'var/cache') | Should -BeFalse
        $process.StandardOutput | Should -Match 'child:var/cache'
        $process.StandardError | Should -BeNullOrEmpty

        $invalidPolicyLiteral = (
            Get-TestPolicyPath -Name 'unknown-property.json'
        ).Replace("'", "''")
        $badCommand = @"
`$ErrorActionPreference = 'Stop'
Import-Module -Name '$moduleLiteral' -Force
Import-CompliancePolicy -Path '$invalidPolicyLiteral'
"@
        $badEncodedCommand = [Convert]::ToBase64String(
            [System.Text.Encoding]::Unicode.GetBytes($badCommand)
        )
        $badProcess = Invoke-TestChildProcess -ArgumentList @(
                '-NoProfile'
                '-EncodedCommand'
                $badEncodedCommand
            )
        $badProcess.ExitCode | Should -Not -Be 0
        $badProcess.StandardError | Should -Match 'compliance policy is invalid'
    }
}

Describe 'Milestone 5: bounded parallel auditing and cleanup' -Tag M5 {
    BeforeEach {
        Import-SelectedComplianceModule
    }

    It 'never exceeds ThrottleLimit and restores policy order after concurrent work' {
        $root = Get-TestRoot -Name 'm5-bounded'
        $policy = Import-CompliancePolicy -Path (Get-ToolPolicyFile -RuleCount 6)
        $state = [System.Collections.Concurrent.ConcurrentDictionary[string, int]]::new()
        $state['active'] = 0
        $state['maximum'] = 0
        $state['completed'] = 0
        $state['started'] = 0
        $entered = [System.Threading.CountdownEvent]::new(3)
        $gate = [System.Threading.ManualResetEventSlim]::new($false)
        $releaseSecond = [System.Threading.ManualResetEventSlim]::new($false)
        $releaseFirst = [System.Threading.ManualResetEventSlim]::new($false)
        $completionOrder = [System.Collections.Concurrent.ConcurrentQueue[int]]::new()
        $adapterState = [pscustomobject]@{
            Counters = $state
            Entered = $entered
            Gate = $gate
            ReleaseSecond = $releaseSecond
            ReleaseFirst = $releaseFirst
            CompletionOrder = $completionOrder
        }
        $probe = {
            param($AdapterState)
            $callNumber = $AdapterState.Counters.AddOrUpdate(
                'started',
                1,
                { param($key, $value) $null = $key; $value + 1 }
            )
            $active = $AdapterState.Counters.AddOrUpdate(
                'active',
                1,
                { param($key, $value) $null = $key; $value + 1 }
            )
            do {
                $maximum = $AdapterState.Counters['maximum']
                if ($active -le $maximum) {
                    break
                }
            } while (-not $AdapterState.Counters.TryUpdate('maximum', $active, $maximum))
            try {
                try {
                    if (
                        $AdapterState.Entered.CurrentCount -gt 0 -and
                        $AdapterState.Entered.Signal()
                    ) {
                        $AdapterState.Gate.Set()
                    }
                }
                catch {
                    $AdapterState.Gate.Set()
                }
                if (-not $AdapterState.Gate.Wait([System.TimeSpan]::FromSeconds(10))) {
                    throw 'parallel audit did not reach the expected bound'
                }
                switch ($callNumber) {
                    3 {
                        $AdapterState.CompletionOrder.Enqueue(3)
                        $AdapterState.ReleaseSecond.Set()
                    }
                    2 {
                        $AdapterState.ReleaseSecond.Wait()
                        $AdapterState.CompletionOrder.Enqueue(2)
                        $AdapterState.ReleaseFirst.Set()
                    }
                    1 {
                        $AdapterState.ReleaseFirst.Wait()
                        $AdapterState.CompletionOrder.Enqueue(1)
                    }
                    default {
                        $AdapterState.CompletionOrder.Enqueue($callNumber)
                    }
                }
                [pscustomobject]@{ ExitCode = 0; Output = '7.4.0' }
            }
            finally {
                $AdapterState.Counters.AddOrUpdate(
                    'active',
                    0,
                    { param($key, $value) $null = $key; $value - 1 }
                ) | Out-Null
                $AdapterState.Counters.AddOrUpdate(
                    'completed',
                    1,
                    { param($key, $value) $null = $key; $value + 1 }
                ) | Out-Null
            }
        }
        $adapter = Get-TestAdapter -State $adapterState -GetToolVersion $probe

        try {
            $findings = @(
                Get-TestTarget -Name fixture -RootPath $root |
                    Test-Compliance `
                        -Policy $policy `
                        -Adapter $adapter `
                        -ThrottleLimit 3
            )
        }
        finally {
            $releaseFirst.Dispose()
            $releaseSecond.Dispose()
            $gate.Dispose()
            $entered.Dispose()
        }

        $findings.Count | Should -Be 6
        ($findings.RuleId -join '|') |
            Should -BeExactly 'tool-1|tool-2|tool-3|tool-4|tool-5|tool-6'
        ($findings.Status | Select-Object -Unique) | Should -BeExactly 'Compliant'
        $state['maximum'] | Should -Be 3
        $state['maximum'] | Should -BeLessOrEqual 3
        $state['active'] | Should -Be 0
        $state['completed'] | Should -Be 6
        (@($completionOrder.ToArray())[0..2] -join '|') | Should -BeExactly '3|2|1'
    }

    It 'converts worker adapter exceptions, preserves all findings, and disposes runspaces' {
        $root = Get-TestRoot -Name 'm5-cleanup'
        $policy = Import-CompliancePolicy -Path (
            Get-ToolPolicyFile -Name 'cleanup-policy.json' -RuleCount 5
        )
        $counter = [System.Collections.Concurrent.ConcurrentDictionary[string, int]]::new()
        $counter['calls'] = 0
        $probe = {
            param($AdapterState)
            $call = $AdapterState.AddOrUpdate(
                'calls',
                1,
                { param($key, $value) $null = $key; $value + 1 }
            )
            if ($call -eq 2) {
                throw 'controlled probe failure'
            }
            [pscustomobject]@{ ExitCode = 0; Output = '7.4.0' }
        }
        $adapter = Get-TestAdapter -State $counter -GetToolVersion $probe
        $runspaceCount = @(Get-Runspace).Count

        $findings = @(
            Get-TestTarget -Name fixture -RootPath $root |
                Test-Compliance -Policy $policy -Adapter $adapter -ThrottleLimit 2
        )

        $findings.Count | Should -Be 5
        @($findings | Where-Object Status -eq Error).Count | Should -Be 1
        @($findings | Where-Object Status -eq Compliant).Count | Should -Be 4
        ($findings.RuleId -join '|') |
            Should -BeExactly 'tool-1|tool-2|tool-3|tool-4|tool-5'
        @(Get-Runspace).Count | Should -Be $runspaceCount
    }
}
