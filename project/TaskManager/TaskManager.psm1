Set-StrictMode -Version Latest

function Assert-TaskStorePath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $LiteralPath)

    if ([string]::IsNullOrWhiteSpace($LiteralPath)) {
        throw [System.ArgumentException]::new('Task store path must not be empty.')
    }
    if (Test-Path -LiteralPath $LiteralPath -PathType Container) {
        throw [System.ArgumentException]::new(
            "Task store path points to a directory: $LiteralPath"
        )
    }
}

function ConvertTo-TaskRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [object] $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            throw [System.IO.InvalidDataException]::new(
                'Task store must not contain null task entries.'
            )
        }
        foreach ($propertyName in 'Id', 'Title', 'Done', 'CreatedAt') {
            if ($null -eq $InputObject.PSObject.Properties[$propertyName]) {
                throw [System.IO.InvalidDataException]::new(
                    "Stored task is missing the '$propertyName' property."
                )
            }
        }

        $parsedId = [guid]::Empty
        if (-not [guid]::TryParse([string] $InputObject.Id, [ref] $parsedId)) {
            throw [System.IO.InvalidDataException]::new(
                "Stored task ID '$($InputObject.Id)' is not a GUID."
            )
        }
        if ($InputObject.Title -isnot [string] -or [string]::IsNullOrWhiteSpace($InputObject.Title)) {
            throw [System.IO.InvalidDataException]::new(
                'Stored task title must be a non-empty string.'
            )
        }
        if ($InputObject.Done -isnot [bool]) {
            throw [System.IO.InvalidDataException]::new(
                'Stored task Done value must be a Boolean.'
            )
        }
        if (
            $InputObject.CreatedAt -isnot [string] -and
            $InputObject.CreatedAt -isnot [datetime] -and
            $InputObject.CreatedAt -isnot [datetimeoffset]
        ) {
            throw [System.IO.InvalidDataException]::new(
                'Stored task CreatedAt value must be an ISO 8601 timestamp.'
            )
        }

        $parsedCreatedAt = [datetimeoffset]::MinValue
        $validCreatedAt = if ($InputObject.CreatedAt -is [string]) {
            [datetimeoffset]::TryParseExact(
                $InputObject.CreatedAt,
                'O',
                [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::RoundtripKind,
                [ref] $parsedCreatedAt
            )
        }
        else {
            $parsedCreatedAt = [datetimeoffset] $InputObject.CreatedAt
            $true
        }
        if (-not $validCreatedAt) {
            throw [System.IO.InvalidDataException]::new(
                "Stored task CreatedAt value '$($InputObject.CreatedAt)' is invalid."
            )
        }

        [pscustomobject]@{
            Id = $parsedId.ToString()
            Title = $InputObject.Title.Trim()
            Done = $InputObject.Done
            CreatedAt = $parsedCreatedAt.UtcDateTime.ToString('O')
        }
    }
}

function Read-TaskStore {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $LiteralPath)

    Assert-TaskStorePath -LiteralPath $LiteralPath
    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        return
    }

    try {
        $content = Get-Content -LiteralPath $LiteralPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($content)) {
            throw [System.IO.InvalidDataException]::new(
                'Task store must contain a top-level JSON array.'
            )
        }
        $decoded = $content | ConvertFrom-Json -NoEnumerate -ErrorAction Stop
        if ($decoded -isnot [array]) {
            throw [System.IO.InvalidDataException]::new(
                'Task store must contain a top-level JSON array.'
            )
        }

        $tasks = @($decoded | ConvertTo-TaskRecord -ErrorAction Stop)
        $ids = @($tasks | ForEach-Object { $_.Id })
        if (@($ids | Select-Object -Unique).Count -ne $ids.Count) {
            throw [System.IO.InvalidDataException]::new(
                'Task store contains duplicate task IDs.'
            )
        }
        $tasks
    }
    catch {
        throw [System.InvalidOperationException]::new(
            "Cannot read task store '$LiteralPath': $($_.Exception.Message)",
            $_.Exception
        )
    }
}

