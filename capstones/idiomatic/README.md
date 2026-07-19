# ⚡ Idiomatic capstone: compliance audit and remediation

Build the manifest-based module defined by [`SPEC.md`](SPEC.md). The required
public surface is exactly:

```text
Import-CompliancePolicy
Test-Compliance
Repair-Compliance
Export-ComplianceReport
```

The project demonstrates PowerShell's object pipeline, advanced functions,
manifest exports, untrusted JSON validation, injected capabilities,
`ShouldProcess`, deterministic reporting, Pester isolation, and bounded
concurrency. Required work stays inside explicit disposable roots and never
touches privileged machine state.

Complete [Module 11: Concurrency](../../lessons/11_concurrency/README.md)
before Milestone 5. Its RunspacePool example introduces the ownership,
`BeginInvoke`/`EndInvoke`, error-stream, ordering, and disposal model used by
the reference solution and sketched in the starter.

## Safe-fixture boundary

“System compliance” is intentionally comparative learning vocabulary, not
permission to inspect or remediate the host. Required behavior is limited to
fixture roots supplied explicitly by the caller, the fixed harmless rule
catalog, and injected adapter operations. Tests use `TestDrive:` or
self-created disposable directories.

Do not point the default adapter at `/`, a drive root, `$HOME`, a production
checkout, or an administrator-managed path. Registry, services, users,
packages, cloud resources, organization policy, privileged paths, and arbitrary
commands from policy JSON are outside the capstone. Symlink/reparse traversal
that could escape an approved root must be rejected before mutation.

`starter/` is a guided scaffold whose unfinished public bodies deliberately fail
with the fully qualified error ID prefix `CapstoneNotImplemented`.
`solution/` is the complete reference implementation. Their public signatures
and exact four-command export surface remain identical; the nonnormative
launcher stays a parsing/argument-binding exercise rather than part of the
module contract.

## Milestones

1. Finding model and pure check decisions.
2. Module, policy import, target validation, adapters, and discovery.
3. Idempotent remediation through `ShouldProcess`.
4. Deterministic JSON/CSV reports, streams, and native-version handling.
5. Bounded auditing, stable ordering, cleanup, and complete integration gates.

## Runnable module smoke

The module is the normative boundary; the optional launcher is intentionally a
nonnormative parsing exercise. This example creates and removes its own root:

```powershell
$root = Join-Path $PWD ('.idiomatic-doc-smoke-{0}' -f [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $root
try {
    Import-Module ./capstones/idiomatic/solution/ComplianceAudit.psd1 -Force
    Get-Command -Module ComplianceAudit
    Get-Help Test-Compliance -Full

    $policy = Import-CompliancePolicy -Path ./capstones/idiomatic/tests/fixtures/policies/minimal.json
    $target = [pscustomobject]@{ Name = 'doc-smoke'; RootPath = $root }
    $before = Test-Compliance -Target $target -Policy $policy
    $before | Repair-Compliance -Policy $policy -WhatIf
    $before | Repair-Compliance -Policy $policy -Confirm:$false
    Test-Compliance -Target $target -Policy $policy
}
finally {
    Remove-Module ComplianceAudit -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
```

## Optional launcher

`solution/compliance-audit.ps1` is a nonnormative reference launcher over the
same four commands, with an explicit parameter contract documented in its own
comment-based help (`Get-Help ./capstones/idiomatic/solution/compliance-audit.ps1 -Full`):
an explicit `-PolicyPath`, one or more explicit disposable `-TargetRoot`
values with optional matching `-TargetName` values, optional `-RuleId`/
`-ThrottleLimit` selection, an optional `-Repair` pass that honors the
script's own `-WhatIf`/`-Confirm`, and an optional `-ReportPath`/
`-ReportFormat`/`-Force` JSON or CSV export. It never builds or evaluates a
shell command string, never reads a secret, and never defaults a target to a
privileged path: `-TargetRoot` is mandatory, and a resolved root that is
exactly a filesystem drive root or exactly `$HOME` is rejected.
`starter/compliance-audit.ps1` declares the identical parameter contract and
intentionally throws `CapstoneNotImplemented` once arguments are bound, so
starter/solution parity stays inspectable with `Get-Command -Syntax`.

```powershell
$root = Join-Path $PWD ('.idiomatic-launcher-smoke-{0}' -f [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $root
try {
    $policyPath = './capstones/idiomatic/tests/fixtures/policies/minimal.json'

    # Audit only; no writes.
    ./capstones/idiomatic/solution/compliance-audit.ps1 `
        -PolicyPath $policyPath -TargetRoot $root -TargetName doc-smoke

    # Preview a repair with zero writes.
    ./capstones/idiomatic/solution/compliance-audit.ps1 `
        -PolicyPath $policyPath -TargetRoot $root -TargetName doc-smoke `
        -Repair -WhatIf

    # Repair, then export a deterministic report.
    ./capstones/idiomatic/solution/compliance-audit.ps1 `
        -PolicyPath $policyPath -TargetRoot $root -TargetName doc-smoke `
        -Repair -Confirm:$false `
        -ReportPath (Join-Path $root 'report.json') -ReportFormat Json
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
```

## Commands

```powershell
# Both importable targets and their shared public boundary.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Idiomatic -Implementation All -Tag Smoke

# Complete reference suite.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Idiomatic -Implementation Solution -Tag All

# Stable focused milestone command.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Idiomatic -Implementation Solution -Tag M1
```

After importing either exact version from [setup](../../docs/SETUP.md), direct
selection remains available for Pester 5.5 and 6:

```powershell
$previousImplementation = $env:CAPSTONE_IMPLEMENTATION
try {
    $env:CAPSTONE_IMPLEMENTATION = 'solution'
    Invoke-Pester -Path ./capstones/idiomatic/tests -TagFilter M1 -Output Detailed
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

No runtime module dependency is allowed for this capstone.

Injected adapters provide `ResolveRoot`, `ResolvePath`, `GetPathKind`,
`ReadFile`, `WriteFile`, `CreateDirectory`, and `GetToolVersion` scriptblocks.
For throttled tests they may also expose a thread-safe `State` object, which is
passed as the final operation argument after worker-local scriptblocks are
created. CI runs Pester 5.5.0 and 6.0.0 on the Linux matrix and Pester 6.0.0 on
hosted Windows and macOS.
