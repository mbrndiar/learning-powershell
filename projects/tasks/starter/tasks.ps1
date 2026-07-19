#Requires -Version 7.4

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', '',
    Justification = 'The guided starter preserves the CLI signature.'
)]
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Add', 'List', 'Show', 'Update', 'Complete', 'Remove')]
    [string] $Command,

    [uri] $BaseUri = 'http://127.0.0.1:8080/',

    [ValidateRange(1, 300)]
    [int] $TimeoutSec = 5,

    [ValidateRange(1, [long]::MaxValue)]
    [long] $Id,

    [AllowEmptyString()]
    [string] $Title,

    [ValidateSet('All', 'True', 'False')]
    [string] $Completed = 'All'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# M5: validate command-specific arguments, build paths and the completed query
# safely, call only the HTTP boundary through Invoke-RestMethod, validate every
# decoded response, print compact JSON, and map usage/API/response/transport
# failures to the documented exit codes.
$null = $Command, $BaseUri, $TimeoutSec, $Id, $Title, $Completed
[Console]::Error.WriteLine(
    'TasksProjectNotImplemented: tasks.ps1 is intentionally incomplete.'
)
exit 2
