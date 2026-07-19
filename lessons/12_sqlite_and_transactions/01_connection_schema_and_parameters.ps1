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

$demoDirectory = Join-Path $PSScriptRoot (
    '.connection-demo-{0}' -f [guid]::NewGuid().ToString('N')
)
$databasePath = Join-Path $demoDirectory 'lesson.sqlite'
$connectionName = 'lesson12-connection-' + [guid]::NewGuid().ToString('N')
$connectionOpened = $false

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
CREATE TABLE lesson_setting (
    setting_key   TEXT NOT NULL PRIMARY KEY,
    setting_value TEXT NOT NULL,
    updated_utc   TEXT NOT NULL
);
'@ | Out-Null

    $unsafeLookingValue = 'O''Reilly said "hello"; DROP TABLE lesson_setting; --'
    Invoke-SqlUpdate -ConnectionName $connectionName -ErrorAction Stop -Query @'
INSERT INTO lesson_setting(setting_key, setting_value, updated_utc)
VALUES (@SettingKey, @SettingValue, @UpdatedUtc);
'@ -Parameters @{
        SettingKey   = 'welcome-message'
        SettingValue = $unsafeLookingValue
        UpdatedUtc   = [DateTimeOffset]::UtcNow.ToString(
            'o',
            [Globalization.CultureInfo]::InvariantCulture
        )
    } | Out-Null

    $row = Invoke-SqlQuery -ConnectionName $connectionName -Stream `
        -ErrorAction Stop -Query @'
SELECT
    setting_key AS SettingKey,
    setting_value AS SettingValue,
    updated_utc AS UpdatedUtc
FROM lesson_setting
WHERE setting_key = @SettingKey;
'@ -Parameters @{ SettingKey = 'welcome-message' }

    $row | Select-Object SettingKey, SettingValue, UpdatedUtc, @{
        Name = 'PowerShellType'
        Expression = { $_.GetType().FullName }
    }
}
finally {
    if ($connectionOpened) {
        Close-SqlConnection -ConnectionName $connectionName `
            -ErrorAction SilentlyContinue
    }
    Remove-LessonDatabaseFile -DatabasePath $databasePath
    Remove-Item -LiteralPath $demoDirectory -Recurse -Force `
        -ErrorAction SilentlyContinue
}
