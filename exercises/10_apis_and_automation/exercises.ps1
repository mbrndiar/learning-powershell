#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

# Starter for Module 10. Get-ActiveRecord parses an injected JSON response and
# must validate the Active flag as a real Boolean; Get-SearchUri must escape
# only the query value. Add tests for filtering, bad data, and URI building.

Set-StrictMode -Version Latest

function Get-ActiveRecord {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Request)
    # TODO: Invoke Request, parse its JSON, and emit records where Active is true.
    throw 'TODO: implement Get-ActiveRecord.'
}

function Get-SearchUri {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri] $BaseUri,
        [Parameter(Mandatory)][string] $Query,
        [ValidateRange(1, 100)][int] $Page = 1
    )
    # TODO: Validate BaseUri and Query, escape the query value, and return a Uri.
    throw 'TODO: implement Get-SearchUri.'
}
# TODO: Add Pester tests for filtering, invalid JSON/schema, and URI construction.
'TODO functions and tests are intentionally incomplete.'
