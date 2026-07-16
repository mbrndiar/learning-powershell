# 🛠️ Setup

## 📥 Install PowerShell 7.4+

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

[Pester](https://pester.dev/docs/introduction/installation) tests and
[PSScriptAnalyzer](https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/overview)
are development dependencies from the
[PowerShell Gallery](https://learn.microsoft.com/powershell/scripting/gallery/overview),
not requirements for reading lessons. Install the versions exercised by this
repository only for your account:

```powershell
Install-Module -Name Pester -RequiredVersion 6.0.0 -Scope CurrentUser -Force
Install-Module -Name PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser -Force
Import-Module Pester -RequiredVersion 6.0.0 -Force
Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Force
Get-Module Pester, PSScriptAnalyzer | Select-Object Name, Version
```

If prompted to install or trust a repository, review the prompt and follow
your organization's package policy. Explicit imports prevent another installed
module version from being auto-loaded accidentally. CI additionally exercises
Pester 5.5.0 for compatibility. Then run:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path ./project/TaskManager/tests -Output Detailed
pwsh -NoProfile -File ./capstones/Invoke-CapstoneTests.ps1 -Implementation All -Tag Smoke
```

## 🆘 Troubleshooting

- **`pwsh` not found:** reopen the terminal after installation and check the
  installer added PowerShell to `PATH`.
- **Wrong version:** run `pwsh`, not Windows PowerShell's `powershell.exe`;
  inspect `$PSVersionTable`.
- **Script is disabled:** read the execution-policy section; use an approved
  CurrentUser policy rather than bypassing policy or changing every user.
- **`Install-Module` fails:** check proxy/repository policy and `Get-PSRepository`;
  your administrator may need to provide an approved internal repository.
- **`Invoke-Pester` missing:** install Pester for `CurrentUser`, close/reopen
  the session, then use `Get-Module -ListAvailable Pester`.
- **A path works on one OS only:** build paths with `Join-Path`, use
  `-LiteralPath` for data paths, and avoid hard-coded drive letters.
