# 📦 Exercise 6: Modules and Reuse

## 📋 Prerequisites

Complete [Module 6](../../lessons/06_modules_and_reuse/README.md). This
exercise uses a scriptblock as a controlled dependency boundary.

## 🧩 Tasks

- Implement `Get-OpenItem -Source <scriptblock>`.
- Invoke `Source` and emit only returned objects whose `Done` property is
  present, Boolean, and `$false`.

## 📐 Contract and edge cases

Do not call an external service or invent global state. The source can emit
zero, one, or many objects; preserve the original open objects and emit none
when all are complete. Let a source failure remain actionable rather than
silently converting it to an empty result. Reject missing or non-Boolean
`Done` values instead of interpreting strings through PowerShell truthiness.
The lesson's first script and both current capstone modules provide separate
manifest/export practice; this exercise focuses on the dependency seam.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/06_modules_and_reuse/exercises.ps1
pwsh -NoProfile -File exercises/06_modules_and_reuse/solutions.ps1
```
