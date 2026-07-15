# 🧵 Exercise 11: Concurrency

## 📋 Prerequisites

Complete [Module 11](../../lessons/11_concurrency/README.md). First reason
about the sequential result; parallelism is an implementation detail here.

## 🧩 Tasks

- Implement `Get-ParallelSquare -Number <int[]> -LabelPrefix <string>`.
- Use `ForEach-Object -Parallel` with a throttle limit.
- Capture `LabelPrefix` with `$using:` inside the worker.
- Emit objects ordered by `Number`, each with `Number`, `Label`, and `Square`.
- Add Pester tests for ordering and empty input.

## 📐 Contract and edge cases

Parallel completion order is nondeterministic, so attach/preserve enough
information to sort the final result deterministically. An empty input should
emit no placeholder objects. Do not mutate shared state from workers or depend
on a real service; use a modest, explicit throttle suitable for the exercise.
Treat the captured prefix as immutable input rather than shared mutable state.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/11_concurrency/exercises.ps1
pwsh -NoProfile -File exercises/11_concurrency/solutions.ps1
```
