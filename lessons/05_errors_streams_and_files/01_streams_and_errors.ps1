#Requires -Version 7.4

# This lesson shows the stream and error model. The mental model: a
# non-terminating error is not catchable until -ErrorAction Stop turns it into
# a terminating one, and warnings travel on a separate stream from output.

Set-StrictMode -Version Latest

function Get-OptionalText {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    try {
        # -ErrorAction Stop promotes the "not found" error to terminating so
        # the catch below can actually intercept it.
        Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    }
    # Catch the specific exception type; broader catches can hide real bugs.
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Warning "Optional input was not found: $Path"
        # Emitting $null produces no success-stream object; a caller capturing
        # the result observes that absence as $null.
        $null
    }
}

Write-Verbose 'Use -Verbose to see this diagnostic.' -Verbose
Get-OptionalText -Path (Join-Path -Path $PWD -ChildPath 'does-not-exist.txt')
