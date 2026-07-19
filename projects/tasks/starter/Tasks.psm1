#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }

Set-StrictMode -Version Latest

function Get-TasksProjectNotImplementedError {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [string] $CommandName
    )

    $exception = [System.NotImplementedException]::new(
        "$CommandName is intentionally incomplete in the Tasks project starter."
    )
    [System.Management.Automation.ErrorRecord]::new(
        $exception,
        'TasksProjectNotImplemented',
        [System.Management.Automation.ErrorCategory]::NotImplemented,
        $CommandName
    )
}

function Initialize-TaskStore {
    <#
    .SYNOPSIS
    Creates or validates a task store.

    .DESCRIPTION
    Initializes one SQLite database or versioned Markdown checklist and returns
    a store descriptor consumed by the other module commands. Complete
    milestones 1 and 2 without changing this public signature.

    .PARAMETER Backend
    The persistence implementation: SQLite or Markdown.

    .PARAMETER DataPath
    The local data-file path. Its parent directory must already exist.

    .OUTPUTS
    Learning.PowerShell.TaskStore

    .EXAMPLE
    $store = Initialize-TaskStore -Backend SQLite -DataPath ./tasks.sqlite

    .EXAMPLE
    $store = Initialize-TaskStore -Backend Markdown -DataPath ./tasks.md -WhatIf
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'The guided starter preserves the public signature before implementation.'
    )]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('SQLite', 'Markdown')]
        [string] $Backend,

        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $DataPath
    )

    # M1: validate the path and return one typed Store descriptor.
    # M2: initialize or validate the selected exact persistence format.
    $null = $PSCmdlet.ShouldProcess($DataPath, "initialize $Backend task store")
    $PSCmdlet.ThrowTerminatingError(
        (Get-TasksProjectNotImplementedError -CommandName $MyInvocation.MyCommand.Name)
    )
}

function Add-Task {
    <#
    .SYNOPSIS
    Adds one incomplete task.

    .DESCRIPTION
    Validates and normalizes a title, allocates a monotonic ID, persists one
    incomplete task atomically, and returns the stored task object.

    .PARAMETER Store
    A descriptor returned by Initialize-TaskStore.

    .PARAMETER Title
    A one-line title containing 1 through 120 Unicode characters after trimming.

    .OUTPUTS
    Learning.PowerShell.Task

    .EXAMPLE
    Add-Task -Store $store -Title 'Learn PowerShell modules'

    .EXAMPLE
    Add-Task -Store $store -Title 'Preview only' -WhatIf
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'The guided starter preserves the public signature before implementation.'
    )]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Store,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Title
    )

    # M1: normalize and validate the title in one shared core helper.
    # M2: delegate allocation and persistence to the selected repository.
    $null = $PSCmdlet.ShouldProcess('task store', "add task '$Title'")
    $PSCmdlet.ThrowTerminatingError(
        (Get-TasksProjectNotImplementedError -CommandName $MyInvocation.MyCommand.Name)
    )
}

function Get-Task {
    <#
    .SYNOPSIS
    Gets tasks from one store.

    .DESCRIPTION
    Returns one task by ID or lists tasks in ascending ID order. List mode can
    filter by an explicit completion state.

    .PARAMETER Store
    A descriptor returned by Initialize-TaskStore.

    .PARAMETER Id
    The positive ID of one task.

    .PARAMETER Completed
    In list mode, limits results to one completion state.

    .OUTPUTS
    Learning.PowerShell.Task

    .EXAMPLE
    Get-Task -Store $store

    .EXAMPLE
    Get-Task -Store $store -Completed $false

    .EXAMPLE
    Get-Task -Store $store -Id 1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'The guided starter preserves the public signature before implementation.'
    )]
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Store,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateRange(1, [long]::MaxValue)]
        [long] $Id,

        [Parameter(ParameterSetName = 'List')]
        [AllowNull()]
        [Nullable[bool]] $Completed
    )

    # M1: distinguish one-task lookup from list/filter behavior.
    # M2: map repository rows into caller-independent Task objects.
    $PSCmdlet.ThrowTerminatingError(
        (Get-TasksProjectNotImplementedError -CommandName $MyInvocation.MyCommand.Name)
    )
}

function Set-Task {
    <#
    .SYNOPSIS
    Updates one task.

    .DESCRIPTION
    Applies a partial title and/or completion update to an existing task. At
    least one field must be supplied.

    .PARAMETER Store
    A descriptor returned by Initialize-TaskStore.

    .PARAMETER Id
    The positive ID of the task to update. It accepts pipeline property input.

    .PARAMETER Title
    A replacement one-line title.

    .PARAMETER Completed
    The replacement completion state.

    .OUTPUTS
    Learning.PowerShell.Task

    .EXAMPLE
    Set-Task -Store $store -Id 1 -Completed $true

    .EXAMPLE
    Get-Task -Store $store -Id 1 | Set-Task -Store $store -Title 'New title'
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'The guided starter preserves the public signature before implementation.'
    )]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Store,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [long]::MaxValue)]
        [long] $Id,

        [AllowEmptyString()]
        [string] $Title,

        [AllowNull()]
        [Nullable[bool]] $Completed
    )

    process {
        # M1: reject an empty partial update and normalize supplied values.
        # M2/M3: update atomically and honor ShouldProcess before persistence.
        $null = $PSCmdlet.ShouldProcess("task $Id", 'update task')
        $PSCmdlet.ThrowTerminatingError(
            (Get-TasksProjectNotImplementedError -CommandName $MyInvocation.MyCommand.Name)
        )
    }
}

function Remove-Task {
    <#
    .SYNOPSIS
    Removes one task.

    .DESCRIPTION
    Deletes one existing task without reusing its ID.

    .PARAMETER Store
    A descriptor returned by Initialize-TaskStore.

    .PARAMETER Id
    The positive ID to remove. It accepts pipeline property input.

    .EXAMPLE
    Remove-Task -Store $store -Id 1 -Confirm:$false

    .EXAMPLE
    Get-Task -Store $store -Completed $true |
        Remove-Task -Store $store -WhatIf
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter', '',
        Justification = 'The guided starter preserves the public signature before implementation.'
    )]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Store,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(1, [long]::MaxValue)]
        [long] $Id
    )

    process {
        # M2/M3: delete atomically, preserve the next ID, and honor ShouldProcess.
        $null = $PSCmdlet.ShouldProcess("task $Id", 'remove task')
        $PSCmdlet.ThrowTerminatingError(
            (Get-TasksProjectNotImplementedError -CommandName $MyInvocation.MyCommand.Name)
        )
    }
}

Export-ModuleMember -Function @(
    'Initialize-TaskStore'
    'Add-Task'
    'Get-Task'
    'Set-Task'
    'Remove-Task'
)
