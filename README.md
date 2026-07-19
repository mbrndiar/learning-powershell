# ⚡ learning-powershell

A hands-on, self-contained introduction to idiomatic PowerShell 7.4+. This
course teaches PowerShell as an object-based automation language: compose
commands through the pipeline, return useful data, and make state changes
safe, testable, and repeatable.

## 🎯 What you will learn

By the end, you will be able to discover commands, work with objects and
collections, write advanced functions and modules, handle errors and files,
test with Pester, analyze code with PSScriptAnalyzer, automate APIs, and
choose an appropriate concurrency tool. A focused SQLite/transaction module
prepares you for a required Tasks applied project and two capstones: one shared
cross-language contract and one idiomatic PowerShell project.

## 👤 Who this is for

This course is for self-directed learners who can use a terminal and edit text
files but do not need prior PowerShell experience. Prior programming or shell
experience helps, but the course explains PowerShell's object pipeline,
collection behavior, function contracts, and automation boundaries directly
rather than assuming another language's syntax or semantics.

## ✅ Requirements

- PowerShell 7.6 LTS is recommended for a new environment; PowerShell 7.4 is the
  minimum language/runtime floor until its support retirement on November 10,
  2026
- `pwsh` on Windows, macOS, or Linux; Windows PowerShell 5.1 is outside scope
- Internet access only once to install
  [Pester](https://pester.dev/docs/introduction/installation) and
  [PSScriptAnalyzer](https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/overview);
  Module 12, the Tasks project, and the comparative capstone additionally use pinned
  [SimplySql](https://www.powershellgallery.com/packages/SimplySql/2.2.0.106)
  `2.2.0.106`; lessons run offline
- On macOS, Module 12, the Tasks project, and the comparative capstone require an Intel/x64 host:
  the pinned SimplySql package does not bundle an Apple Silicon (`osx-arm64`)
  native provider; the remaining course material is architecture-independent
- Optional: Visual Studio Code with the PowerShell extension

See [docs/SETUP.md](docs/SETUP.md) for platform-specific installation and
safe execution-policy guidance.

## ▶️ Active study loop

From the repository root, run a lesson with:

```powershell
pwsh -NoProfile -File lessons/01_basics/01_discovery.ps1
```

For every module:

1. Read its README and predict each script's result.
2. Run the script, then change one small value and explain the difference.
3. Complete `exercises/<module>/exercises.ps1` without reading its solution.
4. Run the reference `solutions.ps1` and compare contracts, not just text.
5. Answer the review questions from memory and revisit uncertain concepts.

PowerShell commands emit objects. Inspect them with `Get-Member` or save them
to a variable instead of assuming displayed table text is the data.

## 🔁 Developer feedback loop

Start with the smallest changed script, then widen feedback:

```powershell
pwsh -NoProfile -File lessons/04_functions_and_parameters/01_advanced_functions.ps1
Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Force
Import-Module Pester -RequiredVersion 6.0.0 -Force
pwsh -NoProfile -File lessons/09_tooling_and_debugging/03_formatting_stage.ps1
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit
pwsh -NoProfile -File exercises/10_apis_and_automation/solutions.ps1
pwsh -NoProfile -File lessons/08_testing_with_pester/03_coverage_diagnostic.ps1
pwsh -NoProfile -File ./projects/Invoke-ProjectTests.ps1 -Implementation All -Tag Smoke
pwsh -NoProfile -File ./projects/Invoke-ProjectTests.ps1 -Implementation Solution -Tag All
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 -Implementation All -Tag Smoke
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 -Capstone Comparative -Implementation Solution -Tag All
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 -Capstone Idiomatic -Implementation Solution -Tag All
```

The workflow in [`.github/workflows/lessons.yml`](.github/workflows/lessons.yml)
parses starter exercises, runs lessons and solutions, analyzes scripts, and
runs both capstone conformance suites. Linux covers the PowerShell 7.4
compatibility floor and the current container with Pester 5.5.0 and 6.0.0;
current hosted Windows and the `macos-15-intel` image cover Pester 6.0.0.
Those are the exact automated combinations, not evidence for every
7.4+/operating-system/architecture pairing.
The course has no coverage threshold:
Module 8 explains why coverage is a diagnostic signal rather than proof of test
quality. Its formatting example previews the built-in `CodeFormatting` preset,
but formatting is not a CI success criterion; analyzer, tests, and capstone
conformance are. Module 9 explains the complete narrow-to-wide loop.

## 📐 Conventions

- Run commands shown after `PS>`; do not type that prompt.
- Examples use full command names, never aliases. `Get-ChildItem`, not `ls`.
- Public functions use approved `Verb-Noun` names, `[CmdletBinding()]`, and
  validated parameters where a boundary needs them.
- A bare expression or `return` emits success-stream output; `Write-Output` is
  usually unnecessary. Do not use `Write-Host` in reusable functions.
- Reusable functions return objects/data and never call `Format-*`; format only
  at an interactive presentation boundary.
- `$null` belongs on the left of comparisons (`$null -eq $value`) to avoid
  collection filtering surprises. The unary comma, `,$value`, preserves a
  value as one array element when array unrolling matters.
- Parentheses group a *command invocation* or expression but do not turn
  PowerShell into arbitrary C-like expression syntax. Use PowerShell operators
  and syntax deliberately.

## 🗺️ Course outline

1. [Basics](lessons/01_basics/README.md): editions, help, variables, strings,
   numeric/time boundaries, and operators.
2. [Control Flow and Collections](lessons/02_control_flow_and_collections/README.md):
   conditions, loops, arrays, hashtables, sets, truthiness, and `$null`.
3. [Objects and Pipeline](lessons/03_objects_and_pipeline/README.md): object
   composition, inspection, filtering, projection, grouping, and measuring.
4. [Functions and Parameters](lessons/04_functions_and_parameters/README.md):
   advanced functions, validation, pipeline input, and splatting.
5. [Errors, Streams, and Files](lessons/05_errors_streams_and_files/README.md):
   stream intent, catchable failures, portable paths, text/bytes, and structured files.
6. [Modules and Reuse](lessons/06_modules_and_reuse/README.md): module
   boundaries, data files, exports, help, and injectable dependencies.
7. [System Automation and Native Commands](lessons/07_system_automation/README.md):
   providers, processes, native exit codes, idempotency, and WhatIf.
8. [Testing with Pester](lessons/08_testing_with_pester/README.md): behavior
   tests, fixtures, TestDrive, mocks, and coverage diagnostics.
9. [Tooling and Debugging](lessons/09_tooling_and_debugging/README.md): strict
   mode, debugger workflow, formatting, analysis, CI, and secret hygiene.
10. [APIs and Automation](lessons/10_apis_and_automation/README.md): offline
    request seams, `Invoke-RestMethod`, JSON, URI construction, retries, and
    automation design.
11. [Concurrency](lessons/11_concurrency/README.md): jobs, parallel pipeline
    work, runspace pools, serialization, ordering, throttling, cancellation,
    and cleanup.
12. [SQLite and Transactions](lessons/12_sqlite_and_transactions/README.md):
    SimplySql connections, parameterized SQL, schemas, transactions, migration,
    WAL, and local locking.

Each has matching [exercises](exercises/README.md). After Module 12, complete the
required [Tasks applied project](projects/tasks/README.md) before either
capstone.

### 📜 Script map

1. **Basics:** [discovery](lessons/01_basics/01_discovery.ps1),
   [values and operators](lessons/01_basics/02_values_and_operators.ps1),
   [numbers and time](lessons/01_basics/03_numbers_and_time.ps1)
2. **Control Flow and Collections:** [flow](lessons/02_control_flow_and_collections/01_flow.ps1),
   [collections](lessons/02_control_flow_and_collections/02_collections.ps1)
3. **Objects and Pipeline:** [object pipeline](lessons/03_objects_and_pipeline/01_object_pipeline.ps1),
   [group and measure](lessons/03_objects_and_pipeline/02_group_and_measure.ps1)
4. **Functions and Parameters:** [advanced functions](lessons/04_functions_and_parameters/01_advanced_functions.ps1),
   [pipeline and splatting](lessons/04_functions_and_parameters/02_pipeline_and_splatting.ps1)
5. **Errors, Streams, and Files:** [streams and errors](lessons/05_errors_streams_and_files/01_streams_and_errors.ps1),
   [structured files](lessons/05_errors_streams_and_files/02_structured_files.ps1),
   [text and bytes](lessons/05_errors_streams_and_files/03_text_and_bytes.ps1)
6. **Modules and Reuse:** [module boundary](lessons/06_modules_and_reuse/01_module_boundary.ps1),
   [dependency injection](lessons/06_modules_and_reuse/02_dependency_injection.ps1)
7. **System Automation:** [providers and processes](lessons/07_system_automation/01_providers_and_processes.ps1),
   [safe state change](lessons/07_system_automation/02_safe_state_change.ps1)
8. **Testing with Pester:** [Pester basics](lessons/08_testing_with_pester/01_pester_basics.ps1),
   [TestDrive](lessons/08_testing_with_pester/02_testdrive_and_mock.ps1),
   [coverage diagnostics](lessons/08_testing_with_pester/03_coverage_diagnostic.ps1)
9. **Tooling and Debugging:** [strict mode](lessons/09_tooling_and_debugging/01_strict_mode.ps1),
   [feedback loop](lessons/09_tooling_and_debugging/02_feedback_loop.ps1),
   [formatting stage](lessons/09_tooling_and_debugging/03_formatting_stage.ps1)
10. **APIs and Automation:** [injected request](lessons/10_apis_and_automation/01_injected_request.ps1),
    [URI construction](lessons/10_apis_and_automation/02_uri_and_retry_design.ps1),
    [`Invoke-RestMethod` wrapper](lessons/10_apis_and_automation/03_rest_method_wrapper.ps1)
11. **Concurrency:** [background job](lessons/11_concurrency/01_background_job.ps1),
    [parallel ordering](lessons/11_concurrency/02_parallel_ordering.ps1),
    [runspace pool](lessons/11_concurrency/03_runspace_pool.ps1)
12. **SQLite and Transactions:** [connection, schema, and parameters](lessons/12_sqlite_and_transactions/01_connection_schema_and_parameters.ps1),
    [transactions and migration](lessons/12_sqlite_and_transactions/02_transactions_and_migration.ps1)

## 🧩 Applied project

The required [Tasks service and client](projects/tasks/README.md) combines the
course's major boundaries in one bounded application:

- one manifest-based module with stable Task and Store objects;
- interchangeable SimplySql/SQLite and versioned Markdown repositories;
- pipeline-friendly commands and `ShouldProcess` for every mutation;
- a loopback-only `HttpListener` adapter with strict JSON/error behavior; and
- a thin `Invoke-RestMethod` CLI that never accesses storage directly.

Work through its five tagged milestones in `starter/`. The matching `solution/`
and shared Pester suite prove the same domain behavior across both repositories
and the HTTP boundary. This project replaces the earlier JSON-only TaskManager
with a deeper applied bridge rather than treating it as a third capstone.

## 🏆 Capstones

The [comparative and idiomatic capstones](capstones/README.md) use paired
`starter/` and `solution/` targets plus shared Pester selection. The comparative
project implements a frozen SQLite versioned-configuration-store contract used
across the learning repositories after the focused Module 12 bridge. Its
conformance scope is a pinned SQLite provider on supported local filesystems
and operating systems, not every
PowerShell provider, architecture, or network filesystem. The idiomatic project
builds a PowerShell-native compliance audit and safe-remediation module whose
required operations stay inside explicit disposable roots.

## 🆘 Getting help from the material

[CHEATSHEET.md](CHEATSHEET.md) is a quick glossary after the course, not a
replacement for command help. Each module README links directly to its scripts,
states the expected contracts, names common mistakes, and ends with review
questions. Start with the module guide, run the small offline examples, then
use the matching exercise contract before consulting its reference solution.

PowerShell expertise is discovery-driven: use `Get-Command` to find commands,
`Get-Help -Examples` and parameter help to learn their contracts, and
`Get-Member` to inspect actual runtime output. When a detail differs by
platform, PowerShell edition, module version, or provider, the installed
command's help is the authority.

## 🧱 Course boundaries

This course builds practical foundations, not every PowerShell subsystem.
Desired State Configuration, remoting at scale, GUI work, Azure/AWS modules,
organization-specific administration, credential governance, and high-scale
concurrency need additional domain-focused study. Windows PowerShell 5.1,
Windows services, Registry, and legacy Windows-only modules have different
compatibility and security considerations from the PowerShell 7.4+ language
floor and current-LTS cross-platform material here. Module 12 is a focused
SQLite/SimplySql bridge, not a general SQL or database-administration course.
Always read command help and test automations in a safe scope before using them
against production systems.
