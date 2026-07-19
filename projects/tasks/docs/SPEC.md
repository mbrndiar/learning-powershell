# Tasks applied-project specification

## Purpose

The application manages small Task records through one reusable PowerShell
module, SQLite and Markdown persistence, a loopback HTTP API, and a command-line
HTTP client. Observable behavior stays stable while storage and transport remain
replaceable adapters.

This specification is the learner contract. Private helper names and source
decomposition are not normative.

## Dependency direction

1. The core module owns domain rules and persistence.
2. The HTTP script imports and calls the core module.
3. The client calls the HTTP API and never imports the core module.
4. The core module does not know about HTTP or client presentation.

## Task model

A Task JSON response has exactly:

```json
{"id":1,"title":"Learn PowerShell","completed":false}
```

| Field | Rule |
| --- | --- |
| `id` | Positive integer allocated by the repository; starts at 1, increases monotonically, and is never reused after deletion |
| `title` | Trimmed string containing 1-120 Unicode text elements, one physical line, and no control characters |
| `completed` | Boolean; new tasks are always incomplete |

Module Task objects use the PowerShell-friendly `Id`, `Title`, and `Completed`
property names plus the type name `Learning.PowerShell.Task`. HTTP JSON uses
lower camel case. Lists are ordered by ID ascending.

## Store descriptor and module contract

`Initialize-TaskStore` returns one
`Learning.PowerShell.TaskStore` object with `Backend` and absolute `DataPath`.
Its parent directory must already exist. Existing data is validated rather than
silently replaced or repaired.

The manifest exports exactly:

```text
Initialize-TaskStore -Backend SQLite|Markdown -DataPath PATH
Add-Task             -Store STORE -Title TITLE
Get-Task             -Store STORE [-Id ID | -Completed BOOL]
Set-Task             -Store STORE -Id ID [-Title TITLE] [-Completed BOOL]
Remove-Task          -Store STORE -Id ID
```

`Set-Task` rejects an update with neither field supplied. A supplied value equal
to the current value still succeeds. `Get-Task -Id` and mutation of a missing ID
produce a not-found error. Empty list mode emits no Task objects, following
normal PowerShell pipeline semantics.

`Initialize-TaskStore`, `Add-Task`, `Set-Task`, and `Remove-Task` support
`WhatIf`/`Confirm`. A declined operation does not modify data.

### Stable module errors

| Fully qualified error ID | Meaning |
| --- | --- |
| `Task.Validation` | Invalid path, store descriptor, title, ID, filter, or update |
| `Task.NotFound` | A positive ID is absent |
| `Task.Storage` | Schema, persisted format, decoding, connection, transaction, or publication failure |

Storage errors retain diagnostic context in-process. HTTP responses sanitize
unexpected storage details.

## SQLite repository

The SQLite backend uses SimplySql `2.2.0.106`, unique named connections,
parameterized SQL, `busy_timeout=5000`, foreign keys, and WAL. Every command owns
and closes its connection.

The exact application objects are:

```sql
CREATE TABLE task_store_metadata (
    singleton      INTEGER NOT NULL PRIMARY KEY CHECK (singleton = 1),
    schema_version INTEGER NOT NULL CHECK (schema_version = 1)
);

CREATE TABLE task (
    task_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    title     TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1))
);
```

The metadata table contains exactly `(1, 1)`. `AUTOINCREMENT` prevents reuse of
deleted IDs. Each mutation uses one transaction. Because SimplySql starts a
deferred transaction, the first statement is a harmless metadata update that
establishes writer intent before reading and changing task state. Failure rolls
back the complete mutation.

The project does not require migrations, pooling, an ORM, network filesystems,
or distributed transactions.

## Markdown repository

A new Markdown store is UTF-8 without BOM, uses LF line endings, and has:

```markdown
<!-- learning-powershell-tasks:v1 next-id=3 -->
# Tasks

- [ ] 1: Learn SQLite
- [x] 2: Build an API
```

The metadata comment and heading are required. Rows use ascending unique
positive IDs; `[ ]` means incomplete and `[x]` means complete. `next-id` must be
greater than every stored ID and is not reduced after deletion.

