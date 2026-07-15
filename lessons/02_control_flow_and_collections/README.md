# 🔀 Module 2: Control Flow and Collections

Automation becomes dependable when branches, loops, and collection shapes are
explicit. This module focuses on the places where PowerShell's convenient
collection semantics can surprise code copied from scalar-only languages.

## 🎯 Objectives

- Express Boolean intent instead of relying accidentally on truthiness.
- Compare with `$null` safely when a value could be a collection.
- Choose `if`, `switch`, and the appropriate looping construct.
- Model ordered sequences, stable array shape, and deliberate unrolling.
- Use hashtables and ordered dictionaries for named lookup and configuration.

## ⚖️ Boolean intent and `$null`

An `if` converts its condition to Boolean. `$null`, `$false`, numeric zero,
`''`, and an empty collection are falsey; non-empty strings and collections
are truthy. That is convenient for a simple existence check, but a business
rule should say what it means:

```powershell
if ([string]::IsNullOrWhiteSpace($name)) { throw 'Name is required.' }
if ($items.Count -eq 0) { 'Nothing to process' }
if ($enabled -eq $true) { 'Explicitly enabled' }
```

Put `$null` on the left: `$null -eq $value`. If `$value` is an array,
`$value -eq $null` performs element-wise filtering and can yield an array,
which is a poor scalar condition. `$null -eq $value` asks one clear question.

## 🔁 Decisions and loops

`if`/`elseif`/`else` branches and can produce a value. `switch` compares one
input against multiple clauses and can process a collection input; use `break`
when the first matching rule should win:

```powershell
$label = if ($score -ge 60) { 'Pass' } else { 'Retry' }
switch -Wildcard ($fileName) {
    '*.json' { 'structured data'; break }
    default  { 'other' }
}
switch -Regex ($text) { '^\d+$' { 'digits' } }
```

The `foreach` *statement* iterates an in-memory collection and supports
`break`/`continue`. `ForEach-Object` is a pipeline command: it receives items
as they arrive and is useful for streaming transformations. They are related
but not interchangeable.

```powershell
foreach ($number in $numbers) { $sum += $number }
$numbers | ForEach-Object { $_ * 2 }
while ($reader.Read()) { $reader.ReadLine() }
do { $answer = Read-Host 'Continue?' } while ($answer -ne 'yes')
```

Use `while` for a precondition and `do` when the body must run at least once.
Avoid changing the collection currently being enumerated; build a new result.

## 🧺 Arrays, shape, and unrolling

`@()` creates an array expression. PowerShell arrays are fixed-size .NET
arrays: `+=` creates a replacement array and is costly for large incremental
builds; use a generic list or emit pipeline output when scale matters.

```powershell
$none = @()
$one = @('Ada')
$names = @('Ada', 'Lin')
$nested = @($names)   # array subexpression captures output
$single = ,$names     # unary comma makes the array one element
```

Pipeline enumeration usually unwraps an array into its members. `@(...)`
stabilizes zero/one/many command output as an array; `,$value` intentionally
prevents unrolling for one boundary. Do not use either merely to hide an
uncertain contract—define the intended cardinality.

## 🗂️ Hashtables and ordered dictionaries

Hashtables map keys to values and are ideal for options or lookup:

```powershell
$settings = @{ Retries = 2; Enabled = $true }
$settings['Retries']
$settings.ContainsKey('Enabled')
$ordered = [ordered]@{ First = 1; Second = 2 }
```

Ordinary hashtable enumeration order is not a contract. `[ordered]@{}` keeps
insertion order, useful for presentation or deterministic serialization, but
keys remain the lookup mechanism. `-in` tests membership from the scalar side
(`'Ada' -in $names`); `-contains` tests from the collection side.

## 📚 Files

- [`01_flow.ps1`](01_flow.ps1) - decisions and loops.
- [`02_collections.ps1`](02_collections.ps1) - arrays, hashtables, null, and unrolling.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/02_control_flow_and_collections/01_flow.ps1
pwsh -NoProfile -File lessons/02_control_flow_and_collections/02_collections.ps1
```

## ⚠️ Common mistakes

- Using `if ($value -eq $null)` when `$value` might be an array.
- Treating `$null`, `@()`, and `@($null)` as the same cardinality.
- Assuming a hashtable preserves insertion order without `[ordered]`.
- Repeatedly using `+=` for a large array or mutating an enumerated collection.
- Confusing the `foreach` statement with `ForEach-Object`.
- Letting a broad wildcard or regex `switch` clause match more than intended.

## ❓ Review questions

1. Why is `$null -eq $value` safer than the reversed comparison?
2. When is truthiness adequate, and when should a test be explicit?
3. Which `switch` parameter changes matching to wildcards or regular expressions?
4. When would a `foreach` statement be clearer than `ForEach-Object`?
5. What does `@()` guarantee about command output?
6. What problem does `,$value` solve?
7. How do `[ordered]@{}` and `@{}` differ?
