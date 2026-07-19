#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

# Guided starter for Module 12. Keep every SQL statement fixed and bind data
# through -Parameters. Complete the milestones in order; do not point this at a
# user database.

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
function Initialize-InventoryStore {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'The guided starter preserves the public signature before implementation.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $DatabasePath
    )

    # TODO M1: validate the existing parent directory and open a unique named
    # SimplySql connection configured for busy timeout, foreign keys, and WAL.
    # TODO M2: create the exact schema and singleton metadata row inside one
    # transaction, validate schema version 1, commit, and close in finally.
    # TODO M2: return DatabasePath/SchemaVersion as one object.
    throw 'TODO: implement Initialize-InventoryStore.'
}

function Set-InventoryItem {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'The guided starter preserves the public signature before implementation.'
    )]
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

    # TODO M3: open an owned named connection and start a transaction.
    # TODO M3: make a harmless metadata write first to establish writer intent.
    # TODO M3: reject Quantity < 0 after the transaction starts, then use a
    # parameterized upsert. Commit on success and roll back on every failure.
    # TODO M3: close in finally and return a Sku/Quantity object.
    throw 'TODO: implement Set-InventoryItem.'
}

function Get-InventoryItem {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'The guided starter preserves the public signature before implementation.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $DatabasePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $Sku
    )

    # TODO M4: open an owned named connection, run a parameterized SELECT with
    # -Stream, emit a Sku/Quantity object (or no object), and close in finally.
    throw 'TODO: implement Get-InventoryItem.'
}
}

Describe 'Inventory store starter' {
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

    It 'initializes and stores a normal item' -Skip {
        # TODO M5: initialize, set an item, and assert the returned/get object.
        throw 'TODO: add the normal behavior assertions.'
    }

    It 'treats quotes and SQL-looking punctuation as SKU data' -Skip {
        # TODO M5: use a quote-containing SKU and prove the table remains usable.
        throw 'TODO: add the parameter-binding assertions.'
    }

    It 'rolls back invalid input without changing the stored quantity' -Skip {
        # TODO M5: store a valid value, reject a negative value, then re-read.
        throw 'TODO: add the rollback assertions.'
    }

    It 'persists data when a later command reopens the database' -Skip {
        # TODO M5: rely on separate command-owned connections and assert reopen.
        throw 'TODO: add the reopen assertions.'
    }

    It 'creates the exact version 1 schema' -Skip {
        # TODO M5: inspect sqlite_schema, pragma_table_info, and metadata.
        throw 'TODO: add exact schema assertions.'
    }

    It 'contains no SQL in expandable strings' -Skip {
        # TODO M5: parse the function definitions and reject expandable SQL text.
        throw 'TODO: add the static SQL interpolation assertion.'
    }
}
