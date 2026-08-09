---
name: powershell-learning-path
description: Course-owned curriculum map, native checks, and solution boundaries for learning-powershell.
---

# Learning PowerShell learning path

This is the course-owned half of the Learning Mentor integration. The shared
[`guided-learning`](../guided-learning/SKILL.md) skill owns teaching policy,
evidence, state, and review behavior. This skill owns curriculum discovery and
native validation for `learning-powershell`.

The machine-readable authority is [`course.json`](course.json). Do not infer
objective identity from directory numbering; use the stable semantic IDs emitted
by the adapter.

## Adapter

Run from the repository root:

```bash
python3 .agents/skills/powershell-learning-path/scripts/course_adapter.py validate
python3 .agents/skills/powershell-learning-path/scripts/course_adapter.py state-projection
```

The adapter fails closed before state mutation when IDs, prerequisites, paths,
commands, implementation selectors, outcomes, or solution boundaries are invalid.

## Objective checks

Each command explicitly selects the learner implementation. The `env KEY=value`
form is an argument vector, not a shell assignment.

PowerShell module scripts deliberately exit zero before their TODOs are complete.
For module objectives, that run is only a syntax and wiring check: completion
also requires learner-authored checks for the README's boundary cases plus an
explanation. Project and capstone commands are deterministic Pester gates.

| objective | focused learner check |
| --- | --- |
| `module.basics` | `pwsh -NoProfile -File exercises/01_basics/exercises.ps1` |
| `module.control-flow-and-collections` | `pwsh -NoProfile -File exercises/02_control_flow_and_collections/exercises.ps1` |
| `module.objects-and-pipeline` | `pwsh -NoProfile -File exercises/03_objects_and_pipeline/exercises.ps1` |
| `module.functions-and-parameters` | `pwsh -NoProfile -File exercises/04_functions_and_parameters/exercises.ps1` |
| `module.errors-streams-and-files` | `pwsh -NoProfile -File exercises/05_errors_streams_and_files/exercises.ps1` |
| `module.modules-and-reuse` | `pwsh -NoProfile -File exercises/06_modules_and_reuse/exercises.ps1` |
| `module.system-automation` | `pwsh -NoProfile -File exercises/07_system_automation/exercises.ps1` |
| `module.testing-with-pester` | `pwsh -NoProfile -File exercises/08_testing_with_pester/exercises.ps1` |
| `module.tooling-and-debugging` | `pwsh -NoProfile -File exercises/09_tooling_and_debugging/exercises.ps1` |
| `module.apis-and-automation` | `pwsh -NoProfile -File exercises/10_apis_and_automation/exercises.ps1` |
| `module.concurrency` | `pwsh -NoProfile -File exercises/11_concurrency/exercises.ps1` |
| `module.sqlite-and-transactions` | `pwsh -NoProfile -File exercises/12_sqlite_and_transactions/exercises.ps1` |
| `project.tasks` | `pwsh -NoProfile -File projects/Invoke-ProjectTests.ps1 -Implementation Starter -Tag All` |
| `capstone.comparative` | `pwsh -NoProfile -File capstones/Invoke-CapstoneTests.ps1 -Capstone Comparative -Implementation Starter -Tag All` |
| `capstone.idiomatic` | `pwsh -NoProfile -File capstones/Invoke-CapstoneTests.ps1 -Capstone Idiomatic -Implementation Starter -Tag All` |

## Diagnostics and evidence

- Treat an untouched starter failure as routing information, not completion.
- Record completion only after the focused native check succeeds and the learner
  can explain the result.
- Keep every `solution_paths` entry locked until the objective's
  `solution_unlock_after` attempt threshold is reached.
- Escalate from the focused check to the repository's documented package/full
  verification only after the focused objective is healthy.
