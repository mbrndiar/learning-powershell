#Requires -Version 7.4

# Starter for Module 2. Advanced-function and validation syntax is supplied
# infrastructure taught in Module 4; edit only TODO bodies. Get-SettingValue
# must distinguish an absent key from a present falsey value, and uniqueness
# must use an explicit case-insensitive set comparer.

Set-StrictMode -Version Latest

function Get-ScoreLabel {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([ValidateRange(0, 100)][int] $Score)
    # TODO: Return Pass for >= 60, otherwise Retry.
    throw 'TODO: implement Get-ScoreLabel.'
}
function Get-SettingValue {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([hashtable] $Setting, [string] $Name)
    # TODO: Return the value, or $null when the key is absent.
    throw 'TODO: implement Get-SettingValue.'
}
function Get-FirstSeenUniqueName {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'Parameters are intentionally unused in the TODO starter.'
    )]
    [CmdletBinding()]
    param([AllowEmptyCollection()][string[]] $Name)
    # TODO: Use HashSet[string] with OrdinalIgnoreCase and emit first-seen names.
    throw 'TODO: implement Get-FirstSeenUniqueName.'
}
'TODO bodies are intentionally incomplete.'
