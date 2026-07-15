# 🐞 Exercise 9: Tooling and Debugging

## 📋 Prerequisites

Complete [Module 9](../../lessons/09_tooling_and_debugging/README.md). Keep
strict mode enabled while implementing and testing the starter.

## 🧩 Tasks

- Implement `Get-NormalizedName -Name <string>` to trim text, uppercase its
  first character, lowercase the remainder, and return it without `Write-Host`.
- Add Pester tests for ordinary input and whitespace-only input.

## 📐 Contract and edge cases

The parameter is mandatory, but that does not make whitespace meaningful.
Choose and test a clear terminating-error contract for whitespace-only input.
Keep the returned value on the success stream, and use analyzer feedback to
spot unused variables or unclear constructs before comparing the solution.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/09_tooling_and_debugging/exercises.ps1
pwsh -NoProfile -File exercises/09_tooling_and_debugging/solutions.ps1
```
