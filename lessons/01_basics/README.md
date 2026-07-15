# 1. Basics

## Objectives

Distinguish `pwsh` from Windows PowerShell, discover help, create typed values,
interpolate strings, and use PowerShell operators.

## Concepts

PowerShell 7 (`pwsh`) is the current cross-platform edition. Commands return
objects, even when the console shows text. Variables begin with `$`; double
quoted strings interpolate variables while single quoted strings are literal.
PowerShell comparison operators use words such as `-eq`, `-gt`, and `-like`.
Parentheses group PowerShell expressions or command output; they do not make
arbitrary syntax from another language valid.

## Files

- `01_discovery.ps1` - version, command discovery, and help patterns.
- `02_values_and_operators.ps1` - scalar values, strings, and operators.

## Run

```powershell
pwsh -NoProfile -File lessons/01_basics/01_discovery.ps1
pwsh -NoProfile -File lessons/01_basics/02_values_and_operators.ps1
```

## Common mistakes

- Starting `powershell.exe` (Windows PowerShell 5.1) instead of `pwsh`.
- Treating help text or formatted output as a data format.
- Expecting `==` and `&&` to be the usual PowerShell operators.

## Review questions

1. What does `Get-Command -Noun Process` discover?
2. When does `$name` interpolate in a string?
3. Why are `-eq` and `-and` preferred in PowerShell code?
