#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('SQLite', 'Markdown')]
    [string] $Backend,

    [Parameter(Mandatory)]
    [ValidateNotNullOrWhiteSpace()]
    [string] $DataPath,

    [uri] $UriPrefix = 'http://127.0.0.1:8080/'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TaskApiErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('TaskApi.InvalidJson', 'Task.Validation')]
        [string] $ErrorId,

        [Parameter(Mandatory)]
        [string] $Message,

        [AllowNull()]
        [object] $TargetObject,

        [AllowNull()]
        [Exception] $InnerException
    )

    $exception = if ($null -eq $InnerException) {
        [System.ArgumentException]::new($Message)
    }
    else {
        [System.ArgumentException]::new($Message, $InnerException)
    }
    [System.Management.Automation.ErrorRecord]::new(
        $exception,
        $ErrorId,
        [System.Management.Automation.ErrorCategory]::InvalidArgument,
        $TargetObject
    )
}

function Stop-TaskApiRequest {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'This private helper creates a terminating validation error and does not mutate state.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('TaskApi.InvalidJson', 'Task.Validation')]
        [string] $ErrorId,

        [Parameter(Mandatory)]
        [string] $Message,

        [AllowNull()]
        [object] $TargetObject,

        [AllowNull()]
        [Exception] $InnerException
    )

    throw (Get-TaskApiErrorRecord @PSBoundParameters)
}

function ConvertTo-TaskApiResponse {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(100, 599)]
        [int] $StatusCode,

        [AllowNull()]
        [object] $Body,

        [AllowNull()]
        [string] $Allow
    )

    [pscustomobject]@{
        StatusCode = $StatusCode
        Body = $Body
        Allow = $Allow
    }
}

function ConvertTo-TaskApiErrorResponse {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(400, 599)]
        [int] $StatusCode,

        [Parameter(Mandatory)]
        [ValidateSet(
            'invalid_json',
            'not_found',
            'method_not_allowed',
            'validation_error',
            'internal_error'
        )]
        [string] $Code,

        [Parameter(Mandatory)]
        [string] $Message,

        [AllowNull()]
        [string] $Allow
    )

    ConvertTo-TaskApiResponse -StatusCode $StatusCode -Allow $Allow -Body @{
        error = [ordered]@{
            code = $Code
            message = $Message
        }
    }
}

function Read-TaskApiJsonObject {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerRequest] $Request
    )

    $mediaType = if ([string]::IsNullOrWhiteSpace($Request.ContentType)) {
        ''
    }
    else {
        ($Request.ContentType -split ';', 2)[0].Trim()
    }
    if (-not $mediaType.Equals(
            'application/json',
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
        Stop-TaskApiRequest -ErrorId TaskApi.InvalidJson `
            -Message 'A JSON request body requires Content-Type application/json.' `
            -TargetObject $Request.ContentType
    }
    if ($Request.ContentLength64 -gt 65536) {
        Stop-TaskApiRequest -ErrorId TaskApi.InvalidJson `
            -Message 'The JSON request body is too large.' `
            -TargetObject $Request.ContentLength64
    }

    $memory = [System.IO.MemoryStream]::new()
    try {
        $buffer = [byte[]]::new(8192)
        while (($bytesRead = $Request.InputStream.Read(
                    $buffer,
                    0,
                    $buffer.Length
                )) -gt 0) {
            if ($memory.Length + $bytesRead -gt 65536) {
                Stop-TaskApiRequest -ErrorId TaskApi.InvalidJson `
                    -Message 'The JSON request body is too large.' `
                    -TargetObject ($memory.Length + $bytesRead)
            }
            $memory.Write($buffer, 0, $bytesRead)
        }

        try {
            $text = [System.Text.UTF8Encoding]::new($false, $true).GetString(
                $memory.ToArray()
            )
        }
        catch {
            Stop-TaskApiRequest -ErrorId TaskApi.InvalidJson `
                -Message 'The JSON request body is not valid UTF-8.' `
                -InnerException $_.Exception
        }
        if ([string]::IsNullOrWhiteSpace($text)) {
            Stop-TaskApiRequest -ErrorId TaskApi.InvalidJson `
                -Message 'The JSON request body is empty.'
        }

        try {
            $body = ConvertFrom-Json -InputObject $text -AsHashtable `
                -NoEnumerate -ErrorAction Stop
        }
        catch {
            Stop-TaskApiRequest -ErrorId TaskApi.InvalidJson `
                -Message 'The request body is not valid JSON.' `
                -InnerException $_.Exception
        }
        if ($body -isnot [System.Collections.IDictionary]) {
            Stop-TaskApiRequest -ErrorId Task.Validation `
                -Message 'The JSON request body must be an object.' `
                -TargetObject $body
        }

        $body
    }
    finally {
        $memory.Dispose()
    }
}

