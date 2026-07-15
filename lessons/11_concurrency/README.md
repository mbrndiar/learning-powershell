# ⚙️ Module 11: Concurrency

## 🎯 Objectives

Use background jobs and `ForEach-Object -Parallel` deliberately, understand
serialization and ordering boundaries, set a throttle limit, and clean up jobs.

## 💡 Concepts

Jobs isolate work and returned values are serialized snapshots, not live objects.
`ForEach-Object -Parallel` in PowerShell 7 uses parallel runspaces and accepts a
throttle limit. Parallel completion order is not a contract, so attach an index
and sort when consumers need deterministic order. Always receive and remove
jobs. Keep examples short; concurrency adds overhead and complexity.

## 📚 Files

- `01_background_job.ps1` - receive and clean up a quick job.
- `02_parallel_ordering.ps1` - bounded parallel work sorted deterministically.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/11_concurrency/01_background_job.ps1
pwsh -NoProfile -File lessons/11_concurrency/02_parallel_ordering.ps1
```

## ⚠️ Common mistakes

- Assuming a job object shares mutable session state.
- Relying on completion order.
- Leaving jobs running or using concurrency for trivial work.

## ❓ Review questions

1. Why are job results serialization boundaries?
2. How can a parallel pipeline produce deterministic output?
3. Why set a throttle limit?
