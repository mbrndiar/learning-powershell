# 🏗️ Projects

The [TaskManager](TaskManager/README.md) capstone is a module-first command-line
application that combines the course patterns. Its module owns validation,
storage, state changes, and object output; its CLI only maps command-line
arguments to that public API.

Complete Modules 1–8 before extending it. First run its tests, then make one
small behavior change with a Pester test. The project intentionally avoids
network, database, authentication, multi-user locking, and UI concerns so the
PowerShell design remains visible.

```powershell
Invoke-Pester -Path ./project/TaskManager/tests -Output Detailed
```

Use the project README for command examples, data schema, error and
`ShouldProcess` behavior, limits, and staged extension exercises.
