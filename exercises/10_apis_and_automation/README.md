# 🌐 Exercise 10: APIs and Automation

## 📋 Prerequisites

Complete [Module 10](../../lessons/10_apis_and_automation/README.md). The
request is injected; do not add network-dependent instructions or tests.

## 🧩 Tasks

- Implement `Get-ActiveRecord -Request <scriptblock>`.
- Invoke `Request`, parse its JSON, and emit only records whose `Active`
  property exists, is Boolean, and is true.
- Implement `Get-SearchUri -BaseUri <uri> -Query <string> -Page <int>` with an
  absolute HTTP(S) base URI that has no existing query string.
- Escape only the query value and preserve a bounded positive page number.
- Add Pester tests for filtering, invalid JSON/schema, and URI construction.

## 📐 Contract and edge cases

Use offline scriptblocks returning JSON text. Test multiple records and no
active records. Invalid JSON must be an observable failure, not silently
converted to an empty collection. Reject missing or non-Boolean `Active`
properties, including the truthy string `"false"`.

Use `System.UriBuilder` and `EscapeDataString`; reject a base URI that already
has a query rather than merging ambiguous parameters. Avoid logging the entire
request/response or putting tokens in a URI.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/10_apis_and_automation/exercises.ps1
pwsh -NoProfile -File exercises/10_apis_and_automation/solutions.ps1
```
