# ✅ Tasks service and client

Build one small Task application across four boundaries: a reusable PowerShell
module, two interchangeable persistence adapters, a loopback HTTP API, and a
thin command-line client. The goal is not CRUD for its own sake. The goal is to
keep one domain contract stable while each boundary owns only its own concerns.

This is the required applied project after
[Module 12: SQLite and Transactions](../../lessons/12_sqlite_and_transactions/README.md)
and before the [capstones](../../capstones/README.md).

## 🧭 Start with the contract

Read [`docs/SPEC.md`](docs/SPEC.md) before source or tests. It defines Task
validation, repository behavior, the HTTP/JSON contract, client exit codes,
safety boundaries, and acceptance criteria.

The source roots have matching public surfaces:

```text
projects/tasks/
├── starter/
│   ├── Tasks.psd1
│   ├── Tasks.psm1
│   ├── Start-TaskApi.ps1
│   └── tasks.ps1
├── solution/
│   └── (the same four files)
└── tests/
    └── Tasks.Tests.ps1
```

`Tasks.psd1` is the module **manifest**: metadata, runtime floor, exact
SimplySql dependency, root module, and exported commands. `Tasks.psm1` is the
module **implementation**: private helpers and the five public functions. Keep
the manifest's export surface small and intentional; do not put implementation
logic in the data file.

## 🏗️ Architecture

| Boundary | Owns | Must not own |
| --- | --- | --- |
| `Tasks.psm1` | Task validation, public command behavior, repository selection, SQLite and Markdown persistence | HTTP request/response objects or CLI presentation |
| `Start-TaskApi.ps1` | Loopback listener lifetime, routing, strict JSON shapes, status codes, error envelopes | Duplicate domain rules or direct SQL/file-format logic |
| `tasks.ps1` | Command-specific arguments, URI construction, `Invoke-RestMethod`, response validation, JSON output, exit codes | Module import or direct repository access |

The reference Python learning project compares three server and three client
libraries. PowerShell does not have an equivalent standard progression whose
framework comparison would improve this course. This adaptation preserves the
transferable lesson—stable core and HTTP contracts across adapters—while using
one explicit built-in `HttpListener` and the native `Invoke-RestMethod` client.
It avoids adding framework dependencies merely to imitate another ecosystem.

## 🪜 Five milestones

1. **Domain and module contract (`M1`)** — create typed Store and Task objects,
   normalize titles, define stable validation/not-found/storage errors, and
   implement create/list/get/update/delete behavior.
2. **Persistence adapters (`M2`)** — implement the exact SimplySql schema and a
   deterministic versioned Markdown checklist. Preserve monotonic IDs, use
   parameters and transactions, validate existing data, and atomically publish
   complete Markdown candidates.
3. **PowerShell command experience (`M3`)** — add parameter sets, pipeline
   property input, ordered object output, filtering, and correct `ShouldProcess`
   behavior for every mutation.
4. **Loopback HTTP adapter (`M4`)** — own one `HttpListener`, keep it bound to
   loopback, implement the documented routes, reject malformed and semantically
   invalid requests distinctly, and close listener/response resources.
5. **HTTP CLI and comparison (`M5`)** — call only the API through
   `Invoke-RestMethod`, validate responses, emit compact JSON, classify failures
   with exit codes, and verify dependency direction.

Attempt each milestone in `starter/` before reading the corresponding solution.
The TODO comments identify responsibilities, not line-by-line instructions.

## ▶️ Run the project

Install the pinned dependencies from [setup](../../docs/SETUP.md), then run from
the repository root.

Inspect the module:

```powershell
Import-Module ./projects/tasks/solution/Tasks.psd1 -Force
Get-Command -Module Tasks
Get-Help Initialize-TaskStore -Full
```

Start a disposable SQLite-backed API:

```powershell
$dataRoot = Join-Path ([IO.Path]::GetTempPath()) 'learning-powershell-tasks'
$null = New-Item -ItemType Directory -Path $dataRoot -Force

pwsh -NoProfile -File ./projects/tasks/solution/Start-TaskApi.ps1 `
    -Backend SQLite `
    -DataPath (Join-Path $dataRoot 'tasks.sqlite') `
    -UriPrefix http://127.0.0.1:8080/
```

In another terminal, choose client commands:

```powershell
pwsh -NoProfile -File ./projects/tasks/solution/tasks.ps1 `
    -Command Add -Title 'Learn project boundaries'

pwsh -NoProfile -File ./projects/tasks/solution/tasks.ps1 `
    -Command List -Completed False

pwsh -NoProfile -File ./projects/tasks/solution/tasks.ps1 `
    -Command Complete -Id 1
```

Use `-Backend Markdown -DataPath .../tasks.md` to exercise the same behavior
against the human-readable adapter. Stop the server with `Ctrl+C` before
removing its data. The server is a local learning process, not production
deployment guidance.

## 🧪 Feedback loop

```powershell
pwsh -NoProfile -File ./projects/Invoke-ProjectTests.ps1 `
    -Implementation All -Tag Smoke

pwsh -NoProfile -File ./projects/Invoke-ProjectTests.ps1 `
    -Implementation Solution -Tag M4

pwsh -NoProfile -File ./projects/Invoke-ProjectTests.ps1 `
    -Implementation Solution -Tag All

Invoke-ScriptAnalyzer -Path ./projects -Recurse `
    -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit
```

The tests use temporary storage, finite timeouts, ephemeral loopback ports, and
disposable child processes. They never call a public network service.

## ⚖️ Deliberate boundaries

- SQLite uses pinned SimplySql `2.2.0.106` on ordinary local filesystems. On
  macOS that dependency is supported by this course only on Intel/x64.
- The Markdown adapter coordinates operations only within one imported module
  instance. It does not claim cross-process locking.
- `HttpListener` handles one request at a time so routing and ownership remain
  visible. It is not a production web server.
- Authentication, users, due dates, pagination, browser UI, public binding,
  TLS termination, retries, and backend synchronization are outside scope.
