# 🔗 Module 3: Objects and Pipeline

The pipeline is PowerShell's primary composition mechanism: commands pass
objects with properties and methods, not screen text. Learn to inspect shape,
transform it deliberately, and reserve formatting for a human-facing endpoint.

## 🎯 Objectives

- Inspect object type names, properties, methods, and pipeline input with `Get-Member`.
- Filter, project, calculate, sort, group, and measure object records.
- Choose pipeline processing or a `foreach` statement based on data flow.
- Reason about zero, one, and many outputs at function boundaries.
- Avoid formatting and text parsing until the final interactive display.

## 💡 Objects, text, and the Extended Type System

Cmdlets commonly return .NET objects. PowerShell's Extended Type System (ETS)
adds adapted and extended members so different sources can present a coherent
property-oriented experience. Ask the runtime rather than guessing:

```powershell
$process = Get-Process | Select-Object -First 1
$process | Get-Member
$process.PSObject.TypeNames
$process | Select-Object Name, Id
```

`Get-Member` reveals whether a member is a property or method and what the
pipeline actually contains. Property enumeration lets `$tasks.Name` retrieve a
property from each member where supported, but an explicit pipeline is often
clearer when filtering or errors matter.

## 💡 Transforming records

Use `Where-Object` to filter and `Select-Object` to project a smaller,
purposeful contract. Calculated properties name a computed value:

```powershell
$tasks |
    Where-Object Done |
    Select-Object Name, @{ Name = 'Hours'; Expression = { $_.Minutes / 60.0 } }
```

`ForEach-Object` transforms streamed input with `$_`; a `foreach` statement is
often clearer for several statements, local accumulation, or `break`:

```powershell
$tasks | ForEach-Object { $_.Name.ToUpperInvariant() }
foreach ($task in $tasks) {
    if ($task.Done) { $task }
}
```

Prefer a pipeline when it communicates a sequence of independent
transformations. Prefer `foreach` when the control flow is inherently local.

## 💡 Aggregation and cardinality

`Sort-Object` orders records, `Group-Object` makes group objects with `Name`,
`Count`, and `Group`, and `Measure-Object` returns a measurement object:

```powershell
$tasks | Sort-Object Minutes -Descending
$tasks | Group-Object Team
$tasks | Measure-Object -Property Minutes -Sum -Average
```

A command can emit zero, one, or many objects. Capture output as `@(...)` when
your next step requires a stable array and explicitly decide whether no result
is valid. Do not write consumers that silently treat a single object and an
array as interchangeable when the public contract promises one shape.

## 💡 Formatting is terminal presentation

`Format-Table`, `Format-List`, and `Out-String` create formatting data or text
for display, not the original records:

```powershell
$tasks | Sort-Object Name | Format-Table Name, Minutes
# Correct: a person-facing terminal command
```

Never feed `Format-*` into `Where-Object`, `Export-Csv`, JSON conversion, or a
reusable function. Filter and select the real objects first, then format only
at the interactive edge. This also avoids brittle parsing of localized or
width-truncated console columns.

## 📚 Files

- [`01_object_pipeline.ps1`](01_object_pipeline.ps1) - inspect and transform records.
- [`02_group_and_measure.ps1`](02_group_and_measure.ps1) - aggregate records while retaining data.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/03_objects_and_pipeline/01_object_pipeline.ps1
pwsh -NoProfile -File lessons/03_objects_and_pipeline/02_group_and_measure.ps1
```

## ⚠️ Common mistakes

- Parsing displayed columns rather than using properties.
- Formatting before a data command or exporting formatted objects.
- Assuming every output is an array instead of designing zero/one/many behavior.
- Selecting properties too early and discarding data needed by a later stage.
- Using `ForEach-Object` for complex control flow that a `foreach` statement explains better.
- Assuming a grouped object's `.Name` is an original record property.

## ❓ Review questions

1. What questions does `Get-Member` answer?
2. What is the difference between a projection and a calculated property?
3. When is `ForEach-Object` a better fit than `foreach`?
4. Which properties does a `Group-Object` result expose?
5. Why use `@(...)` at a cardinality boundary?
6. Why must `Format-Table` end a reusable data pipeline?
