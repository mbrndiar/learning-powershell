#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }

Set-StrictMode -Version Latest

$script:TaskMarkdownLock = [object]::new()
$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false, $true)

function Get-TaskErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Task.Validation', 'Task.NotFound', 'Task.Storage')]
        [string] $ErrorId,

        [Parameter(Mandatory)]
        [string] $Message,

        [AllowNull()]
        [object] $TargetObject,

        [AllowNull()]
        [Exception] $InnerException
    )

    $exception = switch ($ErrorId) {
        'Task.Validation' {
            [System.ArgumentException]::new($Message, $InnerException)
        }
        'Task.NotFound' {
            [System.Collections.Generic.KeyNotFoundException]::new(
                $Message,
                $InnerException
            )
        }
        'Task.Storage' {
            [System.IO.InvalidDataException]::new($Message, $InnerException)
        }
    }
    $category = switch ($ErrorId) {
        'Task.Validation' {
            [System.Management.Automation.ErrorCategory]::InvalidArgument
        }
        'Task.NotFound' {
            [System.Management.Automation.ErrorCategory]::ObjectNotFound
        }
        'Task.Storage' {
            [System.Management.Automation.ErrorCategory]::InvalidData
        }
    }

    [System.Management.Automation.ErrorRecord]::new(
        $exception,
        $ErrorId,
        $category,
        $TargetObject
    )
}

function Stop-TaskOperation {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'This private helper terminates an operation and does not mutate external state.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Task.Validation', 'Task.NotFound', 'Task.Storage')]
        [string] $ErrorId,

        [Parameter(Mandatory)]
        [string] $Message,

        [AllowNull()]
        [object] $TargetObject,

        [AllowNull()]
        [Exception] $InnerException
    )

    throw (Get-TaskErrorRecord @PSBoundParameters)
}

function Resolve-TaskDataPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $DataPath
    )

    try {
        $fullPath = [System.IO.Path]::GetFullPath($DataPath)
    }
    catch {
        Stop-TaskOperation -ErrorId Task.Validation `
            -Message "The data path is invalid: '$DataPath'." `
            -TargetObject $DataPath -InnerException $_.Exception
    }

    $parentPath = [System.IO.Path]::GetDirectoryName($fullPath)
    if ([string]::IsNullOrWhiteSpace($parentPath) -or
        -not [System.IO.Directory]::Exists($parentPath)) {
        Stop-TaskOperation -ErrorId Task.Validation `
            -Message "The data parent directory does not exist: '$parentPath'." `
            -TargetObject $DataPath
    }
    if ([System.IO.Directory]::Exists($fullPath)) {
        Stop-TaskOperation -ErrorId Task.Validation `
            -Message "The data path identifies a directory: '$fullPath'." `
            -TargetObject $DataPath
    }

    $fullPath
}

function ConvertTo-TaskStoreObject {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('SQLite', 'Markdown')]
        [string] $Backend,

        [Parameter(Mandatory)]
        [string] $DataPath
    )

    $store = [pscustomobject][ordered]@{
        Backend = $Backend
        DataPath = $DataPath
    }
    $store.PSObject.TypeNames.Insert(0, 'Learning.PowerShell.TaskStore')
    $store
}

