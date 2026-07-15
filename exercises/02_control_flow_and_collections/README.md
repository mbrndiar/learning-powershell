# 🔀 Exercise 2: Control Flow and Collections

## Prerequisites

Complete [Module 2](../../lessons/02_control_flow_and_collections/README.md).
Preserve the starter parameter validation and implement only its TODOs.

## Tasks

- Implement `Get-ScoreLabel -Score <0..100>` to return `Pass` for scores at
  least 60 and `Retry` otherwise.
- Implement `Get-SettingValue -Setting <hashtable> -Name <string>` to return
  the named value, or `$null` when the key is absent.

## Contract and edge cases

Do not confuse a missing key with a falsey stored value such as `$false`, `0`,
or `''`; use hashtable membership. The score's `ValidateRange` should reject
out-of-range values before the function body. Return the setting value itself,
not a wrapper object.

## Run

```powershell
pwsh -NoProfile -File exercises/02_control_flow_and_collections/exercises.ps1
pwsh -NoProfile -File exercises/02_control_flow_and_collections/solutions.ps1
```
