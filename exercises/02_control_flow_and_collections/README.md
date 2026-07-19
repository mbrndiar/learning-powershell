# 🔀 Exercise 2: Control Flow and Collections

## 📋 Prerequisites

Complete [Module 2](../../lessons/02_control_flow_and_collections/README.md).
The function declarations, `[CmdletBinding()]`, validation attributes, and type
constraints are supplied infrastructure taught in Module 4. Preserve that
scaffolding and implement only the TODO bodies.

## 🧩 Tasks

- Implement `Get-ScoreLabel -Score <0..100>` to return `Pass` for scores at
  least 60 and `Retry` otherwise.
- Implement `Get-SettingValue -Setting <hashtable> -Name <string>` to return
  the named value, or `$null` when the key is absent.
- Implement `Get-FirstSeenUniqueName -Name <string[]>` to emit names in input
  order, keeping only the first value from each case-insensitive equivalence
  group.

## 📐 Contract and edge cases

Do not confuse a missing key with a falsey stored value such as `$false`, `0`,
or `''`; use hashtable membership. The score's `ValidateRange` should reject
out-of-range values before the function body. Return the setting value itself,
not a wrapper object. Build the name set with
`HashSet[string]` and `StringComparer.OrdinalIgnoreCase`; do not sort or change
the spelling of the first value. Empty name input emits nothing.

The reference checks the score boundary and both validation extremes, present
falsey settings plus an absent key, and empty/multiple/duplicate name input.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/02_control_flow_and_collections/exercises.ps1
pwsh -NoProfile -File exercises/02_control_flow_and_collections/solutions.ps1
```
