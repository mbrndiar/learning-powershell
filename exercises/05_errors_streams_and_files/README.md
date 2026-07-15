# Errors, streams, and files exercises

Implement a UTF-8 JSON writer that uses a literal path, always writes a
top-level JSON array (including for zero or one task), and returns an object.
Use `SupportsShouldProcess` for the state change and test it in a project-local
scratch path. Remember that pipeline input to `ConvertTo-Json` is enumerated;
use `-InputObject` when the collection itself is the JSON value.

```powershell
pwsh -NoProfile -File exercises/05_errors_streams_and_files/solutions.ps1
```
