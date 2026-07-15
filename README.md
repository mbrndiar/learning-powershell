# ⚡ learning-powershell

A hands-on, self-contained introduction to idiomatic PowerShell 7.4+. This
course teaches PowerShell as an object-based automation language: compose
commands through the pipeline, return useful data, and make state changes
safe, testable, and repeatable.

## 🎯 What you will learn

By the end, you will be able to discover commands, work with objects and
collections, write advanced functions and modules, handle errors and files,
test with Pester, analyze code with PSScriptAnalyzer, automate APIs, and
choose an appropriate concurrency tool. The capstone combines those skills in
a persistent command-line task manager.

## ✅ Requirements

- PowerShell 7.4 or newer (`pwsh`), on Windows, macOS, or Linux
- Internet access only once to install Pester and PSScriptAnalyzer; lessons run
  offline
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
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path ./project/TaskManager/tests -Output Detailed
```

The workflow in [`.github/workflows/lessons.yml`](.github/workflows/lessons.yml)
parses starter exercises, runs lessons and solutions, analyzes scripts, and
runs capstone tests. Module 9 explains the narrow-to-wide loop.

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
   and operators.
2. [Control Flow and Collections](lessons/02_control_flow_and_collections/README.md):
   conditions, loops, arrays, hashtables, truthiness, and `$null`.
3. [Objects and Pipeline](lessons/03_objects_and_pipeline/README.md): object
   composition, inspection, filtering, projection, grouping, and measuring.
4. [Functions and Parameters](lessons/04_functions_and_parameters/README.md):
   advanced functions, validation, pipeline input, and splatting.
5. [Errors, Streams, and Files](lessons/05_errors_streams_and_files/README.md):
   stream intent, catchable failures, portable paths, and structured files.
6. [Modules and Reuse](lessons/06_modules_and_reuse/README.md): module
   boundaries, exports, help, and injectable dependencies.
7. [System Automation and Native Commands](lessons/07_system_automation/README.md):
   providers, processes, native exit codes, idempotency, and WhatIf.
8. [Testing with Pester](lessons/08_testing_with_pester/README.md): behavior
   tests, fixtures, TestDrive, and mocks.
9. [Tooling and Debugging](lessons/09_tooling_and_debugging/README.md): strict
   mode, debugger workflow, analysis, CI, and secret hygiene.
10. [APIs and Automation](lessons/10_apis_and_automation/README.md): offline
    request seams, JSON, URI construction, retries, and automation design.
11. [Concurrency](lessons/11_concurrency/README.md): jobs, parallel pipeline
    work, serialization, ordering, throttling, and cleanup.

Each has matching [exercises](exercises/README.md).

### 📜 Script map

1. **Basics:** [discovery](lessons/01_basics/01_discovery.ps1),
   [values and operators](lessons/01_basics/02_values_and_operators.ps1)
2. **Control Flow and Collections:** [flow](lessons/02_control_flow_and_collections/01_flow.ps1),
   [collections](lessons/02_control_flow_and_collections/02_collections.ps1)
3. **Objects and Pipeline:** [object pipeline](lessons/03_objects_and_pipeline/01_object_pipeline.ps1),
   [group and measure](lessons/03_objects_and_pipeline/02_group_and_measure.ps1)
4. **Functions and Parameters:** [advanced functions](lessons/04_functions_and_parameters/01_advanced_functions.ps1),
   [pipeline and splatting](lessons/04_functions_and_parameters/02_pipeline_and_splatting.ps1)
5. **Errors, Streams, and Files:** [streams and errors](lessons/05_errors_streams_and_files/01_streams_and_errors.ps1),
   [structured files](lessons/05_errors_streams_and_files/02_structured_files.ps1)
6. **Modules and Reuse:** [module boundary](lessons/06_modules_and_reuse/01_module_boundary.ps1),
   [dependency injection](lessons/06_modules_and_reuse/02_dependency_injection.ps1)
7. **System Automation:** [providers and processes](lessons/07_system_automation/01_providers_and_processes.ps1),
   [safe state change](lessons/07_system_automation/02_safe_state_change.ps1)
8. **Testing with Pester:** [Pester basics](lessons/08_testing_with_pester/01_pester_basics.ps1),
   [TestDrive](lessons/08_testing_with_pester/02_testdrive_and_mock.ps1)
9. **Tooling and Debugging:** [strict mode](lessons/09_tooling_and_debugging/01_strict_mode.ps1),
   [feedback loop](lessons/09_tooling_and_debugging/02_feedback_loop.ps1)
10. **APIs and Automation:** [injected request](lessons/10_apis_and_automation/01_injected_request.ps1),
    [URI construction](lessons/10_apis_and_automation/02_uri_and_retry_design.ps1)
11. **Concurrency:** [background job](lessons/11_concurrency/01_background_job.ps1),
    [parallel ordering](lessons/11_concurrency/02_parallel_ordering.ps1)

## 🏆 Capstone

[TaskManager](project/TaskManager/README.md) is a compact PowerShell module and
CLI. It persists JSON tasks atomically-ish, exposes objects rather than
formatted text, validates public inputs, supports `-WhatIf`, and has isolated
Pester tests. Extend it one behavior at a time, with a test first or alongside
the change.

## 🗒️ Getting help from the material

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
compatibility and security considerations from the PowerShell 7.4+,
cross-platform material here. Always read command help and test automations in
a safe scope before using them against production systems.