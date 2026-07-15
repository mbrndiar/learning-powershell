# 🧩 Module 4: Functions and Parameters

Functions become reusable tools when their names, parameter contracts, output,
and failure behavior are intentional. This module builds advanced functions
that compose in a pipeline without losing the clarity of named calls.

## 🎯 Objectives

- Define public `Verb-Noun` commands with stable input and output contracts.
- Use advanced functions and common parameters appropriately.
- Apply types and validation without confusing mandatory input with meaningful input.
- Bind pipeline input by value or by property name.
- Use named calls and splatting to make options auditable.
- Separate one-time, per-item, and final work with `begin`/`process`/`end`.

## 📜 Command contracts and names

Public functions should use an approved verb from `Get-Verb` and a singular,
specific noun: `Get-Greeting`, not `DoThings`. `[CmdletBinding()]` makes a
function advanced, adding common parameters such as `-Verbose`, `-Debug`, and
`-ErrorAction` and enabling cmdlet-like binding:

```powershell
function Get-Greeting {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Name)
    [pscustomobject]@{ Message = "Hello, $Name" }
}
```

The name and parameter types are a contract, not documentation decoration.
Choose output objects with named properties instead of concatenated display
strings when a caller may filter, export, or test the result.

## 🧲 Binding, conversion, and validation

PowerShell binds named arguments before the function body and converts values
to the declared parameter type. Validation attributes then enforce local
rules:

```powershell
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrWhiteSpace()]
    [string] $Name,
    [ValidateRange(1, 10)]
    [int] $Repeat = 1
)
```

For a mandatory `[string]`, parameter binding already rejects `$null` and the
empty string, but whitespace still counts as supplied text.
`ValidateNotNullOrWhiteSpace` expresses the meaningful boundary directly.
`ValidateNotNullOrEmpty` remains useful where empty input is invalid but
whitespace is meaningful. Validation should explain the local boundary without
embedding unrelated business workflow.

Parameter sets model mutually exclusive calling forms and let binding reject
ambiguous combinations before the function body:

```powershell
[CmdletBinding(DefaultParameterSetName = 'ByName')]
param(
    [Parameter(Mandatory, ParameterSetName = 'ByName')][string] $Name,
    [Parameter(Mandatory, ParameterSetName = 'ById')][guid] $Id
)
$PSCmdlet.ParameterSetName
```

## 🧾 Named calls, splatting, and pipeline binding

Named calls resist parameter-order mistakes:

```powershell
Get-Greeting -Name 'Ada'
$parameters = @{ Name = 'Ada'; Repeat = 2; Verbose = $true }
Get-Greeting @parameters
```

Splatting expands a hashtable into named parameters, keeping optional settings
near each other. Do not use it to conceal dynamic or unvalidated input.

`ValueFromPipeline` binds an incoming object itself;
`ValueFromPipelineByPropertyName` binds a matching property. Declare only the
behavior you support:

```powershell
param([Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)][int] $Number)
1..3 | Get-ScaledNumber -Factor 2
[pscustomobject]@{ Number = 4 } | Get-ScaledNumber -Factor 2
```

## 🚦 Lifecycle and output

`begin` runs once before input, `process` once per pipeline item, and `end`
once after input. Initialize a counter or connection in `begin`, transform
each item in `process`, and emit a final aggregate in `end` when that is the
documented contract.

Writing a bare object to the success stream is output; `return` exits early
but also returns an expression if supplied. `Write-Output` is normally
redundant, while `Write-Host` is presentation, not data. Arrays are unrolled
to the pipeline by default, so use `@(...)` or `,$value` only when preserving
cardinality is part of the contract. Module 7 covers `ShouldProcess` for
state-changing commands.

## 📚 Files

- [`01_advanced_functions.ps1`](01_advanced_functions.ps1) - validation and object output.
- [`02_pipeline_and_splatting.ps1`](02_pipeline_and_splatting.ps1) - lifecycle and named arguments.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/04_functions_and_parameters/01_advanced_functions.ps1
pwsh -NoProfile -File lessons/04_functions_and_parameters/02_pipeline_and_splatting.ps1
```

## ⚠️ Common mistakes

- Naming a public command with an unapproved verb or vague/plural noun.
- Thinking `[Parameter(Mandatory)]` rejects whitespace-only strings.
- Using positional calls after a function gains optional parameters.
- Marking pipeline binding without implementing per-item `process` behavior.
- Defining overlapping parameter sets that leave a call ambiguous.
- Returning diagnostics through `Write-Host` or formatting output in the function.
- Accidentally emitting helper expressions as success output.

## ❓ Review questions

1. What does `[CmdletBinding()]` add to a function?
2. At what stage do type conversion and validation occur?
3. Why does mandatory input not necessarily mean nonblank input?
4. When does `process` run for three piped values?
5. How do binding by value and binding by property name differ?
6. Why is splatting safer than a long positional call?
7. What happens to an array written to the success stream?
8. What invalid argument combination can a parameter set reject before execution?
