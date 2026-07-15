#Requires -Version 7.4

# Reference solution for Module 4. The two ValueFrom* attributes let the same
# command bind Text from a piped string or from a piped object's Text property,
# and the per-item work lives in the process block.

Set-StrictMode -Version Latest

function ConvertTo-Label {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $Text,
        [ValidateSet('Upper', 'Lower')]
        [string] $Case = 'Upper'
    )
    process {
        $output = if ($Case -eq 'Upper') { $Text.ToUpperInvariant() } else { $Text.ToLowerInvariant() }
        [pscustomobject]@{ Input = $Text; Output = $output }
    }
}
$parameters = @{ Case = 'Lower' }
$result = 'ADA' | ConvertTo-Label @parameters
if ($result.Output -ne 'ada') { throw 'Conversion check failed.' }
$propertyResult = [pscustomobject]@{ Text = 'lin' } | ConvertTo-Label
if ($propertyResult.Output -ne 'LIN') { throw 'Property binding check failed.' }
'All checks passed.'
