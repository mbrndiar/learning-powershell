# 🚨 Exercise 5: Errors, Streams, and Files

## 📋 Prerequisites

Complete [Module 5](../../lessons/05_errors_streams_and_files/README.md). Use
a disposable path beneath the repository or `TestDrive:` when testing.

## 🧩 Tasks

- Implement `Save-TaskJson -LiteralPath <string> -Task <PSCustomObject[]>`.
- Serialize `Task` as a stable top-level JSON array using `ConvertTo-Json
  -InputObject`.
- Write UTF-8 only when `ShouldProcess` approves and return one object with
  `Path` and `Count`.

## 📐 Contract and edge cases

An empty task collection must still serialize as an array. Treat `LiteralPath`
as literal data, not a wildcard pattern. `-WhatIf` must not create or modify
the file. Design the result object's properties from the starter comments and
verify JSON with a raw read and `ConvertFrom-Json -NoEnumerate`.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/05_errors_streams_and_files/exercises.ps1
pwsh -NoProfile -File exercises/05_errors_streams_and_files/solutions.ps1
```
