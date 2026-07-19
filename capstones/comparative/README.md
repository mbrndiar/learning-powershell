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

Complete [Module 12: SQLite and
Transactions](../../lessons/12_sqlite_and_transactions/README.md) before
starting. It teaches the PowerShell/SimplySql connection, parameter, transaction,
migration, and local-locking model. This capstone then applies those foundations
to a much stricter shared schema, restricted-JSON model, CLI grammar, revision
protocol, and independent-process conformance suite.

The required [Tasks applied project](../../projects/tasks/README.md) provides an
earlier, smaller use of SQLite transactions, exact manifests, thin adapters,
stable errors, and shared starter/solution tests. Complete it before this
capstone; do not copy its Task schema or HTTP contract into the frozen
configuration-store contract.

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

## Provider and platform scope

“Provider” here means the ADO.NET SQLite provider bundled by SimplySql, not a
drive exposed by `Get-PSProvider`. Both comparative manifests require the exact
SimplySql version so starter and solution fail early if the native dependency is
missing. The workflow exercises the PowerShell 7.4 compatibility floor on Linux
and the current hosted PowerShell on Linux, Windows, and macOS Intel with
ordinary local-filesystem SQLite locking. SimplySql `2.2.0.106` has no
`osx-arm64` native provider, so Apple Silicon is outside this capstone's support
boundary. The workflow does not prove every 7.4+/OS/architecture combination.

Alternate SQLite modules, the `sqlite3` executable, other CPU architectures,
PowerShell providers, network filesystems, synchronized folders, special files,
and symlink-dependent layouts are outside the frozen environment. They require
an explicit provider/path/locking smoke test; do not infer support from a module
import alone.

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

## Runnable CLI smoke

The grammar above uses placeholders. This disposable example invokes all four
normative commands and checks every child-process exit:

```powershell
$db = Join-Path $PWD ('.comparative-doc-smoke-{0}.db' -f [guid]::NewGuid())
function Invoke-ConfigurationStoreDemo {
    param([Parameter(Mandatory)][string[]] $ArgumentList)

    & pwsh -NoProfile -File ./capstones/comparative/solution/configuration-store.ps1 @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "configuration-store.ps1 failed with exit code $LASTEXITCODE."
    }
}

try {
    Invoke-ConfigurationStoreDemo -ArgumentList @('--db', $db, 'set', 'app/mode', '--value-json', '"safe"', '--expect', 'absent')
    Invoke-ConfigurationStoreDemo -ArgumentList @('--db', $db, 'get', 'app/mode')
    Invoke-ConfigurationStoreDemo -ArgumentList @('--db', $db, 'list')
    Invoke-ConfigurationStoreDemo -ArgumentList @('--db', $db, 'delete', 'app/mode', '--expect', '1')
}
finally {
    foreach ($path in @($db, "$($db)-wal", "$($db)-shm", "$($db)-journal")) {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }
}
```

Inspect the PowerShell-local boundary separately:

```powershell
Import-Module ./capstones/comparative/solution/ComparativeKv.psd1 -Force
Get-Command -Module ComparativeKv
Get-Help Set-ConfigurationEntry -Full
Remove-Module ComparativeKv
```

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
have closed. CI runs the solution with Pester 5.5.0 and 6.0.0 on the Linux
matrix and with Pester 6.0.0 on hosted Windows and `macos-15-intel`.
