#Requires -Version 7.4

# Starter for Module 7. Assert-NativeExitCode turns a native exit code into a
# PowerShell error; Set-DesiredContent must be idempotent (write only when the
# content differs) and guard the write behind ShouldProcess.

Set-StrictMode -Version Latest

function Assert-NativeExitCode {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int] $ExitCode,
        [int[]] $SuccessExitCode = @(0)
    )
    # TODO: Return allowed exit codes and throw for every other value.
    throw 'TODO: implement Assert-NativeExitCode.'
}

function Set-DesiredContent {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSShouldProcess', '',
        Justification = 'The learner adds the ShouldProcess call in this TODO starter.'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string] $LiteralPath, [Parameter(Mandatory)][string] $Content)
    # TODO: Write only when content differs and ShouldProcess approves.
    # TODO: Return an object with Path and Changed.
    throw 'TODO: implement Set-DesiredContent.'
}
'TODO functions are intentionally incomplete; add a native exit-code self-check.'
