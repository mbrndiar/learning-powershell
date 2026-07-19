#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseShouldProcessForStateChangingFunctions',
    '',
    Justification = 'Private test lifecycle helpers must execute deterministically without confirmation semantics.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseSingularNouns',
    '',
    Justification = 'Private test helper nouns accurately describe fixture collections.'
)]
param()

Set-StrictMode -Version Latest

$script:ComparativeFixtureRoot = Join-Path -Path $PSScriptRoot -ChildPath '../spec/fixtures'
$script:BarrierScriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'Invoke-CliWithBarrier.ps1'
$script:LockHelperScriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'SQLiteLockHelper.ps1'
$script:PwshPath = (Get-Command -Name pwsh -ErrorAction Stop).Source
$script:ProcessTimeoutMilliseconds = 20000
$script:ParallelTimeoutMilliseconds = 30000

function Assert-TestKnownProperty {
    <#
    .SYNOPSIS
    Fails the harness when a fixture node carries a property outside its exact
    documented contract.

    .DESCRIPTION
    SCENARIOS.md requires that unknown fixture keys or generator kinds fail the
    runner rather than being silently ignored. Every fixture/scenario/step/
    operation/assertion node that this harness reads is validated against its
    exact allowed-property list with this helper before any of its members are
    consumed, so an unexpected property is a loud, precise failure instead of a
    quietly ignored typo.

    .PARAMETER InputObject
    The decoded fixture node (a Hashtable/OrderedHashtable from
    ConvertFrom-Json -AsHashtable) to validate.

    .PARAMETER AllowedProperty
    The exact, case-sensitive set of property names permitted on this node.

    .PARAMETER Context
    A short human-readable description of the node, used in the failure
    message to locate the offending fixture content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $InputObject,

        [Parameter(Mandatory)]
        [string[]] $AllowedProperty,

        [Parameter(Mandatory)]
        [string] $Context
    )

    foreach ($propertyName in @($InputObject.Keys)) {
        if (@($AllowedProperty) -cnotcontains [string] $propertyName) {
            throw "Unknown fixture property '$propertyName' in $Context."
        }
    }
}

function Get-ComparativeFixture {
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    param(
        [Parameter(Mandatory)]
        [string] $RelativePath,

        [Parameter(Mandatory)]
        [string] $ExpectedKind,

        [Parameter(Mandatory)]
        [string[]] $AllowedProperty
    )

    $path = Join-Path -Path $script:ComparativeFixtureRoot -ChildPath $RelativePath
    $fixture = Get-Content -LiteralPath $path -Raw |
        ConvertFrom-Json -AsHashtable -NoEnumerate -Depth 100
    Assert-TestKnownProperty `
        -InputObject $fixture `
        -AllowedProperty $AllowedProperty `
        -Context "fixture '$RelativePath'"
    if ([string] $fixture.kind -cne $ExpectedKind) {
        throw "Fixture '$RelativePath' has kind '$($fixture.kind)', expected '$ExpectedKind'."
    }
    $specVersion = (Get-Content -LiteralPath (
        Join-Path -Path $script:ComparativeFixtureRoot -ChildPath '../SPEC_VERSION'
    ) -Raw).Trim()
    if ([string] $fixture.spec_version -cne $specVersion) {
        throw "Fixture '$RelativePath' has spec version '$($fixture.spec_version)', expected '$specVersion'."
    }
    $fixture
}

function ConvertTo-TestNormalizedObject {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value -or $Value -is [string] -or $Value -is [ValueType]) {
        return $Value
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $keys = [string[]] @($Value.Keys)
        [Array]::Sort($keys, [System.StringComparer]::Ordinal)
        $result = [System.Collections.Generic.Dictionary[string, object]]::new(
            [System.StringComparer]::Ordinal
        )
        foreach ($key in $keys) {
            $result.Add($key, (ConvertTo-TestNormalizedObject -Value $Value[$key]))
        }
        return $result
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @(
            foreach ($item in $Value) {
                ConvertTo-TestNormalizedObject -Value $item
            }
        )
        return ,([object[]] $items)
    }
    $properties = @($Value.PSObject.Properties | Where-Object MemberType -in NoteProperty, Property)
    $dictionary = [System.Collections.Generic.Dictionary[string, object]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($property in $properties) {
        $dictionary.Add(
            $property.Name,
            (ConvertTo-TestNormalizedObject -Value $property.Value)
        )
    }
    ConvertTo-TestNormalizedObject -Value $dictionary
}

function ConvertTo-TestCanonicalJson {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Value
    )

    ConvertTo-Json `
        -InputObject (ConvertTo-TestNormalizedObject -Value $Value) `
        -Compress `
        -Depth 100
}

function Assert-TestSemanticEqual {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Actual,

        [AllowNull()]
        [object] $Expected,

        [string] $Because = 'values must be semantically equal'
    )

    $actualJson = ConvertTo-TestCanonicalJson -Value $Actual
    $expectedJson = ConvertTo-TestCanonicalJson -Value $Expected
    if ($actualJson -cne $expectedJson) {
        throw "$Because.`nExpected: $expectedJson`nActual:   $actualJson"
    }
}

function Assert-TestJsonNumbers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Text.Json.JsonElement] $Element
    )

    switch ($Element.ValueKind) {
        ([System.Text.Json.JsonValueKind]::Number) {
            if ($Element.GetRawText() -cnotmatch '^-?(?:0|[1-9][0-9]*)$') {
                throw "JSON number '$($Element.GetRawText())' is not a canonical integer."
            }
        }
        ([System.Text.Json.JsonValueKind]::Array) {
            foreach ($item in $Element.EnumerateArray()) {
                Assert-TestJsonNumbers -Element $item
            }
        }
        ([System.Text.Json.JsonValueKind]::Object) {
            foreach ($property in $Element.EnumerateObject()) {
                Assert-TestJsonNumbers -Element $property.Value
            }
        }
    }
}

