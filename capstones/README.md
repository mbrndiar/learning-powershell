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

The existing [TaskManager](../project/TaskManager/README.md) is retained as a
completed, smaller reference. Its identity and files are independent of the two
capstone targets.

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
2. Work in `starter/`; do not copy the reference implementation.
3. Run the smallest milestone tag while developing.
4. Run that capstone's complete suite.
5. Only then compare design decisions with `solution/`.
6. Finish local parser/PSScriptAnalyzer and both-Pester-major checks; use CI for
   the operating-system matrix.

The CI matrix runs Pester 5.5.0 and 6.0.0 on PowerShell 7.4/current Linux
containers, then Pester 6.0.0 on current hosted Windows and macOS.

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

## From TaskManager to the capstones

This mapping is conceptual, not a file migration:

| TaskManager concept | Comparative continuation | Idiomatic continuation |
| --- | --- | --- |
| Manifest plus exact exports | Exact four-command module behind the frozen CLI | Exact four-command audit/remediation module |
| Thin launcher over module commands | Normative process grammar, JSON envelopes, streams, and exit codes | Optional launcher stays nonnormative; module/pipeline behavior is the contract |
| Validate JSON before trusting it | Validate restricted JSON values and legacy rows before opening/migrating storage | Validate imported policy shape, types, identifiers, and safe relative paths |
| Complete sibling-file replacement | Replaced by SQLite transactions, revisions, locking, and migration rollback | Retained for bounded configuration/report writes beneath an approved root |
| `ShouldProcess` around mutation | Module mutations remain previewable; the shared CLI is noninteractive | Required for repair and report replacement, with re-observation and idempotency |
| `TestDrive:` and behavior tests | Fresh scenario directories plus real independent-process SQLite tests | `TestDrive:`, disposable roots, mocks, and injected adapters |
| No multi-writer guarantee | Explicitly addressed by SQLite immediate transactions and busy behavior | Avoided by bounded fixture operations; no general machine-state coordinator |

Do not carry forward Task records, task CRUD names, its JSON schema, or its
single-file storage assumptions. Keep the old project intact as a compact
reference and start capstone work in the corresponding `starter/` directory.
