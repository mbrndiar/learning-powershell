# 🗃️ Exercise 12: SQLite and Transactions

Build a tiny inventory store. The goal is the PowerShell/SimplySql boundary:
owned named connections, exact schema, bound values, explicit transaction
outcomes, persistence after reopen, and disposable-file cleanup.

## 📋 Prerequisites

Complete [Module 12](../../lessons/12_sqlite_and_transactions/README.md).
SimplySql `2.2.0.106` and Pester are already installed by repository setup.

## 📐 Public contract

Implement these approved Verb-Noun commands without changing their signatures:

```powershell
Initialize-InventoryStore -DatabasePath <string>
Set-InventoryItem -DatabasePath <string> -Sku <string> -Quantity <int>
Get-InventoryItem -DatabasePath <string> -Sku <string>
```

- `DatabasePath` is a caller-supplied disposable file path whose parent directory
  already exists.
- `Initialize-InventoryStore` creates/validates version 1 and returns an object
  with `DatabasePath` and `SchemaVersion`.
- `Set-InventoryItem` inserts or replaces one quantity and returns an object with
  `Sku` and `Quantity`.
- `Get-InventoryItem` returns the same object shape, or no object when absent.
- Negative quantities are invalid. Validation must occur inside an explicit
  transaction so the failure path exercises rollback.
- Every public command owns a unique SimplySql connection and closes it in
  `finally`.

This focused exercise deliberately omits `SupportsShouldProcess`: invalid input
must enter the transaction to make rollback observable. For a user-facing
automation command, return to the Module 7 pattern—validate input, call
`ShouldProcess` before side effects, and keep the transaction inside the
approved mutation path. The capstones apply that production-facing boundary.

## 🧱 Exact schema

```sql
CREATE TABLE store_metadata (
    singleton      INTEGER NOT NULL PRIMARY KEY CHECK (singleton = 1),
    schema_version INTEGER NOT NULL CHECK (schema_version = 1)
);

CREATE TABLE inventory_item (
    sku      TEXT NOT NULL PRIMARY KEY COLLATE BINARY,
    quantity INTEGER NOT NULL CHECK (quantity >= 0)
);

INSERT INTO store_metadata(singleton, schema_version) VALUES (1, 1);
```

Do not add application tables, views, triggers, or explicit indexes. Fixed SQL
may contain identifiers; `Sku` and `Quantity` must always use SimplySql
parameters. Never interpolate, format, or concatenate data into SQL text.

## 🧩 Starter milestones

Open [`exercises.ps1`](exercises.ps1) and complete the TODOs in order:

1. **Connection ownership:** validate the parent path, open a unique named
   connection, configure busy timeout/foreign keys/WAL, and close in `finally`.
2. **Initialization:** create the exact tables and singleton metadata row in one
   transaction; validate version 1 before commit.
3. **Set:** start a transaction, establish writer intent, reject a negative
   quantity, perform one parameterized upsert, commit, and roll back on error.
4. **Get:** use a parameterized query with `-Stream` and return a PowerShell
   object.
5. **Tests:** complete normal, quote/injection-like data, rollback, reopen
   persistence, exact schema, and no-interpolated-SQL cases.

The starter is parseable and its Pester cases are intentionally skipped. The
reference [`solutions.ps1`](solutions.ps1) is complete.

## 🧪 Test and cleanup rules

Use Pester's `$TestDrive` as the caller-owned parent and generate a unique
database name per test. In `AfterEach`, remove all of:

```text
store.sqlite
store.sqlite-wal
store.sqlite-shm
store.sqlite-journal
```

Tests must cover:

- normal initialize/set/get behavior;
- a SKU containing quotes and SQL-looking punctuation;
- rollback and unchanged persisted data after invalid input;
- persistence when a later command reopens the database;
- the exact tables, columns, constraints/version metadata expected here; and
- a static check that SQL is not held in expandable/interpolated strings.

No test may use a user database, network path, shell evaluation, or external
service.

## ▶️ Run

From the repository root:

```powershell
# Guided starter: tests are skipped until you implement them.
pwsh -NoProfile -File exercises/12_sqlite_and_transactions/exercises.ps1

# Complete reference solution and Pester tests.
pwsh -NoProfile -File exercises/12_sqlite_and_transactions/solutions.ps1

# Static analysis for only this module's new paths.
Invoke-ScriptAnalyzer -Path lessons/12_sqlite_and_transactions,exercises/12_sqlite_and_transactions `
    -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

## 🚧 Scope

Keep this store smaller than the comparative capstone. Do not add JSON
normalization, exact-decimal handling, CLI parsing, compare-and-set revisions,
or multiprocess races. Those are intentionally left for the capstone.
