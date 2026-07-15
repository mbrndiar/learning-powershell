#Requires -Version 7.4

Set-StrictMode -Version Latest

function Get-Greeting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
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
