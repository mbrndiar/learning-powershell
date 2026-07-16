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

`starter/` and `solution/` currently contain only importable scaffolding and a
nonnormative convenience launcher skeleton. Their public signatures are
identical. Each unfinished body deliberately fails with the fully qualified
error ID prefix `CapstoneNotImplemented` after parameter binding and validation.

## Milestones

1. Finding model and pure check decisions.
2. Module, policy import, target validation, adapters, and discovery.
3. Idempotent remediation through `ShouldProcess`.
4. Deterministic JSON/CSV reports, streams, and native-version handling.
5. Bounded auditing, stable ordering, cleanup, and complete integration gates.

## Commands

```powershell
# Both importable scaffold targets.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Idiomatic -Implementation All -Tag Smoke

# Stable future full-solution command.
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
