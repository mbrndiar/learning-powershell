# 🗃️ Module 12: SQLite and Transactions

SQLite is a local transactional store embedded in the process that opens its
database file. It is not a remote service and it is not "just a text file":
SQLite owns the file format, journaling, locking, transaction boundaries, and
recovery rules. PowerShell supplies paths and data; SimplySql supplies named
connections and parameterized commands.

## 🎯 Objectives

- Open one disposable SQLite database with the exact SimplySql dependency.
- Treat a connection as owned state and close it in `finally`.
- Define and validate an exact application schema plus schema-version metadata.
- Bind data as SQL parameters rather than interpolating it into SQL text.
- Read query rows as PowerShell objects.
- Commit complete changes and roll back incomplete changes.
- Understand deferred transactions and immediate write-lock intent.
- Configure WAL and a busy timeout for same-host local files.
- Structure migration as validate, transform, validate, commit-or-rollback.
- Explain why real child processes are required to prove cross-process locking.

## 📋 Prerequisites

Complete Modules 1-11 and the repository
[setup](../../docs/SETUP.md). In particular, this module builds on functions,
objects, errors and `finally`, modules, Pester, and process isolation.

The repository pins SimplySql `2.2.0.106`. Every runnable file uses an exact
module requirement:

```powershell
#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }

Import-Module -Name SimplySql -RequiredVersion '2.2.0.106' -ErrorAction Stop
```

Do not substitute another SQLite module or the `sqlite3` executable for these
lessons.

## 🧠 Mental models

### SQLite is a local transactional store

A database path identifies persistent state, while a connection is a live
process resource. SQLite may create `-wal`, `-shm`, or `-journal` sidecars beside
the main database. Own all of those files as one disposable unit, and use SQLite
only on an ordinary local filesystem for this course.

SimplySql keeps open connections in module/session state. A connection name is
the handle used by `Invoke-SqlQuery`, `Invoke-SqlUpdate`, transaction commands,
and `Close-SqlConnection`. The implicit name is `default`; unique explicit names
avoid accidentally using or replacing unrelated ambient state.

```powershell
$connectionName = 'lesson-' + [guid]::NewGuid().ToString('N')
Open-SQLiteConnection -DataSource $databasePath -ConnectionName $connectionName
try {
    Invoke-SqlQuery -ConnectionName $connectionName -Query 'SELECT 1 AS Value;' -Stream
}
finally {
    Close-SqlConnection -ConnectionName $connectionName -ErrorAction SilentlyContinue
}
```

Closing disposes the provider connection and SimplySql also rolls back a
transaction it still owns. That is a safety net, not a substitute for an
explicit `Undo-SqlTransaction` in the error path.

### SQL text is code; parameters are data

Keep table and column names in fixed SQL. Bind every value with
`-Parameters`. Quoting a PowerShell variable inside SQL is not parameterization.

```powershell
$sql = @'
INSERT INTO lesson_setting(setting_key, setting_value)
VALUES (@SettingKey, @SettingValue);
'@

Invoke-SqlUpdate -ConnectionName $connectionName -Query $sql -Parameters @{
    SettingKey   = 'editor'
    SettingValue = "O'Reilly; DROP TABLE lesson_setting; --"
}
```

The punctuation remains data. Never build SQL with `"$value"`, `-f`, `+`, or
subexpressions. `Invoke-SqlQuery -Stream` emits each result row as a PowerShell
object whose selected SQL aliases become properties:

```powershell
$rows = @(Invoke-SqlQuery -ConnectionName $connectionName -Stream -Query @'
SELECT setting_key AS SettingKey, setting_value AS SettingValue
FROM lesson_setting
WHERE setting_key = @SettingKey;
'@ -Parameters @{ SettingKey = 'editor' })
```

### Schema is a contract, and its version is application data

An exact schema includes the object set, column names, declared types,
nullability, keys, checks, and metadata row—not merely "a table with similar
columns." Store the application schema version explicitly:

```sql
CREATE TABLE schema_metadata (
    singleton      INTEGER NOT NULL PRIMARY KEY CHECK (singleton = 1),
    schema_version INTEGER NOT NULL
);

INSERT INTO schema_metadata(singleton, schema_version) VALUES (1, 0);
```

Read and validate that row before deciding whether the database is current,
migratable, malformed, or from an unsupported future. `PRAGMA table_info(...)`
and `sqlite_schema` expose structural facts; do not silently repair an
unrecognized shape.

### A transaction owns an all-or-nothing decision

With SimplySql, transaction state belongs to the named connection:

