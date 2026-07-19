# ⚡ PowerShell 7 Cheat Sheet

## 🧠 Mental model

PowerShell pipelines pass **.NET objects**, not text. Use `Get-Member` to see
properties and methods. Keep functions data-oriented; use `Format-Table` or
`Format-List` only as the final interactive command.

| Term | Meaning |
| --- | --- |
| cmdlet | Compiled command, conventionally `Verb-Noun` |
| function | Script command; use `[CmdletBinding()]` at public boundaries |
| provider | Exposes data through drives, such as `C:` or `/` (`FileSystem`), `Env:`, and `Variable:` |
| pipeline | Success-stream objects connected with `\|` |
| PSCustomObject | Small named record: `[pscustomobject]@{ Name = 'Ada' }` |
| splatting | Pass a hashtable with `Command @parameters` |
| `$_` / `$PSItem` | Current pipeline object |
| `$LASTEXITCODE` | Native executable exit code; not cmdlet success |

## 🔍 Discover and inspect

```powershell
Get-Command -Noun Process
Get-Help Get-ChildItem -Examples
Get-Process | Get-Member
Get-ChildItem | Select-Object -First 3 Name, Length
```

## 🧮 Data, conditions, and collections

```powershell
$name = 'Ada'
"Hello, $name"; "Hello, $($name.ToUpperInvariant())"
$items = @('one', 'two')
$record = @{ Name = 'Ada'; Active = $true }
$null -eq $value                 # put $null on the left
if ($items.Count -gt 0) { 'has values' }
,$items                           # one array element, even if $items is array

(2147483648).GetType().Name       # Int64: literal no longer fits Int32
2147483647L + 1L                  # exact Int64 arithmetic within its range
0.1 + 0.2                         # Double: approximately 0.30000000000000004
0.1d + 0.2d                       # Decimal: 0.3
$identifier = '003'               # identifiers preserve representation as strings
```

PowerShell unrolls collections written to the pipeline. Wrap a collection in
the unary comma when a consumer needs the collection as *one* object.
Collection `-eq` filters matching elements; use `-in`/`-contains` for one
membership Boolean. Array and hashtable copies are shallow unless you construct
new nested objects. A `HashSet[string]` comparer defines name uniqueness:

```powershell
$seen = [System.Collections.Generic.HashSet[string]]::new(
  [StringComparer]::OrdinalIgnoreCase
)
```

## ⏱️ Time boundaries

```powershell
$instant = [DateTimeOffset]::Parse(
  '2026-07-19T09:00:00+00:00',
  [Globalization.CultureInfo]::InvariantCulture
)
$wire = $instant.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
$end = $instant.AddMinutes(30)
[TimeSpan] $elapsed = $end - $instant
$utc = [TimeZoneInfo]::ConvertTime($instant, [TimeZoneInfo]::Utc)
```

Use `DateTimeOffset` for unambiguous instants, `TimeSpan` for durations, and an
explicit `TimeZoneInfo` when civil-zone rules matter. Inject a clock for tests.

## 🔗 Object pipeline

```powershell
Get-Process |
  Where-Object CPU -gt 10 |
  Sort-Object CPU -Descending |
  Select-Object -First 5 Name, CPU

$numbers | Measure-Object -Average -Sum
$items | Group-Object Status
$items | ForEach-Object { $_.Name.ToUpperInvariant() }
```

## 🛠️ Functions and errors

```powershell
function Get-Greeting {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateNotNullOrWhiteSpace()][string] $Name)
    [pscustomobject]@{ Message = "Hello, $Name" }
}

try {
    Get-Content -LiteralPath $path -ErrorAction Stop
}
catch [System.Management.Automation.ItemNotFoundException] {
    throw "Input file was not found: $path"
}
finally {
    ${resource}?.Dispose() # braces end the variable name before ?.
}
```

A bare value emits success output; `Write-Output` is normally redundant.
Use `Write-Verbose`, `Write-Warning`, `Write-Information`, and `Write-Error`
for their corresponding streams. `-ErrorAction Stop` turns a non-terminating
error into one `catch` can handle.

