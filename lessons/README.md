# 🎓 Lessons

Eleven modules build from interactive language basics to production-minded
automation. Each script is self-contained, non-interactive, safe to run in CI,
and uses `pwsh -NoProfile -File`. The examples are deliberately small: read
the README first, predict the object output, run the script, and then alter one
input to test your mental model.

## 🔁 Recommended study loop

1. Read the module framing, objectives, concepts, and review questions.
2. Run each linked script from the repository root with `pwsh -NoProfile`.
3. Inspect a value or command output with `Get-Member`; do not infer data shape
   from a formatted table.
4. Change one safe input and explain the resulting object, stream, or error.
5. Complete the matching [exercise](../exercises/README.md) before opening its
   reference solution.
6. Run the narrowest relevant script or Pester test, then analyzer and broader
   tests as described in Module 9.

PowerShell expertise is discovery-driven. No curriculum can list every
provider, module, parameter set, or object type. Use `Get-Command`,
`Get-Help -Examples`, `Get-Member`, and small experiments to learn the command
actually available in the current edition and platform. The filesystem,
environment, Registry, service, SQLite, and cloud boundaries are not
interchangeable: confirm the installed provider/module and test the exact
platform before carrying an example to real state.

## 🧱 Example structure

Lesson scripts enable strict mode, keep state local, and emit inspectable
objects rather than formatted output. They avoid network calls and clean up
their disposable files or modules. Occasional comments such as “Explore
interactively” or “Inspect interactively” suggest a safe local extension; they
are not requirements for CI. Some platform capabilities, notably Windows
services and Registry, are named only with their portability caveats.
Tests and experiments that mutate files belong in `TestDrive:` or a
self-created disposable root, never a personal or machine-wide path.

## 🧭 Modules and checkpoints

1. [Basics](01_basics/README.md)
2. [Control Flow and Collections](02_control_flow_and_collections/README.md)
3. [Objects and Pipeline](03_objects_and_pipeline/README.md)
4. [Functions and Parameters](04_functions_and_parameters/README.md)
5. [Errors, Streams, and Files](05_errors_streams_and_files/README.md)
6. [Modules and Reuse](06_modules_and_reuse/README.md)
7. [System Automation](07_system_automation/README.md)
8. [Testing with Pester](08_testing_with_pester/README.md)
9. [Tooling and Debugging](09_tooling_and_debugging/README.md)
10. [APIs and Automation](10_apis_and_automation/README.md)
11. [Concurrency](11_concurrency/README.md)

**After modules 1–3:** you should be able to discover commands, explain object
shape, and transform a collection without parsing text.
**After modules 4–7:** write a validated function/module boundary, persist
data safely, and preview an idempotent mutation.
**After modules 8–11:** test behavior, diagnose failures, design offline API
seams, and decide whether parallelism is justified. Then start the capstone.
