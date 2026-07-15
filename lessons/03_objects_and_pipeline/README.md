# 3. Objects and Pipeline

## Objectives

Inspect objects, compose commands with the pipeline, and filter, select, sort,
group, and measure without prematurely formatting results.

## Concepts

The pipeline carries objects. `Get-Member` reveals their type, properties, and
methods. `Where-Object`, `ForEach-Object`, `Select-Object`, `Sort-Object`,
`Group-Object`, and `Measure-Object` transform objects. `Format-Table` produces
formatting instructions, so use it only as the last command typed for people,
never inside a reusable function.

## Files

- `01_object_pipeline.ps1` - inspect and transform records.
- `02_group_and_measure.ps1` - aggregate records while retaining data.

## Run

```powershell
pwsh -NoProfile -File lessons/03_objects_and_pipeline/01_object_pipeline.ps1
pwsh -NoProfile -File lessons/03_objects_and_pipeline/02_group_and_measure.ps1
```

## Common mistakes

- Parsing displayed columns instead of object properties.
- Calling `Format-Table` before another data command.
- Using a loop when a pipeline expression communicates the transformation.

## Review questions

1. What does `Get-Member` answer?
2. Why should formatting end a pipeline?
3. What object does `Measure-Object` return?
