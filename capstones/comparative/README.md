# 🔁 Comparative capstone: versioned configuration store

Implement the language-neutral contract in [`spec/SPEC.md`](spec/SPEC.md).
[`spec/SCENARIOS.md`](spec/SCENARIOS.md) defines how the frozen fixtures are
executed. The CLI launcher is the normative boundary:

```text
pwsh -NoProfile -File ./capstones/comparative/solution/configuration-store.ps1 --db PATH set KEY --value-json JSON [--expect EXPECTATION]
pwsh -NoProfile -File ./capstones/comparative/solution/configuration-store.ps1 --db PATH get KEY
pwsh -NoProfile -File ./capstones/comparative/solution/configuration-store.ps1 --db PATH delete KEY [--expect EXPECTATION]
pwsh -NoProfile -File ./capstones/comparative/solution/configuration-store.ps1 --db PATH list
```

The PowerShell module is a language-local implementation boundary. Its four
approved Verb-Noun commands map one-to-one to the shared operations:

| Shared command | Exported PowerShell command |
| --- | --- |
| `set` | `Set-ConfigurationEntry` |
| `get` | `Get-ConfigurationEntry` |
| `delete` | `Remove-ConfigurationEntry` |
| `list` | `Get-ConfigurationStore` |

`starter/` remains an importable guided workspace. Its public functions and
launcher deliberately fail with the fully qualified error ID prefix
`CapstoneNotImplemented` after PowerShell parameter binding. `solution/` is the
complete reference implementation and uses pinned
[SimplySql](https://www.powershellgallery.com/packages/SimplySql/2.2.0.106)
`2.2.0.106` for its bundled cross-platform System.Data.SQLite provider.

## Milestones

1. Domain and restricted JSON value contracts.
2. Exact CLI grammar, envelopes, streams, and exit codes.
3. SQLite initialization, validation, and v0-to-v1 migration.
4. Revisions, expectations, transactions, and complete mutations.
5. Real independent-process conformance and cleanup.

The starter manifest declares the same provider pin as the solution so learners
receive dependency failures at setup time rather than halfway through a
milestone. Keep the starter signatures identical to the solution, implement one
milestone at a time, and use the fixture failure as the next concrete target.

## Commands

```powershell
# Both importable scaffold targets.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Comparative -Implementation All -Tag Smoke

# Complete reference conformance, including real child processes.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Comparative -Implementation Solution -Tag All

# Focused reference milestone.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Comparative -Implementation Solution -Tag M1

# Learner target: this intentionally fails at the first unfinished fixture.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Comparative -Implementation Starter -Tag M1
```

The shared specification files, version, fixtures, and manifest are normative.
Do not edit one repository's copy independently.

The Pester runner invokes the launcher through `ProcessStartInfo.ArgumentList`,
never through shell evaluation. Milestone 5 uses independent `pwsh` processes, a
start barrier, and a separate SQLite lock-helper process. Every scenario removes
the database and WAL sidecars only after all owned processes and connections
have closed.
