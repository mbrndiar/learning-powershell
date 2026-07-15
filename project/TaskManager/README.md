# ✅ Capstone Project: TaskManager

TaskManager is a small module-first CLI that demonstrates the course's
production-minded patterns without hiding the mechanics.

## 🗂️ Layout

- `TaskManager.psd1` - manifest and explicit public surface.
- `TaskManager.psm1` - core data functions; no formatting commands or CLI I/O.
- `task-manager.ps1` - thin command-line boundary.
- `tests/TaskManager.Tests.ps1` - Pester tests isolated in `TestDrive:`.

## ▶️ Run

Use a project-local data path while experimenting:

```powershell
$data = Join-Path $PWD '.taskmanager-demo.json'
pwsh -NoProfile -File project/TaskManager/task-manager.ps1 -Action Add -Title 'Read module help' -DataPath $data
pwsh -NoProfile -File project/TaskManager/task-manager.ps1 -Action List -DataPath $data
pwsh -NoProfile -File project/TaskManager/task-manager.ps1 -Action Add -Title 'Preview only' -DataPath $data -WhatIf
Remove-Item -LiteralPath $data -Force
```

Run its tests:

```powershell
Invoke-Pester -Path ./project/TaskManager/tests -Output Detailed
```

## 🏗️ Design decisions

Public commands are advanced functions with validation. `Add-Task`, `Set-Task`,
and `Remove-Task` use `ShouldProcess`, so callers can request `-WhatIf` or
`-Confirm`; they emit task `PSCustomObject` values, never formatted tables.
Errors are exceptions with actionable messages so a caller can catch them.
The storage boundary rejects blank or directory paths, requires a top-level JSON
array, validates every task field, and rejects duplicate identifiers.

The store is JSON. A write first creates a temporary file alongside the target,
then replaces the target with `Move-Item`; this minimizes exposure to a
partially written target but is not a transactional, multi-process database.
For concurrent writers or durability guarantees, use an appropriate database or
locking design. Tests use Pester's `TestDrive:` rather than real user data.