```powershell
$transactionActive = $false
try {
    Start-SqlTransaction -ConnectionName $connectionName -ErrorAction Stop
    $transactionActive = $true

    Invoke-SqlUpdate -ConnectionName $connectionName -Query $sql `
        -Parameters $parameters -ErrorAction Stop | Out-Null

    Complete-SqlTransaction -ConnectionName $connectionName -ErrorAction Stop
    $transactionActive = $false
}
catch {
    if ($transactionActive) {
        Undo-SqlTransaction -ConnectionName $connectionName -ErrorAction Stop
    }
    throw
}
```

SQLite transactions are deferred by default: the write lock is requested only
when the first write occurs. `BEGIN IMMEDIATE` instead declares write intent at
the start, so lock contention is discovered before reads and transformations.
SimplySql's `Start-SqlTransaction` does not expose a transaction-mode parameter.
The second lesson therefore makes a harmless metadata `UPDATE` its first
statement. That immediately turns the SimplySql transaction into a writer
before migration validation. The comparative capstone still owns its stricter
requirement to implement behavior equivalent to `BEGIN IMMEDIATE`.

### WAL, waiting, and the filesystem boundary

Configure connection-scoped `busy_timeout` and `foreign_keys` settings on every
connection. Select and verify the database's persistent journal mode during
initialization, before contended work:

```sql
PRAGMA busy_timeout = 5000;
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
```

WAL lets readers and a writer overlap more effectively, but SQLite still permits
only one writer at a time. `busy_timeout` asks SQLite to wait for a lock rather
than fail immediately; it does not make races deterministic. WAL uses shared
memory and is supported here only for processes on the same host using a normal
local filesystem—not a network share or synchronized folder.

### Migration is validate-transform-commit-or-rollback

A safe small migration follows one transaction:

1. Establish write intent before trusting a snapshot.
2. Re-read and validate the exact old schema and version.
3. Validate old rows before destructive transformation.
4. Apply deterministic schema/data changes.
5. Set the new schema version only after transformation succeeds.
6. Validate the new shape.
7. Commit; on any failure, roll back the entire migration.

Do not catch an error, print a warning, and commit a partial shape.

### Cross-process behavior needs cross-process evidence

Two functions or two named SimplySql connections in one PowerShell session do
not prove the external contract. They share one process, one module registry,
and one scheduler. A locking or race test must start independent `pwsh`
processes, give them the same database path, coordinate a start barrier, inspect
every exit/result, and wait for all processes to close before removing SQLite
sidecars. Module 11 supplied the process-isolation model; the comparative
capstone supplies the real multiprocess fixtures.

## 📚 Files

- [`01_connection_schema_and_parameters.ps1`](01_connection_schema_and_parameters.ps1)
  opens a disposable database, creates an exact schema, inserts hostile-looking
  text safely, and returns a query row as an object.
- [`02_transactions_and_migration.ps1`](02_transactions_and_migration.ps1)
  proves rollback and performs a small validated v0-to-v1 migration.

Both scripts create a unique directory beneath their lesson directory and
remove the database plus `-wal`, `-shm`, and `-journal` sidecars in `finally`.
They never open a user database or access the network.

## ▶️ Run

From the repository root:

```powershell
pwsh -NoProfile -File lessons/12_sqlite_and_transactions/01_connection_schema_and_parameters.ps1
pwsh -NoProfile -File lessons/12_sqlite_and_transactions/02_transactions_and_migration.ps1
```

Then complete the paired
[exercise](../../exercises/12_sqlite_and_transactions/README.md).

## ⚠️ Common mistakes

- Relying on SimplySql's ambient `default` connection.
- Forgetting that connection names and transaction state are process-local.
- Interpolating values into SQL or trying to escape them manually.
- Treating `CREATE TABLE IF NOT EXISTS` as schema validation.
- Updating the schema-version row before the transformation is known to work.
- Catching a failed write without explicitly rolling back.
- Starting with reads, then discovering lock contention halfway through a
  migration.
- Assuming WAL allows multiple writers or works safely over network filesystems.
- Deleting only the main `.sqlite` file while a connection or sidecar remains.
- Using same-process tasks as proof of independent-process races.

## 🔁 Bridge to the comparative capstone

- **Milestone 1:** this module does not implement restricted JSON, exact-decimal
  handling, keys, expectations, or revision rules.
- **Milestone 2:** this module does not implement the frozen CLI grammar,
  envelopes, streams, or exit codes.
- **Milestone 3:** reuse the connection ownership, exact schema/version
  validation, migration transaction, rollback, and reopen mental models.
- **Milestone 4:** extend the transaction model with revisions, expectations,
  conflict precedence, and the capstone's exact immediate-write semantics.
- **Milestone 5:** replace demonstrations with independent-process
  initialization, migration, lock, timeout, and race evidence.

This bridge intentionally does **not** implement the capstone's exact-decimal
JSON, full CLI grammar, compare-and-set revisions, or multiprocess races. Those
remain capstone work.

## 🚧 Scope and non-goals

This is not a general SQL course, ORM, database administration guide, or
distributed-systems module. It covers one provider, small fixed schemas,
parameter binding, local transactions, one migration, and enough locking
vocabulary to begin the comparative capstone safely.

## ❓ Review questions

1. Why is a database connection different from a database path?
2. What state does a SimplySql connection name identify?
3. Why does a quote-containing value not require manual escaping when bound?
4. What schema facts must be validated in addition to a version number?
5. Which command commits, and which command rolls back, a SimplySql transaction?
6. What changes when write intent is established before migration reads?
7. What does a busy timeout guarantee, and what does it not guarantee?
8. Why is WAL limited to same-host local files in this course?
9. Why must a failed migration leave both schema and metadata at v0?
10. Why are independent `pwsh` processes necessary for locking evidence?

## 🔗 Authoritative references

- [SimplySql repository](https://github.com/mithrandyr/SimplySql)
- [Open-SQLiteConnection](https://github.com/mithrandyr/SimplySql/blob/master/Docs/Open-SQLiteConnection.md)
- [Invoke-SqlQuery](https://github.com/mithrandyr/SimplySql/blob/master/Docs/Invoke-SqlQuery.md)
- [Start-SqlTransaction](https://github.com/mithrandyr/SimplySql/blob/master/Docs/Start-SqlTransaction.md)
- [Close-SqlConnection](https://github.com/mithrandyr/SimplySql/blob/master/Docs/Close-SqlConnection.md)
- [SQLite transactions and BEGIN IMMEDIATE](https://www.sqlite.org/lang_transaction.html)
- [SQLite schema table](https://www.sqlite.org/schematab.html)
- [SQLite write-ahead logging](https://www.sqlite.org/wal.html)
- [SQLite busy timeout](https://www.sqlite.org/pragma.html#pragma_busy_timeout)
- [SQLite ALTER TABLE](https://www.sqlite.org/lang_altertable.html)
