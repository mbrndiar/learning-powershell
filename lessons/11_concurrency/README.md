# 🧵 Module 11: Concurrency

Concurrency is a resource-management choice, not a default performance switch.
Use it only after a sequential design is correct and measurements show
independent, latency-bound work can benefit from parallel execution.

## 🎯 Objectives

- Decide when sequential work is safer and faster enough.
- Distinguish process jobs, thread jobs/runspaces, and `ForEach-Object -Parallel`.
- Understand serialization, `$using:` capture, and isolated execution state.
- Preserve ordering and cardinality intentionally.
- Set throttles from resource constraints rather than optimism.
- Receive, remove, aggregate, and cancel concurrent work predictably.

## 🛑 Choose not to parallelize

Avoid concurrency for tiny CPU work, dependent steps, ordered state changes,
shared-file updates, scarce external quotas, or code that has not been measured.
Parallel startup, serialization, contention, nondeterministic ordering, and
debugging complexity can outweigh useful work. First write deterministic
sequential behavior and define its output and error contract.

## 🧵 Execution models

`Start-Job` starts a separate PowerShell process. It isolates crashes and state
but serializes output, so returned objects are deserialized snapshots:

```powershell
$job = Start-Job -ScriptBlock { [pscustomobject]@{ Value = 42 } }
try { $job | Wait-Job | Out-Null; Receive-Job -Job $job }
finally { Remove-Job -Job $job -Force }
```

Thread jobs and custom runspaces run in-process with lower startup cost but
share process resources and require careful synchronization. PowerShell 7's
`ForEach-Object -Parallel` uses parallel runspaces and is concise for
independent pipeline items. It does not make mutation of shared state safe.

Variables from the caller need `$using:name` in parallel scriptblocks where
supported; values may be captured or referenced with semantics that depend on
the concurrency mechanism. Keep inputs immutable and pass explicit values
instead of relying on ambient scope.

## 🎛️ Ordering, pressure, and failures

Parallel completion order is not input order. Include an input index and sort
afterward when the public contract requires deterministic order:

```powershell
$work | ForEach-Object -Parallel {
    [pscustomobject]@{ Index = $_.Index; Value = $_.Value * $_.Value }
} -ThrottleLimit 2 | Sort-Object Index
```

Choose `-ThrottleLimit` from CPU, memory, API rate limits, file descriptors,
and downstream capacity. More workers can make a service slower or cause
rate-limit failures. Define zero-input behavior explicitly; a parallel command
should not emit a placeholder object merely because no work was received.

Jobs have a lifecycle: start, wait/poll, receive output/errors, and remove.
Decide whether one worker failure cancels all work or becomes a structured
per-item failure. Aggregate successes and failures deterministically rather
than letting completion timing choose output. Cancellation support varies by
mechanism; design an explicit stop/timeout policy and always clean up started
jobs in `finally`.

## 📚 Files

- [`01_background_job.ps1`](01_background_job.ps1) - process job lifecycle and cleanup.
- [`02_parallel_ordering.ps1`](02_parallel_ordering.ps1) - throttled parallel work with deterministic ordering.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/11_concurrency/01_background_job.ps1
pwsh -NoProfile -File lessons/11_concurrency/02_parallel_ordering.ps1
```

## ⚠️ Common mistakes

- Parallelizing quick or dependent work without measuring.
- Assuming job output retains live .NET methods after serialization.
- Mutating shared variables, lists, or files from parallel workers.
- Assuming completion order equals input order.
- Selecting an unlimited throttle and exhausting a service or host.
- Receiving jobs without removing them, or ignoring worker errors.

## ❓ Review questions

1. When is sequential execution the better engineering choice?
2. What isolation and serialization tradeoff does `Start-Job` make?
3. How do thread jobs differ from process jobs?
4. Why is `$using:` relevant to parallel scriptblocks?
5. How can a command preserve input ordering after parallel work?
6. What should constrain a throttle limit?
7. What lifecycle steps must a job-owning command perform?
