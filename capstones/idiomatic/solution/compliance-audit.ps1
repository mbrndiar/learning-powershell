#Requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [AllowEmptyCollection()]
    [string[]] $ArgumentList
)

Set-StrictMode -Version Latest
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'ComplianceAudit.psd1') -Force

$argumentCount = @($ArgumentList).Count
$exception = [System.NotImplementedException]::new(
    "The optional compliance launcher is intentionally incomplete; received $argumentCount argument(s)."
)
$errorRecord = [System.Management.Automation.ErrorRecord]::new(
    $exception,
    'CapstoneNotImplemented',
    [System.Management.Automation.ErrorCategory]::NotImplemented,
    $null
)
$PSCmdlet.ThrowTerminatingError($errorRecord)