function Assert-TaskApiProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Body,

        [Parameter(Mandatory)]
        [string[]] $Allowed,

        [string[]] $Required = @()
    )

    foreach ($name in $Body.Keys) {
        if ($name -cnotin $Allowed) {
            Stop-TaskApiRequest -ErrorId Task.Validation `
                -Message "Unknown request property: $name." -TargetObject $name
        }
    }
    foreach ($name in $Required) {
        if (-not $Body.Contains($name)) {
            Stop-TaskApiRequest -ErrorId Task.Validation `
                -Message "Missing required request property: $name." `
                -TargetObject $name
        }
    }
}

function ConvertTo-TaskApiId {
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory)]
        [string] $Text
    )

    $id = [long] 0
    if ($Text -notmatch '^[1-9][0-9]*$' -or
        -not [long]::TryParse(
            $Text,
            [System.Globalization.NumberStyles]::None,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref] $id
        )) {
        Stop-TaskApiRequest -ErrorId Task.Validation `
            -Message 'Task IDs must be positive base-10 integers.' `
            -TargetObject $Text
    }
    $id
}

function ConvertTo-TaskApiModel {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object] $Task
    )

    [pscustomobject][ordered]@{
        id = [long] $Task.Id
        title = [string] $Task.Title
        completed = [bool] $Task.Completed
    }
}

function Get-TaskApiFilter {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerRequest] $Request
    )

    $keys = @($Request.QueryString.AllKeys | Where-Object { $null -ne $_ })
    foreach ($key in $keys) {
        if ($key -cne 'completed') {
            Stop-TaskApiRequest -ErrorId Task.Validation `
                -Message "Unknown query parameter: $key." -TargetObject $key
        }
    }
    $rawValues = $Request.QueryString.GetValues('completed')
    if ($null -eq $rawValues) {
        return [pscustomobject]@{ Supplied = $false; Value = $false }
    }
    $values = @($rawValues)
    if ($values.Count -ne 1 -or $values[0] -cnotin 'true', 'false') {
        Stop-TaskApiRequest -ErrorId Task.Validation `
            -Message 'completed must appear once with value true or false.' `
            -TargetObject $values
    }

    [pscustomobject]@{
        Supplied = $true
        Value = $values[0] -ceq 'true'
    }
}

function Invoke-TaskApiRequest {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerRequest] $Request,

        [Parameter(Mandatory)]
        [object] $Store
    )

    $method = $Request.HttpMethod.ToUpperInvariant()
    $path = $Request.Url.AbsolutePath

    if ($path -ceq '/health') {
        if ($method -cne 'GET') {
            return ConvertTo-TaskApiErrorResponse -StatusCode 405 `
                -Code method_not_allowed -Message 'Method is not allowed for /health.' `
                -Allow 'GET'
        }
        return ConvertTo-TaskApiResponse -StatusCode 200 -Body @{ status = 'ok' }
    }

    if ($path -ceq '/tasks') {
        if ($method -ceq 'GET') {
            $filter = Get-TaskApiFilter -Request $Request
            if ($filter.Supplied) {
                $tasks = @(Get-Task -Store $Store -Completed $filter.Value)
            }
            else {
                $tasks = @(Get-Task -Store $Store)
            }
            $models = @($tasks | ForEach-Object {
                    ConvertTo-TaskApiModel -Task $_
                })
            return ConvertTo-TaskApiResponse -StatusCode 200 -Body $models
        }
        if ($method -ceq 'POST') {
            $body = Read-TaskApiJsonObject -Request $Request
            Assert-TaskApiProperty -Body $body -Allowed @('title') `
                -Required @('title')
            if ($body.title -isnot [string]) {
                Stop-TaskApiRequest -ErrorId Task.Validation `
                    -Message 'title must be a string.' -TargetObject $body.title
            }
            $task = Add-Task -Store $Store -Title $body.title -Confirm:$false
            return ConvertTo-TaskApiResponse -StatusCode 201 `
                -Body (ConvertTo-TaskApiModel -Task $task)
        }
        return ConvertTo-TaskApiErrorResponse -StatusCode 405 `
            -Code method_not_allowed -Message 'Method is not allowed for /tasks.' `
            -Allow 'GET, POST'
    }

    if ($path -match '^/tasks/(?<Id>[^/]+)$') {
        $id = ConvertTo-TaskApiId -Text $Matches.Id
        if ($method -ceq 'GET') {
            return ConvertTo-TaskApiResponse -StatusCode 200 `
                -Body (ConvertTo-TaskApiModel `
                    -Task (Get-Task -Store $Store -Id $id))
        }
        if ($method -ceq 'PATCH') {
            $body = Read-TaskApiJsonObject -Request $Request
            Assert-TaskApiProperty -Body $body -Allowed @('title', 'completed')
            if ($body.Count -eq 0) {
                Stop-TaskApiRequest -ErrorId Task.Validation `
                    -Message 'An update requires title, completed, or both.'
            }

            $parameters = @{
                Store = $Store
                Id = $id
                Confirm = $false
            }
            if ($body.Contains('title')) {
                if ($body.title -isnot [string]) {
                    Stop-TaskApiRequest -ErrorId Task.Validation `
                        -Message 'title must be a string.' -TargetObject $body.title
                }
                $parameters.Title = $body.title
            }
            if ($body.Contains('completed')) {
                if ($body.completed -isnot [bool]) {
                    Stop-TaskApiRequest -ErrorId Task.Validation `
                        -Message 'completed must be a Boolean.' `
                        -TargetObject $body.completed
                }
                $parameters.Completed = $body.completed
            }
            $task = Set-Task @parameters
            return ConvertTo-TaskApiResponse -StatusCode 200 `
                -Body (ConvertTo-TaskApiModel -Task $task)
        }
        if ($method -ceq 'DELETE') {
            Remove-Task -Store $Store -Id $id -Confirm:$false
            return ConvertTo-TaskApiResponse -StatusCode 204
        }
        return ConvertTo-TaskApiErrorResponse -StatusCode 405 `
            -Code method_not_allowed `
            -Message "Method is not allowed for /tasks/$id." `
            -Allow 'GET, PATCH, DELETE'
    }

    ConvertTo-TaskApiErrorResponse -StatusCode 404 -Code not_found `
        -Message 'The requested route was not found.'
}

function Write-TaskApiResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Net.HttpListenerResponse] $Response,

        [Parameter(Mandatory)]
        [object] $ApiResponse
    )

    $Response.StatusCode = $ApiResponse.StatusCode
    if (-not [string]::IsNullOrWhiteSpace($ApiResponse.Allow)) {
        $Response.Headers['Allow'] = $ApiResponse.Allow
    }
    if ($ApiResponse.StatusCode -eq 204) {
        $Response.ContentLength64 = 0
        return
    }

    $json = ConvertTo-Json -InputObject $ApiResponse.Body -Depth 6 -Compress
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)
    $Response.ContentType = 'application/json; charset=utf-8'
    $Response.ContentEncoding = [System.Text.Encoding]::UTF8
    $Response.ContentLength64 = $bytes.Length
    $Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