function ConvertFrom-TestCliOutput {
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Stdout
    )

    if ($Stdout.StartsWith([char] 0xfeff)) {
        throw 'CLI stdout contains a byte-order mark.'
    }
    if (-not $Stdout.EndsWith("`n", [System.StringComparison]::Ordinal)) {
        throw 'CLI stdout does not end with LF.'
    }
    $json = $Stdout.Substring(0, $Stdout.Length - 1)
    if ($json.Length -eq 0 -or $json.Contains("`n") -or $json.Contains("`r")) {
        throw 'CLI stdout is not exactly one compact JSON line.'
    }
    $document = [System.Text.Json.JsonDocument]::Parse($json)
    try {
        if ($document.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            throw 'CLI stdout root is not a JSON object.'
        }
        Assert-TestJsonNumbers -Element $document.RootElement
    }
    finally {
        $document.Dispose()
    }
    $json | ConvertFrom-Json -AsHashtable -NoEnumerate -Depth 100
}

function Start-TestCliProcess {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]] $Arguments,

        [string] $GatePath
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $script:PwshPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $startInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
    $null = $startInfo.ArgumentList.Add('-NoProfile')
    $null = $startInfo.ArgumentList.Add('-File')
    if ([string]::IsNullOrEmpty($GatePath)) {
        $null = $startInfo.ArgumentList.Add($ScriptPath)
    }
    else {
        $null = $startInfo.ArgumentList.Add($script:BarrierScriptPath)
        $null = $startInfo.ArgumentList.Add($GatePath)
        $null = $startInfo.ArgumentList.Add($ScriptPath)
    }
    foreach ($argument in $Arguments) {
        $null = $startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) {
        throw 'Failed to start CLI process.'
    }
    [pscustomobject]@{
        Process = $process
        StdoutTask = $process.StandardOutput.ReadToEndAsync()
        StderrTask = $process.StandardError.ReadToEndAsync()
        Stopwatch = $stopwatch
        Arguments = $Arguments
    }
}

function Receive-TestCliProcess {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object] $Handle,

        [int] $TimeoutMilliseconds = $script:ProcessTimeoutMilliseconds
    )

    if (-not $Handle.Process.WaitForExit($TimeoutMilliseconds)) {
        $Handle.Process.Kill($true)
        $Handle.Process.WaitForExit()
        throw "CLI process $($Handle.Process.Id) exceeded ${TimeoutMilliseconds}ms."
    }
    $Handle.Stopwatch.Stop()
    $stdout = $Handle.StdoutTask.GetAwaiter().GetResult()
    $stderr = $Handle.StderrTask.GetAwaiter().GetResult()
    $exitCode = $Handle.Process.ExitCode
    $Handle.Process.Dispose()
    $parsed = ConvertFrom-TestCliOutput -Stdout $stdout
    [pscustomobject]@{
        ExitCode = $exitCode
        Stdout = $stdout
        Stderr = $stderr
        Parsed = $parsed
        DurationMilliseconds = [long] $Handle.Stopwatch.ElapsedMilliseconds
        Arguments = $Handle.Arguments
    }
}

function Invoke-TestCli {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]] $Arguments,

        [int] $TimeoutMilliseconds = $script:ProcessTimeoutMilliseconds
    )

    $handle = Start-TestCliProcess -ScriptPath $ScriptPath -Arguments $Arguments
    Receive-TestCliProcess -Handle $handle -TimeoutMilliseconds $TimeoutMilliseconds
}

function Assert-TestCliExpectation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Result,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Expectation
    )

    Assert-TestKnownProperty `
        -InputObject $Expectation `
        -AllowedProperty @('exit', 'stderr', 'stdout') `
        -Context 'expect fixture node'
    $Result.ExitCode | Should -Be ([int] $Expectation.exit)
    $Result.Stderr | Should -BeExactly ([string] $Expectation.stderr)
    if ($Expectation.Contains('stdout')) {
        Assert-TestSemanticEqual `
            -Actual $Result.Parsed `
            -Expected $Expectation.stdout `
            -Because 'the CLI envelope must match the frozen fixture'
    }
}

function New-TestFixtureValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Descriptor,

        [switch] $AsJson
    )

    switch ([string] $Descriptor.kind) {
        'nested_arrays' {
            Assert-TestKnownProperty `
                -InputObject $Descriptor `
                -AllowedProperty @('kind', 'leaf', 'depth') `
                -Context 'nested_arrays generator descriptor'
            $value = $Descriptor.leaf
            for ($depth = 0; $depth -lt [int] $Descriptor.depth; $depth++) {
                $value = ,$value
            }
            if ($AsJson) {
                return ConvertTo-Json -InputObject $value -Compress -Depth 100
            }
            return ,$value
        }
        'ascii_string_total_bytes' {
            Assert-TestKnownProperty `
                -InputObject $Descriptor `
                -AllowedProperty @('kind', 'character', 'total_bytes') `
                -Context 'ascii_string_total_bytes generator descriptor'
            $count = [int] $Descriptor.total_bytes - 2
            $value = ([string] $Descriptor.character) * $count
            $json = '"' + $value + '"'
            [System.Text.Encoding]::UTF8.GetByteCount($json) |
                Should -Be ([int] $Descriptor.total_bytes)
            if ($AsJson) {
                return $json
            }
            return $value
        }
        default {
            throw "Unknown fixture generator '$($Descriptor.kind)'."
        }
    }
}

