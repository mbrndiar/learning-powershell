# 📦 Exercise 6: Modules and Reuse

## 📋 Prerequisites

Complete [Module 6](../../lessons/06_modules_and_reuse/README.md). This
exercise uses a scriptblock as a controlled dependency boundary and imports a
general `.psd1` data file safely.

## 🧩 Tasks

- Implement `Get-OpenItem -Source <scriptblock>`.
- Invoke `Source` and emit only returned objects whose `Done` property is
  present, Boolean, and `$false`.
- Implement `Get-DataFileValue -LiteralPath <string> -Name <string>` with
  `Import-PowerShellDataFile -LiteralPath`, returning the named value and
  throwing when the key is absent.

## 📐 Contract and edge cases

Do not call an external service or invent global state. The source can emit
zero, one, or many objects; preserve the original open objects and emit none
when all are complete. Let a source failure remain actionable rather than
silently converting it to an empty result. Reject missing or non-Boolean
`Done` values instead of interpreting strings through PowerShell truthiness.
For data files, do not dot-source content or use `Invoke-Expression`; safe
import still requires a membership check before returning a named value.

The reference checks normal, zero, and many source results; missing and
non-Boolean `Done`; propagation of a source failure; normal and falsey data-file
values; and a missing key. Manifest authoring remains applied in the lesson and
capstones rather than becoming a publishing requirement here.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/06_modules_and_reuse/exercises.ps1
pwsh -NoProfile -File exercises/06_modules_and_reuse/solutions.ps1
```
