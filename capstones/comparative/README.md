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

`starter/` and `solution/` currently contain only importable scaffolding. Every
function and launcher fails deliberately with the fully qualified error ID
prefix `CapstoneNotImplemented` after PowerShell parameter binding.

## Milestones

1. Domain and restricted JSON value contracts.
2. Exact CLI grammar, envelopes, streams, and exit codes.
3. SQLite initialization, validation, and v0-to-v1 migration.
4. Revisions, expectations, transactions, and complete mutations.
5. Real independent-process conformance and cleanup.

Do not add storage behavior during scaffold work. The selected provider for the
implementation pilot is SimplySql `2.2.0.106`, but this scaffold deliberately
does not install it or declare it as a manifest dependency. Provider
integration and the Linux/Windows/macOS proof belong to the pilot.

## Commands

```powershell
# Both importable scaffold targets.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Comparative -Implementation All -Tag Smoke

# Stable future full-solution command.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Comparative -Implementation Solution -Tag All

# Stable future milestone command.
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Comparative -Implementation Solution -Tag M1
```

The shared specification files, version, fixtures, and manifest are normative.
Do not edit one repository's copy independently.