if (-not $UriPrefix.IsAbsoluteUri -or $UriPrefix.Scheme -cne 'http') {
    throw 'UriPrefix must be one absolute HTTP loopback URI.'
}
$isLoopback = $UriPrefix.Host -ceq 'localhost'
$address = $null
if ([System.Net.IPAddress]::TryParse($UriPrefix.Host, [ref] $address)) {
    $isLoopback = [System.Net.IPAddress]::IsLoopback($address)
}
if (-not $isLoopback -or
    -not $UriPrefix.AbsoluteUri.EndsWith(
        '/',
        [System.StringComparison]::Ordinal
    )) {
    throw 'UriPrefix must target loopback and end with a slash.'
}

$modulePath = Join-Path -Path $PSScriptRoot -ChildPath 'Tasks.psd1'
Import-Module -Name $modulePath -Force -ErrorAction Stop
$store = Initialize-TaskStore -Backend $Backend -DataPath $DataPath -Confirm:$false
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($UriPrefix.AbsoluteUri)

try {
    $listener.Start()
    Write-Verbose "Task API listening on $($UriPrefix.AbsoluteUri)"
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            try {
                $apiResponse = Invoke-TaskApiRequest `
                    -Request $context.Request -Store $store
            }
            catch {
                $caughtError = $_
                $apiResponse = switch -Wildcard ($caughtError.FullyQualifiedErrorId) {
                    'TaskApi.InvalidJson*' {
                        ConvertTo-TaskApiErrorResponse -StatusCode 400 `
                            -Code invalid_json -Message $caughtError.Exception.Message
                        break
                    }
                    'Task.Validation*' {
                        ConvertTo-TaskApiErrorResponse -StatusCode 422 `
                            -Code validation_error -Message $caughtError.Exception.Message
                        break
                    }
                    'Task.NotFound*' {
                        ConvertTo-TaskApiErrorResponse -StatusCode 404 `
                            -Code not_found -Message $caughtError.Exception.Message
                        break
                    }
                    default {
                        Write-Warning (
                            'Task API request failed: {0}' -f
                            $caughtError.Exception.Message
                        )
                        ConvertTo-TaskApiErrorResponse -StatusCode 500 `
                            -Code internal_error `
                            -Message 'The server could not complete the request.'
                    }
                }
            }
            try {
                Write-TaskApiResponse -Response $context.Response `
                    -ApiResponse $apiResponse
            }
            catch {
                # The client or HttpListener may close a response before this
                # process can write it. The request is lost, but the listener
                # remains healthy for later independent requests.
                Write-Warning (
                    'Task API response write failed: {0}' -f
                    $_.Exception.Message
                )
            }
        }
        finally {
            try {
                $context.Response.Close()
            }
            catch {
                Write-Warning (
                    'Task API response cleanup failed: {0}' -f
                    $_.Exception.Message
                )
            }
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
    Remove-Module -Name Tasks -Force -ErrorAction SilentlyContinue
}
