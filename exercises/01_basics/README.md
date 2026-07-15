# 🌱 Exercise 1: Basics

## 📋 Prerequisites

Complete [Module 1](../../lessons/01_basics/README.md). Work in
`exercises.ps1`; it deliberately throws until you replace the TODOs.

## 🧩 Tasks

- Implement `Get-Greeting -Name <string>` to return one interpolated greeting
  string for the supplied name.
- Implement `Get-NumberKind -Number <int>` to return exactly `positive`,
  `negative`, or `zero`.

## 📐 Contract and edge cases

Keep both functions advanced functions and emit data on the success stream.
`Name` is mandatory by the starter contract. Test a positive, negative, and
zero value; do not return a formatted object or use `Write-Host`.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/01_basics/exercises.ps1
pwsh -NoProfile -File exercises/01_basics/solutions.ps1
```

Use the second command only to compare after attempting the starter.
