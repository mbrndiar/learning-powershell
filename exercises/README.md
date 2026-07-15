# Exercises

Every lesson module has a matching directory containing:

- `README.md`: problem contracts and running instructions;
- `exercises.ps1`: parseable starter functions with explicit `TODO` markers;
- `solutions.ps1`: executable reference solutions with self-checks.

Run starters to inspect their contracts, but they intentionally report
incomplete work. Run a reference solution with:

```powershell
pwsh -NoProfile -File exercises/01_basics/solutions.ps1
```

Solve before opening the solution. A solution is one readable approach, not the
only valid implementation. Test normal, empty, invalid, and boundary inputs.
From module 8 onward, write Pester tests for behavior rather than relying only
on inline checks.
