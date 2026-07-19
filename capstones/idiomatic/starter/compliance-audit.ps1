#Requires -Version 7.4

<#
.SYNOPSIS
Optional reference launcher over the ComplianceAudit module's four public
commands.

.DESCRIPTION
This script is a nonnormative parsing/wiring exercise, not part of the module
contract described by SPEC.md. The parameter contract below is complete and
matches solution/compliance-audit.ps1 exactly, so starter/solution parity
stays inspectable with Get-Command -Syntax; only the wiring body is left for
the learner. A finished launcher only calls the exported commands
Import-CompliancePolicy, Test-Compliance, Repair-Compliance, and
Export-ComplianceReport with plain parameter binding; it must never build or
evaluate a shell command string, never read secrets, and never default a
target to a privileged path.

Every target root must be supplied explicitly by the caller. There is no
implicit $HOME, drive-root, or working-directory fallback: TargetRoot is
mandatory, and each resolved root should be rejected if it is exactly a
filesystem root or exactly $HOME, so a typo cannot widen the audit past the
disposable directories the caller intended.

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

# Guided scaffold: parameter binding/validation above is complete and final.
# Wiring the four public commands together (policy import, target
# construction with the drive-root/$HOME guard, Test-Compliance, an optional
# Repair-Compliance + re-audit pass honoring WhatIf/Confirm, and an optional
# Export-ComplianceReport call) is left for the learner and is intentionally
# unimplemented in this scaffold.
$null = $PolicyPath, $TargetRoot, $TargetName, $RuleId, $ThrottleLimit,
    $Repair, $ReportPath, $ReportFormat, $Force
$exception = [System.NotImplementedException]::new(
    'The optional compliance launcher is intentionally incomplete after parameter binding.'
)
$errorRecord = [System.Management.Automation.ErrorRecord]::new(
    $exception,
    'CapstoneNotImplemented',
    [System.Management.Automation.ErrorCategory]::NotImplemented,
    $null
)
$PSCmdlet.ThrowTerminatingError($errorRecord)
