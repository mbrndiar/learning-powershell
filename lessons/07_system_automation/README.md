# 🛠️ Module 7: System Automation and Native Commands

System automation crosses boundaries: providers, operating-system processes,
and stateful resources behave differently from pure PowerShell objects. Build
safe commands by reading current state, using explicit arguments, and making
the intended change observable and previewable.

## 🎯 Objectives

- Navigate providers and drives without assuming a Windows-only filesystem.
- Distinguish PowerShell cmdlet failures from native executable exit codes.
- Pass native arguments as values rather than constructing evaluable strings.
- Design idempotent, convergent state changes.
- Implement and consume `ShouldProcess`, `-WhatIf`, and `-Confirm`.
- Identify remoting and service automation as platform-specific follow-on work.

## 🗂️ Providers, drives, and process boundaries

Providers expose stores through PowerShell drives: `FileSystem:`, `Env:`,
`Variable:`, `Function:`, and others installed by modules. Discover them:

```powershell
Get-PSProvider
Get-PSDrive
Get-ChildItem Env:
$env:PATH
Get-Process | Select-Object -First 3 Name, Id
```

`Env:` and .NET path APIs are portable. Service-management cmdlets, registry
providers, and many administrative modules are Windows-only or platform
dependent; guard them with documented requirements rather than presenting
them as universal examples.

Native executables are a boundary. They receive arguments and report an integer
exit code in `$LASTEXITCODE`, while cmdlets use PowerShell error records:

```powershell
& $pwshPath -NoProfile -Command 'exit 7'
if ($LASTEXITCODE -ne 0) { throw "pwsh failed: $LASTEXITCODE" }
```

Read `$LASTEXITCODE` immediately after the native invocation. `$?` tells
whether the most recent PowerShell operation succeeded, but it is not a full
native error policy. `$PSNativeCommandUseErrorActionPreference` changes how nonzero native exit
codes integrate with PowerShell error handling; stderr text alone does not
define failure. Set and restore the preference only with a deliberate, tested
policy.

## 🧰 Safe native invocation

Invoke an executable with the call operator and separate argument values:

```powershell
& $tool '--output' $outputPath '--name' $name
```

Never build a shell command string and pass it to `Invoke-Expression` or a
second shell. Quoting rules, injection risk, and error handling become opaque.
Validate values and choose an API that accepts arguments as arguments.

## 🛡️ Convergence and ShouldProcess

An idempotent operation can run repeatedly and converge on the desired state.
Read before writing, change only when current state differs, and emit a result
object describing what happened:

```powershell
[CmdletBinding(SupportsShouldProcess)]
param([string] $LiteralPath)
if ($changed -and $PSCmdlet.ShouldProcess($LiteralPath, 'write desired content')) {
    Set-Content -LiteralPath $LiteralPath -Value $desired -NoNewline
}
[pscustomobject]@{ Path = $LiteralPath; Changed = $changed; Compliant = $true }
```

`SupportsShouldProcess` adds `-WhatIf` and `-Confirm`. Call
`$PSCmdlet.ShouldProcess()` immediately around the mutation, not around the
read or validation. `-WhatIf` previews approved changes without performing
them; it should not claim that desired state was achieved. Set an appropriate
`ConfirmImpact` for destructive commands and preserve the caller's confirmation
choice through wrapper scripts.

PowerShell remoting, scheduled services, DSC, and OS-specific service control
are valuable follow-on topics. Their authentication, transport, and privilege
models need platform-specific study beyond this module.

## 📚 Files

- [`01_providers_and_processes.ps1`](01_providers_and_processes.ps1) - provider/process inspection and exit-code translation.
- [`02_safe_state_change.ps1`](02_safe_state_change.ps1) - idempotent WhatIf-aware file change.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/07_system_automation/01_providers_and_processes.ps1
pwsh -NoProfile -File lessons/07_system_automation/02_safe_state_change.ps1
```

## ⚠️ Common mistakes

- Checking `$LASTEXITCODE` after a cmdlet instead of the native command.
- Ignoring a nonzero exit code because no exception was thrown.
- Building quoted command strings or using `Invoke-Expression`.
- Declaring an operation idempotent without comparing current and desired state.
- Calling `ShouldProcess` after mutation or returning false compliance under `-WhatIf`.
- Assuming Windows services, Registry, or drive letters exist on macOS/Linux.

## ❓ Review questions

1. What does a PowerShell provider contribute beyond filesystem paths?
2. How do cmdlet errors and native exit codes differ?
3. When must `$LASTEXITCODE` be read?
4. Why are argument values safer than a constructed command string?
5. What makes a state change idempotent?
6. What does `SupportsShouldProcess` provide?
7. Why are remoting and service examples not universally portable?
