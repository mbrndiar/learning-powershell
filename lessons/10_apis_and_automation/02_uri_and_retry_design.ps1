#Requires -Version 7.4

Set-StrictMode -Version Latest

function Get-TaskUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (-not $_.IsAbsoluteUri -or $_.Scheme -notin @('http', 'https')) {
                throw 'BaseUri must be an absolute HTTP or HTTPS URI.'
            }
            if (-not [string]::IsNullOrEmpty($_.Query)) {
                throw 'BaseUri must not already contain a query string.'
            }
            $true
        })]
        [uri] $BaseUri,

        [Parameter(Mandatory)]
        [ValidateScript({
            if ([string]::IsNullOrWhiteSpace($_)) { throw 'Query cannot be blank.' }
            $true
        })]
        [string] $Query,

        [ValidateRange(1, 100)][int] $Page = 1
    )

    $builder = [System.UriBuilder]::new($BaseUri)
    $builder.Query = "q=$([uri]::EscapeDataString($Query))&page=$Page"
    $builder.Uri
}

function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock] $Operation,
        [Parameter(Mandatory)][scriptblock] $ShouldRetry,
        [Parameter(Mandatory)][scriptblock] $Delay,
        [ValidateRange(1, 10)][int] $MaxAttempts = 3
    )

    foreach ($attempt in 1..$MaxAttempts) {
        try {
            $attemptOutput = @(& $Operation $attempt)
            return $attemptOutput
        }
        catch {
            $retryable = & $ShouldRetry $_
            if ($retryable -isnot [bool]) {
                throw 'ShouldRetry must return exactly one Boolean value.'
            }
            if ($attempt -eq $MaxAttempts -or -not $retryable) {
                throw
            }
            & $Delay (100 * $attempt) | Out-Null
        }
    }
}

function Get-PagedTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock] $RequestPage,
        [ValidateRange(1, 100)][int] $MaxPages = 10
    )

    foreach ($page in 1..$MaxPages) {
        $pageOutput = @(& $RequestPage $page)
        if ($pageOutput.Count -ne 1) {
            throw "Page $page must return exactly one response object."
        }
        $response = $pageOutput[0]
        if (
            $null -eq $response -or
            $null -eq $response.PSObject.Properties['Items'] -or
            $null -eq $response.PSObject.Properties['HasMore']
        ) {
            throw "Page $page did not contain Items and HasMore."
        }
        if ($response.HasMore -isnot [bool]) {
            throw "Page $page HasMore must be a Boolean."
        }
        if ($response.Items -isnot [array]) {
            throw "Page $page Items must be an array."
        }
        if (@($response.Items | Where-Object { $null -eq $_ }).Count -gt 0) {
            throw "Page $page Items must not contain null entries."
        }
        foreach ($item in $response.Items) {
            $item
        }
        if (-not $response.HasMore) {
            return
        }
    }
    throw "Pagination exceeded the limit of $MaxPages pages."
}

$retryState = [pscustomobject]@{
    Attempts = 0
    Delays = [System.Collections.Generic.List[int]]::new()
}
$retried = Invoke-WithRetry -MaxAttempts 3 -Operation {
    param($attempt)
    $retryState.Attempts = $attempt
    if ($attempt -lt 2) {
        'This partial response is discarded with the failed attempt.'
        throw [System.TimeoutException]::new('Simulated timeout.')
    }
    [pscustomobject]@{ Name = 'Read'; Done = $true }
} -ShouldRetry {
    param($errorRecord)
    $errorRecord.Exception -is [System.TimeoutException]
} -Delay {
    param($milliseconds)
    $retryState.Delays.Add($milliseconds)
}

$pages = @{
    1 = [pscustomobject]@{
        Items = @([pscustomobject]@{ Name = 'Read' })
        HasMore = $true
    }
    2 = [pscustomobject]@{
        Items = @([pscustomobject]@{ Name = 'Build' })
        HasMore = $false
    }
}
$pagedTasks = @(Get-PagedTask -MaxPages 3 -RequestPage { param($page) $pages[$page] })
$paginationValidation = @(
    try {
        Get-PagedTask -MaxPages 1 -RequestPage {
            [pscustomobject]@{ Items = @(); HasMore = 'false' }
        }
        throw 'Expected invalid HasMore data to fail.'
    }
    catch {
        $_.Exception.Message
    }
    try {
        Get-PagedTask -MaxPages 1 -RequestPage {
            [pscustomobject]@{ Items = [pscustomobject]@{ Name = 'scalar' }; HasMore = $false }
        }
        throw 'Expected scalar Items data to fail.'
    }
    catch {
        $_.Exception.Message
    }
) -join ' | '

[pscustomobject]@{
    Uri = Get-TaskUri -BaseUri 'https://example.invalid/tasks' -Query 'needs review' -Page 2
    RetriedTask = $retried.Name
    RetryAttempts = $retryState.Attempts
    RetryDelays = $retryState.Delays -join ', '
    PagedTasks = $pagedTasks.Name -join ', '
    PaginationValidation = $paginationValidation
}
