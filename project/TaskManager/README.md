# ✅ Capstone Project: TaskManager

TaskManager is a small JSON-backed task manager that demonstrates a
production-minded PowerShell boundary without hiding the mechanics. It is not
a database or a multi-user service: use it to practice contracts, validation,
safe state changes, and tests.

## 🏗️ Architecture

- `TaskManager.psd1` declares metadata, PowerShell 7.4 compatibility, and the
  four exported functions.
- `TaskManager.psm1` owns storage validation and `Get-Task`, `Add-Task`,
  `Set-Task`, and `Remove-Task`. It returns objects and has no formatting or
  CLI input/output code.
- `task-manager.ps1` is a thin CLI. It validates action-specific arguments,
  imports the manifest, and forwards WhatIf/Confirm choices.
- `tests/TaskManager.Tests.ps1` uses Pester and `TestDrive:` so tests never
  use a real task store.

This separation lets code import and test the module without invoking a new
PowerShell process, while the CLI remains a convenient human-facing boundary.

## ▶️ Commands

Use a disposable explicit data path while learning:

```powershell
$data = Join-Path $PWD '.taskmanager-demo.json'
pwsh -NoProfile -File project/TaskManager/task-manager.ps1 -Action Add -Title 'Read module help' -DataPath $data
pwsh -NoProfile -File project/TaskManager/task-manager.ps1 -Action List -DataPath $data
pwsh -NoProfile -File project/TaskManager/task-manager.ps1 -Action Add -Title 'Preview only' -DataPath $data -WhatIf
pwsh -NoProfile -File project/TaskManager/task-manager.ps1 -Action Complete -Id '<task-guid>' -DataPath $data
pwsh -NoProfile -File project/TaskManager/task-manager.ps1 -Action Remove -Id '<task-guid>' -DataPath $data -Confirm
Remove-Item -LiteralPath $data -Force
```

The module can also be imported directly:

```powershell
Import-Module ./project/TaskManager/TaskManager.psd1 -Force
Add-Task -LiteralPath $data -Title 'Use object output' -Confirm:$false
Get-Task -LiteralPath $data -Done
```

## 🗃️ Storage schema and validation

The store is UTF-8 JSON whose top-level value is always an array. Every task
has this validated shape:

```json
[
  {
    "Id": "a GUID string",
    "Title": "nonblank text",
    "Done": false,
    "CreatedAt": "UTC ISO 8601 round-trip timestamp"
  }
]
```

The module rejects blank paths, directory targets, empty/non-array JSON, null
entries, missing fields, invalid GUIDs, blank/non-string titles, non-Boolean
`Done`, invalid timestamps, and duplicate IDs. It normalizes title whitespace
and persists `CreatedAt` in UTC round-trip format. Missing stores read as no
tasks; adding creates the store only after validation and approval.

Writes serialize a complete replacement to a temporary sibling file and then
use `Move-Item` to replace the target. This reduces the chance of a partially
written target and cleans up the temporary file on failure. It is not a
transaction, lock, backup strategy, or multi-process concurrency guarantee.

## 🛡️ State changes and errors

`Add-Task`, `Set-Task`, and `Remove-Task` support `ShouldProcess`.
`-WhatIf` previews but does not persist; `-Confirm` asks according to the
command's impact (`Remove-Task` is high impact). The functions output the
created, updated, or removed task only after the mutation occurs. `Get-Task`
is read-only and accepts `-Done` to filter completed records.

Validation and storage failures throw actionable exceptions. Callers can
catch them; they should not parse formatted console text. An unknown ID is an
error, rather than a silent no-op, because a caller needs to know that the
desired state was not found.

## 🧪 Testing strategy

Run the focused suite:

```powershell
Invoke-Pester -Path ./project/TaskManager/tests -Output Detailed
```

Tests cover object output, persistence, completion, removal, `-WhatIf`, path
validation, top-level array/schema checks, duplicate IDs, null entries, and
timestamp normalization. Add a behavior test before or alongside each
extension. Keep fixtures inside `TestDrive:`, use a fresh filename per test,
and never test against a personal `tasks.json`.

## ⚠️ Limitations

The CLI has only `List`, `Add`, `Complete`, and `Remove`; it has no editing,
searching, due dates, priorities, authentication, remote sync, locking,
database migration, encryption, or conflict resolution. `Move-Item` does not
make concurrent writers safe. Do not use the file store for sensitive or
multi-user production data without a suitable storage and security design.

## ✅ Learning checklist

- [ ] Import the manifest and inspect the four exported commands with `Get-Help`.
- [ ] Add a task, capture its object, and complete it using its `Id`.
- [ ] Run an add operation with `-WhatIf` and verify no store is created.
- [ ] Inspect the raw JSON and explain why it remains a top-level array.
- [ ] Read a failing test and trace the storage validation that satisfies it.
- [ ] Run the Pester suite with `-NoProfile` in a clean session.

## 🧭 Staged extension exercises

1. Add a read-only filter with validation and Pester tests.
2. Add an optional nonblank task field, update schema validation, and preserve
   backward compatibility deliberately.
3. Add a safe update action that uses `ShouldProcess` and returns the updated
   record.
4. Design a locking or database boundary before attempting concurrent writers.
5. Add structured, redacted diagnostics without changing success-stream output.

Each stage should preserve the module/CLI separation, stable JSON shape, and
behavior-oriented tests.
