# 5. Errors, Streams, and Files

## Objectives

Use PowerShell's streams intentionally, make errors catchable, clean up safely,
and read/write portable UTF-8, CSV, and JSON files.

## Concepts

Success output is stream 1; warnings, verbose, debug, information, and errors
have separate streams. Cmdlets can emit non-terminating errors, so use
`-ErrorAction Stop` for an operation a `catch` must handle. Catch narrowly,
preserve actionable details, and use `finally` for cleanup. Build paths with
`Join-Path` and use `-LiteralPath` for data-derived filenames.

## Files

- `01_streams_and_errors.ps1` - stream intent and narrow error handling.
- `02_structured_files.ps1` - temporary UTF-8 JSON and CSV round trips.

## Run

```powershell
pwsh -NoProfile -File lessons/05_errors_streams_and_files/01_streams_and_errors.ps1
pwsh -NoProfile -File lessons/05_errors_streams_and_files/02_structured_files.ps1
```

## Common mistakes

- Catching every error and continuing as if no failure occurred.
- Passing wildcard-containing data with `-Path` instead of `-LiteralPath`.
- Forgetting `-Raw` before `ConvertFrom-Json`.

## Review questions

1. What does `-ErrorAction Stop` change?
2. Which stream should a reusable function use for diagnostics?
3. Why use `Join-Path`?
