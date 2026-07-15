# 🌐 Module 10: APIs and Automation

HTTP automation is mostly boundary design: request data must be encoded,
responses validated, retries classified, and scheduled runs made safe to
repeat. The lesson uses injected offline seams so its examples remain
deterministic and network-independent.

## 🎯 Objectives

- Model HTTP request and response boundaries instead of treating JSON as trusted data.
- Use `Invoke-RestMethod` with clear expectations for status failures and output.
- Build URIs and query strings with proper escaping.
- Keep tokens in secure sources and prevent sensitive logging.
- Inject request and delay seams for deterministic tests.
- Design retries, pagination, timeouts, and scheduled runs with bounded risk.

## 💡 Request and response boundaries

`Invoke-RestMethod` performs an HTTP request and deserializes many JSON
responses into PowerShell objects. It throws for unsuccessful HTTP status
codes, while network and timeout failures have their own exception details;
catch and classify the error record rather than assuming every failure is
retryable. Validate that a successful response has the fields, types, and
cardinality your command expects.

Keep a request boundary injectable:

```powershell
function Get-ApiTask {
    param([Parameter(Mandatory)][scriptblock] $Request)
    (& $Request) | ConvertFrom-Json | Where-Object Done
}
```

This permits a no-network test, but production code should define the
scriptblock's arguments, return type, and error behavior. Do not log a bearer
token or whole response merely to diagnose a request; obtain credentials from
an approved secret store or secure environment mechanism.

## 💡 URIs, headers, and JSON

Build a `Uri` and escape *data*, not the entire already-formed URI:

```powershell
$builder = [System.UriBuilder]::new('https://example.invalid/tasks')
$builder.Query = "q=$([uri]::EscapeDataString($query))&page=$page"
$uri = $builder.Uri
$headers = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
```

Use HTTPS for credentials. Validate decoded JSON before acting on it: properties
may be absent, `"false"` is a string rather than `[bool] $false`, and a page
may return a scalar where an array is required.

## 💡 Retries, output, and pagination

Retry only transient, safe failures—for example a timeout, temporary network
failure, or a documented 429/5xx response. Do not blindly retry authentication,
validation, or most 4xx errors. Use capped exponential backoff plus jitter in
real clients to avoid synchronized retries, and consider idempotency before
repeating a mutation.

Capture output from a failed attempt so it cannot leak into a later successful
result:

```powershell
$attemptOutput = @(& $Operation $attempt)
# return only after the operation succeeds
```

Pagination needs a maximum page count, exactly one response envelope per page,
validated `Items` and Boolean `HasMore`, and clear field types. A server that
never ends pagination must fail boundedly rather than consuming resources
forever.

Timeouts and cancellation are policy decisions: set a request timeout, pass a
cancellation mechanism where the API/library supports one, and make delays
interruptible when appropriate. Scheduled automation should be idempotent,
record safe correlation/status data, and avoid logging credentials or payloads
that contain sensitive data.

## 📚 Files

- [`01_injected_request.ps1`](01_injected_request.ps1) - offline request seam and JSON filtering.
- [`02_uri_and_retry_design.ps1`](02_uri_and_retry_design.ps1) - URI, retry, and pagination contracts.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/10_apis_and_automation/01_injected_request.ps1
pwsh -NoProfile -File lessons/10_apis_and_automation/02_uri_and_retry_design.ps1
```

## ⚠️ Common mistakes

- Assuming every HTTP response is valid JSON with the expected schema.
- Concatenating unescaped query data or putting tokens in a URI.
- Retrying permanent failures or unsafe mutations without idempotency support.
- Letting failed-attempt output contaminate success output.
- Following pagination without a cap or validating `HasMore` truthiness.
- Using real network calls, sleeps, or secret-bearing logs in unit tests.

## ❓ Review questions

1. What behavior should a caller expect from `Invoke-RestMethod` on an error status?
2. Why escape a query value rather than an entire completed URI?
3. What JSON validations are needed after parsing?
4. Which failures are plausible retry candidates, and which are not?
5. Why buffer output from a retry attempt?
6. What must a bounded pagination loop validate?
7. How do idempotency and safe logging matter to scheduled automation?
