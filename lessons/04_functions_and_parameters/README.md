# 4. Functions and Parameters

## Objectives

Create approved `Verb-Noun` functions, validate public inputs, accept pipeline
objects, separate begin/process/end work, and use splatting.

## Concepts

Advanced functions use `[CmdletBinding()]` and a `param` block. Parameter types
and validation fail early with useful messages. `begin` runs once, `process`
runs per pipeline input, and `end` runs once. Splatting passes named options
from a hashtable without positional ambiguity. Return values by writing a bare
object; `Write-Output` is normally redundant.

## Files

- `01_advanced_functions.ps1` - validation and object output.
- `02_pipeline_and_splatting.ps1` - pipeline lifecycle and named arguments.

## Run

```powershell
pwsh -NoProfile -File lessons/04_functions_and_parameters/01_advanced_functions.ps1
pwsh -NoProfile -File lessons/04_functions_and_parameters/02_pipeline_and_splatting.ps1
```

## Common mistakes

- Naming a public command with an unapproved verb or plural noun.
- Using `Write-Host` to return useful data.
- Using positional calls when a named parameter makes intent clearer.

## Review questions

1. When does parameter validation occur?
2. How many times does `process` run for three inputs?
3. Why does splatting reduce mistakes?
