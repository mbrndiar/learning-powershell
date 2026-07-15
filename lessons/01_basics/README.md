# 🌱 Module 1: Basics

PowerShell is an interactive shell and a scripting language built around .NET
objects. This module establishes the habits that make later automation
predictable: discover a command rather than guessing, inspect its output, and
write PowerShell syntax rather than syntax borrowed from another shell.

## 🎯 Objectives

- Select PowerShell 7.4+ (`pwsh`) deliberately and identify the running edition.
- Discover commands and read examples, detailed help, and parameter help.
- Recognize that commands emit objects from the very first pipeline.
- Create variables with useful types and convert values at explicit boundaries.
- Predict quoting, interpolation, subexpressions, and comparison operators.
- Distinguish an expression from a command invocation.

## 💡 Editions, discovery, and help

`pwsh` is PowerShell 7+, the current, cross-platform implementation. On
Windows, `powershell.exe` is Windows PowerShell 5.1: it is Windows-only and
has a different engine and module ecosystem. Prefer `pwsh -NoProfile` for
reproducible learning and scripts. Windows-only cmdlets or modules still need
Windows-specific documentation and testing.

Discovery is a workflow, not a memory test:

```powershell
Get-Command -Noun Process
Get-Command -Verb Get
Get-Help Get-ChildItem -Examples
Get-Help Get-ChildItem -Detailed
Get-Help Get-ChildItem -Parameter LiteralPath
```

PowerShell commands conventionally use `Verb-Noun`, such as `Get-Date`.
`Get-Verb` lists approved verbs for public functions. The convention makes
commands searchable and communicates whether a command reads, changes, or
converts data; it does not itself enforce safety.

## 💡 Objects first

The console renders output as text for people, but a command normally emits
objects. Capture or inspect them before deciding how to use them:

```powershell
$date = Get-Date
$date.GetType().FullName
Get-Process | Select-Object -First 1 | Get-Member
```

`Get-Member` describes properties, methods, and type names. The display may
show only a few properties, so displayed columns are not a file format to
parse. This mental model explains why `Where-Object` can filter a property
without scraping console text.

## 💡 Values, variables, and conversion

Variables start with `$` and are dynamically typed, while type literals make a
boundary explicit. Use them when a parameter, file field, or calculation
requires a particular representation:

```powershell
[string] $name = 'Ada'
[int] $count = '3'       # conversion succeeds
[decimal] $rate = 1.5
$total = $count * $rate
[datetime]::Parse('2026-07-15')
```

Type constraints can reject invalid input early, but conversion is not
validation: `"003"` and `3` may mean different things to an identifier-based
system. Preserve strings for identifiers with meaningful leading zeroes.

## 💡 Strings and expressions

Single quotes are literal; double quotes interpolate variables and escape
sequences. Use `$()` when the interpolated part is an expression or property:

```powershell
$name = 'Ada'
'Hello, $name'                 # literal text
"Hello, $name"                 # Hello, Ada
"Next: $($count + 1)"
"UTC: $($date.ToUniversalTime())"
```

PowerShell uses word operators: `-eq`, `-ne`, `-gt`, `-like`, `-match`,
`-and`, `-or`, and `-not`. They read consistently beside parameter names and
avoid shell-specific punctuation assumptions. `-like` uses wildcards; `-match`
uses regular expressions.

An expression produces a value (`$count + 1`, an `if` expression, a method
call). A command invocation resolves a command and binds arguments:

```powershell
($count + 1) * 2
Get-Date -Format 'yyyy-MM-dd'
(Get-Date).DayOfWeek
```

Parentheses group an expression or capture command output; they do not make
arbitrary C-like syntax valid. Orientation variables such as `$PSVersionTable`,
`$PWD`, `$HOME`, `$PID`, `$?`, and `$LASTEXITCODE` are useful to inspect, but
later modules define their operational semantics.

## 📚 Files

- [`01_discovery.ps1`](01_discovery.ps1) - edition, command discovery, and help patterns.
- [`02_values_and_operators.ps1`](02_values_and_operators.ps1) - typed values, strings, and operators.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/01_basics/01_discovery.ps1
pwsh -NoProfile -File lessons/01_basics/02_values_and_operators.ps1
```

Run `Get-Help` interactively after the scripts; help is most useful when you
change a parameter and observe the result.

## ⚠️ Common mistakes

- Starting `powershell.exe` by accident when the course expects `pwsh`.
- Treating table display text, help text, or `Out-String` output as data.
- Assuming `==`, `&&`, or Bash quoting has PowerShell meaning.
- Using double quotes for data that must stay literal, especially paths with `$`.
- Relying on implicit conversion where validation or a string identifier is needed.
- Assuming `$?` diagnoses every kind of failure; native-command handling comes later.

## ❓ Review questions

1. Which executable starts the cross-platform PowerShell edition?
2. What do `Get-Command -Noun Process` and `Get-Help -Examples` answer?
3. Why can a command look like it returned text while still returning objects?
4. When is `$()` required inside an interpolated string?
5. How do `-like` and `-match` differ?
6. What is the difference between `(Get-Date).Day` and `Get-Date -Format d`?
