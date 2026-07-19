# Idiomatic capstone specification: system compliance audit and remediation module

## Status and interpretation

This is the learner contract for the required PowerShell idiomatic capstone,
equal in weight to the comparative SQLite key/value capstone. Exported command
behavior, pipeline objects, policy rules, safety boundaries, errors, milestones,
and acceptance criteria are normative. Private function/file organization and
runspace implementation are not.

The retired TaskManager module is historical context for the
[concept mapping](../README.md#from-taskmanager-to-the-capstones), not an
implementation target for this capstone.

## Bounded problem and safety model

Build a manifest-based module that audits explicitly supplied fixture/system
roots against a fixed catalog of three harmless cross-platform rule kinds:

1. a relative directory must exist;
2. a key in a simple `key=value` UTF-8 configuration file must have an expected
   value; and
3. the installed PowerShell executable must meet a minimum version.

The module emits rich findings and can idempotently create the required
directory or set the required file value through `ShouldProcess`. Tool-version
findings are audit-only.

Required tests operate on `TestDrive:` or disposable roots and an injected
adapter. The required solution does not inspect privileged machine state,
registry, services, users, packages, cloud resources, or organization policy.
Findings are derived assessments, not Task records or generic KV entries.

## Learning goals and course mapping

| Course material | Capstone outcome |
| --- | --- |
| [Modules 1–3](../../lessons/README.md) | Discover commands and transform/filter/group rich pipeline objects without premature formatting. |
| [Module 4: functions and parameters](../../lessons/04_functions_and_parameters/README.md) | Implement advanced functions, validation, pipeline binding, parameter sets, splatting, and approved Verb-Noun commands. |
| [Module 5: errors, streams, files](../../lessons/05_errors_streams_and_files/README.md) | Separate success/error/verbose/information streams, use actionable ErrorIds, and handle portable UTF-8/JSON/files. |
| [Module 6: modules and reuse](../../lessons/06_modules_and_reuse/README.md) | Define a manifest, explicit exports, private capabilities, comment help, and injectable dependencies. |
| [Module 7: system automation](../../lessons/07_system_automation/README.md) | Work with provider paths/native exits, idempotency, containment, and `SupportsShouldProcess`. |
| [Module 8: Pester](../../lessons/08_testing_with_pester/README.md) | Use behavior tests, `TestDrive:`, mocks, stream assertions, and module isolation. |
| [Module 9: tooling and debugging](../../lessons/09_tooling_and_debugging/README.md) | Apply strict mode, PSScriptAnalyzer, CI, redacted diagnostics, and a narrow-to-wide validation loop. |
| [Module 10: APIs and automation](../../lessons/10_apis_and_automation/README.md) | Validate imported JSON policy as untrusted data; no live API is required. |
| [Module 11: concurrency](../../lessons/11_concurrency/README.md) | Audit independent targets with bounded throttling, plain-object serialization, stable reordering, and cleanup. |

## Exported module surface

`ComplianceAudit.psd1` exports exactly:

```powershell
Import-CompliancePolicy
Test-Compliance
Repair-Compliance
Export-ComplianceReport
```

It exports no aliases, variables, or cmdlets. All commands are advanced
functions with comment-based help and examples. Reusable commands output
objects and never call `Format-*` or `Write-Host`.

Starter and solution manifests use:

- module name `ComplianceAudit`;
- module version `1.0.0`;
- `PowerShellVersion = '7.4'`;
- identical public signatures and exported names.

## Policy shape and validation

`Import-CompliancePolicy -Path PATH` reads exactly one UTF-8 JSON object:

```json
{
  "schemaVersion": 1,
  "policyId": "fixture-baseline",
  "rules": [
    {
      "ruleId": "cache-directory",
      "kind": "DirectoryExists",
      "relativePath": "var/cache",
      "remediation": "Create"
    },
    {
      "ruleId": "safe-mode",
      "kind": "FileSetting",
      "relativePath": "config/app.conf",
      "key": "mode",
      "expectedValue": "safe",
      "remediation": "Set"
    },
    {
      "ruleId": "powershell-version",
      "kind": "ToolVersion",
      "tool": "pwsh",
      "minimumVersion": "7.4.0",
      "remediation": "None"
    }
  ]
}
```

Rules:

- JSON depth is bounded to what this shape requires; trailing values, unknown
  properties, nulls, and wrong types are rejected. Duplicate property names use
  PowerShell `ConvertFrom-Json` last-member-wins behavior before shape
  validation and are not a separate error category;
- only `schemaVersion` `1` is supported;
- `policyId`/`ruleId` match `[A-Za-z0-9][A-Za-z0-9._-]{0,63}`;
- there are `1..100` rules with unique `ruleId`, preserved in file order;
- `relativePath` is a non-rooted provider-independent path using `/`, with
  `1..16` non-empty segments; `.`, `..`, wildcards, drive/provider qualifiers,
  NUL/control characters, and empty segments are rejected;
- `DirectoryExists` accepts exactly `ruleId`, `kind`, `relativePath`,
  `remediation`, and requires `remediation: Create`;
- `FileSetting` also requires `key` and `expectedValue`, and requires
  `remediation: Set`;
- `key` matches `[A-Za-z][A-Za-z0-9_.-]{0,63}`;
- `expectedValue` is trimmed, control-free, excludes `=`/CR/LF, and has 1–256
  characters;
- `ToolVersion` accepts exactly `ruleId`, `kind`, `tool`, `minimumVersion`,
  `remediation`; `tool` is exactly `pwsh`, minimum version parses as
  `System.Version`, and remediation is `None`.

On success, `Import-CompliancePolicy` emits one object with type name
`ComplianceAudit.Policy` and properties:

`SchemaVersion`, `PolicyId`, and `Rules`. Rules are normalized plain objects and
retain policy order. Imported policy objects are immutable by convention;
commands do not modify caller-owned objects.

## Target and adapter boundaries

`Test-Compliance` accepts targets by value and pipeline:

```powershell
[pscustomobject]@{
    Name     = 'fixture-a'
    RootPath = '/explicit/disposable/root'
}
```

Target rules:

- exactly `Name` and `RootPath` are required; additional note properties are
  ignored but not copied to findings;
- `Name` matches `[A-Za-z0-9][A-Za-z0-9._-]{0,63}`;
- `RootPath` resolves to one existing container;
- targets are retained in pipeline input order;
- duplicate target names in one invocation are rejected.

The implementation uses a capability table/object, accepted through the
advanced `-Adapter` parameter for tests and advanced use. It supplies
operations equivalent to:

- test/get/create directory;
- read/write a UTF-8 file;
- invoke the fixed `pwsh` version probe;
- resolve/contain a path beneath a target root.

The default adapter uses local PowerShell/.NET APIs. Adapter exceptions are
converted to structured findings/errors; injected scriptblocks are never read
from policy JSON. Before any read/write, the normalized destination must remain
beneath `RootPath`. Remediation rejects symlink/reparse-point traversal that
could escape the root.

## Configuration-file semantics

`FileSetting` reads a bounded file of at most 1 MiB as UTF-8. Each non-empty,
non-comment line is `key=value`, split at the first `=`. A comment's first
non-whitespace character is `#`. Keys/values are trimmed and use the same key/
value validation as policy. Duplicate keys, malformed lines, invalid UTF-8, or
an oversized file produce an `Error` finding.

Remediation:

- missing parent directories are not implicitly created by `FileSetting`;
- a missing file is created with exactly `key=expectedValue` plus the platform
  newline if its parent exists;
- an existing key is replaced in place logically; unrelated lines/comments and
  their order are preserved;
- a missing key is appended, adding one newline first only if required;
- a compliant file is not rewritten;
- output is UTF-8 without BOM and published through a complete candidate file
  in the same directory before replacement.

## Finding model and audit semantics

For every selected target/rule, `Test-Compliance` emits exactly one object with
type name `ComplianceAudit.Finding` and these properties in this order:

```text
PolicyId
Target
RuleId
RuleKind
Status
Observed
Expected
CanRemediate
Message
```

`Target` is a normalized object with `Name` and resolved `RootPath`.
`Status` is `Compliant`, `NonCompliant`, or `Error`.

| Rule | Compliant | NonCompliant | Error | CanRemediate |
| --- | --- | --- | --- | --- |
| `DirectoryExists` | directory exists | path missing | path exists but is not a directory, containment/provider failure | only missing path |
| `FileSetting` | parsed key equals expected | file/key missing or value differs | malformed/oversized/unreadable file, unsafe path | only non-error mismatch/missing |
| `ToolVersion` | observed version >= minimum | observed version < minimum | command missing, nonzero exit, invalid output | always false |

`Observed`/`Expected` are strings or `$null`; directory values use
`'Present'`/`'Missing'`, file values use actual/expected strings, and tool values
use normalized version strings. Noncompliance is data, not an error stream.

Ordering is target input order then policy rule order, regardless of execution
completion. `-RuleId` is repeatable; it filters without changing policy order.
An unknown requested rule is a terminating validation error.
`-ThrottleLimit` is `1..32`, default `1`; values greater than one may audit
independent target/rule pairs concurrently but must return only serializable
plain finding objects in stable order.

## Remediation contract

Typical pipeline:

```powershell
$policy = Import-CompliancePolicy -Path ./policy.json
$findings = $targets | Test-Compliance -Policy $policy
$findings | Repair-Compliance -Policy $policy -WhatIf
$findings | Repair-Compliance -Policy $policy -Confirm:$false
```

`Repair-Compliance`:

- accepts `ComplianceAudit.Finding` objects from the pipeline;
- supports `ShouldProcess` with ConfirmImpact `Medium`;
- only handles `NonCompliant` findings whose policy rule is remediable;
- re-observes current state immediately before mutation;
- emits no success object when state is already compliant, finding is
  non-remediable, or `ShouldProcess` returns false;
- performs at most one idempotent mutation per input finding;
- after mutation, re-observes and fails if compliance was not achieved;
- processes remediation serially; `-ThrottleLimit` is deliberately absent.

`ShouldProcess` target is `TARGET_NAME:RELATIVE_PATH`; action is respectively
`Create required directory` or `Set configuration value KEY`.

A successful change emits `ComplianceAudit.RemediationResult`:

```text
PolicyId
Target
RuleId
Action
Changed
Before
After
```

`Changed` is always `$true` for emitted results. `-WhatIf` uses PowerShell's
information stream and performs no adapter write. Re-running repair after a
successful run emits nothing and changes no file.

## Report export

```powershell
$findings | Export-ComplianceReport -Path PATH -Format Json -Force
$findings | Export-ComplianceReport -Path PATH -Format Csv -Force
```

The command collects pipeline findings, sorts them by received order, supports
`ShouldProcess`, and writes through a same-directory candidate/replacement.
Without `-Force`, an existing destination is a terminating error.

JSON shape:

```json
{
  "schemaVersion": 1,
  "findings": [
    {
      "policyId": "fixture-baseline",
      "target": "fixture-a",
      "ruleId": "cache-directory",
      "ruleKind": "DirectoryExists",
      "status": "Compliant",
      "observed": "Present",
      "expected": "Present",
      "canRemediate": false,
      "message": "required directory exists"
    }
  ]
}
```

CSV has that same lower-camel-case field order and invariant-culture string
values. JSON is UTF-8 without BOM; CSV uses the repository/runtime's
`Export-Csv` quoting semantics with `-NoTypeInformation` and UTF-8. No absolute
root path is exported. Empty input writes an empty `findings` array/header-only
CSV and succeeds.

## Errors and streams

Policy/target/unsafe-path/report setup failures are terminating. A per-rule
observation problem normally becomes an `Error` finding so a batch continues.
A remediation mutation/recheck failure writes a non-terminating error for that
finding and continues; `-ErrorAction Stop` promotes it normally.

Required fully qualified ErrorId prefixes:

- `CompliancePolicyInvalid,Import-CompliancePolicy`
- `CompliancePolicyUnsupported,Import-CompliancePolicy`
- `CompliancePolicyReadFailed,Import-CompliancePolicy`
- `ComplianceTargetInvalid,Test-Compliance`
- `ComplianceRuleNotFound,Test-Compliance`
- `ComplianceAdapterFailed,Test-Compliance`
- `ComplianceFindingInvalid,Repair-Compliance`
- `ComplianceRemediationFailed,Repair-Compliance`
- `ComplianceReportExists,Export-ComplianceReport`
- `ComplianceReportWriteFailed,Export-ComplianceReport`

Success uses stream 1, verbose diagnostics stream 4, `WhatIf` information stream
6, and errors stream 2. No secret-like environment values, full command lines,
stack traces, or file contents are logged. Native nonzero exits are checked
explicitly.

## Five guided milestones

### Milestone 1 — finding model and checks

Implement policy/domain normalization, the three pure check decisions over
injected observations, stable finding objects, and pipeline output.

Acceptance:

- every rule status boundary produces exact properties/type names;
- noncompliance stays on success output and adapter failures become `Error`
  findings where specified;
- multiple pipeline targets retain deterministic order;
- no `Format-*`/`Write-Host` appears in reusable commands;
- Pester tests tagged `M1` pass.

### Milestone 2 — module and discovery boundary

Implement manifest/exports/help, policy import, target validation, default
adapter reads, `-RuleId`, grouping-ready plain objects, and strict errors.

Acceptance:

- manifest and `Export-ModuleMember` expose exactly four commands;
- every exported command has synopsis, description, parameter, and example help;
- unknown JSON/rules/paths and duplicate IDs use exact ErrorIds;
- `TestDrive:` fixtures cannot escape their target root;
- parse/analyzer smoke and Pester `M2` tests pass.

### Milestone 3 — safe remediation

Implement re-observation, idempotent directory/file changes, `ShouldProcess`,
candidate replacement, recheck, and result objects.

Acceptance:

- `-WhatIf` performs zero writes and emits no remediation result;
- actual repair makes the target compliant and emits one result;
- the second run performs zero writes and emits nothing;
- malformed files/unsafe symlinks are never modified;
- Pester mocks assert exact `ShouldProcess` target/action and `M3` passes.

### Milestone 4 — automation completeness

Implement report JSON/CSV, redacted verbose diagnostics, fixed native `pwsh`
version adapter, stream behavior, and child-process usage.

Acceptance:

- reports are deterministic and exclude root paths/private adapter data;
- native missing/nonzero/malformed version cases are `Error` findings;
- child `pwsh` tests verify success/error/information streams and exit behavior
  under `-ErrorAction Stop`;
- import/export round trips preserve finding semantics where formats permit;
- Pester `M4` tests pass.

### Milestone 5 — throttling and integration

Implement bounded independent audit execution, stable reordering, cleanup,
starter/solution selection, cross-platform fixtures, and complete quality gates.

Acceptance:

- a controlled adapter proves active audits never exceed `ThrottleLimit`;
- reverse completion still returns target/rule order;
- exceptions/cancellation clean runspaces/jobs and preserve completed findings;
- tests pass with Pester 5.5.0 and 6.0.0 on PowerShell 7.4+ Linux, plus Pester
  6.0.0 on hosted Windows and `macos-15-intel`;
- PSScriptAnalyzer returns no configured warning/error.

## Starter, solution, and test architecture

```text
capstones/idiomatic/
├── SPEC.md
├── starter/
│   ├── ComplianceAudit.psd1
│   └── ComplianceAudit.psm1
├── solution/
│   ├── ComplianceAudit.psd1
│   └── ComplianceAudit.psm1
└── tests/
    ├── ComplianceAudit.Tests.ps1
    └── fixtures/
```

Private/Public subdirectories are permitted but not required. Tests choose the
module with `CAPSTONE_IMPLEMENTATION=starter|solution` or Pester container data.
One suite and fixture set applies to both. Tags `M1` through `M5` select
milestones.

The starter manifest, public signatures, parameter validation, help, output
type declarations, and adapter contract are complete. Unfinished function
bodies throw a precise `CapstoneNotImplemented` error after binding/validation,
so parsing, help, manifest, and analyzer checks remain meaningful.

## Deterministic fixtures and seams

Required fixtures:

- valid/minimal/all-rule policy plus unknown-property, duplicate-ID,
  unsupported-version, unsafe-path, and invalid-version policies;
- target roots for compliant, noncompliant, malformed-setting, path-collision,
  and idempotent repair scenarios;
- expected JSON/CSV reports;
- controlled adapter operations for tool exit/output, concurrency barriers,
  read/write failures, and write-call counts.

Tests use `TestDrive:`, Pester mocks, injected adapter scriptblocks/capabilities,
fixed plain objects, child `pwsh -NoProfile`, and stable sorting. They do not
touch registry, services, users, package managers, home directories, public
network, or privileged paths. Concurrency tests use synchronization primitives,
not elapsed-time performance thresholds.

## Dependencies and supported runtime

Exact supported/pinned tools:

- PowerShell `7.4+`;
- Pester `5.5.0` and `6.0.0` compatibility matrix;
- PSScriptAnalyzer `1.25.0`;
- .NET/PowerShell built-in APIs only at runtime.

No new module pin is proposed. Rejected: DSC, PSDesiredStateConfiguration,
cloud/vendor modules, package managers, configuration-management agents,
assertion/helper modules, native JSON tools, and remoting modules. The
comparative capstone's SimplySql dependency, if present elsewhere, is rejected
for this module.

Required behavior is cross-platform on Linux, Windows, and macOS under
PowerShell 7.4+. Provider-specific paths, registry behavior, elevation, and
Unix-only permissions are not part of acceptance.

## Exclusions

No production baseline, privileged remediation, registry/services/users,
Active Directory, package installation, credential handling, secret scanning,
remoting, DSC, cloud APIs, live policy download, rollback engine, destructive
delete, arbitrary native command from policy, platform-specific rule, UI, or
scheduled service is required.

## Quality and coverage commands

Focused:

```powershell
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Idiomatic -Implementation Solution -Tag M1
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Idiomatic -Implementation Solution -Tag All
```

Final:

```powershell
$files = Get-ChildItem ./capstones/idiomatic -Recurse -File |
    Where-Object Extension -in '.ps1', '.psm1'
foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count) { throw $errors }
}

Invoke-ScriptAnalyzer -Path . -Recurse `
    -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 `
    -Capstone Idiomatic -Implementation Solution -Tag All -CI
```

The repository intentionally has no numeric coverage threshold. Required
behavior is enforced through milestone/branch cases, the dual-Pester-major Linux
matrix, and the Pester 6 Linux/Windows/macOS-Intel matrix rather than adding a
misleading percentage gate.

## TaskManager-to-ComplianceAudit concept mapping

| TaskManager concept | ComplianceAudit continuation |
| --- | --- |
| Manifest and explicit four-command export | New exact four-command manifest; task command names are not reused |
| Thin CLI over reusable module functions | Module/pipeline behavior is normative; the optional launcher remains a parsing exercise |
| Private validation before trusting JSON | Exact policy shape/type/identifier/path validation before any adapter operation |
| Object-only success output and comment help | Typed policy/finding/remediation objects and complete help for every export |
| `ShouldProcess` around writes | Re-observe, preview, mutate at most once, recheck, and emit only completed remediation |
| Complete sibling-file replacement | Reused only for bounded configuration/report files beneath an approved root |
| `TestDrive:` and mocks | Extended with explicit disposable roots, injected adapters, safe-path containment, and concurrency controls |
| Pester/analyzer/OS CI | Preserved with Pester 5.5.0/6.0.0 and Linux/Windows/macOS-Intel coverage |

Do not carry over Task CRUD functions, Task records, the task JSON schema, or
the assumption that an arbitrary caller path is a safe fixture. Generalize only
the module, validation, stream, file-publication, and testing techniques.
The last pre-removal TaskManager source is commit
[`9b4506d`](https://github.com/mbrndiar/learning-powershell/tree/9b4506ddb110aaa9ea8bb0ab145e837e6ffd16e6/project/TaskManager)
at `project/TaskManager/`.
