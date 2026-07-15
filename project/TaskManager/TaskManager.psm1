#Requires -Version 7.4

# TaskManager module implementation. Public commands (Get/Add/Set/Remove-Task)
# carry comment-based help below; the helpers above them are private and
# enforce the storage contract in one place. See TaskManager.psd1 for the
# manifest and the exported surface.

Set-StrictMode -Version Latest

# Private guard: a store target must be nonblank and must not be a directory.
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

# Private: validate one stored entry and re-emit it in a canonical shape.
# Stored JSON is untrusted input, so every field is type- and value-checked
# before the rest of the module is allowed to rely on it.
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
        # A string timestamp must be strict round-trip ISO 8601 ('O'); a value
        # that already deserialized as a date type is accepted as-is.
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

        # Canonical form: trimmed title and CreatedAt normalized to a single
        # UTC round-trip string, so equal instants always serialize identically.
        [pscustomobject]@{
            Id = $parsedId.ToString()
            Title = $InputObject.Title.Trim()
            Done = $InputObject.Done
            CreatedAt = $parsedCreatedAt.UtcDateTime.ToString('O')
        }
    }
}

# Private: read and fully validate the store before any command trusts it.
function Read-TaskStore {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $LiteralPath)

    Assert-TaskStorePath -LiteralPath $LiteralPath
    # A missing store is a valid empty store, not an error.
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
        # -NoEnumerate keeps the decoded value an array so a single stored task
        # is not silently unrolled into a scalar we would then reject.
        $decoded = $content | ConvertFrom-Json -NoEnumerate -ErrorAction Stop
        if ($decoded -isnot [array]) {
            throw [System.IO.InvalidDataException]::new(
                'Task store must contain a top-level JSON array.'
            )
        }

        $tasks = @($decoded | ConvertTo-TaskRecord -ErrorAction Stop)
        # IDs are the lookup key for Set/Remove, so duplicates make the store
        # ambiguous and are rejected up front.
        $ids = @($tasks | ForEach-Object { $_.Id })
        if (@($ids | Select-Object -Unique).Count -ne $ids.Count) {
            throw [System.IO.InvalidDataException]::new(
                'Task store contains duplicate task IDs.'
            )
        }
        $tasks
    }
    catch {
        # Wrap every read failure in one type with the file path for context,
        # preserving the original exception as the inner cause.
        throw [System.InvalidOperationException]::new(
            "Cannot read task store '$LiteralPath': $($_.Exception.Message)",
            $_.Exception
        )
    }
}

# Private: persist the whole task set through a temporary sibling file.
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

    # Write to a sibling temp file before replacing the target. This reduces
    # partial-target exposure, but it is not a transaction or locking scheme.
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
        # Remove the temp file if the rename never happened.
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-Task {
    <#
    .SYNOPSIS
    Gets tasks from a JSON task store.

    .DESCRIPTION
    Reads and validates the complete store before returning task objects. A
    missing store is treated as an empty collection; malformed data throws.

    .PARAMETER LiteralPath
    The literal filesystem path to the JSON store.

    .PARAMETER Done
    Returns only completed tasks when present.

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .EXAMPLE
    Get-Task -LiteralPath ./tasks.json

    .EXAMPLE
    Get-Task -LiteralPath ./tasks.json -Done
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

    .DESCRIPTION
    Validates existing data, creates one task with a GUID and UTC timestamp,
    and replaces the store only when ShouldProcess approves.

    .PARAMETER LiteralPath
    The literal filesystem path to the JSON store.

    .PARAMETER Title
    The nonblank task title. Leading and trailing whitespace is removed.

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .EXAMPLE
    Add-Task -LiteralPath ./tasks.json -Title 'Read module help'

    .EXAMPLE
    Add-Task -LiteralPath ./tasks.json -Title 'Preview only' -WhatIf
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
    # Build the next full task set first; persist and emit only after approval,
    # so -WhatIf previews without touching the store.
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

    .DESCRIPTION
    Finds exactly one stored task by GUID and replaces its Boolean completion
    state when ShouldProcess approves. An unknown ID is a terminating error.

    .PARAMETER LiteralPath
    The literal filesystem path to the JSON store.

    .PARAMETER Id
    The GUID of the task to update.

    .PARAMETER Done
    The desired completion state.

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .EXAMPLE
    Set-Task -LiteralPath ./tasks.json -Id $task.Id -Done $true
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
    # Require exactly one match; an unknown ID is a terminating error, not a
    # silent no-op.
    if ($match.Count -ne 1) {
        throw [System.ArgumentException]::new("Task '$normalizedId' was not found.")
    }

    # Rebuild the collection with one replacement object instead of mutating
    # the loaded task in place; all other task objects pass through unchanged.
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

    .DESCRIPTION
    Finds exactly one stored task by GUID and removes it when ShouldProcess
    approves. This high-impact command prompts according to the caller's
    confirmation preference unless the caller explicitly supplies -Confirm.

    .PARAMETER LiteralPath
    The literal filesystem path to the JSON store.

    .PARAMETER Id
    The GUID of the task to remove.

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .EXAMPLE
    Remove-Task -LiteralPath ./tasks.json -Id $task.Id

    .EXAMPLE
    Remove-Task -LiteralPath ./tasks.json -Id $task.Id -WhatIf
    #>
    # ConfirmImpact High: unlike Add/Set (Low), removal prompts by default
    # once $ConfirmPreference allows it, because it destroys data.
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
