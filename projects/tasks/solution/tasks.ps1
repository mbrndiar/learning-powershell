#Requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Add', 'List', 'Show', 'Update', 'Complete', 'Remove')]
    [string] $Command,

    [uri] $BaseUri = 'http://127.0.0.1:8080/',

    [ValidateRange(1, 300)]
    [int] $TimeoutSec = 5,

    [ValidateRange(1, [long]::MaxValue)]
    [long] $Id,

    [AllowEmptyString()]
    [string] $Title,

    [ValidateSet('All', 'True', 'False')]
    [string] $Completed = 'All'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TaskClientErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('TaskClient.Usage', 'TaskClient.Response')]
        [string] $ErrorId,

        [Parameter(Mandatory)]
        [string] $Message,

        [AllowNull()]
        [object] $TargetObject
    )

    [System.Management.Automation.ErrorRecord]::new(
        [System.InvalidOperationException]::new($Message),
        $ErrorId,
        [System.Management.Automation.ErrorCategory]::InvalidData,
        $TargetObject
    )
}

function Stop-TaskClientRequest {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'This private helper creates a terminating client error and does not mutate state.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('TaskClient.Usage', 'TaskClient.Response')]
        [string] $ErrorId,

        [Parameter(Mandatory)]
        [string] $Message,

        [AllowNull()]
        [object] $TargetObject
    )

    throw (Get-TaskClientErrorRecord @PSBoundParameters)
}

