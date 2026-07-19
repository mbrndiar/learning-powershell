#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }

BeforeAll {
    $script:projectRoot = Split-Path -Path $PSScriptRoot -Parent
    $script:implementation = if (
        [string]::IsNullOrWhiteSpace($env:TASKS_IMPLEMENTATION)
    ) {
        'solution'
    }
    else {
        $env:TASKS_IMPLEMENTATION.ToLowerInvariant()
    }
    if ($script:implementation -notin 'starter', 'solution') {
        throw 'TASKS_IMPLEMENTATION must be starter or solution.'
    }

    $script:implementationRoot = Join-Path -Path $script:projectRoot `
        -ChildPath $script:implementation
    $script:modulePath = Join-Path -Path $script:implementationRoot `
        -ChildPath 'Tasks.psd1'
    $script:serverPath = Join-Path -Path $script:implementationRoot `
        -ChildPath 'Start-TaskApi.ps1'
    $script:clientPath = Join-Path -Path $script:implementationRoot `
        -ChildPath 'tasks.ps1'
    $script:projectRunnerPath = Join-Path -Path (
        Split-Path -Path $script:projectRoot -Parent
    ) -ChildPath 'Invoke-ProjectTests.ps1'
    $script:pwshPath = (
        Get-Command -Name pwsh -CommandType Application -ErrorAction Stop |
            Select-Object -First 1
    ).Source
    $script:exportedFunctions = @(
        'Initialize-TaskStore'
        'Add-Task'
        'Get-Task'
        'Set-Task'
        'Remove-Task'
    )

    function Import-SelectedTasksModule {
        Remove-Module -Name Tasks -Force -ErrorAction SilentlyContinue
        Import-Module -Name $script:modulePath -Force -ErrorAction Stop
    }

    function Get-CaughtTaskError {
        param(
            [Parameter(Mandatory)]
            [scriptblock] $Operation
        )

        try {
            & $Operation
        }
        catch {
            return $_
        }
        throw 'Expected the operation to fail.'
    }

    function Get-TestTaskStorePath {
        param(
            [Parameter(Mandatory)]
            [ValidateSet('SQLite', 'Markdown')]
            [string] $Backend,

            [Parameter(Mandatory)]
            [string] $Name
        )

        $extension = if ($Backend -eq 'SQLite') { 'sqlite' } else { 'md' }
        Join-Path -Path $TestDrive -ChildPath "$Name.$extension"
    }

    function Remove-TestTaskStore {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseShouldProcessForStateChangingFunctions', '',
            Justification = 'Test cleanup is confined to TestDrive and must be unconditional.'
        )]
        param(
            [Parameter(Mandatory)]
            [string] $DataPath
        )

        foreach ($path in @(
                $DataPath
                "$DataPath-wal"
                "$DataPath-shm"
                "$DataPath-journal"
            )) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }

    function Get-TestModuleSignature {
        param(
            [Parameter(Mandatory)]
            [string] $ModulePath
        )

        Remove-Module -Name Tasks -Force -ErrorAction SilentlyContinue
        Import-Module -Name $ModulePath -Force -ErrorAction Stop
        try {
            foreach ($commandName in $script:exportedFunctions) {
                $syntax = Get-Command -Name $commandName -Module Tasks -Syntax
                '{0}:{1}' -f $commandName, ($syntax -replace '\s+', ' ').Trim()
            }
        }
        finally {
            Remove-Module -Name Tasks -Force -ErrorAction SilentlyContinue
        }
    }

    function Get-TestFreePort {
        $listener = [System.Net.Sockets.TcpListener]::new(
            [System.Net.IPAddress]::Loopback,
            0
        )
        try {
            $listener.Start()
            ([System.Net.IPEndPoint] $listener.LocalEndpoint).Port
        }
        finally {
            $listener.Stop()
        }
    }

    function Start-TestTaskApi {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseShouldProcessForStateChangingFunctions', '',
            Justification = 'This test helper owns a disposable child process and returns its handle.'
        )]
        param(
            [Parameter(Mandatory)]
            [ValidateSet('SQLite', 'Markdown')]
            [string] $Backend,

            [Parameter(Mandatory)]
            [string] $DataPath
        )

        $port = Get-TestFreePort
        $baseUri = [uri] "http://127.0.0.1:$port/"
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $script:pwshPath
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in @(
                '-NoProfile'
                '-File'
                $script:serverPath
                '-Backend'
                $Backend
                '-DataPath'
                $DataPath
                '-UriPrefix'
                $baseUri.AbsoluteUri
            )) {
            $startInfo.ArgumentList.Add($argument)
        }

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        $null = $process.Start()
        for ($attempt = 0; $attempt -lt 50; $attempt++) {
            if ($process.HasExited) {
                $standardOutput = $process.StandardOutput.ReadToEnd()
                $standardError = $process.StandardError.ReadToEnd()
                $process.Dispose()
                throw "Task API exited early.`n$standardOutput`n$standardError"
            }
            try {
                $health = Invoke-RestMethod -Uri ([uri] "$baseUri`health") `
                    -TimeoutSec 1 -ErrorAction Stop
                if ($health.status -ceq 'ok') {
                    return [pscustomobject]@{
                        Process = $process
                        BaseUri = $baseUri
                    }
                }
            }
            catch {
                Start-Sleep -Milliseconds 100
            }
        }

        if (-not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $output = $process.StandardOutput.ReadToEnd()
        $errorOutput = $process.StandardError.ReadToEnd()
        $process.Dispose()
        throw "Task API did not become ready.`n$output`n$errorOutput"
    }

    function Stop-TestTaskApi {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseShouldProcessForStateChangingFunctions', '',
            Justification = 'This test helper unconditionally cleans up its disposable child process.'
        )]
        param(
            [Parameter(Mandatory)]
            [object] $Server
        )

        try {
            if (-not $Server.Process.HasExited) {
                $Server.Process.Kill($true)
                $Server.Process.WaitForExit()
            }
        }
        finally {
            $Server.Process.Dispose()
        }
    }

    function Start-TestPowerShellScript {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
            'PSUseShouldProcessForStateChangingFunctions', '',
            Justification = 'This test helper starts one explicitly selected disposable pwsh process.'
        )]
        param(
            [Parameter(Mandatory)]
            [string] $ScriptPath,

            [Parameter(Mandatory)]
            [string[]] $Argument
        )

        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $script:pwshPath
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.ArgumentList.Add('-NoProfile')
        $startInfo.ArgumentList.Add('-File')
        $startInfo.ArgumentList.Add($ScriptPath)
        foreach ($item in $Argument) {
            $startInfo.ArgumentList.Add($item)
        }

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        $null = $process.Start()
        [pscustomobject]@{
            Process = $process
            StandardOutput = $process.StandardOutput.ReadToEndAsync()
            StandardError = $process.StandardError.ReadToEndAsync()
        }
    }

    function Complete-TestPowerShellScript {
        param(
            [Parameter(Mandatory)]
            [object] $Execution
        )

        try {
            $Execution.Process.WaitForExit()
            [pscustomobject]@{
                ExitCode = $Execution.Process.ExitCode
                StandardOutput =
                    $Execution.StandardOutput.GetAwaiter().GetResult().Trim()
                StandardError =
                    $Execution.StandardError.GetAwaiter().GetResult().Trim()
            }
        }
        finally {
            $Execution.Process.Dispose()
        }
    }

    function Invoke-TestPowerShellScript {
        param(
            [Parameter(Mandatory)]
            [string] $ScriptPath,

            [Parameter(Mandatory)]
            [string[]] $Argument
        )

        $execution = Start-TestPowerShellScript `
            -ScriptPath $ScriptPath -Argument $Argument
        Complete-TestPowerShellScript -Execution $execution
    }

    function Invoke-TestTaskClient {
        param(
            [Parameter(Mandatory)]
            [string[]] $Argument
        )

        Invoke-TestPowerShellScript -ScriptPath $script:clientPath `
            -Argument $Argument
    }

    function Invoke-TestRawHttpRequest {
        param(
            [Parameter(Mandatory)]
            [uri] $BaseUri,

            [Parameter(Mandatory)]
            [byte[]] $RequestBytes
        )

        $client = [System.Net.Sockets.TcpClient]::new()
        $stream = $null
        $reader = $null
        try {
            $client.ReceiveTimeout = 3000
            $client.SendTimeout = 3000
            $client.Connect($BaseUri.Host, $BaseUri.Port)
            $stream = $client.GetStream()
            $stream.Write($RequestBytes, 0, $RequestBytes.Length)
            $stream.Flush()
            $reader = [System.IO.StreamReader]::new(
                $stream,
                [System.Text.Encoding]::ASCII,
                $false,
                1024,
                $true
            )
            $reader.ReadToEnd()
        }
        finally {
            $null = ${reader}?.Dispose()
            $null = ${stream}?.Dispose()
            $client.Dispose()
        }
    }

    function Invoke-TestTaskClientResponse {
        param(
            [Parameter(Mandatory)]
            [ValidateSet(200, 500)]
            [int] $StatusCode,

            [Parameter(Mandatory)]
            [string] $Body
        )

        $listener = [System.Net.Sockets.TcpListener]::new(
            [System.Net.IPAddress]::Loopback,
            0
        )
        $connection = $null
        $stream = $null
        $reader = $null
        $execution = $null
        try {
            $listener.Start()
            $port = ([System.Net.IPEndPoint] $listener.LocalEndpoint).Port
            $baseUri = "http://127.0.0.1:$port/"
            $execution = Start-TestPowerShellScript `
                -ScriptPath $script:clientPath -Argument @(
                    '-Command'
                    'Show'
                    '-Id'
                    '1'
                    '-BaseUri'
                    $baseUri
                )

            $connection = $listener.AcceptTcpClient()
            $stream = $connection.GetStream()
            $reader = [System.IO.StreamReader]::new(
                $stream,
                [System.Text.Encoding]::ASCII,
                $false,
                1024,
                $true
            )
            while (-not [string]::IsNullOrEmpty($reader.ReadLine())) {
            }

            $reason = if ($StatusCode -eq 200) {
                'OK'
            }
            else {
                'Internal Server Error'
            }
            $bodyBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Body)
            $headers = "HTTP/1.1 $StatusCode $reason`r`n" +
                "Content-Type: application/json`r`n" +
                "Content-Length: $($bodyBytes.Length)`r`n" +
                "Connection: close`r`n`r`n"
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($bodyBytes, 0, $bodyBytes.Length)
            $stream.Flush()
            $connection.Close()

            Complete-TestPowerShellScript -Execution $execution
            $execution = $null
        }
        finally {
            $null = ${reader}?.Dispose()
            $null = ${stream}?.Dispose()
            $null = ${connection}?.Dispose()
            $listener.Stop()
            if ($null -ne $execution) {
                if (-not $execution.Process.HasExited) {
                    $execution.Process.Kill($true)
                    $execution.Process.WaitForExit()
                }
                $execution.Process.Dispose()
            }
        }
    }
}

