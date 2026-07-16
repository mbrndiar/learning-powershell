# 🏆 Capstones

The course now has two equally required capstone tracks:

1. [Comparative](comparative/README.md): implement the frozen, cross-language
   SQLite versioned key/value contract.
2. [Idiomatic](idiomatic/README.md): build a PowerShell-native compliance audit
   and safe remediation module.

Both tracks use `starter/` and `solution/` with the same public signatures. The
starter is the learner workspace. The solution is the reference target used for
the complete acceptance suite. Both solutions are complete; both guided
starters intentionally throw `CapstoneNotImplemented` until learners fill in
their milestone behavior.

The existing [TaskManager](../project/TaskManager/README.md) remains available
as a completed reference until both replacements pass the full PowerShell,
Pester, and operating-system matrix.

## Target selection

Shared tests select `starter` or `solution` through
`CAPSTONE_IMPLEMENTATION`. The repository wrapper sets and restores that
variable for a test run:

```powershell
# Import, manifest, signature, help, parser, and intentional-incomplete smoke.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone All -Implementation All -Tag Smoke

# Complete comparative reference suite.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Comparative -Implementation Solution -Tag All

# Complete idiomatic reference suite.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Idiomatic -Implementation Solution -Tag All

# Focused comparative reference milestone.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Comparative -Implementation Solution -Tag M1
```

`All` implementations is intended for scaffold smoke only. Behavioral suites
target one implementation. A starter milestone command intentionally fails until
the learner completes that stage; CI runs full behavioral conformance against
the solution.

For direct Pester use:

```powershell
$env:CAPSTONE_IMPLEMENTATION = 'solution'
Invoke-Pester -Path ./capstones/comparative/tests -Tag M1 -Output Detailed
Remove-Item Env:CAPSTONE_IMPLEMENTATION
```

## Learning workflow

1. Read the relevant specification and README.
2. Work in `starter/`; do not copy the reference implementation.
3. Run the smallest milestone tag while developing.
4. Run that capstone's complete suite.
5. Only then compare design decisions with `solution/`.
6. Finish with parser, PSScriptAnalyzer, both Pester majors, and the OS matrix.
