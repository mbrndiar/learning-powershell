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
- Choose numeric and time representations that preserve the intended meaning.
- Predict quoting, interpolation, subexpressions, and comparison operators.
- Distinguish an expression from a command invocation.

## 🔎 Editions, discovery, and help

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

## 🧱 Objects first

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

The first scripts emit a `[pscustomobject]@{ ... }`: read it for now as a small
record whose labels name each value. Module 2 introduces the underlying
hashtable literal, and Module 3 builds custom objects deliberately. Seeing the
shape here makes the object-output convention explicit without requiring those
details early.

## 🔢 Values, variables, and conversion

Variables start with `$` and are dynamically typed, while type literals make a
boundary explicit. Integer literals without a suffix use `[int]` when they fit,
then `[long]`, then wider numeric representations. That literal choice does not
promise that later arithmetic stays integral: when an operation exceeds its
operand range PowerShell widens the result, sometimes to `[double]`.

```powershell
[string] $name = 'Ada'
[int] $count = '3'       # conversion succeeds
[long] $largeCount = 2147483648
[decimal] $rate = 1.5d
$total = $count * $rate

([int]::MaxValue + 1).GetType().FullName # System.Double
(2147483647L + 1L).GetType().FullName    # System.Int64
```

A constrained variable converts every assignment back to its declared type.
`[int] $bounded = [int]::MaxValue; $bounded += 1` therefore fails rather than
silently changing `$bounded` to another type. Choose `[long]` before arithmetic
that must remain an integer within its range, `[decimal]` for base-10 quantities
such as money, and `[bigint]` when arbitrary-size integer arithmetic is truly
required.

Binary floating-point cannot represent every decimal fraction exactly:
`0.1 + 0.2` is approximately `0.30000000000000004`, while
`0.1d + 0.2d` is the decimal value `0.3`. Neither representation supplies
domain validation. Conversion is also not validation: `"003"` and `3` can mean
different identifiers, so preserve identifiers as strings when leading zeroes
or exact spelling matter.

## ⏱️ Instants, durations, and civil time

Use `[DateTimeOffset]` for an unambiguous instant at a system boundary. Its
offset identifies the corresponding UTC instant; it does not preserve the
historical daylight-saving rules of a named civil time zone. Serialize boundary
instants with the round-trip `o` format:

```powershell
$start = [DateTimeOffset]::Parse(
    '2026-03-29T00:30:00+00:00',
    [Globalization.CultureInfo]::InvariantCulture
)
$end = [DateTimeOffset]::Parse(
    '2026-03-29T03:00:00+02:00',
    [Globalization.CultureInfo]::InvariantCulture
)
$wireValue = $start.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
$elapsed = $end - $start             # a TimeSpan, not another instant
$utc = [TimeZoneInfo]::ConvertTime($start, [TimeZoneInfo]::Utc)
```

Use `[TimeSpan]` for elapsed durations. When a rule is expressed in local civil
time—such as "09:00 in the configured business zone"—accept or resolve an
explicit `[TimeZoneInfo]` and let it apply that zone's rules. Time-zone IDs are
not uniformly portable across operating systems, so avoid embedding one in
cross-platform examples. Code that asks for the current instant should later
receive an injected clock so tests can supply a fixed value.

## 💬 Strings and expressions

Single quotes are literal; double quotes interpolate variables and escape
sequences. Use `$()` when the interpolated part is an expression or property:

```powershell
$name = 'Ada'
'Hello, $name'                 # literal text
"Hello, $name"                 # Hello, Ada
"Next: $($count + 1)"
"UTC: $($date.ToUniversalTime())"
```

PowerShell uses word operators such as `-eq`, `-ne`, `-gt`, `-like`, `-match`,
`-and`, `-or`, and `-not` for expressions. `-like` uses wildcards; `-match`
uses regular expressions. PowerShell 7 also has pipeline-chain operators:
`command1 && command2` runs the second pipeline only when the first succeeds,
while `command1 || command2` runs it after failure. They control command
execution and are not substitutes for Boolean `-and`/`-or`.

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
- [`03_numbers_and_time.ps1`](03_numbers_and_time.ps1) - numeric boundaries, instants, and durations.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/01_basics/01_discovery.ps1
pwsh -NoProfile -File lessons/01_basics/02_values_and_operators.ps1
pwsh -NoProfile -File lessons/01_basics/03_numbers_and_time.ps1
```

Run `Get-Help` interactively after the scripts; help is most useful when you
change a parameter and observe the result.

## ⚠️ Common mistakes

- Starting `powershell.exe` by accident when the course expects `pwsh`.
- Treating table display text, help text, or `Out-String` output as data.
- Using `==`, or confusing pipeline-chain `&&`/`||` with Boolean `-and`/`-or`.
- Using double quotes for data that must stay literal, especially paths with `$`.
- Relying on implicit conversion where validation or a string identifier is needed.
- Assuming widened integer arithmetic remains integral or that `[double]` is exact decimal arithmetic.
- Using local `[datetime]` values as unambiguous instants or using instants as durations.
- Assuming `$?` diagnoses every kind of failure; native-command handling comes later.

## ❓ Review questions

1. Which executable starts the cross-platform PowerShell edition?
2. What do `Get-Command -Noun Process` and `Get-Help -Examples` answer?
3. Why can a command look like it returned text while still returning objects?
4. When is `$()` required inside an interpolated string?
5. How do `-like` and `-match` differ?
6. What is the difference between `(Get-Date).Day` and `Get-Date -Format d`?
7. When would `&&` be appropriate instead of `-and`?
8. Why can an `[int]` constraint fail after arithmetic that produced a wider value?
9. When should a value be `[DateTimeOffset]`, `[TimeSpan]`, or interpreted with `[TimeZoneInfo]`?
