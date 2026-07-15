# 🌐 Exercise 10: APIs and Automation

## 📋 Prerequisites

Complete [Module 10](../../lessons/10_apis_and_automation/README.md). The
request is injected; do not add network-dependent instructions or tests.

## 🧩 Tasks

- Implement `Get-ActiveRecord -Request <scriptblock>`.
- Invoke `Request`, parse its JSON, and emit only records whose `Active`
  property is true.
- Add Pester tests for active filtering and invalid JSON.

## 📐 Contract and edge cases

Use offline scriptblocks returning JSON text. Test multiple records and no
active records. Invalid JSON must be an observable failure, not silently
converted to an empty collection. Avoid logging the entire request/response;
production boundaries should validate field types before acting on them.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/10_apis_and_automation/exercises.ps1
pwsh -NoProfile -File exercises/10_apis_and_automation/solutions.ps1
```
