#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }

Set-StrictMode -Version Latest
Import-Module -Name SimplySql -RequiredVersion '2.2.0.106' -ErrorAction Stop

function Remove-LessonDatabaseFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string] $DatabasePath
    )

    foreach ($path in @(
            $DatabasePath
            "$DatabasePath-wal"
            "$DatabasePath-shm"
            "$DatabasePath-journal"
        )) {
        if ($PSCmdlet.ShouldProcess($path, 'Remove SQLite lesson artifact')) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }
}

function Assert-LessonColumnContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]] $Column,

        [Parameter(Mandatory)]
        [string[]] $Expected
    )

    $actual = @($Column | ForEach-Object {
            '{0}|{1}|{2}|{3}' -f $_.name, $_.type, $_.notnull, $_.pk
        })
    if (($actual -join "`n") -cne ($Expected -join "`n")) {
        throw "Unexpected table contract. Actual: $($actual -join ', ')"
    }
}

$demoDirectory = Join-Path $PSScriptRoot (
    '.transaction-demo-{0}' -f [guid]::NewGuid().ToString('N')
)
$databasePath = Join-Path $demoDirectory 'lesson.sqlite'
$connectionName = 'lesson12-transaction-' + [guid]::NewGuid().ToString('N')
$connectionOpened = $false
$transactionActive = $false

New-Item -ItemType Directory -Path $demoDirectory -ErrorAction Stop | Out-Null

try {
    Open-SQLiteConnection -DataSource $databasePath `
        -ConnectionName $connectionName -CommandTimeout 5 -ErrorAction Stop
    $connectionOpened = $true

    Invoke-SqlUpdate -ConnectionName $connectionName `
        -Query 'PRAGMA busy_timeout = 5000;' -ErrorAction Stop | Out-Null
    Invoke-SqlUpdate -ConnectionName $connectionName `
        -Query 'PRAGMA foreign_keys = ON;' -ErrorAction Stop | Out-Null
    Invoke-SqlQuery -ConnectionName $connectionName `
        -Query 'PRAGMA journal_mode = WAL;' -Stream -ErrorAction Stop | Out-Null

    Invoke-SqlUpdate -ConnectionName $connectionName -ErrorAction Stop -Query @'
CREATE TABLE schema_metadata (
    singleton      INTEGER NOT NULL PRIMARY KEY CHECK (singleton = 1),
    schema_version INTEGER NOT NULL
);
'@ | Out-Null
    Invoke-SqlUpdate -ConnectionName $connectionName -ErrorAction Stop -Query @'
CREATE TABLE note (
    note_id     INTEGER PRIMARY KEY,
    body        TEXT NOT NULL,
    created_utc TEXT NOT NULL
);
'@ | Out-Null
    Invoke-SqlUpdate -ConnectionName $connectionName -ErrorAction Stop -Query @'
INSERT INTO schema_metadata(singleton, schema_version) VALUES (1, 0);
'@ | Out-Null

    try {
        Start-SqlTransaction -ConnectionName $connectionName -ErrorAction Stop
        $transactionActive = $true
        Invoke-SqlUpdate -ConnectionName $connectionName -ErrorAction Stop -Query @'
INSERT INTO note(body, created_utc) VALUES (@Body, @CreatedUtc);
'@ -Parameters @{
            Body       = 'This row must be rolled back.'
            CreatedUtc = [DateTimeOffset]::UtcNow.ToString(
                'o',
                [Globalization.CultureInfo]::InvariantCulture
            )
        } | Out-Null
        throw 'Simulated validation failure after the insert.'
    }
    catch {
        if ($transactionActive) {
            Undo-SqlTransaction -ConnectionName $connectionName -ErrorAction Stop
            $transactionActive = $false
        }
    }

    $countAfterRollback = Invoke-SqlQuery -ConnectionName $connectionName `
        -Query 'SELECT COUNT(*) AS NoteCount FROM note;' -Stream -ErrorAction Stop

    try {
        Start-SqlTransaction -ConnectionName $connectionName -ErrorAction Stop
        $transactionActive = $true

        # SimplySql starts a deferred transaction. Making this harmless write the
        # first statement establishes writer intent before migration validation.
        $lockedRows = Invoke-SqlUpdate -ConnectionName $connectionName `
            -ErrorAction Stop -Query @'
UPDATE schema_metadata
SET schema_version = schema_version
WHERE singleton = 1;
'@
        if ($lockedRows -ne 1) {
            throw 'The schema metadata singleton is missing.'
        }

        $version = @(Invoke-SqlQuery -ConnectionName $connectionName -Stream `
                -ErrorAction Stop -Query @'
SELECT schema_version AS SchemaVersion
FROM schema_metadata
WHERE singleton = 1;
'@)
        if ($version.Count -ne 1 -or [int] $version[0].SchemaVersion -ne 0) {
            throw 'Expected exactly one schema metadata row at version 0.'
        }

        $v0Columns = @(Invoke-SqlQuery -ConnectionName $connectionName -Stream `
                -Query 'PRAGMA table_info(''note'');' -ErrorAction Stop)
        Assert-LessonColumnContract -Column $v0Columns -Expected @(
            'note_id|INTEGER|0|1'
            'body|TEXT|1|0'
            'created_utc|TEXT|1|0'
        )

        Invoke-SqlUpdate -ConnectionName $connectionName -ErrorAction Stop -Query @'
ALTER TABLE note
ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0
CHECK (is_pinned IN (0, 1));
'@ | Out-Null

        $versionRows = Invoke-SqlUpdate -ConnectionName $connectionName `
            -ErrorAction Stop -Query @'
UPDATE schema_metadata
SET schema_version = 1
WHERE singleton = 1 AND schema_version = 0;
'@
        if ($versionRows -ne 1) {
            throw 'The version transition from 0 to 1 did not occur exactly once.'
        }

        $v1Columns = @(Invoke-SqlQuery -ConnectionName $connectionName -Stream `
                -Query 'PRAGMA table_info(''note'');' -ErrorAction Stop)
        Assert-LessonColumnContract -Column $v1Columns -Expected @(
            'note_id|INTEGER|0|1'
            'body|TEXT|1|0'
            'created_utc|TEXT|1|0'
            'is_pinned|INTEGER|1|0'
        )

        Complete-SqlTransaction -ConnectionName $connectionName -ErrorAction Stop
        $transactionActive = $false
    }
    catch {
        if ($transactionActive) {
            Undo-SqlTransaction -ConnectionName $connectionName `
                -ErrorAction SilentlyContinue
            $transactionActive = $false
        }
        throw
    }

    $migratedVersion = Invoke-SqlQuery -ConnectionName $connectionName `
        -Query 'SELECT schema_version AS SchemaVersion FROM schema_metadata;' `
        -Stream -ErrorAction Stop

    [pscustomobject]@{
        Demonstration = 'Rollback'
        Actual        = [int] $countAfterRollback.NoteCount
        Expected      = 0
    }
    [pscustomobject]@{
        Demonstration = 'Migration'
        Actual        = [int] $migratedVersion.SchemaVersion
        Expected      = 1
    }
}
finally {
    if ($transactionActive) {
        Undo-SqlTransaction -ConnectionName $connectionName `
            -ErrorAction SilentlyContinue
    }
    if ($connectionOpened) {
        Close-SqlConnection -ConnectionName $connectionName `
            -ErrorAction SilentlyContinue
    }
    Remove-LessonDatabaseFile -DatabasePath $databasePath
    Remove-Item -LiteralPath $demoDirectory -Recurse -Force `
        -ErrorAction SilentlyContinue
}
