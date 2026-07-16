# 🐞 Module 9: Tooling and Debugging

Good automation has a short, evidence-driven feedback loop. Use strict mode to
find ambiguous code early, reproduce one failure narrowly, then widen testing
and analysis before CI does it for you.

## 🎯 Objectives

- Apply strict mode with an understood scope and version.
- Read `ErrorRecord` information and call stacks during a failure.
- Use breakpoints and the VS Code debugger deliberately.
- Combine focused execution, PSScriptAnalyzer, Pester, and CI feedback.
- Protect secrets in logs, history, profiles, and transcripts.
- Keep scripts readable enough to debug and review.

## 🔒 Strict mode and error evidence

`Set-StrictMode -Version Latest` applies to the current scope and child scopes,
not magically to every imported module or separate process. Select a version
deliberately: `Latest` follows the installed engine's most recent strictness;
a numeric version can make a compatibility promise. It catches issues such as
uninitialized variables and invalid property access that might otherwise
silently produce `$null`.

In `catch`, inspect the full error record before rewriting it:

```powershell
catch {
    $_.Exception.Message
    $_.CategoryInfo
    $_.InvocationInfo.PositionMessage
    $_.ScriptStackTrace
    throw
}
```

Preserve the original exception as an inner exception when adding boundary
context. Do not discard the stack trace by reducing every error to a string.

## 🔬 Debugging workflow

Make the smallest deterministic reproduction: one command, one test, one
fixture. Set a VS Code line breakpoint or use `Set-PSBreakpoint -Script ...`
and inspect variables, scope, and call stack when execution stops. Step over
to test the next statement, step into only code whose behavior is unknown, and
remove breakpoints after learning the cause. Debuggers complement assertions;
they do not replace a regression test.

## 🔍 Analysis, readability, and CI

PSScriptAnalyzer finds common PowerShell pitfalls and enforces selected style
rules. This repository uses
[`PSScriptAnalyzerSettings.psd1`](../../PSScriptAnalyzerSettings.psd1); run
the configured settings rather than an invented rule set. A suppression needs
a narrow scope and a justification explaining why the rule does not apply,
not merely a desire for a clean report.

Readable formatting—small focused functions, named parameters, consistent
indentation, and meaningful names—lowers review and debugging cost. The CI
matrix validates PowerShell 7.4/current Linux containers with Pester 5.5.0 and
6.0.0, then repeats the complete course validation with Pester 6.0.0 on current
hosted Windows and macOS. Local focused checks are faster; CI is the broader
safety net, not a substitute for local reasoning.

## 🔐 Reproducibility and secret hygiene

Profiles can define aliases, modules, and variables that hide dependencies.
Use `pwsh -NoProfile` for scripts and reproduction; then test intentional
profile integration separately. Never put tokens in source, command-line
history, logs, transcripts, or error messages. Obtain secrets from an approved
secure source, pass only what is needed, and redact request headers and
responses before logging. Transcripts can capture sensitive material, so use
them only with an approved storage and retention policy.

## 📚 Files

- [`01_strict_mode.ps1`](01_strict_mode.ps1) - strict mode and explicit validation.
- [`02_feedback_loop.ps1`](02_feedback_loop.ps1) - analyzer-aware narrow-to-wide feedback.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/09_tooling_and_debugging/01_strict_mode.ps1
pwsh -NoProfile -File lessons/09_tooling_and_debugging/02_feedback_loop.ps1
Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Force
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit
```

## ⚠️ Common mistakes

- Assuming strict mode applies to imported modules or a new `pwsh` process.
- Swallowing an `ErrorRecord` and losing invocation and stack details.
- Starting a full test suite before reproducing the smallest failure.
- Globally disabling analyzer rules instead of documenting a narrow exception.
- Depending on a personal profile during CI or in a support reproduction.
- Printing tokens, authorization headers, or sensitive response bodies.

## ❓ Review questions

1. What scope does `Set-StrictMode` affect?
2. Which error-record members help locate a failing call?
3. What makes a reproduction loop narrow?
4. Why must an analyzer suppression be justified?
5. What responsibility does CI have that a focused local run does not?
6. Why use `-NoProfile` for reproducibility?
7. What can make transcripts and command history sensitive?