An existing empty, malformed, non-UTF-8, unsupported-version, duplicate,
out-of-order, or non-normalized file is `Task.Storage`; it is never treated as a
new store and bad lines are never skipped.

Each mutation holds one module-instance monitor for the complete
load-modify-save operation. Saving writes and flushes a complete temporary
sibling, closes it, and then replaces the target. The format is deterministic
and ends with one newline. Cross-process Markdown locking and crash recovery
between filesystem operations are non-goals.

## HTTP contract

The server accepts one absolute `http://` loopback prefix ending in `/`. It must
not bind a public interface. JSON is UTF-8 with
`Content-Type: application/json`; request bodies are limited to 64 KiB.

| Method | Path | Request | Success |
| --- | --- | --- | --- |
| `GET` | `/health` | none | `200 {"status":"ok"}` |
| `POST` | `/tasks` | exactly `{"title":"..."}` | `201` Task |
| `GET` | `/tasks` | optional exact `completed=true|false` | `200` Task array |
| `GET` | `/tasks/{id}` | none | `200` Task |
| `PATCH` | `/tasks/{id}` | `title`, `completed`, or both | `200` Task |
| `DELETE` | `/tasks/{id}` | none | `204`, empty body |

JSON request objects reject unknown properties. `title` must be a JSON string,
`completed` must be a JSON Boolean, IDs must be positive base-10 digits, and a
PATCH body must not be empty. Trailing-slash aliases are not part of the
contract.

### HTTP errors

Every error body has:

```json
{"error":{"code":"validation_error","message":"useful message"}}
```

| Status | Code | Meaning |
| --- | --- | --- |
| `400` | `invalid_json` | Missing/unsupported JSON content type, invalid UTF-8, malformed JSON, empty body, or oversized body |
| `404` | `not_found` | Missing Task or unknown route |
| `405` | `method_not_allowed` | Unsupported method for a known route; includes `Allow` |
| `422` | `validation_error` | Valid HTTP/JSON shape with invalid ID, query, property, or domain value |
| `500` | `internal_error` | Unexpected server or storage failure |

Responses never include a traceback or raw internal storage exception.

## Client contract

`tasks.ps1` accepts:

```text
Add      -Title TITLE
List     [-Completed All|True|False]
Show     -Id ID
Update   -Id ID [-Title TITLE] [-Completed True|False]
Complete -Id ID
Remove   -Id ID
```

It also accepts absolute `-BaseUri` and `-TimeoutSec` from 1 through 300.
`Complete` sends `{"completed":true}`. The client never reads a repository
directly and never retries implicitly.

Success writes one compact JSON value to stdout:

- Add, Show, Update, and Complete write a Task;
- List writes a Task array, including `[]`;
- Remove writes `{"deleted":ID}`.

Failures write one concise line to stderr:

| Exit | Meaning |
| --- | --- |
| `0` | Success |
| `2` | Command usage error detected by the script |
| `3` | Documented API error |
| `4` | Malformed or unexpected API response |
| `5` | Connection, DNS, TLS, or timeout failure |

PowerShell parameter-binding failures that occur before script execution retain
PowerShell's own process behavior.

## Acceptance criteria

The project is complete when:

- starter and solution manifests export identical commands and signatures;
- both repositories pass the same lifecycle, restart, filtering, validation,
  monotonic-ID, and corruption behavior;
- SQL-looking titles remain data and failed mutations do not partially commit;
- Markdown output is deterministic and published from a complete sibling file;
- every mutation honors `ShouldProcess`;
- both repositories pass the same black-box HTTP lifecycle;
- invalid JSON, invalid shapes, methods, routes, IDs, filters, and missing tasks
  produce distinct documented outcomes;
- the CLI succeeds against the server and classifies API failures;
- tests use temporary storage, finite timeouts, ephemeral loopback ports, and
  guaranteed process cleanup; and
- parser, Pester 5.5/6.0, PSScriptAnalyzer, links, and course-wide regression
  checks pass.

## Non-goals

Authentication, authorization, users, due dates, priorities, tags, pagination,
search, browser UI, CORS, public deployment, TLS termination, production server
tuning, automatic retries, backend synchronization, cross-process Markdown
locking, SQLite migrations, and high-scale concurrent serving are outside this
project.
