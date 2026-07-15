Set-StrictMode -Version Latest

function Get-TaskUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri] $BaseUri,
        [Parameter(Mandatory)][string] $Query,
        [ValidateRange(1, 100)][int] $Page = 1
    )

    $builder = [System.UriBuilder]::new($BaseUri)
    $builder.Query = "q=$([uri]::EscapeDataString($Query))&page=$Page"
    $builder.Uri
}

Get-TaskUri -BaseUri 'https://example.invalid/tasks' -Query 'needs review' -Page 2
'Production policy: set timeouts, cap retries, honor pagination, and log no tokens.'
