# 🚨 Module 5: Errors, Streams, and Files

Reliable scripts distinguish data, diagnostics, and failure, then treat files
as untrusted boundaries. This module introduces the stream model and portable
structured-file patterns without assuming that a successful-looking console
line means a safe operation.

## 🎯 Objectives

- Route success, error, warning, verbose, debug, and information output intentionally.
- Make required failures catchable and inspect actionable error records.
- Use narrow `try`/`catch`/`finally` regions and choose `throw` or `Write-Error`.
- Build provider-aware paths safely and read literal filenames predictably.
- Distinguish text strings, encoded bytes, and uninterpreted binary data.
- Preserve encoding, JSON shape, CSV schema, and array cardinality at boundaries.
- Recognize cleanup and atomic-write concerns before persisting state.

## 🌊 Streams and errors

PowerShell has success (1), error (2), warning (3), verbose (4), debug (5),
and information (6) streams. Redirection such as `2>` and `*>` is useful for
an interactive boundary, but reusable functions should emit data on success
and diagnostics on the appropriate non-success stream:

```powershell
Write-Verbose 'Connecting'
Write-Warning 'Optional input is absent'
Write-Information 'Progress event'
```

Cmdlets can report *non-terminating* errors and continue. For an operation that
must enter `catch`, request `-ErrorAction Stop` locally:

```powershell
try { Get-Content -LiteralPath $path -Raw -ErrorAction Stop }
catch [System.Management.Automation.ItemNotFoundException] { $null }
finally { ${resource}?.Dispose() }
```

`$ErrorActionPreference` changes broader behavior and is best kept narrowly
scoped when necessary. An error record (`$_` in `catch`) contains the
exception, category, target object, invocation information, and often an inner
exception. Catch only the operation you can meaningfully recover from.

The braces in `${resource}?.Dispose()` matter. `?` is permitted in an
unbraced PowerShell variable name, so `$resource?.Dispose()` is parsed as a
reference to `$resource?`, followed by `.Dispose()`. `${resource}` ends the
variable name before the null-conditional member operator. The operator then
skips `Dispose()` only when the actual `$resource` value is `$null`.

`throw` creates a terminating failure for an invalid contract. `Write-Error`
adds an error record and may continue according to error action; use it only
when continuation is intentionally supported.

## 🗺️ Providers, paths, text, and bytes

Paths live in providers (`FileSystem:`, `Env:`, and others), not just the local
disk. Build filesystem paths with `Join-Path`; use `-LiteralPath` for a value
that may contain wildcard characters:

```powershell
$path = Join-Path -Path $PSScriptRoot -ChildPath 'tasks.json'
Get-Content -LiteralPath $path -Raw -Encoding utf8
```

`-Path` permits provider semantics and wildcard expansion. `-LiteralPath`
treats data as exactly one path. `-Raw` reads one string, required before
`ConvertFrom-Json`; without it, line-by-line pipeline input alters the parsing
boundary. Specify `utf8` for portable new files rather than relying on a
platform's historical defaults.

A PowerShell `[string]` is text in memory; a `[byte[]]` is a sequence of raw
8-bit values. An encoding such as UTF-8 is the explicit transformation between
those models. In text mode, `Set-Content -Encoding utf8` encodes strings and
`Get-Content -Encoding utf8 -Raw` decodes the whole file into one string:

```powershell
Set-Content -LiteralPath $textPath -Value $text -Encoding utf8 -NoNewline
$textAgain = Get-Content -LiteralPath $textPath -Encoding utf8 -Raw
```

For bytes that must not be decoded, use byte-stream mode:

```powershell
[byte[]] $bytes = Get-Content -LiteralPath $binaryPath -AsByteStream -Raw
Set-Content -LiteralPath $copyPath -AsByteStream -Value $bytes
```

`-Raw` is important in both modes: text mode returns one string instead of
lines, while byte-stream mode returns one `[byte[]]` instead of emitting each
`[byte]` separately. `-AsByteStream` and `-Encoding` describe mutually
exclusive interpretations. PowerShell accepts both switches but warns and
ignores `-Encoding`; do not combine them. Decode only data whose encoding is
part of the contract—arbitrary binary is not malformed text.

## 🧾 CSV and JSON are schemas

CSV is tabular text: `Export-Csv` writes selected properties as columns and
`Import-Csv` returns strings unless you convert them. JSON can represent nested
objects and typed concepts but `ConvertFrom-Json` still needs validation at the
boundary. Neither format guarantees a domain schema for you.

Pipeline enumeration changes JSON cardinality. Persist an array deliberately:

```powershell
$tasks = @([pscustomobject]@{ Name = 'Read'; Done = $true })
$collapsed = $tasks | ConvertTo-Json
ConvertTo-Json -InputObject $tasks | Set-Content -LiteralPath $path -Encoding utf8
$loaded = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -NoEnumerate
```

With one task, `$collapsed` is a JSON object because the pipeline enumerated the
array before conversion. `-InputObject` passes the collection as one value and
preserves the top-level array. Validate required fields, types, identifiers,
and duplicates after loading. Keep a collection a top-level array even when it
has zero or one record.

## 💾 Persistence orientation

Use `finally` to remove disposable files and close resources. For important
state, write a validated replacement beside the target and then replace or
move it, cleaning up failures; this reduces partial-target exposure but is not
a substitute for transaction or multi-writer locking guarantees.

## 📚 Files

- [`01_streams_and_errors.ps1`](01_streams_and_errors.ps1) - stream intent and narrow error handling.
- [`02_structured_files.ps1`](02_structured_files.ps1) - UTF-8 JSON and CSV round trips.
- [`03_text_and_bytes.ps1`](03_text_and_bytes.ps1) - explicit UTF-8 and raw byte round trips.

## ▶️ Run

```powershell
pwsh -NoProfile -File lessons/05_errors_streams_and_files/01_streams_and_errors.ps1
pwsh -NoProfile -File lessons/05_errors_streams_and_files/02_structured_files.ps1
pwsh -NoProfile -File lessons/05_errors_streams_and_files/03_text_and_bytes.ps1
```

## ⚠️ Common mistakes

- Catching every exception and continuing with corrupted or missing state.
- Expecting `catch` after a non-terminating error without `-ErrorAction Stop`.
- Using `-Path` for user data containing `[` or `*`.
- Forgetting `-Raw` before JSON conversion or relying on implicit encoding.
- Combining `-AsByteStream` with `-Encoding` or decoding arbitrary binary as text.
- Letting JSON switch between no value, one object, and an array.
- Treating CSV-imported strings as validated numeric or Boolean values.

## ❓ Review questions

1. Which stream should a reusable function use for data?
2. What does `-ErrorAction Stop` change?
3. When should a function `throw` rather than `Write-Error`?
4. Why use `-LiteralPath` for data-derived filenames?
5. Why are `-Raw` and `-NoEnumerate` relevant to JSON arrays?
6. What schema work remains after parsing CSV or JSON?
7. What reliability does a temporary-file replacement provide—and not provide?
8. Why does raw byte input need both `-AsByteStream` and `-Raw`?
9. Why must `${resource}` be braced before the null-conditional operator?
