# 🧩 Applied projects

Applied projects sit between focused lessons and the larger
[capstones](../capstones/README.md). They combine several course topics in one
bounded application while retaining guided milestones and fast feedback.

## 📌 Required project

| Project | Focus | When to start |
| --- | --- | --- |
| [Tasks service and client](tasks/README.md) | Module contracts, SQLite and Markdown repositories, `ShouldProcess`, loopback HTTP/JSON, and a thin PowerShell client | Required after Module 12 and before the capstones |

The Tasks project is deliberately larger than an exercise and smaller than a
capstone. Complete its five milestones in order in `starter/`, run the matching
tag after each milestone, and compare with `solution/` only after attempting the
behavior yourself.

## 🧪 Test selection

The shared suite selects one source root through `TASKS_IMPLEMENTATION`. The
wrapper sets and restores that variable:

```powershell
# Import, signatures, help, parser, and intentional-incomplete starter checks.
pwsh -NoProfile -File ./projects/Invoke-ProjectTests.ps1 `
    -Implementation All -Tag Smoke

# One completed learner milestone.
pwsh -NoProfile -File ./projects/Invoke-ProjectTests.ps1 `
    -Implementation Starter -Tag M2

# Complete reference behavior.
pwsh -NoProfile -File ./projects/Invoke-ProjectTests.ps1 `
    -Implementation Solution -Tag All
```

`All` implementations is intended for scaffold smoke checks. Behavioral tags
against the unfinished starter fail until that milestone is implemented.
