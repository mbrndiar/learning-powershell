#Requires -Version 7.4

# Starter for Module 2. Get-ScoreLabel branches on a range; Get-SettingValue
# must distinguish an absent key from a present one. Prefer a membership test
# because indexing alone cannot distinguish an absent key from a present key
# whose value is $null.

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
'TODO functions are intentionally incomplete.'
