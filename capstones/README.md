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

Complete all twelve modules and the required
[Tasks applied project](../projects/tasks/README.md) first. In particular,
[Module 12](../lessons/12_sqlite_and_transactions/README.md) supplies the
SQLite connection, parameterized-SQL, transaction, migration, and locking
foundation required by the comparative track. The frozen capstone contract
still adds its own exact schema, restricted JSON, revision, CLI, and
multi-process requirements.

The Tasks project is an applied bridge, not a third capstone target. Its smaller
domain and HTTP contract prepare module, persistence, safety, and adapter
boundaries without the capstones' broader conformance requirements.

## Scope and safety

| Track | Required scope | Deliberate boundary |
| --- | --- | --- |
| Comparative | Frozen cross-language CLI/JSON/SQLite behavior through SimplySql `2.2.0.106` on local filesystems | Not every PowerShell provider, CPU architecture, SQLite binding, or network/synchronized filesystem |
| Idiomatic | PowerShell-native audit/remediation against explicit disposable roots and injected adapters | No registry, services, users, packages, home-directory scan, privileged path, or organization policy |

For the idiomatic track, “system compliance” means the bounded fixture model in
its specification. Use `TestDrive:` or a root created for the current exercise;
never point examples at `/`, a drive root, `$HOME`, or a production tree.

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

After importing either exact supported Pester version from
[setup](../docs/SETUP.md), direct selection is also available:

```powershell
$previousImplementation = $env:CAPSTONE_IMPLEMENTATION
try {
    $env:CAPSTONE_IMPLEMENTATION = 'solution'
    Invoke-Pester -Path ./capstones/comparative/tests -TagFilter M1 -Output Detailed
}
finally {
    if ($null -eq $previousImplementation) {
        Remove-Item Env:CAPSTONE_IMPLEMENTATION -ErrorAction SilentlyContinue
    }
    else {
        $env:CAPSTONE_IMPLEMENTATION = $previousImplementation
    }
}
```

## Learning workflow

1. Read the relevant specification and README.
2. Confirm its prerequisites, including the Tasks project and Module 12.
3. Work in `starter/`; do not copy the reference implementation.
4. Run the smallest milestone tag while developing.
5. Run that capstone's complete suite.
6. Only then compare design decisions with `solution/`.
7. Finish local parser/PSScriptAnalyzer and both-Pester-major checks; use CI for
   the operating-system matrix.

The CI matrix runs Pester 5.5.0 and 6.0.0 on PowerShell 7.4/current Linux
containers, then Pester 6.0.0 on current hosted Windows and `macos-15-intel`.

## Discover the module contracts

Import one implementation at a time, inspect its exact exports, and read the
installed comment-based help:

```powershell
Import-Module ./capstones/comparative/solution/ComparativeKv.psd1 -Force
Get-Command -Module ComparativeKv
Get-Help Set-ConfigurationEntry -Full
Remove-Module ComparativeKv

Import-Module ./capstones/idiomatic/solution/ComplianceAudit.psd1 -Force
Get-Command -Module ComplianceAudit
Get-Help Test-Compliance -Full
Remove-Module ComplianceAudit
```

Starter and solution manifests export the same four commands in each track.
The comparative import requires the pinned SimplySql dependency; the idiomatic
module has no runtime module dependency.

## From the Tasks project to the capstones

This mapping is conceptual, not a file migration:

| Tasks project concept | Comparative continuation | Idiomatic continuation |
| --- | --- | --- |
| Manifest plus exact exports | Exact four-command module behind the frozen CLI | Exact four-command audit/remediation module |
| Reusable module behind thin adapters | Exact module behind the frozen process CLI | Module/pipeline behavior remains the normative contract |
| Validate HTTP JSON and persisted data before trusting it | Validate restricted JSON values and legacy rows before opening/migrating storage | Validate imported policy shape, types, identifiers, and safe relative paths |
| SQLite transactions plus complete Markdown sibling replacement | Extended with revisions, locking, and migration rollback | Sibling replacement retained for bounded configuration/report writes beneath an approved root |
| `ShouldProcess` around mutation | Module mutations remain previewable; the shared CLI is noninteractive | Required for repair and report replacement, with re-observation and idempotency |
| `TestDrive:` and behavior tests | Fresh scenario directories plus real independent-process SQLite tests | `TestDrive:`, disposable roots, mocks, and injected adapters |
| No cross-process Markdown guarantee; bounded SQLite writer behavior | Explicitly addressed by stricter SQLite immediate transactions and busy behavior | Avoided by bounded fixture operations; no general machine-state coordinator |
| Thin HTTP adapter and client over a reusable module | Replaced by a frozen process CLI/JSON contract | Optional launcher stays nonnormative; module/pipeline behavior is the contract |

Do not carry forward Task records, task CRUD names, or its HTTP schema. Reuse
only the module, validation, persistence-ownership, `ShouldProcess`, adapter,
testing, and cleanup techniques; start current capstone work in the
corresponding `starter/` directory.
