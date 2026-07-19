#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', 'databasePath',
    Justification = 'Pester BeforeEach creates this variable for It and AfterEach blocks.'
)]
param()

Set-StrictMode -Version Latest
Import-Module -Name SimplySql -RequiredVersion '2.2.0.106' -ErrorAction Stop

# Pester separates discovery from execution. BeforeAll keeps these commands
# available whether the learner uses pwsh -File or Invoke-Pester.
BeforeAll {
function Open-InventoryStoreConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $DatabasePath
    )

    $fullPath = [IO.Path]::GetFullPath($DatabasePath)
    $parentPath = [IO.Path]::GetDirectoryName($fullPath)
    if ([string]::IsNullOrWhiteSpace($parentPath) -or
        -not (Test-Path -LiteralPath $parentPath -PathType Container)) {
        throw "The database parent directory does not exist: '$parentPath'."
    }
    if (Test-Path -LiteralPath $fullPath -PathType Container) {
        throw "The database path identifies a directory: '$fullPath'."
    }

    $connectionName = 'inventory-' + [guid]::NewGuid().ToString('N')
    try {
        Open-SQLiteConnection -DataSource $fullPath `
            -ConnectionName $connectionName -CommandTimeout 5 -ErrorAction Stop
        Invoke-SqlUpdate -ConnectionName $connectionName `
            -Query 'PRAGMA busy_timeout = 5000;' -ErrorAction Stop | Out-Null
        Invoke-SqlUpdate -ConnectionName $connectionName `
            -Query 'PRAGMA foreign_keys = ON;' -ErrorAction Stop | Out-Null
        Invoke-SqlQuery -ConnectionName $connectionName `
            -Query 'PRAGMA journal_mode = WAL;' -Stream -ErrorAction Stop | Out-Null
    }
    catch {
        Close-SqlConnection -ConnectionName $connectionName `
            -ErrorAction SilentlyContinue
        throw
    }

    [pscustomobject]@{
        Name         = $connectionName
        DatabasePath = $fullPath
    }
}

function Assert-InventoryStoreSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $ConnectionName
    )

    $objects = @(Invoke-SqlQuery -ConnectionName $ConnectionName `
            -Stream -ErrorAction Stop -Query @'
SELECT type AS Type, name AS Name, sql AS Sql
FROM sqlite_schema
WHERE name NOT LIKE 'sqlite_%'
ORDER BY name;
'@)
    if (($objects.Name -join ',') -cne 'inventory_item,store_metadata' -or
        (($objects.Type | Sort-Object -Unique) -join ',') -cne 'table') {
        throw 'The inventory store application object set is not exact.'
    }

    $metadataColumns = @(Invoke-SqlQuery -ConnectionName $ConnectionName `
            -Stream -ErrorAction Stop -Query @'
SELECT
    name AS Name,
    type AS Type,
    "notnull" AS "NotNull",
    pk AS "PrimaryKey"
FROM pragma_table_info('store_metadata')
ORDER BY cid;
'@)
    $inventoryColumns = @(Invoke-SqlQuery -ConnectionName $ConnectionName `
            -Stream -ErrorAction Stop -Query @'
SELECT
    name AS Name,
    type AS Type,
    "notnull" AS "NotNull",
    pk AS "PrimaryKey"
FROM pragma_table_info('inventory_item')
ORDER BY cid;
'@)
    $metadataContract = ($metadataColumns | ForEach-Object {
            '{0}|{1}|{2}|{3}' -f
            $_.Name, $_.Type, $_.NotNull, $_.PrimaryKey
        }) -join ','
    $inventoryContract = ($inventoryColumns | ForEach-Object {
            '{0}|{1}|{2}|{3}' -f
            $_.Name, $_.Type, $_.NotNull, $_.PrimaryKey
        }) -join ','
    if ($metadataContract -cne 'singleton|INTEGER|1|1,schema_version|INTEGER|1|0' -or
        $inventoryContract -cne 'sku|TEXT|1|1,quantity|INTEGER|1|0') {
        throw 'The inventory store column contract is not exact.'
    }

    $metadataSql = [string] ($objects |
            Where-Object Name -CEQ 'store_metadata').Sql
    $inventorySql = [string] ($objects |
            Where-Object Name -CEQ 'inventory_item').Sql
    $metadataPattern = @'
(?is)^\s*CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?store_metadata\s*\(\s*singleton\s+INTEGER\s+NOT\s+NULL\s+PRIMARY\s+KEY\s+CHECK\s*\(\s*singleton\s*=\s*1\s*\)\s*,\s*schema_version\s+INTEGER\s+NOT\s+NULL\s+CHECK\s*\(\s*schema_version\s*=\s*1\s*\)\s*\)\s*;?\s*$
'@
    $inventoryPattern = @'
(?is)^\s*CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?inventory_item\s*\(\s*sku\s+TEXT\s+NOT\s+NULL\s+PRIMARY\s+KEY\s+COLLATE\s+BINARY\s*,\s*quantity\s+INTEGER\s+NOT\s+NULL\s+CHECK\s*\(\s*quantity\s*>=\s*0\s*\)\s*\)\s*;?\s*$
'@
    if ($metadataSql -notmatch $metadataPattern -or
        $inventorySql -notmatch $inventoryPattern) {
        throw 'The inventory store constraints or collation are not exact.'
    }

    $metadata = @(Invoke-SqlQuery -ConnectionName $ConnectionName `
            -Stream -ErrorAction Stop -Query @'
SELECT singleton AS Singleton, schema_version AS SchemaVersion
FROM store_metadata;
'@)
    if ($metadata.Count -ne 1 -or
        [int] $metadata[0].Singleton -ne 1 -or
        [int] $metadata[0].SchemaVersion -ne 1) {
        throw 'The inventory store does not contain exactly one version 1 metadata row.'
    }
}

function Initialize-InventoryStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $DatabasePath
    )

    $connection = Open-InventoryStoreConnection -DatabasePath $DatabasePath
    $transactionActive = $false
    try {
        Start-SqlTransaction -ConnectionName $connection.Name -ErrorAction Stop
        $transactionActive = $true

        Invoke-SqlUpdate -ConnectionName $connection.Name -ErrorAction Stop -Query @'
CREATE TABLE IF NOT EXISTS store_metadata (
    singleton      INTEGER NOT NULL PRIMARY KEY CHECK (singleton = 1),
    schema_version INTEGER NOT NULL CHECK (schema_version = 1)
);
'@ | Out-Null
        Invoke-SqlUpdate -ConnectionName $connection.Name -ErrorAction Stop -Query @'
CREATE TABLE IF NOT EXISTS inventory_item (
    sku      TEXT NOT NULL PRIMARY KEY COLLATE BINARY,
    quantity INTEGER NOT NULL CHECK (quantity >= 0)
);
'@ | Out-Null
        Invoke-SqlUpdate -ConnectionName $connection.Name -ErrorAction Stop -Query @'
INSERT OR IGNORE INTO store_metadata(singleton, schema_version)
VALUES (1, 1);
'@ | Out-Null

        Assert-InventoryStoreSchema -ConnectionName $connection.Name

        Complete-SqlTransaction -ConnectionName $connection.Name -ErrorAction Stop
        $transactionActive = $false

        [pscustomobject]@{
            DatabasePath  = $connection.DatabasePath
            SchemaVersion = 1
        }
    }
    catch {
        if ($transactionActive) {
            Undo-SqlTransaction -ConnectionName $connection.Name `
                -ErrorAction SilentlyContinue
        }
        throw
    }
    finally {
        Close-SqlConnection -ConnectionName $connection.Name `
            -ErrorAction SilentlyContinue
    }
}

function Set-InventoryItem {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'The exercise focuses on explicit SQLite commit and rollback behavior.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $DatabasePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $Sku,

        [Parameter(Mandatory)]
        [int] $Quantity
    )

    $connection = Open-InventoryStoreConnection -DatabasePath $DatabasePath
    $transactionActive = $false
    try {
        Start-SqlTransaction -ConnectionName $connection.Name -ErrorAction Stop
        $transactionActive = $true

        $metadataRows = Invoke-SqlUpdate -ConnectionName $connection.Name `
            -ErrorAction Stop -Query @'
UPDATE store_metadata
SET schema_version = schema_version
WHERE singleton = 1 AND schema_version = 1;
'@
        if ($metadataRows -ne 1) {
            throw 'The inventory store is not initialized at schema version 1.'
        }
        if ($Quantity -lt 0) {
            throw 'Quantity must be zero or greater.'
        }

        Invoke-SqlUpdate -ConnectionName $connection.Name -ErrorAction Stop -Query @'
INSERT INTO inventory_item(sku, quantity)
VALUES (@Sku, @Quantity)
ON CONFLICT(sku) DO UPDATE SET quantity = excluded.quantity;
'@ -Parameters @{
            Sku      = $Sku
            Quantity = $Quantity
        } | Out-Null

        Complete-SqlTransaction -ConnectionName $connection.Name -ErrorAction Stop
        $transactionActive = $false

        [pscustomobject]@{
            Sku      = $Sku
            Quantity = $Quantity
        }
    }
    catch {
        if ($transactionActive) {
            Undo-SqlTransaction -ConnectionName $connection.Name `
                -ErrorAction SilentlyContinue
        }
        throw
    }
    finally {
        Close-SqlConnection -ConnectionName $connection.Name `
            -ErrorAction SilentlyContinue
    }
}