function Get-TestCaseKey {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Case
    )

    if ($Case.Contains('key')) {
        return [string] $Case.key
    }
    if ([string] $Case.key_generator.kind -cne 'repeat_suffix') {
        throw "Unknown key generator '$($Case.key_generator.kind)'."
    }
    Assert-TestKnownProperty `
        -InputObject $Case.key_generator `
        -AllowedProperty @('kind', 'prefix', 'character', 'count') `
        -Context 'repeat_suffix key_generator descriptor'
    [string] $Case.key_generator.prefix +
        ([string] $Case.key_generator.character * [int] $Case.key_generator.count)
}

function New-TestScenarioPaths {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $ParentPath,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $directory = Join-Path -Path $ParentPath -ChildPath (
        '{0}-{1}' -f $Name, [guid]::NewGuid().ToString('N')
    )
    $null = New-Item -ItemType Directory -Path $directory
    [pscustomobject]@{
        Directory = $directory
        Database = Join-Path -Path $directory -ChildPath 'store.db'
        MissingParent = Join-Path -Path $directory -ChildPath 'missing'
    }
}

function Remove-TestScenarioPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Paths
    )

    foreach ($path in @(
            $Paths.Database,
            "$($Paths.Database)-wal",
            "$($Paths.Database)-shm",
            "$($Paths.Database)-journal"
        )) {
        if ([System.IO.File]::Exists($path)) {
            [System.IO.File]::Delete($path)
        }
        [System.IO.File]::Exists($path) | Should -BeFalse
    }
    if ([System.IO.Directory]::Exists($Paths.Directory)) {
        [System.IO.Directory]::Delete($Paths.Directory, $true)
    }
    [System.IO.Directory]::Exists($Paths.Directory) | Should -BeFalse
}

function Open-TestSqlite {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $DatabasePath
    )

    Import-Module SimplySql -RequiredVersion 2.2.0.106 -Force -WarningAction SilentlyContinue
    $name = 'comparative-test-{0}-{1}' -f $PID, [guid]::NewGuid().ToString('N')
    Open-SQLiteConnection `
        -DataSource $DatabasePath `
        -ConnectionName $name `
        -CommandTimeout 30 `
        -Additional @{
            BusyTimeout = 10000
            WaitTimeout = 10000
            DefaultTimeout = 10
            ForeignKeys = $true
            Pooling = $false
        } `
        -WarningAction SilentlyContinue |
        Out-Null
    [pscustomobject]@{
        Name = $name
        Connection = Get-SqlConnection -ConnectionName $name
    }
}

function Close-TestSqlite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context
    )

    Close-SqlConnection -ConnectionName $Context.Name -ErrorAction SilentlyContinue
}

function Invoke-TestSqliteStatements {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $DatabasePath,

        [Parameter(Mandatory)]
        [object[]] $Statements
    )

    $context = Open-TestSqlite -DatabasePath $DatabasePath
    try {
        foreach ($statement in $Statements) {
            $command = $context.Connection.CreateCommand()
            try {
                $command.CommandText = [string] $statement
                $null = $command.ExecuteNonQuery()
            }
            finally {
                $command.Dispose()
            }
        }
    }
    finally {
        Close-TestSqlite -Context $context
    }
}

function Invoke-TestSqliteQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $DatabasePath,

        [Parameter(Mandatory)]
        [string] $Sql
    )

    $context = Open-TestSqlite -DatabasePath $DatabasePath
    try {
        $command = $context.Connection.CreateCommand()
        $reader = $null
        try {
            $command.CommandText = $Sql
            $reader = $command.ExecuteReader()
            $rows = @(
                while ($reader.Read()) {
                    $row = @(
                        for ($index = 0; $index -lt $reader.FieldCount; $index++) {
                            $value = $reader.GetValue($index)
                            if ($value -is [DBNull]) { $null } else { $value }
                        }
                    )
                    ,$row
                }
            )
            return ,$rows
        }
        finally {
            if ($null -ne $reader) {
                $reader.Dispose()
            }
            $command.Dispose()
        }
    }
    finally {
        Close-TestSqlite -Context $context
    }
}

function Assert-TestSqliteIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $DatabasePath
    )

    if (-not [System.IO.File]::Exists($DatabasePath)) {
        return
    }
    $rows = @(Invoke-TestSqliteQuery -DatabasePath $DatabasePath -Sql 'PRAGMA integrity_check')
    $rows.Count | Should -Be 1
    $rows[0][0] | Should -BeExactly 'ok'
}

function Expand-TestArguments {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Arguments,

        [Parameter(Mandatory)]
        [object] $Paths,

        [int] $Index = -1,

        [int] $PadWidth = 0
    )

    $expanded = @(
        foreach ($argument in $Arguments) {
            $value = ([string] $argument).
                Replace('${DB}', $Paths.Database).
                Replace('${MISSING_PARENT}', $Paths.MissingParent)
            if ($Index -ge 0) {
                $number = $Index + 1
                $padded = if ($PadWidth -gt 0) {
                    $number.ToString("D$PadWidth", [System.Globalization.CultureInfo]::InvariantCulture)
                }
                else {
                    [string] $number
                }
                $value = $value.
                    Replace('${i}', [string] $Index).
                    Replace('${n}', [string] $number).
                    Replace('${padded_n}', $padded)
            }
            $value
        }
    )
    return ,([string[]] $expanded)
}