function Assert-TaskClientTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Task
    )

    if ($null -eq $Task) {
        Stop-TaskClientRequest -ErrorId TaskClient.Response `
            -Message 'The server returned no Task object.'
    }
    $properties = @($Task.PSObject.Properties |
            ForEach-Object { $_.Name } |
            Sort-Object)
    if (($properties -join ',') -cne 'completed,id,title') {
        Stop-TaskClientRequest -ErrorId TaskClient.Response `
            -Message 'The server returned an invalid Task object.' `
            -TargetObject $Task
    }

    $id = $Task.PSObject.Properties['id'].Value
    $title = $Task.PSObject.Properties['title'].Value
    $completed = $Task.PSObject.Properties['completed'].Value
    $validTitle = $title -is [string] -and $title -ceq $title.Trim()
    if ($validTitle) {
        $characterCount =
            [System.Globalization.StringInfo]::ParseCombiningCharacters(
                $title
            ).Count
        $validTitle = $characterCount -ge 1 -and $characterCount -le 120
    }
    if ($validTitle) {
        foreach ($character in $title.ToCharArray()) {
            if ([char]::IsControl($character)) {
                $validTitle = $false
                break
            }
        }
    }
    if (($id -isnot [long] -and $id -isnot [int]) -or
        [long] $id -lt 1 -or
        -not $validTitle -or
        $completed -isnot [bool]) {
        Stop-TaskClientRequest -ErrorId TaskClient.Response `
            -Message 'The server returned an invalid Task object.' `
            -TargetObject $Task
    }
}

function ConvertFrom-TaskClientErrorResponse {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [AllowNull()]
        [string] $Json
    )

    if ([string]::IsNullOrWhiteSpace($Json)) {
        return
    }
    try {
        $decoded = ConvertFrom-Json -InputObject $Json -ErrorAction Stop
    }
    catch {
        return
    }
    if ($null -eq $decoded -or
        (@($decoded.PSObject.Properties |
                ForEach-Object { $_.Name } |
                Sort-Object) -join ',') -cne
        'error') {
        return
    }

    $errorValue = $decoded.PSObject.Properties['error'].Value
    if ($null -eq $errorValue -or
        (@($errorValue.PSObject.Properties |
                ForEach-Object { $_.Name } |
                Sort-Object) -join ',') -cne
        'code,message') {
        return
    }
    $code = $errorValue.PSObject.Properties['code'].Value
    $message = $errorValue.PSObject.Properties['message'].Value
    if ($code -isnot [string] -or
        [string]::IsNullOrWhiteSpace($code) -or
        $message -isnot [string] -or
        [string]::IsNullOrWhiteSpace($message)) {
        return
    }

    [pscustomobject]@{
        Code = $code
        Message = $message
    }
}

function Invoke-TaskClientRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri] $Uri,

        [Parameter(Mandatory)]
        [ValidateSet('Get', 'Post', 'Patch', 'Delete')]
        [string] $Method,

        [AllowNull()]
        [hashtable] $Body
    )

    $parameters = @{
        Uri = $Uri
        Method = $Method
        TimeoutSec = $TimeoutSec
        ErrorAction = 'Stop'
    }
    if ($null -ne $Body) {
        $parameters.ContentType = 'application/json'
        $parameters.Body = ConvertTo-Json -InputObject $Body -Compress
    }
    Invoke-RestMethod @parameters
}

function Get-TaskClientUri {
    [CmdletBinding()]
    [OutputType([uri])]
    param(
        [Parameter(Mandatory)]
        [string] $RelativePath
    )

    if (-not $BaseUri.IsAbsoluteUri -or
        $BaseUri.Scheme -notin 'http', 'https') {
        Stop-TaskClientRequest -ErrorId TaskClient.Usage `
            -Message 'BaseUri must be an absolute HTTP or HTTPS URI.' `
            -TargetObject $BaseUri
    }
    [uri] ($BaseUri.AbsoluteUri.TrimEnd('/') + '/' + $RelativePath.TrimStart('/'))
}

function Write-TaskClientJson {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value
    )

    [Console]::Out.WriteLine(
        (ConvertTo-Json -InputObject $Value -Depth 5 -Compress)
    )
}

try {
    $hasId = $PSBoundParameters.ContainsKey('Id')
    $hasTitle = $PSBoundParameters.ContainsKey('Title')
    $result = switch ($Command) {
        'Add' {
            if (-not $hasTitle -or $hasId -or $Completed -ne 'All') {
                Stop-TaskClientRequest -ErrorId TaskClient.Usage `
                    -Message 'Add requires only -Title.'
            }
            $task = Invoke-TaskClientRequest -Uri (Get-TaskClientUri 'tasks') `
                -Method Post -Body @{ title = $Title }
            Assert-TaskClientTask -Task $task
            $task
        }
        'List' {
            if ($hasId -or $hasTitle) {
                Stop-TaskClientRequest -ErrorId TaskClient.Usage `
                    -Message 'List does not accept -Id or -Title.'
            }
            $relativePath = if ($Completed -eq 'All') {
                'tasks'
            }
            else {
                'tasks?completed=' + $Completed.ToLowerInvariant()
            }
            $response = Invoke-TaskClientRequest `
                -Uri (Get-TaskClientUri $relativePath) -Method Get
            $tasks = @($response)
            foreach ($task in $tasks) {
                Assert-TaskClientTask -Task $task
            }
            [pscustomobject]@{ Tasks = $tasks }
        }
        'Show' {
            if (-not $hasId -or $hasTitle -or $Completed -ne 'All') {
                Stop-TaskClientRequest -ErrorId TaskClient.Usage `
                    -Message 'Show requires only -Id.'
            }
            $task = Invoke-TaskClientRequest `
                -Uri (Get-TaskClientUri "tasks/$Id") -Method Get
            Assert-TaskClientTask -Task $task
            $task
        }
        'Update' {
            if (-not $hasId -or
                -not $hasTitle -and $Completed -eq 'All') {
                Stop-TaskClientRequest -ErrorId TaskClient.Usage `
                    -Message 'Update requires -Id plus -Title, -Completed, or both.'
            }
            $body = @{}
            if ($hasTitle) {
                $body.title = $Title
            }
            if ($Completed -ne 'All') {
                $body.completed = $Completed -eq 'True'
            }
            $task = Invoke-TaskClientRequest `
                -Uri (Get-TaskClientUri "tasks/$Id") -Method Patch -Body $body
            Assert-TaskClientTask -Task $task
            $task
        }
        'Complete' {
            if (-not $hasId -or $hasTitle -or $Completed -ne 'All') {
                Stop-TaskClientRequest -ErrorId TaskClient.Usage `
                    -Message 'Complete requires only -Id.'
            }
            $task = Invoke-TaskClientRequest `
                -Uri (Get-TaskClientUri "tasks/$Id") -Method Patch `
                -Body @{ completed = $true }
            Assert-TaskClientTask -Task $task
            $task
        }
        'Remove' {
            if (-not $hasId -or $hasTitle -or $Completed -ne 'All') {
                Stop-TaskClientRequest -ErrorId TaskClient.Usage `
                    -Message 'Remove requires only -Id.'
            }
            Invoke-TaskClientRequest -Uri (Get-TaskClientUri "tasks/$Id") `
                -Method Delete | Out-Null
            [pscustomobject][ordered]@{ deleted = $Id }
        }
    }

    if ($Command -eq 'List') {
        Write-TaskClientJson -Value $result.Tasks
    }
    else {
        Write-TaskClientJson -Value $result
    }
    exit 0
}
catch {
    $caughtError = $_
    if ($caughtError.FullyQualifiedErrorId -like 'TaskClient.Usage*') {
        [Console]::Error.WriteLine(
            "usage_error: $($caughtError.Exception.Message)"
        )
        exit 2
    }
    if ($caughtError.FullyQualifiedErrorId -like 'TaskClient.Response*') {
        [Console]::Error.WriteLine(
            "response_error: $($caughtError.Exception.Message)"
        )
        exit 4
    }

    $responseProperty = $caughtError.Exception.PSObject.Properties['Response']
    $response = if ($null -ne $responseProperty) {
        $responseProperty.Value
    }
    if ($null -ne $response) {
        $message = if ($null -ne $caughtError.ErrorDetails) {
            $caughtError.ErrorDetails.Message
        }
        $apiError = $null
        $apiError = ConvertFrom-TaskClientErrorResponse -Json $message
        if ($null -ne $apiError) {
            [Console]::Error.WriteLine(
                ('{0}: {1}' -f $apiError.Code, $apiError.Message)
            )
            exit 3
        }
        [Console]::Error.WriteLine('response_error: invalid API error response')
        exit 4
    }

    [Console]::Error.WriteLine(
        "transport_error: $($caughtError.Exception.Message)"
    )
    exit 5
}