function Write-TaskStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Task
    )

    Assert-TaskStorePath -LiteralPath $LiteralPath
    $directory = Split-Path -Path $LiteralPath -Parent
    if ([string]::IsNullOrWhiteSpace($directory)) {
        $directory = (Get-Location).Path
    }
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        throw [System.IO.DirectoryNotFoundException]::new("Task store directory does not exist: $directory")
    }

    $temporaryPath = Join-Path -Path $directory -ChildPath ('.tasks-' + [guid]::NewGuid() + '.tmp')
    try {
        ConvertTo-Json -InputObject @($Task) -Depth 5 |
            Set-Content -LiteralPath $temporaryPath -Encoding utf8 -NoNewline -ErrorAction Stop
        Move-Item -LiteralPath $temporaryPath -Destination $LiteralPath -Force -ErrorAction Stop
    }
    catch {
        throw [System.IO.IOException]::new(
            "Cannot write task store '$LiteralPath': $($_.Exception.Message)",
            $_.Exception
        )
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-Task {
    <#
    .SYNOPSIS
    Gets tasks from a JSON task store.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $LiteralPath,

        [switch] $Done
    )

    $tasks = @(Read-TaskStore -LiteralPath $LiteralPath)
    if ($Done) {
        $tasks | Where-Object Done
    }
    else {
        $tasks
    }
}

function Add-Task {
    <#
    .SYNOPSIS
    Adds one task to a JSON task store.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [string] $LiteralPath,

        [Parameter(Mandatory)]
        [ValidateScript({
            if ([string]::IsNullOrWhiteSpace($_)) {
                throw 'Task title must contain a non-whitespace character.'
            }
            $true
        })]
        [string] $Title
    )

    $task = [pscustomobject]@{
        Id = [guid]::NewGuid().ToString()
        Title = $Title.Trim()
        Done = $false
        CreatedAt = [datetime]::UtcNow.ToString('O')
    }
    $tasks = @((Read-TaskStore -LiteralPath $LiteralPath)) + $task
    if ($PSCmdlet.ShouldProcess($LiteralPath, "add task '$($task.Title)'")) {
        Write-TaskStore -LiteralPath $LiteralPath -Task $tasks
        $task
    }
}

function Set-Task {
    <#
    .SYNOPSIS
    Changes a task's completion state.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [string] $LiteralPath,

        [Parameter(Mandatory)]
        [guid] $Id,

        [Parameter(Mandatory)]
        [bool] $Done
    )

    $normalizedId = $Id.ToString()
    $tasks = @(Read-TaskStore -LiteralPath $LiteralPath)
    $match = @($tasks | Where-Object Id -eq $normalizedId)
    if ($match.Count -ne 1) {
        throw [System.ArgumentException]::new("Task '$normalizedId' was not found.")
    }

    $updated = foreach ($task in $tasks) {
        if ($task.Id -eq $normalizedId) {
            [pscustomobject]@{
                Id = $task.Id
                Title = $task.Title
                Done = $Done
                CreatedAt = $task.CreatedAt
            }
        }
        else {
            $task
        }
    }
    if ($PSCmdlet.ShouldProcess($LiteralPath, "set task '$normalizedId' completion to '$Done'")) {
        Write-TaskStore -LiteralPath $LiteralPath -Task @($updated)
        $updated | Where-Object Id -eq $normalizedId
    }
}

function Remove-Task {
    <#
    .SYNOPSIS
    Removes one task from a JSON task store.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string] $LiteralPath,

        [Parameter(Mandatory)]
        [guid] $Id
    )

    $normalizedId = $Id.ToString()
    $tasks = @(Read-TaskStore -LiteralPath $LiteralPath)
    $match = @($tasks | Where-Object Id -eq $normalizedId)
    if ($match.Count -ne 1) {
        throw [System.ArgumentException]::new("Task '$normalizedId' was not found.")
    }

    if ($PSCmdlet.ShouldProcess($LiteralPath, "remove task '$normalizedId'")) {
        $remaining = @($tasks | Where-Object Id -ne $normalizedId)
        Write-TaskStore -LiteralPath $LiteralPath -Task $remaining
        $match[0]
    }
}

Export-ModuleMember -Function Get-Task, Add-Task, Set-Task, Remove-Task
