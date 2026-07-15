#Requires -Version 7.4

Set-StrictMode -Version Latest

function Get-DisplayName {
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject] $Person)

    if ([string]::IsNullOrWhiteSpace($Person.Name)) {
        throw 'Person.Name must contain text.'
    }
    $Person.Name.Trim()
}

$person = [pscustomobject]@{ Name = ' Ada ' }
$strictModeMessage = try {
    $person.MissingProperty
    throw 'Expected strict mode to reject a missing property.'
}
catch {
    $_.Exception.Message
}

[pscustomobject]@{
    DisplayName = Get-DisplayName -Person $person
    StrictModeError = $strictModeMessage
}
