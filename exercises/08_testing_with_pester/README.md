# 🧪 Exercise 8: Testing with Pester

## Prerequisites

Complete [Module 8](../../lessons/08_testing_with_pester/README.md) and install
Pester using [setup](../../docs/SETUP.md).

## Tasks

- Implement `Get-Initial -Name <string>` to return the uppercase first
  character, or `$null` for empty input.
- Add a `Describe` block with at least two `It` examples.

## Contract and edge cases

Test normal lowercase input and empty input; add a whitespace or already
uppercase case if it clarifies your contract. Tests should call the public
function and assert its success-stream value with `Should`, not inspect the
TODO text or use external files.

## Run

```powershell
pwsh -NoProfile -File exercises/08_testing_with_pester/exercises.ps1
pwsh -NoProfile -File exercises/08_testing_with_pester/solutions.ps1
```
