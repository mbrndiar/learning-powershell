# 🌱 Exercise 1: Basics

## 📋 Prerequisites

Complete [Module 1](../../lessons/01_basics/README.md). Work in
`exercises.ps1`; it deliberately throws until you replace the TODOs.

The function declarations, `[CmdletBinding()]`, parameter attributes, and type
constraints are supplied infrastructure. Module 4 teaches that advanced-function
syntax. In this exercise, edit only the TODO bodies.

## 🧩 Tasks

- Implement `Get-Greeting -Name <string>` to return one interpolated greeting
  string for the supplied name.
- Implement `Get-ElapsedDuration -Start <DateTimeOffset> -End <DateTimeOffset>`
  to return the `[TimeSpan]` obtained by subtracting the start instant from the
  end instant.

## 📐 Contract and edge cases

Do not change the supplied signatures. `Name` is mandatory by the starter
contract; preserve identifier-like text such as `003` in the greeting. Duration
subtraction must compare instants, so equivalent instants written with different
offsets produce a zero `TimeSpan`. An earlier end produces a negative duration.
Return values on the success stream; do not format output or use `Write-Host`.

The reference checks a normal greeting, an identifier-like name, a positive
duration, equivalent instants with different offsets, and a negative duration.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/01_basics/exercises.ps1
pwsh -NoProfile -File exercises/01_basics/solutions.ps1
```

Use the second command only to compare after attempting the starter.
