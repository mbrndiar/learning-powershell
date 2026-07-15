# 7. System Automation and Native Commands

## Objectives

Explore providers and processes portably, handle native exit codes, construct
arguments safely, write idempotent operations, and preview changes with WhatIf.

## Concepts

Providers expose data stores as drives; `Env:` is portable while Windows-only
services are not. Cmdlets report errors through PowerShell; native executables
report an integer in `$LASTEXITCODE`. Treat arguments as explicit values, avoid
building shell command strings, and validate exit codes. State-changing public
commands should support `ShouldProcess`, `-WhatIf`, and `-Confirm`; repeated
runs should converge on the same desired state.

## Files

- `01_providers_and_processes.ps1` - portable provider and process inspection.
- `02_safe_state_change.ps1` - an idempotent, WhatIf-aware file operation.

## Run

```powershell
pwsh -NoProfile -File lessons/07_system_automation/01_providers_and_processes.ps1
pwsh -NoProfile -File lessons/07_system_automation/02_safe_state_change.ps1
```

## Common mistakes

- Checking `$LASTEXITCODE` after a cmdlet rather than a native executable.
- Writing Windows service examples that fail on other platforms.
- Making irreversible changes without `ShouldProcess`.

## Review questions

1. How do native command failures differ from cmdlet failures?
2. What makes an operation idempotent?
3. What does `-WhatIf` provide?
