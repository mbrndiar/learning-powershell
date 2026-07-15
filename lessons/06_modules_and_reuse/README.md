# 📦 Module 6: Modules and Reuse

Scripts are convenient for one-off work; modules establish an explicit,
testable public boundary. This module separates implementation from exported
commands and shows how to make external dependencies visible rather than
hidden in session state.

## 🎯 Objectives

- Understand scopes, dot-sourcing, imports, and the state they introduce.
- Distinguish a module implementation (`.psm1`) from its manifest (`.psd1`).
- Export an intentional public surface while keeping helpers private.
- Add useful comment-based help to public commands.
- Reload and invoke modules predictably during development.
- Use scriptblock dependency injection judiciously and avoid hidden globals.

## 💡 Scope and loading choices

Variables and functions have scopes. Dot-sourcing (`. ./helpers.ps1`) runs a
script in the current scope, making its definitions and state available to the
caller. It is useful for small, controlled composition, but it can silently
overwrite names and couples tests to session state.

`Import-Module` creates a module scope and exposes only its exports to the
caller. Imported modules remain loaded in the session; use `-Force` during
development to reload changed code and `Remove-Module` when a test needs a
fresh import. Start scripts with `-NoProfile` when a profile must not supply
implicit functions, aliases, or variables.

## 💡 Module shape and exports

A `.psm1` contains implementation. A `.psd1` manifest declares metadata such
as `RootModule`, version, required PowerShell version, and explicit exports:

```powershell
# in a .psm1
function ConvertTo-InternalName { param([string] $Name) $Name.Trim() }
function Get-Greeting { [CmdletBinding()] param([string] $Name) ... }
Export-ModuleMember -Function Get-Greeting
```

The manifest's `FunctionsToExport` should agree with the implementation.
Explicit exports prevent helpers becoming accidental API promises. Invoke an
ambiguous command by module qualification, for example
`Greeting\Get-Greeting`, and inspect exports with `Get-Command -Module Greeting`.

## 💡 Help and contracts

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

## 💡 Dependency injection and state

Pass a scriptblock for a network, process, clock, or storage boundary:

```powershell
function Get-RemoteTask {
    param([Parameter(Mandatory)][scriptblock] $Request)
    & $Request | Where-Object Done
}
Get-RemoteTask -Request { @([pscustomobject]@{ Done = $true }) }
```

This makes offline tests deterministic. A scriptblock is still executable code:
define its input/output/error contract, avoid accepting untrusted code, and do
not use it as a substitute for a well-designed interface. Prefer explicit
parameters or private module state over globals; hidden global state makes
imports order-dependent and parallel work unsafe.

## 📚 Files

- [`01_module_boundary.ps1`](01_module_boundary.ps1) - disposable manifest-backed module.
- [`02_dependency_injection.ps1`](02_dependency_injection.ps1) - injected data source.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/06_modules_and_reuse/01_module_boundary.ps1
pwsh -NoProfile -File lessons/06_modules_and_reuse/02_dependency_injection.ps1
```

## ⚠️ Common mistakes

- Dot-sourcing untrusted or stateful scripts indiscriminately.
- Exporting every helper and later being unable to change it safely.
- Relying on a profile, current location, or global variable as an implicit dependency.
- Forgetting that an imported module remains loaded in the session.
- Writing help that promises parameters or outputs the implementation lacks.
- Passing arbitrary scriptblocks across a security boundary.

## ❓ Review questions

1. How does dot-sourcing differ from importing a module?
2. What information belongs in a `.psd1` manifest?
3. Why should a helper normally remain private?
4. How can module qualification resolve a command-name collision?
5. Which comment-based help sections help a caller discover a command?
6. What testing benefit does an injected scriptblock provide?
7. Why is hidden global state a poor reusable-module dependency?
