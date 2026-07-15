#Requires -Version 7.4

# This lesson demonstrates strict mode as an early-warning tool. The mental
# model: under Set-StrictMode -Version Latest, referencing a property that does
# not exist throws instead of silently returning $null, catching typos early.

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
# Under strict mode $person.MissingProperty throws; the catch captures that
# error message as evidence rather than letting the bug pass silently.
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
