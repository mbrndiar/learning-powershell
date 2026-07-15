Set-StrictMode -Version Latest

function Get-Greeting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [ValidateRange(1, 10)]
        [int] $Repeat = 1
    )

    foreach ($index in 1..$Repeat) {
        [pscustomobject]@{ Number = $index; Message = "Hello, $Name" }
    }
}

Get-Greeting -Name 'Ada' -Repeat 2
