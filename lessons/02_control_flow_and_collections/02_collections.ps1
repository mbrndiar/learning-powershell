#Requires -Version 7.4

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSPossibleIncorrectComparisonWithNull', '',
    Justification = 'The right-side null comparison is an intentional counterexample.'
)]
param()

Set-StrictMode -Version Latest

$names = @('Ada', 'Lin', 'Sam')
$settings = [ordered]@{ Retries = 2; Enabled = $true }
$maybeMissing = $null
$singleElement = ,$names
$valuesWithNull = @(1, $null, 3)
$reversedNullComparison = $valuesWithNull -eq $null

[pscustomobject]@{
    FirstName = $names[0]
    RetryCount = $settings['Retries']
    IsMissing = ($null -eq $maybeMissing)
    PipelineCount = @($names | ForEach-Object { $_ }).Count
    SingleElementCount = $singleElement.Count
    EmptyCollectionIsTruthy = [bool] @()
    SingleZeroIsTruthy = [bool] @(0)
    TwoFalseValuesAreTruthy = [bool] @($false, $false)
    ReversedNullComparisonCount = @($reversedNullComparison).Count
}
