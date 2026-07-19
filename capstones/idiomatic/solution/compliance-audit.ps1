#Requires -Version 7.4

<#
.SYNOPSIS
Optional reference launcher over the ComplianceAudit module's four public
commands.

.DESCRIPTION
This script is a nonnormative parsing/wiring exercise, not part of the module
contract described by SPEC.md. It only calls the exported commands
Import-CompliancePolicy, Test-Compliance, Repair-Compliance, and
Export-ComplianceReport with plain parameter binding; it never builds or
evaluates a shell command string, never reads secrets, and never defaults a
target to a privileged path.

Every target root must be supplied explicitly by the caller. There is no
implicit $HOME, drive-root, or working-directory fallback: TargetRoot is
mandatory, and each resolved root is rejected if it is exactly a filesystem
root or exactly $HOME, so a typo cannot widen the audit past the disposable
directories the caller intended.

.PARAMETER PolicyPath
The explicit path to the UTF-8 JSON compliance policy document. There is no
default; the caller must always name the policy to load.

.PARAMETER TargetRoot
One or more explicit, disposable target root directories to audit. Each root
must already exist and must not resolve to a filesystem drive root or $HOME.

.PARAMETER TargetName
One optional name per TargetRoot, in the same order. When omitted, targets are
named 'target-1', 'target-2', and so on, in TargetRoot order.

.PARAMETER RuleId
One or more policy rule IDs to select. When omitted, every rule in the policy
is audited.

.PARAMETER ThrottleLimit
The maximum number of independent target/rule audits, from 1 through 32.
Forwarded to Test-Compliance unchanged.

.PARAMETER Repair
Requests a remediation pass. When set, every NonCompliant, remediable finding
from the initial audit is piped through Repair-Compliance, and the targets are
re-audited afterward so the emitted findings reflect the current state. This
switch does not itself force or suppress confirmation: this script explicitly
forwards its own effective -WhatIf value, and any -Confirm value the caller
bound, to Repair-Compliance and Export-ComplianceReport, so
./compliance-audit.ps1 -Repair -WhatIf previews with zero writes exactly as a
direct Repair-Compliance -WhatIf call would. The forwarding is explicit,
rather than left to PowerShell's preference-variable inheritance, because that
inheritance is not reliable across every hosting/invocation context.

.PARAMETER ReportPath
An optional destination for a deterministic JSON or CSV report of the final
findings, written through Export-ComplianceReport.

.PARAMETER ReportFormat
The report format used with ReportPath: Json or Csv. Defaults to Json.

.PARAMETER Force
Forwarded to Export-ComplianceReport to allow replacing an existing
ReportPath destination.

.OUTPUTS
ComplianceAudit.Finding

.EXAMPLE
$root = Join-Path $PWD ('.launcher-demo-{0}' -f [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $root
./compliance-audit.ps1 -PolicyPath ./policy.json -TargetRoot $root -TargetName demo

.EXAMPLE
./compliance-audit.ps1 -PolicyPath ./policy.json -TargetRoot $root -Repair -Confirm:$false `
    -ReportPath ./report.json -ReportFormat Json -Force
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $PolicyPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]] $TargetRoot,

    [ValidateNotNullOrEmpty()]
    [string[]] $TargetName,

    [ValidateNotNullOrEmpty()]
    [string[]] $RuleId,

    [ValidateRange(1, 32)]
    [int] $ThrottleLimit = 1,

    [switch] $Repair,

    [ValidateNotNullOrEmpty()]
    [string] $ReportPath,

    [ValidateSet('Json', 'Csv')]
    [string] $ReportFormat = 'Json',

    [switch] $Force
)

Set-StrictMode -Version Latest
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'ComplianceAudit.psd1') -Force

function Assert-LauncherDisposableRoot {
    # Refuses exactly a drive root or exactly $HOME. This is an explicit
    # belt-and-suspenders check for the reference launcher; it never widens
    # or replaces the module's own containment/adapter validation.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    if ($resolved.Provider.Name -cne 'FileSystem') {
        throw [System.ArgumentException]::new(
            "TargetRoot '$Path' must resolve through the FileSystem provider."
        )
    }
    $resolvedPath = $resolved.ProviderPath
    $trimmedPath = [System.IO.Path]::TrimEndingDirectorySeparator($resolvedPath)
    $driveRoot = [System.IO.Path]::TrimEndingDirectorySeparator(
        [System.IO.Path]::GetPathRoot($resolvedPath)
    )
    $pathComparer = if ($IsWindows) {
        [System.StringComparer]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparer]::Ordinal
    }
    $isDriveRoot = $pathComparer.Equals($trimmedPath, $driveRoot)
    $isHomeDirectory = -not [string]::IsNullOrEmpty($HOME) -and (
        $pathComparer.Equals(
            $trimmedPath,
            [System.IO.Path]::TrimEndingDirectorySeparator(
                [System.IO.Path]::GetFullPath($HOME)
            )
        )
    )
    if ($isDriveRoot -or $isHomeDirectory) {
        throw [System.ArgumentException]::new(
            "TargetRoot '$Path' resolves to a filesystem drive root or `$HOME. " +
            'Supply an explicit disposable directory created for this run instead.'
        )
    }
}

if ($PSBoundParameters.ContainsKey('TargetName') -and $TargetName.Count -ne $TargetRoot.Count) {
    throw [System.ArgumentException]::new(
        'TargetName must supply exactly one name per TargetRoot, in the same order.'
    )
}

$targets = for ($index = 0; $index -lt $TargetRoot.Count; $index++) {
    Assert-LauncherDisposableRoot -Path $TargetRoot[$index]
    [pscustomobject]@{
        Name = if ($PSBoundParameters.ContainsKey('TargetName')) {
            $TargetName[$index]
        }
        else {
            'target-{0}' -f ($index + 1)
        }
        RootPath = $TargetRoot[$index]
    }
}

$policy = Import-CompliancePolicy -Path $PolicyPath

$auditParameters = @{ Policy = $policy }
if ($PSBoundParameters.ContainsKey('RuleId')) {
    $auditParameters.RuleId = $RuleId
}
if ($PSBoundParameters.ContainsKey('ThrottleLimit')) {
    $auditParameters.ThrottleLimit = $ThrottleLimit
}

# Repair-Compliance and Export-ComplianceReport each own a ShouldProcess
# check. $WhatIfPreference/$ConfirmPreference do not reliably cross a nested
# advanced-function call in every hosting context (for example, invocation
# through the call operator versus -File), so this script forwards -WhatIf
# and any explicitly bound -Confirm value itself rather than depending on
# implicit preference-variable inheritance. This keeps
# ./compliance-audit.ps1 -Repair -WhatIf and -Confirm/-Confirm:$false exactly
# equivalent to calling Repair-Compliance/Export-ComplianceReport directly
# with the same switches.
$shouldProcessParameters = @{ WhatIf = [bool] $WhatIfPreference }
if ($PSBoundParameters.ContainsKey('Confirm')) {
    $shouldProcessParameters.Confirm = [bool] $PSBoundParameters['Confirm']
}

$findings = @($targets | Test-Compliance @auditParameters)

if ($Repair) {
    $findings | Repair-Compliance -Policy $policy @shouldProcessParameters | Out-Null
    $findings = @($targets | Test-Compliance @auditParameters)
}

if ($PSBoundParameters.ContainsKey('ReportPath')) {
    $reportParameters = @{ Path = $ReportPath; Format = $ReportFormat }
    if ($Force) {
        $reportParameters.Force = $true
    }
    $findings | Export-ComplianceReport @reportParameters @shouldProcessParameters
}

$findings
