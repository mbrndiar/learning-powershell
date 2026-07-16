# 🏗️ Reference project

The [TaskManager](TaskManager/README.md) project is a module-first command-line
application that combines the course patterns. Its module owns validation,
storage, state changes, and object output; its CLI only maps command-line
arguments to that public API.

It is retained as a completed reference beside the paired
[comparative and idiomatic capstones](../capstones/README.md). Keep its name and
files intact; use the capstone
[concept map](../capstones/README.md#from-taskmanager-to-the-capstones) to reuse
techniques without carrying forward its task domain or file schema.

Complete Modules 1–8 before extending it. First run its tests, then make one
small behavior change with a Pester test. The project intentionally avoids
network, database, authentication, multi-user locking, and UI concerns so the
PowerShell design remains visible.

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 6.0.0 -Force; Invoke-Pester -Path ./project/TaskManager/tests -Output Detailed'
```

Use the project README for command examples, data schema, error and
`ShouldProcess` behavior, limits, and staged extension exercises.
