# 🚨 Exercise 5: Errors, Streams, and Files

## 📋 Prerequisites

Complete [Module 5](../../lessons/05_errors_streams_and_files/README.md). Use
a disposable path beneath the repository or `TestDrive:` when testing.

## 🧩 Tasks

- Implement `Save-TaskJson -LiteralPath <string> -Task <PSCustomObject[]>`.
- Serialize `Task` as a stable top-level JSON array using `ConvertTo-Json
  -InputObject`.
- Write UTF-8 and return one object with `Path` and `Count`.
- Implement `Copy-BinaryFile -SourceLiteralPath <string>
  -DestinationLiteralPath <string>` with raw byte-stream reads and writes.

## 📐 Contract and edge cases

An empty task collection must still serialize as an array. Treat `LiteralPath`
as literal data, not a wildcard pattern. Design the result object's properties
from the starter comments and verify JSON with a raw read and
`ConvertFrom-Json -NoEnumerate`.

The binary copy must preserve arbitrary byte values without text decoding. Use
`Get-Content -AsByteStream -Raw` and `Set-Content -AsByteStream`; do not add an
encoding. The reference checks empty and single-item JSON arrays, filenames
containing wildcard characters, bytes including `0` and `255`, exact
cardinality, and cleanup of every disposable file.

## ▶️ Run

```powershell
pwsh -NoProfile -File exercises/05_errors_streams_and_files/exercises.ps1
pwsh -NoProfile -File exercises/05_errors_streams_and_files/solutions.ps1
```
