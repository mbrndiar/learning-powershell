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
- Distinguish filtering equality, shallow copies, identity, and set membership.

## ⚖️ Boolean intent and `$null`

An `if` converts its condition to Boolean. `$null`, `$false`, numeric zero,
`''`, and an empty collection are falsey. A one-element collection takes the
truthiness of that element, so `@(0)` and `@($false)` are falsey; a collection
with two or more elements is truthy even when every element is falsey. That
convenience is easy to misread, so a business rule should say what it means:

```powershell
if ([string]::IsNullOrWhiteSpace($name)) { throw 'Name is required.' }
if ($items.Count -eq 0) { 'Nothing to process' }
if ($enabled -eq $true) { 'Explicitly enabled' }
```

Put `$null` on the left: `$null -eq $value`. If `$value` is an array,
`$value -eq $null` performs element-wise filtering instead of one scalar
comparison. Matching null elements do not provide a reliable Boolean signal on
the success stream. `$null -eq $value` asks one clear question about the value
itself.

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
while ($null -ne ($line = $reader.ReadLine())) { $line }
do { $answer = Read-Host 'Continue?' } while ($answer -ne 'yes')
```

Use `while` for a precondition and `do` when the body must run at least once.
`ReadLine()` returns `$null` only after the input ends, so the loop neither
discards the first character nor treats the numeric end marker `-1` as truthy.
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

## 🟰 Equality, filtering, and reference boundaries

Comparison operators are scalar when the left operand is scalar, but a
collection on the left makes `-eq` and `-ne` filters that return matching
elements:

```powershell
$names = @('Ada', 'Lin', 'ADA')
@($names -eq 'ada')     # Ada, ADA: default string comparison ignores case
@($names -ceq 'ada')    # no matches: c-prefixed operators are case-sensitive
'ada' -in $names        # one Boolean membership answer
```

Use filtering when matching elements are the result; use `-contains` or `-in`
when the result is one Boolean. For objects, define equality from the domain:
compare a stable key or selected properties. Two separately created
`PSCustomObject` instances with identical-looking properties are not thereby
the same object. There is no universal deep object equality: nested references,
collection ordering, cycles, ignored fields, and domain-specific normalization
all affect what "equal" should mean.

Array copying is shallow. `@($original)` creates a distinct outer array, but
reference-type elements are shared:

```powershell
$original = @([pscustomobject]@{ Name = 'Ada' })
$copy = @($original)
$copy[0].Name = 'Grace' # the object visible through $original also changes
```

Hashtable `Clone()` is shallow for the same reason. When callers must not share
mutable nested state, construct new domain objects deliberately or define a
format-specific serialization copy with understood type losses; do not label a
generic shortcut "deep copy."

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

## 🧮 Sets and first-seen uniqueness

A `HashSet<T>` models unique membership and makes the equality policy explicit.
For portable identifier-like name matching, choose a comparer rather than
depending on ambient culture:

```powershell
$seen = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
foreach ($name in @('Ada', 'ada', 'Lin')) {
    if ($seen.Add($name)) { $name } # Add is true only for the first equivalent value
}
```

A set does not promise the presentation order you want. Emit the input value at
the moment `Add()` succeeds to preserve first-seen order and spelling.

## 📚 Files

- [`01_flow.ps1`](01_flow.ps1) - decisions and loops.
- [`02_collections.ps1`](02_collections.ps1) - arrays, equality, shallow copies, sets, and unrolling.

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
- Expecting collection `-eq` to return one Boolean or assuming object equality is universally deep.
- Treating a new outer array or cloned hashtable as a copy of every nested object.
- Using a set without choosing the comparer that defines uniqueness.

## ❓ Review questions

1. Why is `$null -eq $value` safer than the reversed comparison?
2. When is truthiness adequate, and when should a test be explicit?
3. Which `switch` parameter changes matching to wildcards or regular expressions?
4. When would a `foreach` statement be clearer than `ForEach-Object`?
5. What does `@()` guarantee about command output?
6. What problem does `,$value` solve?
7. How do `[ordered]@{}` and `@{}` differ?
8. When does `-eq` filter a collection rather than return one Boolean?
9. Why can editing an object through a copied array affect the original array?
10. How does a `HashSet[string]` comparer define duplicate names?
