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
```

PowerShell unrolls collections written to the pipeline. Wrap a collection in
the unary comma when a consumer needs the collection as *one* object.

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
```

A bare value emits success output; `Write-Output` is normally redundant.
Use `Write-Verbose`, `Write-Warning`, `Write-Information`, and `Write-Error`
for their corresponding streams. `-ErrorAction Stop` turns a non-terminating
error into one `catch` can handle.

## 📂 Files and modules

```powershell
$path = Join-Path -Path $HOME -ChildPath 'data.json'
$data | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding utf8
$data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
Import-Module ./MyModule/MyModule.psd1 -Force
Get-Help Get-Widget -Full
```

Use `-LiteralPath` for paths from users or data. `-Path` allows wildcard
interpretation. Export only public functions from a `.psm1`; dot-sourcing
shares scope and is a deliberate tradeoff, not a default module system.

## 🛡️ Safety and testing

```powershell
Remove-Item -LiteralPath $path -WhatIf
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit
Import-Module Pester -RequiredVersion 6.0.0 -Force
Invoke-Pester -Path ./project/TaskManager/tests
```

For state changes, use `SupportsShouldProcess`, call
`$PSCmdlet.ShouldProcess()`, make repeat runs safe (idempotent), and test in
Pester `TestDrive:`. Never put secrets in scripts, transcripts, source
control, or command history.

## 📚 Authoritative references

- `Get-Help about_*` (for example, `Get-Help about_Streams`)
- [PowerShell documentation](https://learn.microsoft.com/powershell/)
- [Pester documentation](https://pester.dev/)
- [PSScriptAnalyzer rules](https://github.com/PowerShell/PSScriptAnalyzer)
