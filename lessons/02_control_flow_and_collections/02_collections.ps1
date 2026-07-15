#Requires -Version 7.4

# This lesson focuses on collection sharp edges that surprise code copied
# from scalar-only languages: null comparison direction, array shape and
# deliberate wrapping, and where PowerShell's truthiness rules bite.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSPossibleIncorrectComparisonWithNull', '',
    Justification = 'The right-side null comparison is an intentional counterexample.'
)]
param()

Set-StrictMode -Version Latest

$names = @('Ada', 'Lin', 'Sam')
$settings = [ordered]@{ Retries = 2; Enabled = $true }
$maybeMissing = $null
# The unary comma wraps a value in a one-element array without unrolling it.
$singleElement = ,$names
$valuesWithNull = @(1, $null, 3)
# COUNTEREXAMPLE: with a collection on the left, -eq applies element-wise
# filtering instead of one scalar test. It returns an Object[] containing the
# matching $null, whose Boolean value is still falsey.
$reversedNullComparison = $valuesWithNull -eq $null

[pscustomobject]@{
    FirstName = $names[0]
    RetryCount = $settings['Retries']
    # $null on the left is the safe form: it always yields a single Boolean.
    IsMissing = ($null -eq $maybeMissing)
    PipelineCount = @($names | ForEach-Object { $_ }).Count
    # ,$names is one element (the inner array), so Count is 1, not 3.
    SingleElementCount = $singleElement.Count
    # An empty collection is falsy.
    EmptyCollectionIsTruthy = [bool] @()
    # Boolean conversion of a one-element collection uses its element's value.
    SingleZeroIsTruthy = [bool] @(0)
    # A multi-element array is truthy regardless of the values inside it.
    TwoFalseValuesAreTruthy = [bool] @($false, $false)
    # Count is 1, but the one returned value is $null/falsy. That is why this
    # filtered result is not a reliable scalar null test.
    ReversedNullComparisonCount = @($reversedNullComparison).Count
}