function Get-InventoryItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $DatabasePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $Sku
    )

    $connection = Open-InventoryStoreConnection -DatabasePath $DatabasePath
    try {
        $rows = @(Invoke-SqlQuery -ConnectionName $connection.Name -Stream `
                -ErrorAction Stop -Query @'
SELECT sku AS Sku, quantity AS Quantity
FROM inventory_item
WHERE sku = @Sku;
'@ -Parameters @{ Sku = $Sku })

        foreach ($row in $rows) {
            [pscustomobject]@{
                Sku      = [string] $row.Sku
                Quantity = [int] $row.Quantity
            }
        }
    }
    finally {
        Close-SqlConnection -ConnectionName $connection.Name `
            -ErrorAction SilentlyContinue
    }
}
}

Describe 'Inventory store solution' {
    BeforeEach {
        $databasePath = Join-Path $TestDrive (
            'inventory-{0}.sqlite' -f [guid]::NewGuid().ToString('N')
        )
    }

    AfterEach {
        foreach ($path in @(
                $databasePath
                "$databasePath-wal"
                "$databasePath-shm"
                "$databasePath-journal"
            )) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }

    It 'initializes and stores a normal item' {
        $initialized = Initialize-InventoryStore -DatabasePath $databasePath
        $stored = Set-InventoryItem -DatabasePath $databasePath -Sku 'paper' -Quantity 12
        $read = Get-InventoryItem -DatabasePath $databasePath -Sku 'paper'

        $initialized.SchemaVersion | Should -Be 1
        $initialized.DatabasePath | Should -Be ([IO.Path]::GetFullPath($databasePath))
        $stored.Sku | Should -BeExactly 'paper'
        $stored.Quantity | Should -Be 12
        $read.Sku | Should -BeExactly 'paper'
        $read.Quantity | Should -Be 12
    }

    It 'treats quotes and SQL-looking punctuation as SKU data' {
        $hostileSku = "part'; DROP TABLE inventory_item; --"
        Initialize-InventoryStore -DatabasePath $databasePath | Out-Null

        Set-InventoryItem -DatabasePath $databasePath `
            -Sku $hostileSku -Quantity 4 | Out-Null
        Set-InventoryItem -DatabasePath $databasePath `
            -Sku 'still-present' -Quantity 2 | Out-Null

        (Get-InventoryItem -DatabasePath $databasePath -Sku $hostileSku).Quantity |
            Should -Be 4
        (Get-InventoryItem -DatabasePath $databasePath -Sku 'still-present').Quantity |
            Should -Be 2
    }

    It 'rolls back invalid input without changing the stored quantity' {
        Initialize-InventoryStore -DatabasePath $databasePath | Out-Null
        Set-InventoryItem -DatabasePath $databasePath -Sku 'cable' -Quantity 8 |
            Out-Null

        {
            Set-InventoryItem -DatabasePath $databasePath -Sku 'cable' -Quantity -1
        } | Should -Throw '*zero or greater*'

        (Get-InventoryItem -DatabasePath $databasePath -Sku 'cable').Quantity |
            Should -Be 8
    }

    It 'persists data when a later command reopens the database' {
        Initialize-InventoryStore -DatabasePath $databasePath | Out-Null
        Set-InventoryItem -DatabasePath $databasePath -Sku 'adapter' -Quantity 3 |
            Out-Null

        $reopened = Get-InventoryItem -DatabasePath $databasePath -Sku 'adapter'
        $reopened | Should -Not -BeNullOrEmpty
        $reopened.Quantity | Should -Be 3
    }

    It 'creates the exact version 1 schema' {
        Initialize-InventoryStore -DatabasePath $databasePath | Out-Null
        $connectionName = 'schema-test-' + [guid]::NewGuid().ToString('N')
        try {
            Open-SQLiteConnection -DataSource $databasePath `
                -ConnectionName $connectionName -ErrorAction Stop

            $objects = @(Invoke-SqlQuery -ConnectionName $connectionName `
                    -Stream -ErrorAction Stop -Query @'
SELECT type AS Type, name AS Name, sql AS Sql
FROM sqlite_schema
WHERE name NOT LIKE 'sqlite_%'
ORDER BY name;
'@)
            ($objects.Name -join ',') | Should -BeExactly 'inventory_item,store_metadata'
            ($objects.Type | Select-Object -Unique) | Should -BeExactly 'table'

            $metadataColumns = @(Invoke-SqlQuery -ConnectionName $connectionName `
                    -Stream -ErrorAction Stop -Query @'
SELECT
    name AS Name,
    type AS Type,
    "notnull" AS "NotNull",
    pk AS "PrimaryKey"
FROM pragma_table_info('store_metadata')
ORDER BY cid;
'@)
            $inventoryColumns = @(Invoke-SqlQuery -ConnectionName $connectionName `
                    -Stream -ErrorAction Stop -Query @'
SELECT
    name AS Name,
    type AS Type,
    "notnull" AS "NotNull",
    pk AS "PrimaryKey"
FROM pragma_table_info('inventory_item')
ORDER BY cid;
'@)

            (($metadataColumns | ForEach-Object {
                            '{0}|{1}|{2}|{3}' -f
                            $_.Name, $_.Type, $_.NotNull, $_.PrimaryKey
                        }) -join ',') |
                Should -BeExactly 'singleton|INTEGER|1|1,schema_version|INTEGER|1|0'
            (($inventoryColumns | ForEach-Object {
                            '{0}|{1}|{2}|{3}' -f
                            $_.Name, $_.Type, $_.NotNull, $_.PrimaryKey
                        }) -join ',') |
                Should -BeExactly 'sku|TEXT|1|1,quantity|INTEGER|1|0'

            $metadataSql = [string] ($objects |
                    Where-Object Name -CEQ 'store_metadata').Sql
            $inventorySql = [string] ($objects |
                    Where-Object Name -CEQ 'inventory_item').Sql
            $metadataSql | Should -Match @'
(?is)^\s*CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?store_metadata\s*\(\s*singleton\s+INTEGER\s+NOT\s+NULL\s+PRIMARY\s+KEY\s+CHECK\s*\(\s*singleton\s*=\s*1\s*\)\s*,\s*schema_version\s+INTEGER\s+NOT\s+NULL\s+CHECK\s*\(\s*schema_version\s*=\s*1\s*\)\s*\)\s*;?\s*$
'@
            $inventorySql | Should -Match @'
(?is)^\s*CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?inventory_item\s*\(\s*sku\s+TEXT\s+NOT\s+NULL\s+PRIMARY\s+KEY\s+COLLATE\s+BINARY\s*,\s*quantity\s+INTEGER\s+NOT\s+NULL\s+CHECK\s*\(\s*quantity\s*>=\s*0\s*\)\s*\)\s*;?\s*$
'@

            $metadata = Invoke-SqlQuery -ConnectionName $connectionName `
                -Stream -ErrorAction Stop -Query @'
SELECT singleton AS Singleton, schema_version AS SchemaVersion
FROM store_metadata;
'@
            [int] $metadata.Singleton | Should -Be 1
            [int] $metadata.SchemaVersion | Should -Be 1
        }
        finally {
            Close-SqlConnection -ConnectionName $connectionName `
                -ErrorAction SilentlyContinue
        }
    }

    It 'contains no SQL in expandable strings' {
        $commandNames = @(
            'Open-InventoryStoreConnection'
            'Assert-InventoryStoreSchema'
            'Initialize-InventoryStore'
            'Set-InventoryItem'
            'Get-InventoryItem'
        )
        $expandableSql = @($commandNames | ForEach-Object {
                $functionAst = (
                    Get-Command -Name $_ -CommandType Function -ErrorAction Stop
                ).ScriptBlock.Ast
                $functionAst.FindAll({
                        param($node)
                        $node -is [Management.Automation.Language.ExpandableStringExpressionAst] -and
                        $node.Value -match (
                            '(?i)\b(CREATE|INSERT|SELECT|UPDATE|DELETE|ALTER|PRAGMA)\b'
                        )
                    }, $true)
            })
        $expandableSql.Count | Should -Be 0
    }
}