## 📂 Files and modules

```powershell
$path = Join-Path -Path $HOME -ChildPath 'data.json'
ConvertTo-Json -InputObject @($data) -Depth 5 |
  Set-Content -LiteralPath $path -Encoding utf8
$data = Get-Content -LiteralPath $path -Raw -Encoding utf8 |
  ConvertFrom-Json -NoEnumerate

$text = Get-Content -LiteralPath $textPath -Raw -Encoding utf8
[byte[]] $bytes = Get-Content -LiteralPath $binaryPath -AsByteStream -Raw
Set-Content -LiteralPath $copyPath -AsByteStream -Value $bytes

$config = Import-PowerShellDataFile -LiteralPath ./Configuration.psd1
Import-Module ./MyModule/MyModule.psd1 -Force
Get-Help Get-Widget -Full
```

Use `-LiteralPath` for paths from users or data. `-Path` allows wildcard
interpretation. `-Encoding` transforms strings to or from bytes; byte-stream
mode preserves a `[byte[]]`, and combining it with `-Encoding` only warns and
ignores the encoding.

A `.psm1` contains script-module implementation. A `.psd1` is a general
PowerShell data file; a module manifest is a specialized `.psd1` with module
metadata and exports. Read general data with `Import-PowerShellDataFile
-LiteralPath` rather than executing it, validate the imported values, and keep
the default 500-key/5000-AST-node limits for untrusted input. Export only public
functions from a module; dot-sourcing deliberately shares caller scope.

## 🗄️ SQLite transactions

```powershell
Open-SQLiteConnection -DataSource $databasePath -ConnectionName Inventory
try {
    Invoke-SqlQuery -ConnectionName Inventory `
      -Query 'SELECT sku, quantity FROM inventory WHERE sku = @sku;' `
      -Parameters @{ sku = $sku }

    Start-SqlTransaction -ConnectionName Inventory
    try {
        Invoke-SqlUpdate -ConnectionName Inventory `
          -Query 'UPDATE inventory SET quantity = @quantity WHERE sku = @sku;' `
          -Parameters @{ sku = $sku; quantity = $quantity }
        Complete-SqlTransaction -ConnectionName Inventory
    }
    catch {
        Undo-SqlTransaction -ConnectionName Inventory
        throw
    }
}
finally {
    Close-SqlConnection -ConnectionName Inventory -ErrorAction SilentlyContinue
}
```

Own and name each SimplySql connection, parameterize values rather than
interpolating SQL, validate the schema you actually opened, and keep related
writes in one transaction. Roll back on failure and close the connection before
removing the database or its `-wal`, `-shm`, and `-journal` sidecars.

## 🛡️ Safety and testing

```powershell
Remove-Item -LiteralPath $path -WhatIf
Invoke-Formatter -ScriptDefinition $source -Settings CodeFormatting # preview candidate text
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit
Import-Module Pester -RequiredVersion 6.0.0 -Force
& ./lessons/08_testing_with_pester/03_coverage_diagnostic.ps1
& ./projects/Invoke-ProjectTests.ps1 -Implementation All -Tag Smoke
& ./capstones/Invoke-CapstoneTests.ps1 -Implementation All -Tag Smoke
```

For state changes, use `SupportsShouldProcess`, call
`$PSCmdlet.ShouldProcess()`, make repeat runs safe (idempotent), and test in
Pester `TestDrive:`. Never put secrets in scripts, transcripts, source
control, or command history. Treat formatting as a reviewed candidate and
coverage as a diagnostic; neither replaces behavior assertions.

## 📚 Authoritative references

- `Get-Help about_*` (for example, `Get-Help about_Streams`)
- [PowerShell documentation](https://learn.microsoft.com/powershell/)
- [Pester documentation](https://pester.dev/)
- [PSScriptAnalyzer rules](https://github.com/PowerShell/PSScriptAnalyzer)
- [SimplySql documentation](https://github.com/mithrandyr/SimplySql)
- [SQLite documentation](https://www.sqlite.org/docs.html)
