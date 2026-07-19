# 🔗 Exercise 3: Objects and Pipeline

## 📋 Prerequisites

Complete [Module 3](../../lessons/03_objects_and_pipeline/README.md). Keep
the supplied array parameter and ordinary `foreach` boundary in the starter.

The function declarations, `[CmdletBinding()]`, parameter attributes, and type
constraints are supplied infrastructure taught in Module 4. Edit only the TODO
bodies; pipeline parameter binding and `process` blocks are intentionally not
required by this exercise.

## 🧩 Tasks

- Implement `Get-CompletedTask -Task <PSCustomObject[]>` so it emits only task
  objects whose
  `Done` property exists, is Boolean, and is `$true`.
- Implement `Get-TaskSummary -Task <PSCustomObject[]>` to return one
  `PSCustomObject` with `Count` and `CompletedCount`.

## 📐 Contract and edge cases

`Get-CompletedTask` must preserve the original completed objects and emit
nothing for incomplete input. A missing or non-Boolean `Done` property is an
invalid contract and must throw rather than relying on truthiness. The summary
must handle an empty array predictably: both counts should be zero. Do not
format output or parse display text; iterate the array with an ordinary
`foreach` statement.

The reference checks empty and multiple input, original-object preservation,
missing and non-Boolean `Done`, and both summary counts.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/03_objects_and_pipeline/exercises.ps1
pwsh -NoProfile -File exercises/03_objects_and_pipeline/solutions.ps1
```
