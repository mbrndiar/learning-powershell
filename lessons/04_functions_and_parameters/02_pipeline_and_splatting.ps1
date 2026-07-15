#Requires -Version 7.4

# This lesson shows how a function consumes pipeline input and how splatting
# passes options. The mental model: begin/process/end separate one-time setup
# from per-item work, and a hashtable of parameters keeps calls auditable.

Set-StrictMode -Version Latest

function Get-ScaledNumber {
    [CmdletBinding()]
    param(
        # ValueFromPipeline binds a piped scalar; ValueFromPipelineByPropertyName
        # binds a matching .Number property from a piped object.
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [int] $Number,
        [int] $Factor = 2
    )

    # begin/end run once; process runs once per pipeline item, so the shared
    # $seen counter accumulates across the whole stream.
    begin { $seen = 0 }
    process {
        $seen++
        [pscustomobject]@{ Input = $Number; Output = $Number * $Factor; Seen = $seen }
    }
    end { Write-Verbose "Processed $seen values." }
}

# Splatting: the hashtable's keys become named parameters (Verbose is a common
# parameter passed as data), which keeps the chosen options explicit.
$parameters = @{ Factor = 3; Verbose = $true }
1..3 | Get-ScaledNumber @parameters
[pscustomobject]@{ Number = 4 } | Get-ScaledNumber -Factor 3
