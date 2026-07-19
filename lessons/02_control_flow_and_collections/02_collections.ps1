#Requires -Version 7.4

# This lesson focuses on collection sharp edges that surprise code copied
# from scalar-only languages: null comparison direction, array shape and
# deliberate wrapping, filtering equality, shallow references, and explicit
# set comparison.

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

# A collection on the left turns -eq into a filter. String comparisons are
# case-insensitive by default; -ceq selects the case-sensitive variant.
$caseInsensitiveMatches = @($names -eq 'ada')
$caseSensitiveMatches = @($names -ceq 'ada')

$originalTasks = @([pscustomobject]@{ Name = 'Read'; Done = $false })
$copiedTasks = @($originalTasks)
# Only the outer array was copied. Both arrays still refer to this same mutable
# task object, so a property edit is visible through either array.
$copiedTasks[0].Done = $true
$outerArrayWasCopied = -not [object]::ReferenceEquals($originalTasks, $copiedTasks)
$innerObjectIsShared = [object]::ReferenceEquals($originalTasks[0], $copiedTasks[0])

$firstRecord = [pscustomobject]@{ Name = 'Ada' }
$secondRecord = [pscustomobject]@{ Name = 'Ada' }
# Identical-looking properties do not define universal deep object equality.
$separateRecordsAreEqual = $firstRecord -eq $secondRecord

$seen = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
$uniqueNames = @(
    foreach ($candidate in @('Ada', 'ada', 'Lin', 'LIN')) {
        # Add returns false for an equivalent value, so emission at this point
        # preserves both first-seen order and the original spelling.
        if ($seen.Add($candidate)) { $candidate }
    }
)

if ($caseInsensitiveMatches.Count -ne 1 -or $caseInsensitiveMatches[0] -ne 'Ada') {
    throw 'Case-insensitive filtering evidence failed.'
}
if ($caseSensitiveMatches.Count -ne 0) {
    throw 'Case-sensitive filtering evidence failed.'
}
if (-not $outerArrayWasCopied -or -not $innerObjectIsShared -or -not $originalTasks[0].Done) {
    throw 'Shallow-copy evidence failed.'
}
if ($separateRecordsAreEqual -or ($uniqueNames -join ',') -ne 'Ada,Lin') {
    throw 'Object equality or set evidence failed.'
}

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
    CaseInsensitiveMatchCount = $caseInsensitiveMatches.Count
    CaseSensitiveMatchCount = $caseSensitiveMatches.Count
    OuterArrayWasCopied = $outerArrayWasCopied
    InnerObjectIsShared = $innerObjectIsShared
    SeparateRecordsAreEqual = $separateRecordsAreEqual
    FirstSeenUniqueNames = $uniqueNames -join ', '
}