function Invoke-TestKeyFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [string] $ParentPath
    )

    $fixture = Get-ComparativeFixture `
        -RelativePath 'keys.json' `
        -ExpectedKind 'key_cases' `
        -AllowedProperty @('kind', 'spec_version', 'accepted', 'rejected', 'ordering')
    foreach ($case in $fixture.accepted) {
        $paths = New-TestScenarioPaths -ParentPath $ParentPath -Name "key-$($case.id)"
        try {
            $caseAllowed = if ($case.Contains('key')) { @('id', 'key') } else { @('id', 'key_generator') }
            Assert-TestKnownProperty `
                -InputObject $case `
                -AllowedProperty $caseAllowed `
                -Context "accepted key case '$($case.id)'"
            $key = Get-TestCaseKey -Case $case
            $set = Invoke-TestCli -ScriptPath $ScriptPath -Arguments @(
                '--db', $paths.Database, 'set', $key, '--value-json', 'null', '--expect', 'absent'
            )
            $set.ExitCode | Should -Be 0
            $get = Invoke-TestCli -ScriptPath $ScriptPath -Arguments @(
                '--db', $paths.Database, 'get', $key
            )
            $get.ExitCode | Should -Be 0
            $get.Parsed.result.key | Should -BeExactly $key
        }
        finally {
            Assert-TestSqliteIntegrity -DatabasePath $paths.Database
            Remove-TestScenarioPaths -Paths $paths
        }
    }
    foreach ($case in $fixture.rejected) {
        $paths = New-TestScenarioPaths -ParentPath $ParentPath -Name "key-$($case.id)"
        try {
            $caseAllowed = if ($case.Contains('key')) { @('id', 'key') } else { @('id', 'key_generator') }
            Assert-TestKnownProperty `
                -InputObject $case `
                -AllowedProperty $caseAllowed `
                -Context "rejected key case '$($case.id)'"
            $key = Get-TestCaseKey -Case $case
            $result = Invoke-TestCli -ScriptPath $ScriptPath -Arguments @(
                '--db', $paths.Database, 'get', $key
            )
            $result.ExitCode | Should -Be 2
            Assert-TestSemanticEqual -Actual $result.Parsed -Expected @{
                ok = $false
                error = @{
                    category = 'invalid_argument'
                    details = @{ field = 'key'; reason = 'format' }
                }
            }
            [System.IO.File]::Exists($paths.Database) | Should -BeFalse
        }
        finally {
            Remove-TestScenarioPaths -Paths $paths
        }
    }

    $paths = New-TestScenarioPaths -ParentPath $ParentPath -Name 'key-ordering'
    try {
        $reverse = @($fixture.ordering)
        [Array]::Reverse($reverse)
        foreach ($key in $reverse) {
            $result = Invoke-TestCli -ScriptPath $ScriptPath -Arguments @(
                '--db', $paths.Database, 'set', [string] $key, '--value-json', 'null'
            )
            $result.ExitCode | Should -Be 0
        }
        $list = Invoke-TestCli -ScriptPath $ScriptPath -Arguments @(
            '--db', $paths.Database, 'list'
        )
        @($list.Parsed.result.entries | ForEach-Object { $_.key }) |
            Should -BeExactly @($fixture.ordering)
    }
    finally {
        Assert-TestSqliteIntegrity -DatabasePath $paths.Database
        Remove-TestScenarioPaths -Paths $paths
    }
}

function Invoke-TestAcceptedValueFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [string] $ParentPath
    )

    $fixture = Get-ComparativeFixture `
        -RelativePath 'values-accepted.json' `
        -ExpectedKind 'accepted_value_cases' `
        -AllowedProperty @('kind', 'spec_version', 'cases')
    foreach ($case in $fixture.cases) {
        $paths = New-TestScenarioPaths -ParentPath $ParentPath -Name "accepted-$($case.id)"
        try {
            $inputProperty = if ($case.Contains('input_json')) { 'input_json' } else { 'input_generator' }
            $normalizedProperty = if ($case.Contains('normalized')) { 'normalized' } else { 'normalized_generator' }
            Assert-TestKnownProperty `
                -InputObject $case `
                -AllowedProperty @('id', $inputProperty, $normalizedProperty) `
                -Context "accepted value case '$($case.id)'"
            $inputJson = if ($case.Contains('input_json')) {
                [string] $case.input_json
            }
            else {
                New-TestFixtureValue -Descriptor $case.input_generator -AsJson
            }
            $normalized = if ($case.Contains('normalized')) {
                $case.normalized
            }
            else {
                New-TestFixtureValue -Descriptor $case.normalized_generator
            }
            $set = Invoke-TestCli -ScriptPath $ScriptPath -Arguments @(
                '--db', $paths.Database, 'set', 'value', '--value-json', $inputJson, '--expect', 'absent'
            )
            $set.ExitCode | Should -Be 0
            $set.Parsed.result.created | Should -BeTrue
            $set.Parsed.result.revision | Should -Be 1
            Assert-TestSemanticEqual -Actual $set.Parsed.result.value -Expected $normalized

            $get = Invoke-TestCli -ScriptPath $ScriptPath -Arguments @(
                '--db', $paths.Database, 'get', 'value'
            )
            $get.ExitCode | Should -Be 0
            $get.Parsed.result.revision | Should -Be 1
            Assert-TestSemanticEqual -Actual $get.Parsed.result.value -Expected $normalized
        }
        finally {
            Assert-TestSqliteIntegrity -DatabasePath $paths.Database
            Remove-TestScenarioPaths -Paths $paths
        }
    }
}

function Invoke-TestRejectedValueFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [string] $ParentPath
    )

    $fixture = Get-ComparativeFixture `
        -RelativePath 'values-rejected.json' `
        -ExpectedKind 'rejected_value_cases' `
        -AllowedProperty @('kind', 'spec_version', 'cases')
    foreach ($case in $fixture.cases) {
        $paths = New-TestScenarioPaths -ParentPath $ParentPath -Name "rejected-$($case.id)"
        try {
            $inputProperty = if ($case.Contains('input_json')) { 'input_json' } else { 'input_generator' }
            Assert-TestKnownProperty `
                -InputObject $case `
                -AllowedProperty @('id', 'exit', 'category', 'details', $inputProperty) `
                -Context "rejected value case '$($case.id)'"
            $inputJson = if ($case.Contains('input_json')) {
                [string] $case.input_json
            }
            else {
                New-TestFixtureValue -Descriptor $case.input_generator -AsJson
            }
            $result = Invoke-TestCli -ScriptPath $ScriptPath -Arguments @(
                '--db', $paths.Database, 'set', 'value', '--value-json', $inputJson
            )
            $result.ExitCode | Should -Be ([int] $case.exit)
            $result.Parsed.error.category | Should -BeExactly ([string] $case.category)
            Assert-TestSemanticEqual -Actual $result.Parsed.error.details -Expected $case.details
            [System.IO.File]::Exists($paths.Database) | Should -BeFalse
        }
        finally {
            Remove-TestScenarioPaths -Paths $paths
        }
    }
}

function Invoke-TestFixtureReference {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [string] $ParentPath,

        [Parameter(Mandatory)]
        [string] $Reference
    )

    switch ([System.IO.Path]::GetFileName($Reference)) {
        'keys.json' {
            Invoke-TestKeyFixture -ScriptPath $ScriptPath -ParentPath $ParentPath
        }
        'values-accepted.json' {
            Invoke-TestAcceptedValueFixture -ScriptPath $ScriptPath -ParentPath $ParentPath
        }
        'values-rejected.json' {
            Invoke-TestRejectedValueFixture -ScriptPath $ScriptPath -ParentPath $ParentPath
        }
        default {
            throw "Unknown fixture reference '$Reference'."
        }
    }
}

function Invoke-TestSequentialFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [string] $ParentPath,

        [Parameter(Mandatory)]
        [string] $RelativePath
    )

    $fixture = Get-ComparativeFixture `
        -RelativePath $RelativePath `
        -ExpectedKind 'sequential_scenarios' `
        -AllowedProperty @('kind', 'spec_version', 'scenarios')
    foreach ($scenario in $fixture.scenarios) {
        Assert-TestKnownProperty `
            -InputObject $scenario `
            -AllowedProperty @('id', 'database', 'setup', 'steps') `
            -Context "sequential scenario '$($scenario.id)'"
        if (@('fresh', 'sqlite_setup') -cnotcontains [string] $scenario.database) {
            throw "Unknown sequential scenario database kind '$($scenario.database)' in '$($scenario.id)'."
        }
        $paths = New-TestScenarioPaths -ParentPath $ParentPath -Name ([string] $scenario.id)
        try {
            if ([string] $scenario.database -ceq 'sqlite_setup') {
                Assert-TestKnownProperty `
                    -InputObject $scenario.setup `
                    -AllowedProperty @('statements') `
                    -Context "sqlite_setup in '$($scenario.id)'"
                Invoke-TestSqliteStatements `
                    -DatabasePath $paths.Database `
                    -Statements @($scenario.setup.statements)
            }
            foreach ($step in $scenario.steps) {
                if ($step.Contains('run')) {
                    Assert-TestKnownProperty `
                        -InputObject $step `
                        -AllowedProperty @('run', 'expect') `
                        -Context "sequential run step in '$($scenario.id)'"
                    Assert-TestKnownProperty `
                        -InputObject $step.run `
                        -AllowedProperty @('args') `
                        -Context "sequential run node in '$($scenario.id)'"
                    $arguments = Expand-TestArguments -Arguments @($step.run.args) -Paths $paths
                    $result = Invoke-TestCli -ScriptPath $ScriptPath -Arguments $arguments
                    Assert-TestCliExpectation -Result $result -Expectation $step.expect
                }
                elseif ($step.Contains('sqlite_assert')) {
                    Assert-TestKnownProperty `
                        -InputObject $step `
                        -AllowedProperty @('sqlite_assert') `
                        -Context "sequential sqlite_assert step in '$($scenario.id)'"
                    Assert-TestKnownProperty `
                        -InputObject $step.sqlite_assert `
                        -AllowedProperty @('queries') `
                        -Context "sqlite_assert node in '$($scenario.id)'"
                    foreach ($query in $step.sqlite_assert.queries) {
                        Assert-TestKnownProperty `
                            -InputObject $query `
                            -AllowedProperty @('sql', 'rows') `
                            -Context "sqlite_assert query in '$($scenario.id)'"
                        $rows = Invoke-TestSqliteQuery `
                            -DatabasePath $paths.Database `
                            -Sql ([string] $query.sql)
                        Assert-TestSemanticEqual -Actual $rows -Expected $query.rows
                    }
                }
                elseif ($step.Contains('fixture_references')) {
                    Assert-TestKnownProperty `
                        -InputObject $step `
                        -AllowedProperty @('fixture_references') `
                        -Context "sequential fixture_references step in '$($scenario.id)'"
                    foreach ($reference in $step.fixture_references) {
                        Invoke-TestFixtureReference `
                            -ScriptPath $ScriptPath `
                            -ParentPath $paths.Directory `
                            -Reference ([string] $reference)
                    }
                }
                else {
                    throw "Unknown sequential step in '$($scenario.id)'."
                }
            }
        }
        finally {
            Assert-TestSqliteIntegrity -DatabasePath $paths.Database
            Remove-TestScenarioPaths -Paths $paths
        }
    }
}

function Start-TestLockHelper {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object] $Paths,

        [Parameter(Mandatory)]
        [string] $Id
    )

    $readyPath = Join-Path -Path $Paths.Directory -ChildPath "$Id.ready"
    $releasePath = Join-Path -Path $Paths.Directory -ChildPath "$Id.release"
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $script:PwshPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @(
            '-NoProfile',
            '-File',
            $script:LockHelperScriptPath,
            $Paths.Database,
            $readyPath,
            $releasePath
        )) {
        $null = $startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw 'Failed to start SQLite lock helper.'
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not [System.IO.File]::Exists($readyPath)) {
        if ($process.HasExited) {
            throw "SQLite lock helper exited early with code $($process.ExitCode)."
        }
        if ($stopwatch.ElapsedMilliseconds -gt $script:ProcessTimeoutMilliseconds) {
            $process.Kill($true)
            $process.WaitForExit()
            throw 'SQLite lock helper did not become ready.'
        }
        Start-Sleep -Milliseconds 10
    }
    [pscustomobject]@{
        Process = $process
        StdoutTask = $stdoutTask
        StderrTask = $stderrTask
        ReadyPath = $readyPath
        ReleasePath = $releasePath
    }
}

function Stop-TestLockHelper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Handle
    )

    [System.IO.File]::WriteAllText($Handle.ReleasePath, 'release')
    if (-not $Handle.Process.WaitForExit($script:ProcessTimeoutMilliseconds)) {
        $Handle.Process.Kill($true)
        $Handle.Process.WaitForExit()
        throw 'SQLite lock helper did not exit after release.'
    }
    $stdout = $Handle.StdoutTask.GetAwaiter().GetResult()
    $stderr = $Handle.StderrTask.GetAwaiter().GetResult()
    $Handle.Process.ExitCode | Should -Be 0
    $stdout | Should -BeExactly ''
    $stderr | Should -BeExactly ''
    $Handle.Process.Dispose()
}

function Assert-TestRunStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Result,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Assertions
    )

    $payload = $Result.Parsed.result
    Assert-TestKnownProperty `
        -InputObject $Assertions `
        -AllowedProperty @(
            'keys_in_order'
            'global_revision'
            'entry_count'
            'entry_revision_set'
            'values_by_key'
        ) `
        -Context 'run_assert assert node'
    if ($Assertions.Contains('keys_in_order')) {
        @($payload.entries | ForEach-Object { $_.key }) |
            Should -BeExactly @($Assertions.keys_in_order)
    }
    if ($Assertions.Contains('global_revision')) {
        $payload.global_revision | Should -Be ([long] $Assertions.global_revision)
    }
    if ($Assertions.Contains('entry_count')) {
        @($payload.entries).Count | Should -Be ([int] $Assertions.entry_count)
    }
    if ($Assertions.Contains('entry_revision_set')) {
        $actual = @($payload.entries.revision | Sort-Object)
        $expected = @(
            [long] $Assertions.entry_revision_set.from..
                [long] $Assertions.entry_revision_set.to
        )
        $actual | Should -BeExactly $expected
    }
    if ($Assertions.Contains('values_by_key')) {
        foreach ($key in $Assertions.values_by_key.Keys) {
            $entry = @($payload.entries | Where-Object { $_.key -ceq $key })
            $entry.Count | Should -Be 1
            Assert-TestSemanticEqual `
                -Actual $entry[0].value `
                -Expected $Assertions.values_by_key[$key]
        }
    }
}

function Assert-TestParallelResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]] $Results,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Assertions,

        [Parameter(Mandatory)]
        [string] $ScriptPath
    )

    Assert-TestKnownProperty `
        -InputObject $Assertions `
        -AllowedProperty @(
            'all_exit'
            'all_ok'
            'stdout_semantic_all'
            'success_count'
            'category_counts'
            'result_revision_set'
            'success_revision'
            'conflict_actual'
            'not_found_count'
            'winner_value_matches_final'
        ) `
        -Context 'parallel assert node'
    if ($Assertions.Contains('all_exit')) {
        foreach ($result in $Results) {
            $result.ExitCode | Should -Be ([int] $Assertions.all_exit)
        }
    }
    if ($Assertions.Contains('all_ok')) {
        foreach ($result in $Results) {
            $result.Parsed.ok | Should -Be ([bool] $Assertions.all_ok)
        }
    }
    if ($Assertions.Contains('stdout_semantic_all')) {
        foreach ($result in $Results) {
            Assert-TestSemanticEqual -Actual $result.Parsed -Expected $Assertions.stdout_semantic_all
        }
    }
    $successes = @($Results | Where-Object { $_.Parsed.ok })
    if ($Assertions.Contains('success_count')) {
        $successes.Count | Should -Be ([int] $Assertions.success_count)
    }
    if ($Assertions.Contains('category_counts')) {
        foreach ($category in $Assertions.category_counts.Keys) {
            @(
                $Results | Where-Object {
                    -not $_.Parsed.ok -and $_.Parsed.error.category -ceq $category
                }
            ).Count |
                Should -Be ([int] $Assertions.category_counts[$category])
        }
    }
    if ($Assertions.Contains('result_revision_set')) {
        $actual = @($successes.Parsed.result.revision | Sort-Object)
        $expected = @(
            [long] $Assertions.result_revision_set.from..
                [long] $Assertions.result_revision_set.to
        )
        $actual | Should -BeExactly $expected
    }
    if ($Assertions.Contains('success_revision')) {
        foreach ($success in $successes) {
            $success.Parsed.result.revision | Should -Be ([long] $Assertions.success_revision)
        }
    }
    if ($Assertions.Contains('conflict_actual')) {
        foreach ($conflict in @(
                $Results | Where-Object {
                    -not $_.Parsed.ok -and $_.Parsed.error.category -ceq 'conflict'
                }
            )) {
            $conflict.Parsed.error.details.actual | Should -Be ([long] $Assertions.conflict_actual)
        }
    }
    if ($Assertions.Contains('not_found_count')) {
        @(
            $Results | Where-Object {
                -not $_.Parsed.ok -and $_.Parsed.error.category -ceq 'not_found'
            }
        ).Count |
            Should -Be ([int] $Assertions.not_found_count)
    }
    if ($Assertions.Contains('winner_value_matches_final')) {
        $winner = $successes | Select-Object -First 1
        $arguments = @($winner.Arguments)
        $keyIndex = [Array]::IndexOf($arguments, 'set') + 1
        $databaseIndex = [Array]::IndexOf($arguments, '--db') + 1
        $final = Invoke-TestCli -ScriptPath $ScriptPath -Arguments @(
            '--db', $arguments[$databaseIndex], 'get', $arguments[$keyIndex]
        )
        $final.ExitCode | Should -Be 0
        Assert-TestSemanticEqual `
            -Actual $final.Parsed.result.value `
            -Expected $winner.Parsed.result.value
    }
}

function Invoke-TestMultiprocessFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [string] $ParentPath
    )

    $fixture = Get-ComparativeFixture `
        -RelativePath 'scenarios/multiprocess.json' `
        -ExpectedKind 'multiprocess_scenarios' `
        -AllowedProperty @('kind', 'spec_version', 'scenarios')
    foreach ($scenario in $fixture.scenarios) {
        Assert-TestKnownProperty `
            -InputObject $scenario `
            -AllowedProperty @('id', 'database', 'setup', 'operations', 'repeat') `
            -Context "multiprocess scenario '$($scenario.id)'"
        if (@('fresh', 'sqlite_setup') -cnotcontains [string] $scenario.database) {
            throw "Unknown multiprocess scenario database kind '$($scenario.database)' in '$($scenario.id)'."
        }
        for ($repeat = 1; $repeat -le [int] $scenario.repeat; $repeat++) {
            $paths = New-TestScenarioPaths `
                -ParentPath $ParentPath `
                -Name "$($scenario.id)-$repeat"
            $cliHandles = @{}
            $lockHandles = @{}
            try {
                if ([string] $scenario.database -ceq 'sqlite_setup') {
                    Assert-TestKnownProperty `
                        -InputObject $scenario.setup `
                        -AllowedProperty @('statements') `
                        -Context "sqlite_setup in '$($scenario.id)'"
                    Invoke-TestSqliteStatements `
                        -DatabasePath $paths.Database `
                        -Statements @($scenario.setup.statements)
                }
                foreach ($operation in $scenario.operations) {
                    if ($operation.Contains('parallel')) {
                        Assert-TestKnownProperty `
                            -InputObject $operation `
                            -AllowedProperty @('parallel') `
                            -Context "multiprocess operation in '$($scenario.id)'"
                        Assert-TestKnownProperty `
                            -InputObject $operation.parallel `
                            -AllowedProperty @('actors_generator', 'assert') `
                            -Context "parallel node in '$($scenario.id)'"
                        $generator = $operation.parallel.actors_generator
                        if ([string] $generator.kind -cne 'indexed_commands') {
                            throw "Unknown actor generator '$($generator.kind)'."
                        }
                        Assert-TestKnownProperty `
                            -InputObject $generator `
                            -AllowedProperty @('kind', 'count', 'args', 'pad_width') `
                            -Context "indexed_commands actors_generator in '$($scenario.id)'"
                        $gatePath = Join-Path -Path $paths.Directory -ChildPath (
                            'gate-{0}' -f [guid]::NewGuid().ToString('N')
                        )
                        $padWidth = if ($generator.Contains('pad_width')) {
                            [int] $generator.pad_width
                        }
                        else {
                            0
                        }
                        $handles = @(
                            for ($index = 0; $index -lt [int] $generator.count; $index++) {
                                $arguments = Expand-TestArguments `
                                    -Arguments @($generator.args) `
                                    -Paths $paths `
                                    -Index $index `
                                    -PadWidth $padWidth
                                Start-TestCliProcess `
                                    -ScriptPath $ScriptPath `
                                    -Arguments $arguments `
                                    -GatePath $gatePath
                            }
                        )
                        [System.IO.File]::WriteAllText($gatePath, 'go')
                        $results = @(
                            foreach ($handle in $handles) {
                                Receive-TestCliProcess `
                                    -Handle $handle `
                                    -TimeoutMilliseconds $script:ParallelTimeoutMilliseconds
                            }
                        )
                        Assert-TestParallelResults `
                            -Results $results `
                            -Assertions $operation.parallel.assert `
                            -ScriptPath $ScriptPath
                    }
                    elseif ($operation.Contains('run_assert')) {
                        Assert-TestKnownProperty `
                            -InputObject $operation `
                            -AllowedProperty @('run_assert') `
                            -Context "multiprocess operation in '$($scenario.id)'"
                        Assert-TestKnownProperty `
                            -InputObject $operation.run_assert `
                            -AllowedProperty @('args', 'expect', 'assert') `
                            -Context "run_assert node in '$($scenario.id)'"
                        $arguments = Expand-TestArguments `
                            -Arguments @($operation.run_assert.args) `
                            -Paths $paths
                        $result = Invoke-TestCli -ScriptPath $ScriptPath -Arguments $arguments
                        Assert-TestCliExpectation `
                            -Result $result `
                            -Expectation $operation.run_assert.expect
                        if ($operation.run_assert.Contains('assert')) {
                            Assert-TestRunStructure `
                                -Result $result `
                                -Assertions $operation.run_assert.assert
                        }
                    }
                    elseif ($operation.Contains('start_lock_helper')) {
                        Assert-TestKnownProperty `
                            -InputObject $operation `
                            -AllowedProperty @('start_lock_helper') `
                            -Context "multiprocess operation in '$($scenario.id)'"
                        Assert-TestKnownProperty `
                            -InputObject $operation.start_lock_helper `
                            -AllowedProperty @('id') `
                            -Context "start_lock_helper node in '$($scenario.id)'"
                        $id = [string] $operation.start_lock_helper.id
                        $lockHandles[$id] = Start-TestLockHelper -Paths $paths -Id $id
                    }
                    elseif ($operation.Contains('start_cli')) {
                        Assert-TestKnownProperty `
                            -InputObject $operation `
                            -AllowedProperty @('start_cli') `
                            -Context "multiprocess operation in '$($scenario.id)'"
                        Assert-TestKnownProperty `
                            -InputObject $operation.start_cli `
                            -AllowedProperty @('id', 'args') `
                            -Context "start_cli node in '$($scenario.id)'"
                        $id = [string] $operation.start_cli.id
                        $arguments = Expand-TestArguments `
                            -Arguments @($operation.start_cli.args) `
                            -Paths $paths
                        $cliHandles[$id] = Start-TestCliProcess `
                            -ScriptPath $ScriptPath `
                            -Arguments $arguments
                    }
                    elseif ($operation.Contains('sleep_ms')) {
                        Assert-TestKnownProperty `
                            -InputObject $operation `
                            -AllowedProperty @('sleep_ms') `
                            -Context "multiprocess operation in '$($scenario.id)'"
                        Start-Sleep -Milliseconds ([int] $operation.sleep_ms)
                    }
                    elseif ($operation.Contains('release_lock_helper')) {
                        Assert-TestKnownProperty `
                            -InputObject $operation `
                            -AllowedProperty @('release_lock_helper') `
                            -Context "multiprocess operation in '$($scenario.id)'"
                        Assert-TestKnownProperty `
                            -InputObject $operation.release_lock_helper `
                            -AllowedProperty @('id') `
                            -Context "release_lock_helper node in '$($scenario.id)'"
                        $id = [string] $operation.release_lock_helper.id
                        Stop-TestLockHelper -Handle $lockHandles[$id]
                        $lockHandles.Remove($id)
                    }
                    elseif ($operation.Contains('await_cli')) {
                        Assert-TestKnownProperty `
                            -InputObject $operation `
                            -AllowedProperty @('await_cli') `
                            -Context "multiprocess operation in '$($scenario.id)'"
                        Assert-TestKnownProperty `
                            -InputObject $operation.await_cli `
                            -AllowedProperty @('id', 'expect', 'assert') `
                            -Context "await_cli node in '$($scenario.id)'"
                        $id = [string] $operation.await_cli.id
                        $result = Receive-TestCliProcess `
                            -Handle $cliHandles[$id] `
                            -TimeoutMilliseconds $script:ProcessTimeoutMilliseconds
                        $cliHandles.Remove($id)
                        Assert-TestCliExpectation `
                            -Result $result `
                            -Expectation $operation.await_cli.expect
                        if ($operation.await_cli.Contains('assert')) {
                            $assertions = $operation.await_cli.assert
                            Assert-TestKnownProperty `
                                -InputObject $assertions `
                                -AllowedProperty @('duration_less_than_ms', 'duration_at_least_ms') `
                                -Context "await_cli assert node in '$($scenario.id)'"
                            if ($assertions.Contains('duration_less_than_ms')) {
                                $result.DurationMilliseconds |
                                    Should -BeLessThan ([long] $assertions.duration_less_than_ms)
                            }
                            if ($assertions.Contains('duration_at_least_ms')) {
                                $result.DurationMilliseconds |
                                    Should -BeGreaterOrEqual ([long] $assertions.duration_at_least_ms)
                            }
                        }
                    }
                    else {
                        throw "Unknown multiprocess operation in '$($scenario.id)'."
                    }
                }
            }
            finally {
                foreach ($handle in @($cliHandles.Values)) {
                    if (-not $handle.Process.HasExited) {
                        $handle.Process.Kill($true)
                        $handle.Process.WaitForExit()
                    }
                    $handle.Process.Dispose()
                }
                foreach ($handle in @($lockHandles.Values)) {
                    if (-not $handle.Process.HasExited) {
                        [System.IO.File]::WriteAllText($handle.ReleasePath, 'release')
                        if (-not $handle.Process.WaitForExit(30000)) {
                            $handle.Process.Kill($true)
                            $handle.Process.WaitForExit()
                        }
                    }
                    $handle.Process.Dispose()
                }
                Assert-TestSqliteIntegrity -DatabasePath $paths.Database
                Remove-TestScenarioPaths -Paths $paths
            }
        }
    }
}
