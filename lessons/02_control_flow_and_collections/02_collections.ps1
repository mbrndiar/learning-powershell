Set-StrictMode -Version Latest

$names = @('Ada', 'Lin', 'Sam')
$settings = [ordered]@{ Retries = 2; Enabled = $true }
$maybeMissing = $null
$singleElement = ,$names

[pscustomobject]@{
    FirstName = $names[0]
    RetryCount = $settings['Retries']
    IsMissing = ($null -eq $maybeMissing)
    PipelineCount = @($names | ForEach-Object { $_ }).Count
    SingleElementCount = $singleElement.Count
}
