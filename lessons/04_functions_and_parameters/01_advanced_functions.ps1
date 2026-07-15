#Requires -Version 7.4

# This lesson builds advanced functions: CmdletBinding turns a function into a
# cmdlet-like command, validation attributes enforce the input contract before
# the body runs, and parameter sets model mutually exclusive ways to call it.

Set-StrictMode -Version Latest

function Get-Greeting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        # Validation attributes reject bad input at bind time, so the body can
        # assume Name is present and non-blank and Repeat is within range.
        [ValidateNotNullOrWhiteSpace()]
        [string] $Name,

        [ValidateRange(1, 10)]
        [int] $Repeat = 1
    )

    foreach ($index in 1..$Repeat) {
        [pscustomobject]@{ Number = $index; Message = "Hello, $Name" }
    }
}

Get-Greeting -Name 'Ada' -Repeat 2

function Get-IdentityLabel {
    # Parameter sets make Name and Id mutually exclusive; the caller supplies
    # exactly one, and $PSCmdlet.ParameterSetName reports which set bound.
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [ValidateNotNullOrWhiteSpace()]
        [string] $Name,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [guid] $Id
    )

    $value = if ($PSCmdlet.ParameterSetName -eq 'ByName') { $Name } else { $Id.ToString() }
    [pscustomobject]@{ ParameterSet = $PSCmdlet.ParameterSetName; Value = $value }
}

Get-IdentityLabel -Name 'Ada'
Get-IdentityLabel -Id '00000000-0000-0000-0000-000000000001'
