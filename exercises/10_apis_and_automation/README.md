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
- Implement `Get-RemoteRecord -Uri <uri> -Method <string> -TimeoutSec <int>
  -Headers <hashtable>` that calls `Invoke-RestMethod` directly with an explicit
  Uri, method, timeout, and `-ErrorAction Stop`, forwards optional headers
  without logging them, and returns the deserialized objects.
- Add Pester tests for filtering, invalid JSON/schema, URI construction, and the
  wrapper's request parameters and propagated failure.

## 📐 Contract and edge cases

Use offline scriptblocks returning JSON text for `Get-ActiveRecord`. Test a
mixed set (only the active record), multiple active records, and no active
records. Invalid JSON must be an observable failure, not silently converted to
an empty collection. Reject missing or non-Boolean `Active` properties,
including the truthy string `"false"`.

Use `System.UriBuilder` and `EscapeDataString`; reject a base URI that already
has a query rather than merging ambiguous parameters. Avoid logging the entire
request/response or putting tokens in a URI.

`Get-RemoteRecord` is a real `Invoke-RestMethod` boundary: unlike the JSON-text
seam, `Invoke-RestMethod` already deserializes the body, so the wrapper returns
objects (no `ConvertFrom-Json`). Test it offline by mocking `Invoke-RestMethod`
(never a live call); assert the request parameters with `Should -Invoke
-ParameterFilter`, including unchanged optional headers, and that a thrown
request failure propagates. Never log full headers or tokens.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/10_apis_and_automation/exercises.ps1
pwsh -NoProfile -File exercises/10_apis_and_automation/solutions.ps1
```
