# 🔀 Module 2: Control Flow and Collections

## 🎯 Objectives

Use `if` and `switch`, iterate with `foreach` and `while`, and choose arrays or
hashtables while handling empty and `$null` values predictably.

## 💡 Concepts

An `if` condition converts to Boolean; empty collections and empty strings are
falsey, but test intent explicitly when possible. Put `$null` on the left:
`$null -eq $value`. Arrays are ordered and may be unrolled into the pipeline.
Use `,$value` when a collection must travel as one element. Hashtables map keys
to values and are not ordered unless created as `[ordered]@{}`.

## 📚 Files

- `01_flow.ps1` - decisions and loops.
- `02_collections.ps1` - arrays, hashtables, null, and unrolling.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/02_control_flow_and_collections/01_flow.ps1
pwsh -NoProfile -File lessons/02_control_flow_and_collections/02_collections.ps1
```

## ⚠️ Common mistakes

- Using `if ($value -eq $null)` when `$value` could be an array.
- Assuming `@()` and `$null` are interchangeable.
- Mutating a collection while enumerating it.

## ❓ Review questions

1. Why should `$null` be on the left of an equality comparison?
2. When is the unary comma useful?
3. Which collection is appropriate for named lookup?
