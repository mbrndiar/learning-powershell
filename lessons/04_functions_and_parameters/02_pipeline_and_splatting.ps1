Set-StrictMode -Version Latest

function Get-ScaledNumber {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [int] $Number,
        [int] $Factor = 2
    )

    begin { $seen = 0 }
    process {
        $seen++
        [pscustomobject]@{ Input = $Number; Output = $Number * $Factor; Seen = $seen }
    }
    end { Write-Verbose "Processed $seen values." }
}

$parameters = @{ Factor = 3; Verbose = $true }
1..3 | Get-ScaledNumber @parameters
