Set-StrictMode -Version Latest

function Get-DisplayName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject] $Person)

    if ([string]::IsNullOrWhiteSpace($Person.Name)) {
        throw 'Person.Name must contain text.'
    }
    $Person.Name.Trim()
}

Get-DisplayName -Person ([pscustomobject]@{ Name = ' Ada ' })
