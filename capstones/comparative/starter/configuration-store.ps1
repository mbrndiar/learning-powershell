#Requires -Version 7.4

Set-StrictMode -Version Latest
Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'ComparativeKv.psd1') -Force

# Automatic $args preserves shared tokens such as --db when pwsh uses -File.
# Milestone 2 replaces this deliberate failure with the exact grammar parser.
$argumentCount = @($args).Count
$exception = [System.NotImplementedException]::new(
    "The comparative CLI parser is intentionally incomplete; received $argumentCount argument(s)."
)
$errorRecord = [System.Management.Automation.ErrorRecord]::new(
    $exception,
    'CapstoneNotImplemented',
    [System.Management.Automation.ErrorCategory]::NotImplemented,
    $null
)
$PSCmdlet.ThrowTerminatingError($errorRecord)