function Resolve-TaskStore {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Store
    )

    if ($Store.PSObject.TypeNames -notcontains 'Learning.PowerShell.TaskStore') {
        Stop-TaskOperation -ErrorId Task.Validation `
            -Message 'Store must be returned by Initialize-TaskStore.' `
            -TargetObject $Store
    }

    $backend = [string] $Store.Backend
    if ($backend -notin 'SQLite', 'Markdown') {
        Stop-TaskOperation -ErrorId Task.Validation `
            -Message "Unsupported task backend: '$backend'." `
            -TargetObject $Store
    }

    ConvertTo-TaskStoreObject -Backend $backend `
        -DataPath (Resolve-TaskDataPath -DataPath ([string] $Store.DataPath))
}

function ConvertTo-NormalizedTaskTitle {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Title
    )

    $normalized = $Title.Trim()
    $characterCount = [System.Globalization.StringInfo]::ParseCombiningCharacters(
        $normalized
    ).Count
    if ($characterCount -lt 1 -or $characterCount -gt 120) {
        Stop-TaskOperation -ErrorId Task.Validation `
            -Message 'Title must contain between 1 and 120 Unicode characters.' `
            -TargetObject $Title
    }
    foreach ($character in $normalized.ToCharArray()) {
        if ([char]::IsControl($character)) {
            Stop-TaskOperation -ErrorId Task.Validation `
                -Message 'Title must occupy one line and contain no control characters.' `
                -TargetObject $Title
        }
    }

    $normalized
}

function ConvertTo-TaskObject {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [long]::MaxValue)]
        [long] $Id,

        [Parameter(Mandatory)]
        [string] $Title,

        [Parameter(Mandatory)]
        [bool] $Completed
    )

    $task = [pscustomobject][ordered]@{
        Id = $Id
        Title = $Title
        Completed = $Completed
    }
    $task.PSObject.TypeNames.Insert(0, 'Learning.PowerShell.Task')
    $task
}

function Open-TaskSqliteConnection {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $DataPath
    )

    $connectionName = 'tasks-' + [guid]::NewGuid().ToString('N')
    try {
        Open-SQLiteConnection -DataSource $DataPath `
            -ConnectionName $connectionName -CommandTimeout 5 -ErrorAction Stop
        Invoke-SqlUpdate -ConnectionName $connectionName `
            -Query 'PRAGMA busy_timeout = 5000;' -ErrorAction Stop | Out-Null
        Invoke-SqlUpdate -ConnectionName $connectionName `
            -Query 'PRAGMA foreign_keys = ON;' -ErrorAction Stop | Out-Null
    }
    catch {
        Close-SqlConnection -ConnectionName $connectionName `
            -ErrorAction SilentlyContinue
        Stop-TaskOperation -ErrorId Task.Storage `
            -Message "Could not open the SQLite task store '$DataPath'." `
            -TargetObject $DataPath -InnerException $_.Exception
    }

    $connectionName
}

function Assert-TaskSqliteSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ConnectionName
    )

    try {
        $objects = @(Invoke-SqlQuery -ConnectionName $ConnectionName `
                -Stream -ErrorAction Stop -Query @'
SELECT type AS Type, name AS Name, sql AS Sql
FROM sqlite_schema
WHERE name NOT LIKE 'sqlite_%'
ORDER BY name;
'@)
        if (($objects.Name -join ',') -cne 'task,task_store_metadata' -or
            (($objects.Type | Sort-Object -Unique) -join ',') -cne 'table') {
            throw 'The application object set is not exact.'
        }

        $metadataColumns = @(Invoke-SqlQuery -ConnectionName $ConnectionName `
                -Stream -ErrorAction Stop -Query @'
SELECT name AS Name, type AS Type, "notnull" AS "NotNull", pk AS "PrimaryKey"
FROM pragma_table_info('task_store_metadata')
ORDER BY cid;
'@)
        $taskColumns = @(Invoke-SqlQuery -ConnectionName $ConnectionName `
                -Stream -ErrorAction Stop -Query @'
SELECT name AS Name, type AS Type, "notnull" AS "NotNull", pk AS "PrimaryKey"
FROM pragma_table_info('task')
ORDER BY cid;
'@)
        $metadataContract = ($metadataColumns | ForEach-Object {
                '{0}|{1}|{2}|{3}' -f
                $_.Name, $_.Type, $_.NotNull, $_.PrimaryKey
            }) -join ','
        $taskContract = ($taskColumns | ForEach-Object {
                '{0}|{1}|{2}|{3}' -f
                $_.Name, $_.Type, $_.NotNull, $_.PrimaryKey
            }) -join ','
        if ($metadataContract -cne
            'singleton|INTEGER|1|1,schema_version|INTEGER|1|0' -or
            $taskContract -cne
            'task_id|INTEGER|0|1,title|TEXT|1|0,completed|INTEGER|1|0') {
            throw 'The task-store column contract is not exact.'
        }

        $taskSql = [string] ($objects | Where-Object Name -CEQ 'task').Sql
        if ($taskSql -notmatch '(?is)\bAUTOINCREMENT\b' -or
            $taskSql -notmatch '(?is)CHECK\s*\(\s*completed\s+IN\s*\(\s*0\s*,\s*1\s*\)\s*\)') {
            throw 'The task table is missing its monotonic-ID or Boolean constraint.'
        }

        $metadata = @(Invoke-SqlQuery -ConnectionName $ConnectionName `
                -Stream -ErrorAction Stop -Query @'
SELECT singleton AS Singleton, schema_version AS SchemaVersion
FROM task_store_metadata;
'@)
        if ($metadata.Count -ne 1 -or
            [int] $metadata[0].Singleton -ne 1 -or
            [int] $metadata[0].SchemaVersion -ne 1) {
            throw 'The task store does not contain exactly one version 1 metadata row.'
        }
    }
    catch {
        Stop-TaskOperation -ErrorId Task.Storage `
            -Message 'The SQLite task-store schema is invalid.' `
            -TargetObject $ConnectionName -InnerException $_.Exception
    }
}

function Invoke-TaskSqliteMutation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ConnectionName,

        [Parameter(Mandatory)]
        [scriptblock] $Operation
    )

    $transactionActive = $false
    try {
        Start-SqlTransaction -ConnectionName $ConnectionName -ErrorAction Stop
        $transactionActive = $true

        # SimplySql starts a deferred transaction. This harmless write establishes
        # writer intent before the operation reads or changes task state.
        $metadataRows = Invoke-SqlUpdate -ConnectionName $ConnectionName `
            -ErrorAction Stop -Query @'
UPDATE task_store_metadata
SET schema_version = schema_version
WHERE singleton = 1 AND schema_version = 1;
'@
        if ($metadataRows -ne 1) {
            throw 'The task store is not initialized at schema version 1.'
        }

        $result = @(& $Operation)
        Complete-SqlTransaction -ConnectionName $ConnectionName -ErrorAction Stop
        $transactionActive = $false
        $result
    }
    catch {
        if ($transactionActive) {
            Undo-SqlTransaction -ConnectionName $ConnectionName `
                -ErrorAction SilentlyContinue
        }
        if ($_.FullyQualifiedErrorId -like 'Task.*') {
            throw
        }
        Stop-TaskOperation -ErrorId Task.Storage `
            -Message 'The SQLite task mutation failed and was rolled back.' `
            -TargetObject $ConnectionName -InnerException $_.Exception
    }
}

function ConvertFrom-TaskSqliteRow {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object] $Row
    )

    try {
        $title = [string] $Row.Title
        $normalizedTitle = ConvertTo-NormalizedTaskTitle -Title $title
        if ($normalizedTitle -cne $title -or
            [long] $Row.Id -lt 1 -or
            [int] $Row.Completed -notin 0, 1) {
            throw 'The row violates the Task domain contract.'
        }
        ConvertTo-TaskObject -Id ([long] $Row.Id) -Title $title `
            -Completed ([int] $Row.Completed -eq 1)
    }
    catch {
        Stop-TaskOperation -ErrorId Task.Storage `
            -Message 'A persisted SQLite task row is invalid.' `
            -TargetObject $Row -InnerException $_.Exception
    }
}

function Read-TaskMarkdownState {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $DataPath
    )

    if (-not [System.IO.File]::Exists($DataPath)) {
        return [pscustomobject]@{
            NextId = [long] 1
            Tasks = @()
        }
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($DataPath)
        $content = $script:Utf8NoBom.GetString($bytes)
        if (-not $content.EndsWith("`n", [System.StringComparison]::Ordinal) -or
            $content.Contains("`r", [System.StringComparison]::Ordinal)) {
            throw 'The Markdown store must use LF line endings and one final newline.'
        }

        $lines = $content.Split("`n")
        if ($lines.Count -lt 4 -or
            $lines[0] -notmatch
            '^<!-- learning-powershell-tasks:v1 next-id=(?<NextId>[1-9][0-9]*) -->$' -or
            $lines[1] -cne '# Tasks' -or
            $lines[2] -cne '' -or
            $lines[-1] -cne '') {
            throw 'The Markdown task-store header is malformed.'
        }

        $nextId = [long]::Parse(
            $Matches.NextId,
            [System.Globalization.CultureInfo]::InvariantCulture
        )
        $tasks = [System.Collections.Generic.List[object]]::new()
        $previousId = [long] 0
        for ($index = 3; $index -lt $lines.Count - 1; $index++) {
            $line = $lines[$index]
            if ($line -notmatch
                '^- \[(?<State>[ x])\] (?<Id>[1-9][0-9]*): (?<Title>.+)$') {
                throw "Malformed task row at line $($index + 1)."
            }
            $id = [long]::Parse(
                $Matches.Id,
                [System.Globalization.CultureInfo]::InvariantCulture
            )
            if ($id -le $previousId) {
                throw 'Markdown task IDs must be unique and ascending.'
            }

            $title = $Matches.Title
            try {
                $normalizedTitle = ConvertTo-NormalizedTaskTitle -Title $title
            }
            catch {
                throw "Invalid title at line $($index + 1): $($_.Exception.Message)"
            }
            if ($normalizedTitle -cne $title) {
                throw "Task titles must be stored in normalized form at line $($index + 1)."
            }

            $tasks.Add((ConvertTo-TaskObject -Id $id -Title $title `
                        -Completed ($Matches.State -ceq 'x')))
            $previousId = $id
        }
        if ($nextId -le $previousId) {
            throw 'Markdown next-id must be greater than every stored task ID.'
        }

        [pscustomobject]@{
            NextId = $nextId
            Tasks = $tasks.ToArray()
        }
    }
    catch {
        if ($_.FullyQualifiedErrorId -eq 'Task.Storage') {
            throw
        }
        Stop-TaskOperation -ErrorId Task.Storage `
            -Message "The Markdown task store '$DataPath' is malformed." `
            -TargetObject $DataPath -InnerException $_.Exception
    }
}

function Write-TaskMarkdownState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $DataPath,

        [Parameter(Mandatory)]
        [ValidateRange(1, [long]::MaxValue)]
        [long] $NextId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Task
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add(
        '<!-- learning-powershell-tasks:v1 next-id={0} -->' -f $NextId
    )
    $lines.Add('# Tasks')
    $lines.Add('')
    foreach ($item in @($Task | Sort-Object Id)) {
        $marker = if ($item.Completed) { 'x' } else { ' ' }
        $lines.Add(('- [{0}] {1}: {2}' -f $marker, $item.Id, $item.Title))
    }
    $content = ($lines -join "`n") + "`n"

    $directory = [System.IO.Path]::GetDirectoryName($DataPath)
    $fileName = [System.IO.Path]::GetFileName($DataPath)
    $temporaryPath = Join-Path -Path $directory -ChildPath (
        '.{0}.{1}.tmp' -f $fileName, [guid]::NewGuid().ToString('N')
    )
    $stream = $null
    $writer = $null
    try {
        $stream = [System.IO.FileStream]::new(
            $temporaryPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None
        )
        $writer = [System.IO.StreamWriter]::new(
            $stream,
            [System.Text.UTF8Encoding]::new($false)
        )
        $writer.Write($content)
        $writer.Flush()
        $stream.Flush($true)
        $writer.Dispose()
        $writer = $null
        $stream = $null

        [System.IO.File]::Move($temporaryPath, $DataPath, $true)
    }
    catch {
        Stop-TaskOperation -ErrorId Task.Storage `
            -Message "Could not publish the Markdown task store '$DataPath'." `
            -TargetObject $DataPath -InnerException $_.Exception
    }
    finally {
        $null = ${writer}?.Dispose()
        $null = ${stream}?.Dispose()
        [System.IO.File]::Delete($temporaryPath)
    }
}

function Invoke-WithTaskMarkdownLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $Operation
    )

    [System.Threading.Monitor]::Enter($script:TaskMarkdownLock)
    try {
        & $Operation
    }
    finally {
        [System.Threading.Monitor]::Exit($script:TaskMarkdownLock)
    }
}

function Initialize-TaskStore {
    <#
    .SYNOPSIS
    Creates or validates a task store.

    .DESCRIPTION
    Initializes one SQLite database or versioned Markdown checklist and returns
    a store descriptor consumed by the other module commands. Existing stores
    are validated rather than silently replaced or repaired.

    .PARAMETER Backend
    The persistence implementation: SQLite or Markdown.

    .PARAMETER DataPath
    The local data-file path. Its parent directory must already exist.

    .OUTPUTS
    Learning.PowerShell.TaskStore

    .EXAMPLE
    $store = Initialize-TaskStore -Backend SQLite -DataPath ./tasks.sqlite

    .EXAMPLE
    $store = Initialize-TaskStore -Backend Markdown -DataPath ./tasks.md -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('SQLite', 'Markdown')]
        [string] $Backend,

        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $DataPath
    )

    $fullPath = Resolve-TaskDataPath -DataPath $DataPath
    $storeExisted = [System.IO.File]::Exists($fullPath)
    if (-not $PSCmdlet.ShouldProcess($fullPath, "initialize $Backend task store")) {
        return
    }

    if ($Backend -eq 'SQLite') {
        $connectionName = Open-TaskSqliteConnection -DataPath $fullPath
        $transactionActive = $false
        try {
            if ($storeExisted) {
                # Validate an existing database before any schema or metadata
                # write so initialization cannot repair an unknown shape.
                Assert-TaskSqliteSchema -ConnectionName $connectionName
            }
            else {
                Invoke-SqlQuery -ConnectionName $connectionName `
                    -Query 'PRAGMA journal_mode = WAL;' -Stream -ErrorAction Stop |
                    Out-Null
                Start-SqlTransaction -ConnectionName $connectionName `
                    -ErrorAction Stop
                $transactionActive = $true
                Invoke-SqlUpdate -ConnectionName $connectionName -ErrorAction Stop `
                    -Query @'
CREATE TABLE IF NOT EXISTS task_store_metadata (
    singleton      INTEGER NOT NULL PRIMARY KEY CHECK (singleton = 1),
    schema_version INTEGER NOT NULL CHECK (schema_version = 1)
);
'@ | Out-Null
                Invoke-SqlUpdate -ConnectionName $connectionName -ErrorAction Stop `
                    -Query @'
CREATE TABLE IF NOT EXISTS task (
    task_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    title     TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1))
);
'@ | Out-Null
                Invoke-SqlUpdate -ConnectionName $connectionName -ErrorAction Stop `
                    -Query @'
INSERT OR IGNORE INTO task_store_metadata(singleton, schema_version)
VALUES (1, 1);
'@ | Out-Null
                Assert-TaskSqliteSchema -ConnectionName $connectionName
                Complete-SqlTransaction -ConnectionName $connectionName `
                    -ErrorAction Stop
                $transactionActive = $false
            }

            # Journal mode is application configuration, but only set it after
            # an existing store has passed the complete schema validation.
            Invoke-SqlQuery -ConnectionName $connectionName `
                -Query 'PRAGMA journal_mode = WAL;' -Stream -ErrorAction Stop |
                Out-Null
        }
        catch {
            if ($transactionActive) {
                Undo-SqlTransaction -ConnectionName $connectionName `
                    -ErrorAction SilentlyContinue
            }
            if ($_.FullyQualifiedErrorId -like 'Task.*') {
                throw
            }
            Stop-TaskOperation -ErrorId Task.Storage `
                -Message "Could not initialize SQLite task store '$fullPath'." `
                -TargetObject $fullPath -InnerException $_.Exception
        }
        finally {
            Close-SqlConnection -ConnectionName $connectionName `
                -ErrorAction SilentlyContinue
        }
    }
    else {
        Invoke-WithTaskMarkdownLock -Operation {
            if ([System.IO.File]::Exists($fullPath)) {
                Read-TaskMarkdownState -DataPath $fullPath | Out-Null
            }
            else {
                Write-TaskMarkdownState -DataPath $fullPath -NextId 1 -Task @()
            }
        }
    }

    ConvertTo-TaskStoreObject -Backend $Backend -DataPath $fullPath
}

function Add-Task {
    <#
    .SYNOPSIS
    Adds one incomplete task.

    .DESCRIPTION
    Validates and normalizes a title, allocates a monotonic ID, persists one
    incomplete task atomically, and returns the stored task object.

    .PARAMETER Store
    A descriptor returned by Initialize-TaskStore.

    .PARAMETER Title
    A one-line title containing 1 through 120 Unicode characters after trimming.

    .OUTPUTS
    Learning.PowerShell.Task

    .EXAMPLE
    Add-Task -Store $store -Title 'Learn PowerShell modules'

    .EXAMPLE
    Add-Task -Store $store -Title 'Preview only' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Store,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Title
    )

    $resolvedStore = Resolve-TaskStore -Store $Store
    $normalizedTitle = ConvertTo-NormalizedTaskTitle -Title $Title
    if (-not $PSCmdlet.ShouldProcess(
            $resolvedStore.DataPath,
            "add task '$normalizedTitle'"
        )) {
        return
    }

    if ($resolvedStore.Backend -eq 'SQLite') {
        $connectionName = Open-TaskSqliteConnection -DataPath $resolvedStore.DataPath
        try {
            Invoke-TaskSqliteMutation -ConnectionName $connectionName -Operation {
                Invoke-SqlUpdate -ConnectionName $connectionName `
                    -ErrorAction Stop -Query @'
INSERT INTO task(title, completed)
VALUES (@Title, 0);
'@ -Parameters @{ Title = $normalizedTitle } | Out-Null
                $row = Invoke-SqlQuery -ConnectionName $connectionName `
                    -Stream -ErrorAction Stop -Query @'
SELECT task_id AS Id, title AS Title, completed AS Completed
FROM task
WHERE task_id = last_insert_rowid();
'@
                ConvertFrom-TaskSqliteRow -Row $row
            }
        }
        finally {
            Close-SqlConnection -ConnectionName $connectionName `
                -ErrorAction SilentlyContinue
        }
        return
    }

    Invoke-WithTaskMarkdownLock -Operation {
        $state = Read-TaskMarkdownState -DataPath $resolvedStore.DataPath
        $task = ConvertTo-TaskObject -Id $state.NextId -Title $normalizedTitle `
            -Completed $false
        $tasks = @($state.Tasks) + $task
        Write-TaskMarkdownState -DataPath $resolvedStore.DataPath `
            -NextId ($state.NextId + 1) -Task $tasks
        $task
    }
}

function Get-Task {
    <#
    .SYNOPSIS
    Gets tasks from one store.

    .DESCRIPTION
    Returns one task by ID or lists tasks in ascending ID order. List mode can
    filter by an explicit completion state. A missing requested ID is a
    Task.NotFound terminating error; an empty list emits no task objects.

    .PARAMETER Store
    A descriptor returned by Initialize-TaskStore.

    .PARAMETER Id
    The positive ID of one task.

    .PARAMETER Completed
    In list mode, limits results to one completion state.

    .OUTPUTS
    Learning.PowerShell.Task

    .EXAMPLE
    Get-Task -Store $store

    .EXAMPLE
    Get-Task -Store $store -Completed $false

    .EXAMPLE
    Get-Task -Store $store -Id 1
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Store,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateRange(1, [long]::MaxValue)]
        [long] $Id,

        [Parameter(ParameterSetName = 'List')]
        [AllowNull()]
        [Nullable[bool]] $Completed
    )

    $resolvedStore = Resolve-TaskStore -Store $Store
    $hasCompletedFilter = $PSBoundParameters.ContainsKey('Completed')
    $parameterSetName = $PSCmdlet.ParameterSetName

    if ($resolvedStore.Backend -eq 'SQLite') {
        $connectionName = Open-TaskSqliteConnection -DataPath $resolvedStore.DataPath
        try {
            Assert-TaskSqliteSchema -ConnectionName $connectionName
            if ($parameterSetName -eq 'ById') {
                $rows = @(Invoke-SqlQuery -ConnectionName $connectionName `
                        -Stream -ErrorAction Stop -Query @'
SELECT task_id AS Id, title AS Title, completed AS Completed
FROM task
WHERE task_id = @Id;
'@ -Parameters @{ Id = $Id })
                if ($rows.Count -eq 0) {
                    Stop-TaskOperation -ErrorId Task.NotFound `
                        -Message "Task $Id was not found." -TargetObject $Id
                }
            }
            elseif ($hasCompletedFilter) {
                $rows = @(Invoke-SqlQuery -ConnectionName $connectionName `
                        -Stream -ErrorAction Stop -Query @'
SELECT task_id AS Id, title AS Title, completed AS Completed
FROM task
WHERE completed = @Completed
ORDER BY task_id;
'@ -Parameters @{ Completed = [int] [bool] $Completed })
            }
            else {
                $rows = @(Invoke-SqlQuery -ConnectionName $connectionName `
                        -Stream -ErrorAction Stop -Query @'
SELECT task_id AS Id, title AS Title, completed AS Completed
FROM task
ORDER BY task_id;
'@)
            }
            foreach ($row in $rows) {
                ConvertFrom-TaskSqliteRow -Row $row
            }
        }
        catch {
            if ($_.FullyQualifiedErrorId -like 'Task.*') {
                throw
            }
            Stop-TaskOperation -ErrorId Task.Storage `
                -Message 'Could not read the SQLite task store.' `
                -TargetObject $resolvedStore.DataPath -InnerException $_.Exception
        }
        finally {
            Close-SqlConnection -ConnectionName $connectionName `
                -ErrorAction SilentlyContinue
        }
        return
    }

    Invoke-WithTaskMarkdownLock -Operation {
        $state = Read-TaskMarkdownState -DataPath $resolvedStore.DataPath
        if ($parameterSetName -eq 'ById') {
            $match = @($state.Tasks | Where-Object Id -EQ $Id)
            if ($match.Count -eq 0) {
                Stop-TaskOperation -ErrorId Task.NotFound `
                    -Message "Task $Id was not found." -TargetObject $Id
            }
            $match[0]
        }
        elseif ($hasCompletedFilter) {
            $state.Tasks | Where-Object Completed -EQ ([bool] $Completed)
        }
        else {
            $state.Tasks
        }
    }
}

function Set-Task {
    <#
    .SYNOPSIS
    Updates one task.

    .DESCRIPTION
    Applies a partial title and/or completion update to an existing task. At
    least one field must be supplied. The mutation is atomic and previewable
    through PowerShell's common WhatIf and Confirm parameters.

    .PARAMETER Store
    A descriptor returned by Initialize-TaskStore.

    .PARAMETER Id
    The positive ID of the task to update. It accepts pipeline property input.

    .PARAMETER Title
    A replacement one-line title.

    .PARAMETER Completed
    The replacement completion state.

    .OUTPUTS
    Learning.PowerShell.Task

    .EXAMPLE
    Set-Task -Store $store -Id 1 -Completed $true

    .EXAMPLE
    Get-Task -Store $store -Id 1 | Set-Task -Store $store -Title 'New title'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Store,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [long]::MaxValue)]
        [long] $Id,

        [AllowEmptyString()]
        [string] $Title,

        [AllowNull()]
        [Nullable[bool]] $Completed
    )

    process {
        $hasTitle = $PSBoundParameters.ContainsKey('Title')
        $hasCompleted = $PSBoundParameters.ContainsKey('Completed')
        if (-not $hasTitle -and -not $hasCompleted) {
            Stop-TaskOperation -ErrorId Task.Validation `
                -Message 'Set-Task requires Title, Completed, or both.' `
                -TargetObject $Id
        }

        $resolvedStore = Resolve-TaskStore -Store $Store
        $normalizedTitle = if ($hasTitle) {
            ConvertTo-NormalizedTaskTitle -Title $Title
        }
        if (-not $PSCmdlet.ShouldProcess(
                "task $Id in $($resolvedStore.DataPath)",
                'update task'
            )) {
            return
        }

        if ($resolvedStore.Backend -eq 'SQLite') {
            $connectionName = Open-TaskSqliteConnection `
                -DataPath $resolvedStore.DataPath
            try {
                Invoke-TaskSqliteMutation -ConnectionName $connectionName -Operation {
                    $currentRows = @(Invoke-SqlQuery -ConnectionName $connectionName `
                            -Stream -ErrorAction Stop -Query @'
SELECT task_id AS Id, title AS Title, completed AS Completed
FROM task
WHERE task_id = @Id;
'@ -Parameters @{ Id = $Id })
                    if ($currentRows.Count -eq 0) {
                        Stop-TaskOperation -ErrorId Task.NotFound `
                            -Message "Task $Id was not found." -TargetObject $Id
                    }

                    $current = ConvertFrom-TaskSqliteRow -Row $currentRows[0]
                    $newTitle = if ($hasTitle) {
                        $normalizedTitle
                    }
                    else {
                        $current.Title
                    }
                    $newCompleted = if ($hasCompleted) {
                        [bool] $Completed
                    }
                    else {
                        $current.Completed
                    }
                    Invoke-SqlUpdate -ConnectionName $connectionName `
                        -ErrorAction Stop -Query @'
UPDATE task
SET title = @Title, completed = @Completed
WHERE task_id = @Id;
'@ -Parameters @{
                        Id = $Id
                        Title = $newTitle
                        Completed = [int] $newCompleted
                    } | Out-Null
                    ConvertTo-TaskObject -Id $Id -Title $newTitle `
                        -Completed $newCompleted
                }
            }
            finally {
                Close-SqlConnection -ConnectionName $connectionName `
                    -ErrorAction SilentlyContinue
            }
            return
        }

        Invoke-WithTaskMarkdownLock -Operation {
            $state = Read-TaskMarkdownState -DataPath $resolvedStore.DataPath
            $tasks = @($state.Tasks)
            $matchIndex = -1
            for ($index = 0; $index -lt $tasks.Count; $index++) {
                if ($tasks[$index].Id -eq $Id) {
                    $matchIndex = $index
                    break
                }
            }
            if ($matchIndex -lt 0) {
                Stop-TaskOperation -ErrorId Task.NotFound `
                    -Message "Task $Id was not found." -TargetObject $Id
            }

            $current = $tasks[$matchIndex]
            $updated = ConvertTo-TaskObject -Id $Id `
                -Title $(if ($hasTitle) { $normalizedTitle } else { $current.Title }) `
                -Completed $(if ($hasCompleted) {
                    [bool] $Completed
                }
                else {
                    $current.Completed
                })
            $tasks[$matchIndex] = $updated
            Write-TaskMarkdownState -DataPath $resolvedStore.DataPath `
                -NextId $state.NextId -Task $tasks
            $updated
        }
    }
}

function Remove-Task {
    <#
    .SYNOPSIS
    Removes one task.

    .DESCRIPTION
    Deletes one existing task without reusing its ID. The mutation is atomic and
    supports WhatIf and Confirm. Successful removal emits no task object.

    .PARAMETER Store
    A descriptor returned by Initialize-TaskStore.

    .PARAMETER Id
    The positive ID to remove. It accepts pipeline property input.

    .EXAMPLE
    Remove-Task -Store $store -Id 1 -Confirm:$false

    .EXAMPLE
    Get-Task -Store $store -Completed $true |
        Remove-Task -Store $store -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Store,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [long]::MaxValue)]
        [long] $Id
    )

    process {
        $resolvedStore = Resolve-TaskStore -Store $Store
        if (-not $PSCmdlet.ShouldProcess(
                "task $Id in $($resolvedStore.DataPath)",
                'remove task'
            )) {
            return
        }

        if ($resolvedStore.Backend -eq 'SQLite') {
            $connectionName = Open-TaskSqliteConnection `
                -DataPath $resolvedStore.DataPath
            try {
                Invoke-TaskSqliteMutation -ConnectionName $connectionName -Operation {
                    $affected = Invoke-SqlUpdate -ConnectionName $connectionName `
                        -ErrorAction Stop -Query @'
DELETE FROM task
WHERE task_id = @Id;
'@ -Parameters @{ Id = $Id }
                    if ($affected -eq 0) {
                        Stop-TaskOperation -ErrorId Task.NotFound `
                            -Message "Task $Id was not found." -TargetObject $Id
                    }
                } | Out-Null
            }
            finally {
                Close-SqlConnection -ConnectionName $connectionName `
                    -ErrorAction SilentlyContinue
            }
            return
        }

        Invoke-WithTaskMarkdownLock -Operation {
            $state = Read-TaskMarkdownState -DataPath $resolvedStore.DataPath
            $remaining = @($state.Tasks | Where-Object Id -NE $Id)
            if ($remaining.Count -eq @($state.Tasks).Count) {
                Stop-TaskOperation -ErrorId Task.NotFound `
                    -Message "Task $Id was not found." -TargetObject $Id
            }
            Write-TaskMarkdownState -DataPath $resolvedStore.DataPath `
                -NextId $state.NextId -Task $remaining
        }
    }
}

Export-ModuleMember -Function @(
    'Initialize-TaskStore'
    'Add-Task'
    'Get-Task'
    'Set-Task'
    'Remove-Task'
)
