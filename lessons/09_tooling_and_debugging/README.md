# 🐞 Module 9: Tooling and Debugging

## 🎯 Objectives

Use strict mode, investigate failures with a debugger, read analyzer feedback,
format readable scripts, protect secrets, and expand feedback from narrow to
wide.

## 💡 Concepts

`Set-StrictMode -Version Latest` catches uninitialized variables and ambiguous
code. Use VS Code breakpoints or `Set-PSBreakpoint`, then inspect variables and
the call stack. PSScriptAnalyzer identifies common PowerShell risks but does
not replace tests. Format code for review; do not log tokens or commit
credentials. Run one script/test first, then analysis and the broader suite.

## 📚 Files

- `01_strict_mode.ps1` - a strict, readable function.
- `02_feedback_loop.ps1` - invokes analysis only when available.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/09_tooling_and_debugging/01_strict_mode.ps1
pwsh -NoProfile -File lessons/09_tooling_and_debugging/02_feedback_loop.ps1
```

## ⚠️ Common mistakes

- Disabling strict mode to hide a bug.
- Logging headers, tokens, or full secret-bearing requests.
- Running only the full suite and missing fast local feedback.

## ❓ Review questions

1. What kind of defect does strict mode reveal early?
2. Where can a breakpoint be set in VS Code?
3. Why should analysis complement, not replace, tests?
