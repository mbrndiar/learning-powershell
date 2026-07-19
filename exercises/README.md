# 🧠 Exercises

Every lesson module has a matching directory containing a problem contract,
parseable starter, and executable reference. Exercises deliberately practice
behavior and boundaries rather than a specific spelling of the implementation.

## 📁 What each directory contains

- `README.md` states prerequisites, exact functions, behavior, edge cases, and
  commands to run.
- `exercises.ps1` is a parseable starter with explicit `TODO` markers.
- `solutions.ps1` is one reference implementation with self-checks.

## 🔁 Workflow

1. Read the matching lesson and exercise contract.
2. Run the starter once to see its current TODO failure or explicitly skipped
   test plan.
3. Replace one TODO at a time and call the function with normal, boundary, and
   invalid inputs.
4. From Module 8 onward, add Pester examples that assert behavior and errors.
5. Run the reference only after your attempt; compare contracts, edge cases,
   stream behavior, and tests rather than copying its text.

```powershell
pwsh -NoProfile -File exercises/01_basics/exercises.ps1
pwsh -NoProfile -File exercises/01_basics/solutions.ps1
```

The starter suppressions are intentional. A TODO function does not yet use its
parameters or call `ShouldProcess`, so its narrowly scoped PSScriptAnalyzer
suppressions prevent the learning skeleton from obscuring analyzer feedback.
Remove a suppression when the completed implementation satisfies the rule; do
not expand a suppression merely to hide a real issue.

## 🧪 Pester progression

Modules 1–7 can be checked with focused calls and the solution self-checks.
Beginning with Module 8, write Pester `Describe`/`It` tests alongside the
function: assert normal behavior, empty or boundary input, and terminating
failures where relevant. Use injected scriptblocks and `TestDrive:` instead of
the network or personal files. A passing reference solution is evidence, not a
replacement for understanding why its contract holds.

Module 12 adds the exact SimplySql dependency from [setup](../docs/SETUP.md).
Its exercise uses a fresh disposable SQLite database and closes every owned
connection before cleanup.

After all twelve exercise solutions, continue with the required
[Tasks applied project](../projects/tasks/README.md). It changes the scale from
one-file exercises to a shared module, two repositories, an HTTP boundary, a
CLI, and tagged starter/solution acceptance tests.
