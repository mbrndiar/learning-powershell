# 🛠️ Setup

## 📥 Install PowerShell

Use the current [PowerShell LTS release](https://learn.microsoft.com/lifecycle/products/powershell)
for a new learning environment. PowerShell 7.6 LTS is the current recommendation;
the course retains a PowerShell 7.4 language/runtime floor through its support
retirement on November 10, 2026.

Use the supported installer instructions at
[Microsoft Learn](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).
Do not assume `powershell` means PowerShell 7: the cross-platform executable is
`pwsh`.

### 🪟 Windows

Use the MSI from Microsoft Learn or
[WinGet](https://learn.microsoft.com/windows/package-manager/winget/), where
allowed:

```powershell
winget install --id Microsoft.PowerShell --source winget
```

Windows PowerShell 5.1 remains installed for Windows compatibility; keep it
separate from this course's `pwsh` sessions.

### 🍎 macOS

Use the signed package from Microsoft Learn, or
[Homebrew](https://docs.brew.sh/Installation) if it is part of your approved
tooling:

```sh
brew install --cask powershell
```

### 🐧 Linux

Follow the distribution-specific Microsoft repository instructions from
Microsoft Learn (Ubuntu/Debian, RHEL-family, and others differ). Prefer your
package manager over downloading an untracked binary; after installation,
launch `pwsh` from a new shell.

Verify the version in a new terminal:

```powershell
pwsh -NoProfile -Command '$PSVersionTable.PSVersion'
pwsh -NoProfile -Command 'if ($PSVersionTable.PSVersion -lt [version]"7.4") { throw "PowerShell 7.4+ is required." }'
```

`-NoProfile` makes lessons reproducible by avoiding personal profile changes.
If you are creating a new environment, install 7.6 LTS rather than starting on
the soon-retiring 7.4 line.

Full local help is downloaded separately from the engine. Populate it for your
account, then use online help if a module does not publish downloadable files:

```powershell
Update-Help -Scope CurrentUser
Get-Help Get-ChildItem -Detailed
Get-Help Get-ChildItem -Online
```

See the official [`Update-Help`
documentation](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/update-help)
for language and administrative-scope details.

## 🧰 VS Code

Install [Visual Studio Code](https://code.visualstudio.com/) and the
[PowerShell extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell).
Open this repository, select the `pwsh` session when prompted, and use the
integrated terminal for commands. The extension provides completion, help,
lint diagnostics, breakpoints, and a debugger; it does not replace learning to
run scripts in a normal terminal.

## 🛡️ Execution policy on Windows

Execution policy is a Windows safety feature, not a security boundary, and it
does not apply on macOS or Linux. First inspect effective settings:

```powershell
Get-ExecutionPolicy -List
```

Do **not** weaken `LocalMachine` policy globally. If your organization permits
local learning scripts, prefer a scoped, reversible choice such as:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Group Policy can override this. Keep downloaded scripts reviewed and signed
where appropriate; `Unblock-File` is only for a script you have inspected and
trust. Your organization may require a different policy, which takes priority.

## 📦 Install development modules

[Pester](https://pester.dev/docs/introduction/installation) tests,
[PSScriptAnalyzer](https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/overview)
analysis, and
[SimplySql](https://www.powershellgallery.com/packages/SimplySql/2.2.0.106)
SQLite access are dependencies from the
[PowerShell Gallery](https://learn.microsoft.com/powershell/scripting/gallery/overview),
not requirements for reading ordinary lessons. SimplySql is required only for
Module 12 and the comparative capstone. PowerShell 7.4+ includes
[`Microsoft.PowerShell.PSResourceGet`](https://learn.microsoft.com/powershell/gallery/powershellget/overview),
the preferred package manager. Install the exact versions exercised by this
repository for your account. Pester 6.0.0 is the default local runner; 5.5.0 is
installed alongside it for compatibility checks:

```powershell
Install-PSResource -Name Pester -Version 5.5.0 -Repository PSGallery -Scope CurrentUser -TrustRepository
Install-PSResource -Name Pester -Version 6.0.0 -Repository PSGallery -Scope CurrentUser -TrustRepository
Install-PSResource -Name PSScriptAnalyzer -Version 1.25.0 -Repository PSGallery -Scope CurrentUser -TrustRepository
Install-PSResource -Name SimplySql -Version 2.2.0.106 -Repository PSGallery -Scope CurrentUser -TrustRepository
Import-Module Pester -RequiredVersion 6.0.0 -Force
Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Force
Import-Module SimplySql -RequiredVersion 2.2.0.106 -Force -WarningAction SilentlyContinue
Get-Module -ListAvailable Pester, PSScriptAnalyzer, SimplySql |
    Sort-Object Name, Version |
    Select-Object Name, Version, Path
```

`-TrustRepository` applies to that installation request; it does not globally
change the registered repository policy. Review the source and follow your
organization's package policy before using it. Explicit imports prevent another
installed module version from being auto-loaded accidentally. SimplySql is
intentionally pinned rather than floated because it bundles different native
SQLite assets for Linux, Windows, and macOS. Both comparative manifests declare
that exact pin; verify the dependency before running Module 12 or the capstone:

```powershell
$manifests = @(
    './capstones/comparative/starter/ComparativeKv.psd1'
    './capstones/comparative/solution/ComparativeKv.psd1'
)
foreach ($manifestPath in $manifests) {
    $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    $dependency = @($manifest.RequiredModules | Where-Object Name -eq 'SimplySql')
    if ($dependency.Count -ne 1 -or $dependency[0].Version -ne [version]'2.2.0.106') {
        throw "Unexpected SimplySql dependency in $manifestPath."
    }
}
```

Run the ordinary local feedback loop from the repository root:

```powershell
pwsh -NoProfile -File ./lessons/09_tooling_and_debugging/03_formatting_stage.ps1
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit
pwsh -NoProfile -File ./exercises/10_apis_and_automation/solutions.ps1
pwsh -NoProfile -File ./lessons/08_testing_with_pester/03_coverage_diagnostic.ps1
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 -Implementation All -Tag Smoke
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 -Capstone Comparative -Implementation Solution -Tag All
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 -Capstone Idiomatic -Implementation Solution -Tag All
```

The formatting script previews a candidate and writes only a disposable copy;
this repository does not enforce a layout gate. The coverage script likewise
produces a disposable diagnostic without a percentage threshold.

For an explicit local Pester compatibility check, run both complete solution
suites in separate clean processes so one imported major cannot mask the other:

```powershell
pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 5.5.0 -Force; & ./capstones/Invoke-CapstoneTests.ps1 -Capstone Comparative -Implementation Solution -Tag All'
pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 5.5.0 -Force; & ./capstones/Invoke-CapstoneTests.ps1 -Capstone Idiomatic -Implementation Solution -Tag All'
pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 6.0.0 -Force; & ./capstones/Invoke-CapstoneTests.ps1 -Capstone Comparative -Implementation Solution -Tag All'
pwsh -NoProfile -Command 'Import-Module Pester -RequiredVersion 6.0.0 -Force; & ./capstones/Invoke-CapstoneTests.ps1 -Capstone Idiomatic -Implementation Solution -Tag All'
```

CI exercises the PowerShell 7.4 compatibility floor and the current container
on Linux with both Pester versions. Pester 6.0.0 runs on the current hosted
PowerShell available on Windows and macOS. This is evidence for those exact
combinations, not every 7.4+/OS pairing. The SimplySql provider is exercised on
the selected hosted runner images; other architectures, PowerShell providers,
and network filesystems need their own smoke test.

## 🆘 Troubleshooting

- **`pwsh` not found:** reopen the terminal after installation and check the
  installer added PowerShell to `PATH`.
- **Wrong version:** run `pwsh`, not Windows PowerShell's `powershell.exe`;
  inspect `$PSVersionTable`.
- **Script is disabled:** read the execution-policy section; use an approved
  CurrentUser policy rather than bypassing policy or changing every user.
- **`Install-PSResource` fails:** inspect `Get-PSResourceRepository`, proxy and
  repository policy; your administrator may need to provide an approved internal
  repository.
- **`Invoke-Pester` missing:** install Pester for `CurrentUser`, close/reopen
  the session, then use `Get-Module -ListAvailable Pester`.
- **`SimplySql` missing or the wrong version:** install exact version
  `2.2.0.106`, then verify it with
  `Get-Module -ListAvailable SimplySql | Select-Object Name, Version, Path`.
- **SQLite native provider fails to load:** confirm the installed SimplySql
  package contains assets for the current OS and architecture. The repository
  validates its hosted Linux, Windows, and macOS runner images; a different
  architecture requires a separate provider smoke test.
- **A path works on one OS only:** build paths with `Join-Path`, use
  `-LiteralPath` for data paths, and avoid hard-coded drive letters.
