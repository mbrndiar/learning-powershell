Set-StrictMode -Version Latest

function ConvertTo-Label {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [ValidateNotNullOrEmpty()]
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
'All checks passed.'
