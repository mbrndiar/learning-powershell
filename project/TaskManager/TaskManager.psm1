Set-StrictMode -Version Latest

function Read-TaskStore {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $LiteralPath)

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        return
    }

    try {
        $content = Get-Content -LiteralPath $LiteralPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($content)) {
            return
        }
        $content | ConvertFrom-Json -ErrorAction Stop
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
