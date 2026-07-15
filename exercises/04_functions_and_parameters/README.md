# 🧩 Exercise 4: Functions and Parameters

## 📋 Prerequisites

Complete [Module 4](../../lessons/04_functions_and_parameters/README.md).
Retain the starter's pipeline binding and `ValidateSet`.

## 🧩 Tasks

- Implement `ConvertTo-Label` to emit one object per piped `Text`, with
  `Input` and `Output` properties.
- Honor `-Case Upper` (the default) and `-Case Lower`.
- Add a call to the function using a splatted parameter hashtable.

## 📐 Contract and edge cases

`Input` preserves the received text; `Output` has the requested casing. Test
multiple piped values and each allowed case. Invalid case values should be
rejected by parameter binding. Emit objects from `process`; do not write
presentation with `Write-Host`.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/04_functions_and_parameters/exercises.ps1
pwsh -NoProfile -File exercises/04_functions_and_parameters/solutions.ps1
```
