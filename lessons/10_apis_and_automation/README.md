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

## ↔️ Request and response boundaries

`Invoke-RestMethod` performs an HTTP request and deserializes many JSON
responses into PowerShell objects. It throws for unsuccessful HTTP status
codes, while network and timeout failures have their own exception details;
catch and classify the error record rather than assuming every failure is
retryable. Validate that a successful response has the fields, types, and
cardinality your command expects.

Two boundaries appear in this module and must not be confused. The first injects
JSON *text* so a command can practice validating untrusted input with
`ConvertFrom-Json`:

```powershell
function Get-ApiTask {
    param([Parameter(Mandatory)][scriptblock] $Request)
    foreach ($task in @((& $Request) | ConvertFrom-Json)) {
        $done = $task.PSObject.Properties['Done']
        if ($null -eq $done -or $done.Value -isnot [bool]) {
            throw 'Each API task requires a Boolean Done property.'
        }
        if ($done.Value) { $task }
    }
}
```

This permits a no-network test, but production code should define the
scriptblock's arguments, return type, and error behavior. Do not log a bearer
token or whole response merely to diagnose a request; obtain credentials from
an approved secret store or secure environment mechanism.

The second boundary is a real wrapper that calls `Invoke-RestMethod` directly.
Because `Invoke-RestMethod` already deserializes the body, the wrapper receives
and returns *objects*—there is no `ConvertFrom-Json`:

```powershell
function Get-RemoteTask {
    param(
        [Parameter(Mandatory)][uri] $Uri,
        [ValidateSet('Get', 'Post', 'Put', 'Delete', 'Patch')][string] $Method = 'Get',
        [ValidateRange(1, 300)][int] $TimeoutSec = 30,
        [ValidateNotNull()][hashtable] $Headers
    )
    $parameters = @{ Uri = $Uri; Method = $Method; TimeoutSec = $TimeoutSec; ErrorAction = 'Stop' }
    if ($PSBoundParameters.ContainsKey('Headers') -and $Headers.Count -gt 0) { $parameters.Headers = $Headers }
    Invoke-RestMethod @parameters
}
```

Test it offline by mocking the boundary command—never a live call—and assert
the request parameters and that a failure propagates:

```powershell
Mock Invoke-RestMethod { [pscustomobject]@{ Name = 'Read' } }
Get-RemoteTask -Uri 'https://example.invalid/tasks' -TimeoutSec 15 | Out-Null
Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
    $TimeoutSec -eq 15 -and $ErrorAction -eq 'Stop'
}
```

Forward headers but never log them; they may hold a token. Include a mock-based
assertion that supplied headers reach `Invoke-RestMethod` unchanged.

## 🧭 URIs, headers, and JSON

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

## 🔁 Retries, output, and pagination

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

- [`01_injected_request.ps1`](01_injected_request.ps1) - offline JSON-text seam and schema filtering.
- [`02_uri_and_retry_design.ps1`](02_uri_and_retry_design.ps1) - URI, retry, and pagination contracts.
- [`03_rest_method_wrapper.ps1`](03_rest_method_wrapper.ps1) - real `Invoke-RestMethod` wrapper tested with a Pester mock.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/10_apis_and_automation/01_injected_request.ps1
pwsh -NoProfile -File lessons/10_apis_and_automation/02_uri_and_retry_design.ps1
pwsh -NoProfile -File lessons/10_apis_and_automation/03_rest_method_wrapper.ps1
```

## ⚠️ Common mistakes

- Assuming every HTTP response is valid JSON with the expected schema.
- Re-parsing `Invoke-RestMethod` output as text; it already returns objects.
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
8. How does `Invoke-RestMethod`'s output differ from injected JSON text, and how do you test a wrapper offline?
