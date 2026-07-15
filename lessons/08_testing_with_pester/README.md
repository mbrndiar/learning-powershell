# 8. Testing with Pester

## Objectives

Write behavior-oriented Pester tests with `Describe`, `Context`, `It`, `Should`,
`BeforeEach`, `TestDrive:`, and `Mock`.

## Concepts

Pester describes observable behavior. `BeforeEach` creates independent state;
`TestDrive:` is an isolated temporary test filesystem. Mock at an external
boundary (file, process, web request), not every internal helper. Test outputs,
errors, and state transitions rather than implementation details.

## Files

- `01_pester_basics.ps1` - a small in-memory behavior suite.
- `02_testdrive_and_mock.ps1` - isolated file tests and a boundary mock.

## Run

```powershell
pwsh -NoProfile -File lessons/08_testing_with_pester/01_pester_basics.ps1
pwsh -NoProfile -File lessons/08_testing_with_pester/02_testdrive_and_mock.ps1
```

Pester must be installed as described in [setup](../../docs/SETUP.md).

## Common mistakes

- Sharing mutable state across `It` blocks.
- Testing a private implementation step instead of a contract.
- Writing tests that use real user files or the network.

## Review questions

1. Why does `BeforeEach` improve isolation?
2. When should you use `TestDrive:`?
3. What is a good mock boundary?
