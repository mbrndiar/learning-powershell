# 🧪 Module 8: Testing with Pester

Pester gives PowerShell behavior an executable contract. This repository tests
the course with Pester 5.5.0 and 6.0.0 on Linux and with 6.0.0 on hosted Windows
and macOS. The fundamentals used here are shared; import the intended version
explicitly and check that version's documentation for runner-configuration
differences while keeping test intent version-independent.

## 🎯 Objectives

- Organize Pester tests into discovery, containers, examples, and assertions.
- Write Arrange-Act-Assert tests that describe observable behavior.
- Isolate mutable test state with setup blocks and `TestDrive:`.
- Assert values and failure behavior using `Should`.
- Mock only meaningful external lookup boundaries.
- Recognize deterministic-test and coverage limitations.

## 🏗️ Discovery and test structure

Pester discovers test files, then evaluates `Describe`/`Context` containers and
their `It` examples. Use a hierarchy that answers *what behavior* and *under
which condition*:

```powershell
Describe 'Get-Total' {
    Context 'with valid collections' {
        It 'adds supplied numbers' {
            # Arrange, Act, Assert
            Get-Total -Number @(2, 3) | Should -Be 5
        }
    }
}
```

Keep test declarations free of expensive side effects because discovery and
execution phases differ. Arrange input and state, act once, then assert the
result—not incidental console output or a private helper's implementation.

## ✅ Assertions, errors, and isolation

`Should` checks behavior: `-Be`, `-BeTrue`, `-BeFalse`, `-BeNullOrEmpty`,
`-Match`, and collection assertions cover common contracts. Assert terminating
failures with a scriptblock:

```powershell
{ Get-Task -LiteralPath 'missing.json' } | Should -Throw '*not found*'
```

Use `BeforeAll` for stable setup such as importing a module. Use `BeforeEach`
for state each example changes. `TestDrive:` is an isolated filesystem location
for a *test container*; it is not automatically reset per `It`. Give each `It`
its own filename or reset content in `BeforeEach`, and never point tests at a
real user path.

## 🎭 Mocks at the edge

Mock a command where the code looks up the outside world—filesystem, HTTP,
native process, clock—not every internal helper:

```powershell
Mock -CommandName Get-Content -MockWith { 'mocked text' }
Get-FirstLine -LiteralPath 'unreachable.txt' | Should -Be 'mocked text'
```

For module code, Pester mocks can need module scope so the command resolution
inside the module sees the mock; consult the Pester version's module-mocking
syntax. Assert behavior and important calls only when call behavior itself is
the contract. Over-mocking couples tests to implementation and misses real
integration mistakes.

## 📏 Determinism and coverage

Inject time, random sources, delays, requests, and paths so tests do not depend
on the network, wall clock, machine locale, or execution order. Coverage can
show executed lines, but it cannot prove assertion quality, concurrency safety,
or that all business cases were considered. Use it as a signal to investigate,
not a quality score.

## 📚 Files

- [`01_pester_basics.ps1`](01_pester_basics.ps1) - small in-memory behavior suite.
- [`02_testdrive_and_mock.ps1`](02_testdrive_and_mock.ps1) - isolated files and a boundary mock.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/08_testing_with_pester/01_pester_basics.ps1
pwsh -NoProfile -File lessons/08_testing_with_pester/02_testdrive_and_mock.ps1
```

Pester must be installed as described in [setup](../../docs/SETUP.md).
To prove a test works under both supported majors, use separate clean sessions:

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 5.5.0 -Force; Invoke-Pester -Path ./project/TaskManager/tests -Output Detailed'
pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 6.0.0 -Force; Invoke-Pester -Path ./project/TaskManager/tests -Output Detailed'
```

## ⚠️ Common mistakes

- Sharing mutable state across `It` examples or relying on their order.
- Assuming `TestDrive:` is recreated for every `It`.
- Importing whichever Pester version happens to resolve first and calling that a
  compatibility check.
- Testing a private implementation step instead of output, error, or state.
- Mocking all collaborators and no longer testing useful composition.
- Using real files, network access, sleeps, or current time in unit tests.
- Treating line coverage as proof of correctness.

## ❓ Review questions

1. What is the relationship between `Describe`, `Context`, and `It`?
2. What does Arrange-Act-Assert make easier to read?
3. When should setup use `BeforeAll` versus `BeforeEach`?
4. What is the lifecycle scope of `TestDrive:`?
5. How do you assert a terminating error?
6. Where is a useful mock boundary?
7. What important qualities does coverage not prove?
