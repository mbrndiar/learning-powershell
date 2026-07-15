# 🌐 Module 10: APIs and Automation

## 🎯 Objectives

Model HTTP/JSON boundaries offline, construct URIs safely, plan pagination,
retries and timeouts, and protect credentials in reliable scheduled automation.

## 💡 Concepts

`Invoke-RestMethod` converts JSON responses to objects, but examples inject
request and delay scriptblocks so no lesson needs the internet or real waiting.
Accept only HTTP/HTTPS base URIs and define whether an existing query is merged
or rejected instead of silently replacing it. Bound retries and pagination,
retry only failures you have classified as transient, and buffer an attempt so
partial output from a failed request is not mistaken for success. Validate API
field types instead of relying on PowerShell truthiness. Never put tokens in
source, transcripts, or logs. Scheduled work should be idempotent and log safe
correlation/status data.

## 📚 Files

- `01_injected_request.ps1` - an offline JSON request seam.
- `02_uri_and_retry_design.ps1` - validated URI construction, classified bounded
  retries, injected delays, and capped offline pagination.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/10_apis_and_automation/01_injected_request.ps1
pwsh -NoProfile -File lessons/10_apis_and_automation/02_uri_and_retry_design.ps1
```

## ⚠️ Common mistakes

- Making a lesson or test depend on public internet availability.
- Concatenating unescaped query strings.
- Silently replacing an existing query string on a base URI.
- Retrying non-idempotent requests without an idempotency strategy.
- Retrying every exception or paginating without a maximum.
- Leaking partial output from an attempt that later failed.
- Treating the string `"false"` as Boolean false; non-empty strings are truthy.

## ❓ Review questions

1. Why inject a request scriptblock?
2. What data must not enter logs or transcripts?
3. Which requests are safe to retry by default?
4. Why inject the delay used by retry logic?
5. What prevents a broken API from causing infinite pagination?