AfterAll {
    Remove-Module -Name Tasks -Force -ErrorAction SilentlyContinue
}

Describe 'Tasks applied-project boundary' -Tag Smoke {
    It 'imports the selected manifest with the exact dependency and exports' {
        $manifest = Test-ModuleManifest -Path $script:modulePath -ErrorAction Stop
        $manifest.PowerShellVersion | Should -BeGreaterOrEqual ([version] '7.4')
        $dependency = @($manifest.RequiredModules |
                Where-Object Name -EQ 'SimplySql')
        $dependency.Count | Should -Be 1
        $dependency[0].Version | Should -Be ([version] '2.2.0.106')

        $module = Import-Module -Name $script:modulePath -Force `
            -PassThru -ErrorAction Stop
        $actual = @($module.ExportedFunctions.Keys | Sort-Object)
        $expected = @($script:exportedFunctions | Sort-Object)
        ($actual -join '|') | Should -BeExactly ($expected -join '|')
    }

    It 'keeps starter and solution command signatures identical' {
        $starterPath = Join-Path -Path $script:projectRoot `
            -ChildPath 'starter/Tasks.psd1'
        $solutionPath = Join-Path -Path $script:projectRoot `
            -ChildPath 'solution/Tasks.psd1'
        $starter = @(Get-TestModuleSignature -ModulePath $starterPath)
        $solution = @(Get-TestModuleSignature -ModulePath $solutionPath)
        ($starter -join "`n") | Should -BeExactly ($solution -join "`n")
    }

    It 'publishes help for every exported command' {
        Import-SelectedTasksModule
        foreach ($commandName in $script:exportedFunctions) {
            $help = Get-Help -Name $commandName -Full
            $help.Description.Text | Should -Not -BeNullOrEmpty
            @($help.Examples.Example).Count | Should -BeGreaterThan 0
        }
    }

    It 'parses every script in the selected implementation' {
        foreach ($path in Get-ChildItem -LiteralPath $script:implementationRoot `
                -File) {
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
        Import-SelectedTasksModule
        $dataPath = Get-TestTaskStorePath -Backend Markdown -Name 'smoke'
        if ($script:implementation -eq 'starter') {
            $caught = Get-CaughtTaskError {
                Initialize-TaskStore -Backend Markdown -DataPath $dataPath `
                    -Confirm:$false
            }
            $caught.FullyQualifiedErrorId |
                Should -Match '^TasksProjectNotImplemented,'
        }
        else {
            $store = Initialize-TaskStore -Backend Markdown -DataPath $dataPath `
                -Confirm:$false
            $task = Add-Task -Store $store -Title 'Project smoke' -Confirm:$false
            $task.Id | Should -Be 1
            $task.Title | Should -BeExactly 'Project smoke'
        }
    }

    It 'returns a nonzero process exit when a selected suite fails' {
        $result = Invoke-TestPowerShellScript `
            -ScriptPath $script:projectRunnerPath -Argument @(
                '-Implementation'
                'Starter'
                '-Tag'
                'M1'
            )
        $result.ExitCode | Should -Not -Be 0
        $result.StandardError | Should -Match 'test run reported'
    }
}

Describe 'Milestone 1: domain and repository contract' -Tag M1 {
    BeforeEach {
        Import-SelectedTasksModule
    }

    It 'runs one CRUD contract against both repositories' {
        foreach ($backend in 'SQLite', 'Markdown') {
            $dataPath = Get-TestTaskStorePath -Backend $backend `
                -Name "crud-$backend"
            try {
                $store = Initialize-TaskStore -Backend $backend `
                    -DataPath $dataPath -Confirm:$false
                $first = Add-Task -Store $store -Title '  Learn contracts  ' `
                    -Confirm:$false
                $second = Add-Task -Store $store -Title 'Test adapters' `
                    -Confirm:$false

                $first.Id | Should -Be 1
                $first.Title | Should -BeExactly 'Learn contracts'
                $first.Completed | Should -BeFalse
                $second.Id | Should -Be 2
                (@(Get-Task -Store $store).Id -join ',') |
                    Should -BeExactly '1,2'

                $updated = Set-Task -Store $store -Id $first.Id `
                    -Title 'Learn repository contracts' -Completed $true `
                    -Confirm:$false
                $updated.Completed | Should -BeTrue
                (Get-Task -Store $store -Id $first.Id).Title |
                    Should -BeExactly 'Learn repository contracts'

                Remove-Task -Store $store -Id $second.Id -Confirm:$false
                @(Get-Task -Store $store).Count | Should -Be 1
                $missing = Get-CaughtTaskError {
                    Get-Task -Store $store -Id $second.Id
                }
                $missing.FullyQualifiedErrorId | Should -BeExactly 'Task.NotFound'
            }
            finally {
                Remove-TestTaskStore -DataPath $dataPath
            }
        }
    }

    It 'rejects empty, multiline, control-character, and overlong titles' {
        $dataPath = Get-TestTaskStorePath -Backend Markdown -Name 'titles'
        $store = Initialize-TaskStore -Backend Markdown -DataPath $dataPath `
            -Confirm:$false
        foreach ($title in @('', '   ', "two`nlines", "tab`tvalue", ('x' * 121))) {
            $caught = Get-CaughtTaskError {
                Add-Task -Store $store -Title $title -Confirm:$false
            }
            $caught.FullyQualifiedErrorId | Should -BeExactly 'Task.Validation'
        }
        @(Get-Task -Store $store).Count | Should -Be 0
    }

    It 'requires at least one field for a partial update' {
        $dataPath = Get-TestTaskStorePath -Backend Markdown -Name 'empty-update'
        $store = Initialize-TaskStore -Backend Markdown -DataPath $dataPath `
            -Confirm:$false
        $task = Add-Task -Store $store -Title 'Keep me' -Confirm:$false
        $caught = Get-CaughtTaskError {
            Set-Task -Store $store -Id $task.Id -Confirm:$false
        }
        $caught.FullyQualifiedErrorId | Should -BeExactly 'Task.Validation'
    }
}

Describe 'Milestone 2: persistence behavior' -Tag M2 {
    BeforeEach {
        Import-SelectedTasksModule
    }

    It 'persists state and never reuses a deleted ID in either repository' {
        foreach ($backend in 'SQLite', 'Markdown') {
            $dataPath = Get-TestTaskStorePath -Backend $backend `
                -Name "restart-$backend"
            try {
                $store = Initialize-TaskStore -Backend $backend `
                    -DataPath $dataPath -Confirm:$false
                $first = Add-Task -Store $store -Title 'First' -Confirm:$false
                Remove-Task -Store $store -Id $first.Id -Confirm:$false

                $reopened = Initialize-TaskStore -Backend $backend `
                    -DataPath $dataPath -Confirm:$false
                $second = Add-Task -Store $reopened -Title 'Second' `
                    -Confirm:$false
                $second.Id | Should -Be 2
                (Get-Task -Store $reopened -Id 2).Title |
                    Should -BeExactly 'Second'
            }
            finally {
                Remove-TestTaskStore -DataPath $dataPath
            }
        }
    }

    It 'writes a deterministic versioned Markdown checklist' {
        $dataPath = Get-TestTaskStorePath -Backend Markdown -Name 'format'
        $store = Initialize-TaskStore -Backend Markdown -DataPath $dataPath `
            -Confirm:$false
        $first = Add-Task -Store $store -Title 'Learn SQLite' -Confirm:$false
        Add-Task -Store $store -Title 'Build an API' -Confirm:$false | Out-Null
        Set-Task -Store $store -Id $first.Id -Completed $true `
            -Confirm:$false | Out-Null

        [System.IO.File]::ReadAllText($dataPath) | Should -BeExactly @'
<!-- learning-powershell-tasks:v1 next-id=3 -->
# Tasks

- [x] 1: Learn SQLite
- [ ] 2: Build an API

'@
    }

    It 'rejects malformed Markdown instead of guessing or repairing it' {
        $dataPath = Get-TestTaskStorePath -Backend Markdown -Name 'malformed'
        [System.IO.File]::WriteAllText(
            $dataPath,
            "<!-- learning-powershell-tasks:v1 next-id=1 -->`n# Tasks`n`n- [ ] 2: Broken`n",
            [System.Text.UTF8Encoding]::new($false)
        )
        $caught = Get-CaughtTaskError {
            Initialize-TaskStore -Backend Markdown -DataPath $dataPath `
                -Confirm:$false
        }
        $caught.FullyQualifiedErrorId | Should -BeExactly 'Task.Storage'
        [System.IO.File]::ReadAllText($dataPath) |
            Should -Match 'next-id=1'
    }

    It 'treats SQL-looking punctuation as SQLite title data' {
        $dataPath = Get-TestTaskStorePath -Backend SQLite -Name 'parameters'
        try {
            $store = Initialize-TaskStore -Backend SQLite -DataPath $dataPath `
                -Confirm:$false
            $title = "O'Reilly'); DROP TABLE task; --"
            $task = Add-Task -Store $store -Title $title -Confirm:$false
            (Get-Task -Store $store -Id $task.Id).Title |
                Should -BeExactly $title
            Add-Task -Store $store -Title 'Table still exists' `
                -Confirm:$false | Out-Null
            @(Get-Task -Store $store).Count | Should -Be 2
        }
        finally {
            Remove-TestTaskStore -DataPath $dataPath
        }
    }

    It 'reports a persisted SQLite row that violates the Task contract' {
        $dataPath = Get-TestTaskStorePath -Backend SQLite -Name 'corrupt-row'
        $connectionName = 'test-' + [guid]::NewGuid().ToString('N')
        try {
            $store = Initialize-TaskStore -Backend SQLite -DataPath $dataPath `
                -Confirm:$false
            $task = Add-Task -Store $store -Title 'Valid first' -Confirm:$false
            Open-SQLiteConnection -DataSource $dataPath `
                -ConnectionName $connectionName -ErrorAction Stop
            Invoke-SqlUpdate -ConnectionName $connectionName `
                -Query 'UPDATE task SET title = @Title WHERE task_id = @Id;' `
                -Parameters @{ Title = ''; Id = $task.Id } -ErrorAction Stop |
                Out-Null
            Close-SqlConnection -ConnectionName $connectionName

            $caught = Get-CaughtTaskError {
                Get-Task -Store $store -Id $task.Id
            }
            $caught.FullyQualifiedErrorId | Should -BeExactly 'Task.Storage'
        }
        finally {
            Close-SqlConnection -ConnectionName $connectionName `
                -ErrorAction SilentlyContinue
            Remove-TestTaskStore -DataPath $dataPath
        }
    }

    It 'rejects an incomplete existing SQLite store without repairing it' {
        $dataPath = Get-TestTaskStorePath -Backend SQLite -Name 'incomplete'
        $connectionName = 'test-' + [guid]::NewGuid().ToString('N')
        try {
            Open-SQLiteConnection -DataSource $dataPath `
                -ConnectionName $connectionName -ErrorAction Stop
            Invoke-SqlUpdate -ConnectionName $connectionName -ErrorAction Stop `
                -Query @'
CREATE TABLE task (
    task_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    title     TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1))
);
'@ | Out-Null
            Close-SqlConnection -ConnectionName $connectionName

            $caught = Get-CaughtTaskError {
                Initialize-TaskStore -Backend SQLite -DataPath $dataPath `
                    -Confirm:$false
            }
            $caught.FullyQualifiedErrorId | Should -BeExactly 'Task.Storage'

            Open-SQLiteConnection -DataSource $dataPath `
                -ConnectionName $connectionName -ErrorAction Stop
            $objects = @(Invoke-SqlQuery -ConnectionName $connectionName `
                    -Stream -ErrorAction Stop -Query @'
SELECT name AS Name
FROM sqlite_schema
WHERE name NOT LIKE 'sqlite_%'
ORDER BY name;
'@)
            ($objects.Name -join ',') | Should -BeExactly 'task'
        }
        finally {
            Close-SqlConnection -ConnectionName $connectionName `
                -ErrorAction SilentlyContinue
            Remove-TestTaskStore -DataPath $dataPath
        }
    }
}

Describe 'Milestone 3: PowerShell command behavior' -Tag M3 {
    BeforeEach {
        Import-SelectedTasksModule
    }

    It 'supports WhatIf without changing state' {
        $dataPath = Get-TestTaskStorePath -Backend Markdown -Name 'whatif'
        $store = Initialize-TaskStore -Backend Markdown -DataPath $dataPath `
            -Confirm:$false
        Add-Task -Store $store -Title 'Not written' -WhatIf
        @(Get-Task -Store $store).Count | Should -Be 0

        $task = Add-Task -Store $store -Title 'Written' -Confirm:$false
        Set-Task -Store $store -Id $task.Id -Completed $true -WhatIf
        (Get-Task -Store $store -Id $task.Id).Completed | Should -BeFalse
        Remove-Task -Store $store -Id $task.Id -WhatIf
        (Get-Task -Store $store -Id $task.Id).Id | Should -Be $task.Id
    }

    It 'filters by explicit Boolean state and preserves ID order' {
        $dataPath = Get-TestTaskStorePath -Backend Markdown -Name 'filter'
        $store = Initialize-TaskStore -Backend Markdown -DataPath $dataPath `
            -Confirm:$false
        $first = Add-Task -Store $store -Title 'First' -Confirm:$false
        Add-Task -Store $store -Title 'Second' -Confirm:$false | Out-Null
        Set-Task -Store $store -Id $first.Id -Completed $true `
            -Confirm:$false | Out-Null

        (@(Get-Task -Store $store -Completed $true).Id -join ',') |
            Should -BeExactly '1'
        (@(Get-Task -Store $store -Completed $false).Id -join ',') |
            Should -BeExactly '2'
    }

    It 'accepts task IDs from pipeline properties for updates and removals' {
        $dataPath = Get-TestTaskStorePath -Backend Markdown -Name 'pipeline'
        $store = Initialize-TaskStore -Backend Markdown -DataPath $dataPath `
            -Confirm:$false
        Add-Task -Store $store -Title 'Pipeline task' -Confirm:$false |
            Set-Task -Store $store -Completed $true -Confirm:$false |
            Remove-Task -Store $store -Confirm:$false
        @(Get-Task -Store $store).Count | Should -Be 0
    }
}

Describe 'Milestone 4: loopback HTTP adapter' -Tag M4 {
    It 'runs the normal HTTP contract against both repositories' {
        foreach ($backend in 'SQLite', 'Markdown') {
            $dataPath = Get-TestTaskStorePath -Backend $backend `
                -Name "http-$backend"
            $server = $null
            try {
                $server = Start-TestTaskApi -Backend $backend -DataPath $dataPath
                $empty = Invoke-WebRequest `
                    -Uri ([uri] "$($server.BaseUri)tasks") -TimeoutSec 3
                $empty.StatusCode | Should -Be 200
                $empty.Content | Should -BeExactly '[]'

                $created = Invoke-RestMethod -Uri ([uri] "$($server.BaseUri)tasks") `
                    -Method Post -ContentType 'application/json' `
                    -Body '{"title":"  Learn HTTP  "}' -TimeoutSec 3
                $created.id | Should -Be 1
                $created.title | Should -BeExactly 'Learn HTTP'
                $created.completed | Should -BeFalse

                $updated = Invoke-RestMethod `
                    -Uri ([uri] "$($server.BaseUri)tasks/1") `
                    -Method Patch -ContentType 'application/json' `
                    -Body '{"completed":true}' -TimeoutSec 3
                $updated.completed | Should -BeTrue

                $response = Invoke-RestMethod `
                    -Uri ([uri] "$($server.BaseUri)tasks?completed=true") `
                    -TimeoutSec 3
                $listed = @($response)
                $listed.Count | Should -Be 1
                $listed[0].id | Should -Be 1

                Invoke-RestMethod -Uri ([uri] "$($server.BaseUri)tasks/1") `
                    -Method Delete -TimeoutSec 3 | Out-Null
                $missing = Invoke-WebRequest `
                    -Uri ([uri] "$($server.BaseUri)tasks/1") `
                    -SkipHttpErrorCheck -TimeoutSec 3
                $missing.StatusCode | Should -Be 404
                (ConvertFrom-Json $missing.Content).error.code |
                    Should -BeExactly 'not_found'
            }
            finally {
                if ($null -ne $server) {
                    Stop-TestTaskApi -Server $server
                }
                Remove-TestTaskStore -DataPath $dataPath
            }
        }
    }

    It 'distinguishes invalid JSON, semantic validation, methods, and routes' {
        $dataPath = Get-TestTaskStorePath -Backend Markdown -Name 'http-errors'
        $server = $null
        try {
            $server = Start-TestTaskApi -Backend Markdown -DataPath $dataPath
            $invalidJson = Invoke-WebRequest `
                -Uri ([uri] "$($server.BaseUri)tasks") -Method Post `
                -ContentType 'application/json' -Body '{' `
                -SkipHttpErrorCheck -TimeoutSec 3
            $invalidJson.StatusCode | Should -Be 400
            (ConvertFrom-Json $invalidJson.Content).error.code |
                Should -BeExactly 'invalid_json'

            $invalidShape = Invoke-WebRequest `
                -Uri ([uri] "$($server.BaseUri)tasks") -Method Post `
                -ContentType 'application/json' -Body '{"done":true}' `
                -SkipHttpErrorCheck -TimeoutSec 3
            $invalidShape.StatusCode | Should -Be 422
            (ConvertFrom-Json $invalidShape.Content).error.code |
                Should -BeExactly 'validation_error'

            $unsupportedType = Invoke-WebRequest `
                -Uri ([uri] "$($server.BaseUri)tasks") -Method Post `
                -ContentType 'application/json-patch+json' `
                -Body '{"title":"Wrong media type"}' `
                -SkipHttpErrorCheck -TimeoutSec 3
            $unsupportedType.StatusCode | Should -Be 400
            (ConvertFrom-Json $unsupportedType.Content).error.code |
                Should -BeExactly 'invalid_json'

            $method = Invoke-WebRequest `
                -Uri ([uri] "$($server.BaseUri)tasks") -Method Put `
                -SkipHttpErrorCheck -TimeoutSec 3
            $method.StatusCode | Should -Be 405
            $method.Headers.Allow -join ',' | Should -Match 'GET'

            $route = Invoke-WebRequest `
                -Uri ([uri] "$($server.BaseUri)unknown") `
                -SkipHttpErrorCheck -TimeoutSec 3
            $route.StatusCode | Should -Be 404
        }
        finally {
            if ($null -ne $server) {
                Stop-TestTaskApi -Server $server
            }
            Remove-TestTaskStore -DataPath $dataPath
        }
    }

    It 'keeps serving after HttpListener rejects a request before the handler writes' {
        $dataPath = Get-TestTaskStorePath -Backend Markdown -Name 'http-survival'
        $server = $null
        try {
            $server = Start-TestTaskApi -Backend Markdown -DataPath $dataPath
            $request = "PUT /tasks HTTP/1.1`r`n" +
                "Host: $($server.BaseUri.Authority)`r`n" +
                "Connection: close`r`n`r`n"
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($request)
            $rawResponse = Invoke-TestRawHttpRequest `
                -BaseUri $server.BaseUri -RequestBytes $bytes
            $rawResponse | Should -Match 'HTTP/1\.[01] 411'

            $health = Invoke-RestMethod `
                -Uri ([uri] "$($server.BaseUri)health") -TimeoutSec 3
            $health.status | Should -BeExactly 'ok'
        }
        finally {
            if ($null -ne $server) {
                Stop-TestTaskApi -Server $server
            }
            Remove-TestTaskStore -DataPath $dataPath
        }
    }

    It 'rejects an oversized chunked body without buffering the complete request' {
        $dataPath = Get-TestTaskStorePath -Backend Markdown -Name 'http-chunked'
        $server = $null
        try {
            $server = Start-TestTaskApi -Backend Markdown -DataPath $dataPath
            $body = 'x' * 65537
            $request = "POST /tasks HTTP/1.1`r`n" +
                "Host: $($server.BaseUri.Authority)`r`n" +
                "Content-Type: application/json`r`n" +
                "Transfer-Encoding: chunked`r`n" +
                "Connection: close`r`n`r`n" +
                "$($body.Length.ToString('X'))`r`n$body`r`n" +
                "0`r`n`r`n"
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($request)
            $rawResponse = Invoke-TestRawHttpRequest `
                -BaseUri $server.BaseUri -RequestBytes $bytes
            $rawResponse | Should -Match 'HTTP/1\.[01] 400'
            $rawResponse | Should -Match '"code":"invalid_json"'

            $health = Invoke-RestMethod `
                -Uri ([uri] "$($server.BaseUri)health") -TimeoutSec 3
            $health.status | Should -BeExactly 'ok'
        }
        finally {
            if ($null -ne $server) {
                Stop-TestTaskApi -Server $server
            }
            Remove-TestTaskStore -DataPath $dataPath
        }
    }
}

Describe 'Milestone 5: HTTP CLI and architecture' -Tag M5 {
    It 'drives the API through the CLI without direct repository access' {
        $dataPath = Get-TestTaskStorePath -Backend SQLite -Name 'client'
        $server = $null
        try {
            $server = Start-TestTaskApi -Backend SQLite -DataPath $dataPath
            $baseArguments = @('-BaseUri', $server.BaseUri.AbsoluteUri)

            $added = Invoke-TestTaskClient -Argument (
                @('-Command', 'Add', '-Title', 'Use CLI') + $baseArguments
            )
            $added.ExitCode | Should -Be 0
            (ConvertFrom-Json $added.StandardOutput).id | Should -Be 1

            $completed = Invoke-TestTaskClient -Argument (
                @('-Command', 'Complete', '-Id', '1') + $baseArguments
            )
            $completed.ExitCode | Should -Be 0
            (ConvertFrom-Json $completed.StandardOutput).completed |
                Should -BeTrue

            $listed = Invoke-TestTaskClient -Argument (
                @('-Command', 'List', '-Completed', 'True') + $baseArguments
            )
            $listed.ExitCode | Should -Be 0
            @((ConvertFrom-Json $listed.StandardOutput)).Count | Should -Be 1

            $removed = Invoke-TestTaskClient -Argument (
                @('-Command', 'Remove', '-Id', '1') + $baseArguments
            )
            $removed.ExitCode | Should -Be 0
            (ConvertFrom-Json $removed.StandardOutput).deleted | Should -Be 1

            $missing = Invoke-TestTaskClient -Argument (
                @('-Command', 'Show', '-Id', '1') + $baseArguments
            )
            $missing.ExitCode | Should -Be 3
            $missing.StandardError | Should -Match '^not_found:'
        }
        finally {
            if ($null -ne $server) {
                Stop-TestTaskApi -Server $server
            }
            Remove-TestTaskStore -DataPath $dataPath
        }
    }

    It 'keeps core, inbound adapter, and outbound client dependencies directed' {
        $moduleText = Get-Content -LiteralPath (
            Join-Path $script:implementationRoot 'Tasks.psm1'
        ) -Raw
        $serverText = Get-Content -LiteralPath $script:serverPath -Raw
        $clientText = Get-Content -LiteralPath $script:clientPath -Raw

        $moduleText | Should -Not -Match 'HttpListener|Invoke-RestMethod'
        $serverText | Should -Match 'Import-Module'
        $serverText | Should -Match 'Initialize-TaskStore'
        $clientText | Should -Match 'Invoke-RestMethod'
        $clientText | Should -Not -Match 'Initialize-TaskStore|Open-SQLiteConnection'
    }

    It 'rejects command-specific extra arguments before making a request' {
        $result = Invoke-TestTaskClient -Argument @(
            '-Command'
            'Add'
            '-Title'
            'Too many arguments'
            '-Id'
            '1'
        )
        $result.ExitCode | Should -Be 2
        $result.StandardError | Should -Match '^usage_error:'
    }

    It 'classifies malformed success and error responses as response errors' {
        $missingTask = Invoke-TestTaskClientResponse -StatusCode 200 -Body '{}'
        $missingTask.ExitCode | Should -Be 4
        $missingTask.StandardError | Should -Match '^response_error:'

        $invalidTitle = Invoke-TestTaskClientResponse -StatusCode 200 -Body (
            '{"id":1,"title":"","completed":false}'
        )
        $invalidTitle.ExitCode | Should -Be 4
        $invalidTitle.StandardError | Should -Match '^response_error:'

        $invalidError = Invoke-TestTaskClientResponse -StatusCode 500 -Body '{}'
        $invalidError.ExitCode | Should -Be 4
        $invalidError.StandardError | Should -Match '^response_error:'
    }
}
