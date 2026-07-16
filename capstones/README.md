# 🏆 Capstones

The course now has two equally required capstone tracks:

1. [Comparative](comparative/README.md): implement the frozen, cross-language
   SQLite versioned key/value contract.
2. [Idiomatic](idiomatic/README.md): build a PowerShell-native compliance audit
   and safe remediation module.

Both tracks use `starter/` and `solution/` with the same public signatures. The
starter is the learner workspace. The solution is the reference target used for
the complete acceptance suite. During this scaffolding phase, both targets
intentionally throw `CapstoneNotImplemented`; no key/value or compliance
behavior has been implemented yet.

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

# Future complete solution suites.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone All -Implementation Solution -Tag All

# Future focused milestone suite.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Idiomatic -Implementation Solution -Tag M1
```

`All` implementations is intended for scaffold smoke only. Behavioral suites
should target one implementation, normally `Solution`.

For direct Pester use:

```powershell
$env:CAPSTONE_IMPLEMENTATION = 'starter'
Invoke-Pester -Path ./capstones/idiomatic/tests -Tag Smoke -Output Detailed
Remove-Item Env:CAPSTONE_IMPLEMENTATION
```

## Learning workflow

1. Read the relevant specification and README.
2. Work in `starter/`; do not copy the reference implementation.
3. Run the smallest milestone tag while developing.
4. Run that capstone's complete suite.
5. Only then compare design decisions with `solution/`.
6. Finish with parser, PSScriptAnalyzer, both Pester majors, and the OS matrix.
