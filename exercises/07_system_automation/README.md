# 🛠️ Exercise 7: System Automation

## Prerequisites

Complete [Module 7](../../lessons/07_system_automation/README.md). Test only
against a disposable file, never a system configuration path.

## Tasks

- Implement `Set-DesiredContent -LiteralPath <string> -Content <string>`.
- Read current content and write only when it differs and `ShouldProcess`
  approves.
- Return an object with `Path` and `Changed`.

## Contract and edge cases

Use literal path semantics and UTF-8. A compliant file should not be rewritten
and should report `Changed` as false. `Changed` reports whether current content
differs from desired content, so under `-WhatIf` a differing file remains
unchanged but still reports `Changed` as true. Preserve the starter's
advanced-function and ShouldProcess declarations.

## Run

```powershell
pwsh -NoProfile -File exercises/07_system_automation/exercises.ps1
pwsh -NoProfile -File exercises/07_system_automation/solutions.ps1
```
