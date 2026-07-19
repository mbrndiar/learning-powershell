# 📦 Module 6: Modules and Reuse

Scripts are convenient for one-off work; modules establish an explicit,
testable public boundary. This module separates implementation from exported
commands and shows how to make external dependencies visible rather than
hidden in session state.

## 🎯 Objectives

- Understand scopes, dot-sourcing, imports, and the state they introduce.
- Distinguish a script-module implementation, a general `.psd1` data file, and
  the specialized `.psd1` module-manifest schema.
- Export an intentional public surface while keeping helpers private.
- Add useful comment-based help to public commands.
- Reload and invoke modules predictably during development.
- Use scriptblock dependency injection judiciously and avoid hidden globals.

## 🔭 Scope and loading choices

Variables and functions have scopes. Dot-sourcing (`. ./helpers.ps1`) runs a
script in the current scope, making its definitions and state available to the
caller. It is useful for small, controlled composition, but it can silently
overwrite names and couples tests to session state.

`Import-Module` creates a module scope and exposes only its exports to the
caller. Imported modules remain loaded in the session; use `-Force` during
development to reload changed code and `Remove-Module` when a test needs a
fresh import. Start scripts with `-NoProfile` when a profile must not supply
implicit functions, aliases, or variables.

## 🗃️ PowerShell data files and module manifests

A `.psd1` is a general PowerShell data file: a hashtable-shaped document written
in PowerShell's restricted data language. Read configuration and lookup data
without executing the file:

```powershell
$configuration = Import-PowerShellDataFile -LiteralPath './Configuration.psd1'
$configuration['Mode']
```

`Import-PowerShellDataFile` parses allowed data expressions rather than
dot-sourcing the file or passing its text to `Invoke-Expression`. That is an
important execution boundary, not a substitute for validating keys and values.
Use `-LiteralPath` for a data-derived filename. By default the cmdlet limits an
import to 500 keys and 5000 syntax-tree nodes to reduce denial-of-service risk.
`-SkipLimitCheck` removes that guard and belongs only at a separately justified,
trusted boundary.

A module manifest is a specialized `.psd1` whose recognized keys describe a
module. It is still a data file, but fields such as `RootModule`,
`ModuleVersion`, `PowerShellVersion`, and `FunctionsToExport` have module-loader
semantics. A `.psm1`, by contrast, is script-module implementation code.

## 🧱 Module shape and exports

A `.psm1` contains implementation. Its module manifest declares metadata and
the intended public surface:

```powershell
# in a .psm1
function ConvertTo-InternalName { param([string] $Name) $Name.Trim() }
function Get-Greeting { [CmdletBinding()] param([string] $Name) ... }
Export-ModuleMember -Function Get-Greeting
```

The manifest's `FunctionsToExport` should agree with the implementation.
Explicit exports prevent helpers becoming accidental API promises. Invoke an
ambiguous command by module qualification, for example
`Greeting\Get-Greeting`, inspect exports with `Get-Command -Module Greeting`,
and validate manifest structure with `Test-ModuleManifest`.

## 📖 Help and contracts

Comment-based help belongs immediately before the public function:

```powershell
<#
.SYNOPSIS
Returns a greeting object for one person.
.PARAMETER Name
The nonblank name to normalize.
.EXAMPLE
Get-Greeting -Name 'Ada'
#>
```

Add `.DESCRIPTION`, `.OUTPUTS`, `.NOTES`, and examples when consumers need
them. `Get-Help Get-Greeting -Full` tests the discoverability of the contract;
help should describe actual behavior, not aspirational features.

## 🔌 Dependency injection and state

Pass a scriptblock for a network, process, clock, or storage boundary:

```powershell
function Get-RemoteTask {
    param([Parameter(Mandatory)][scriptblock] $Request)
    foreach ($task in @(& $Request)) {
        $done = $task.PSObject.Properties['Done']
        if ($null -eq $done -or $done.Value -isnot [bool]) {
            throw 'Request results require a Boolean Done property.'
        }
        if ($done.Value) { $task }
    }
}
Get-RemoteTask -Request { @([pscustomobject]@{ Done = $true }) }
```

This makes offline tests deterministic. A scriptblock is still executable code:
define its input/output/error contract, avoid accepting untrusted code, and do
not use it as a substitute for a well-designed interface. Prefer explicit
parameters or private module state over globals; hidden global state makes
imports order-dependent and parallel work unsafe.

## 📚 Files

- [`01_module_boundary.ps1`](01_module_boundary.ps1) - general data import and a disposable manifest-backed module.
- [`02_dependency_injection.ps1`](02_dependency_injection.ps1) - injected data source.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/06_modules_and_reuse/01_module_boundary.ps1
pwsh -NoProfile -File lessons/06_modules_and_reuse/02_dependency_injection.ps1
```

## ⚠️ Common mistakes

- Dot-sourcing untrusted or stateful scripts indiscriminately.
- Treating every `.psd1` as a manifest or executing a data file to read it.
- Using `-SkipLimitCheck` for untrusted data or skipping schema validation after import.
- Exporting every helper and later being unable to change it safely.
- Relying on a profile, current location, or global variable as an implicit dependency.
- Forgetting that an imported module remains loaded in the session.
- Writing help that promises parameters or outputs the implementation lacks.
- Passing arbitrary scriptblocks across a security boundary.

## ❓ Review questions

1. How does dot-sourcing differ from importing a module?
2. How do a general `.psd1`, a module-manifest `.psd1`, and a `.psm1` differ?
3. Why should a helper normally remain private?
4. How can module qualification resolve a command-name collision?
5. Which comment-based help sections help a caller discover a command?
6. What testing benefit does an injected scriptblock provide?
7. Why is hidden global state a poor reusable-module dependency?
8. Why is `Import-PowerShellDataFile` safer than executing a data file, and
   what validation remains afterward?
