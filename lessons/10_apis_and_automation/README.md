# 10. APIs and Automation

## Objectives

Model HTTP/JSON boundaries offline, construct URIs safely, plan pagination,
retries and timeouts, and protect credentials in reliable scheduled automation.

## Concepts

`Invoke-RestMethod` converts JSON responses to objects, but examples inject a
request scriptblock so no lesson needs the internet. Use a URI builder and
escaped query values, define timeout/retry/pagination behavior before production
use, and never put tokens in source, transcripts, or logs. Scheduled work
should be idempotent and log safe correlation/status data.

## Files

- `01_injected_request.ps1` - an offline JSON request seam.
- `02_uri_and_retry_design.ps1` - deterministic URI construction and retry idea.

## Run

```powershell
pwsh -NoProfile -File lessons/10_apis_and_automation/01_injected_request.ps1
pwsh -NoProfile -File lessons/10_apis_and_automation/02_uri_and_retry_design.ps1
```

## Common mistakes

- Making a lesson or test depend on public internet availability.
- Concatenating unescaped query strings.
- Retrying non-idempotent requests without an idempotency strategy.

## Review questions

1. Why inject a request scriptblock?
2. What data must not enter logs or transcripts?
3. Which requests are safe to retry by default?
