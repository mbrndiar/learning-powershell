# 🔗 Exercise 3: Objects and Pipeline

## 📋 Prerequisites

Complete [Module 3](../../lessons/03_objects_and_pipeline/README.md). Keep
the pipeline parameter and `process` block in the starter.

## 🧩 Tasks

- Implement `Get-CompletedTask` so it emits only incoming task objects whose
  `Done` property exists, is Boolean, and is `$true`.
- Implement `Get-TaskSummary -Task <PSCustomObject[]>` to return one
  `PSCustomObject` with `Count` and `CompletedCount`.

## 📐 Contract and edge cases

`Get-CompletedTask` must preserve the original completed objects and emit
nothing for incomplete input. A missing or non-Boolean `Done` property is an
invalid contract and must throw rather than relying on truthiness. The summary
must handle an empty array predictably: both counts should be zero. Do not
format output or parse display text; test with multiple pipeline records.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/03_objects_and_pipeline/exercises.ps1
pwsh -NoProfile -File exercises/03_objects_and_pipeline/solutions.ps1
```
