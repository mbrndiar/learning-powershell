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

Direct selection also remains available for Pester 5.5 and 6:

```powershell
$env:CAPSTONE_IMPLEMENTATION = 'solution'
Invoke-Pester -Path ./capstones/idiomatic/tests -Tag M1 -Output Detailed
```

No runtime module dependency is allowed for this capstone.

Injected adapters provide `ResolveRoot`, `ResolvePath`, `GetPathKind`,
`ReadFile`, `WriteFile`, `CreateDirectory`, and `GetToolVersion` scriptblocks.
For throttled tests they may also expose a thread-safe `State` object, which is
passed as the final operation argument after worker-local scriptblocks are
created.
