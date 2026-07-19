#Requires -Version 7.4

# This lesson bridges from ForEach-Object -Parallel to an explicit RunspacePool,
# the model the idiomatic capstone uses. The mental model: the script OWNS the
# pool and every PowerShell instance it creates, so it is responsible for their
# full lifecycle: Open the pool, BeginInvoke each work item, EndInvoke to collect
# results and surface errors, reorder deterministically, and Dispose everything
# in finally.
#
# Prefer ForEach-Object -Parallel for a simple, independent pipeline: it manages
# the runspaces and throttle for you. Reach for a RunspacePool only when you need
# that fine-grained control (per-item handles, explicit error streams, reuse),
# as the capstone does. This is a teaching sketch, not a production framework.

Set-StrictMode -Version Latest

# Immutable work items. Each carries its input index so results can be restored
# to input order after nondeterministic completion.
$workItems = @(
    [pscustomobject]@{ Index = 0; Value = 2 }
    [pscustomobject]@{ Index = 1; Value = -3 }
    [pscustomobject]@{ Index = 2; Value = 4 }
    [pscustomobject]@{ Index = 3; Value = 5 }
)

# Throttle bounds how many runspaces run concurrently; choose it from resource
# limits, not optimism. Min 1, max $throttleLimit.
$throttleLimit = 2

$worker = @'
param($Index, $Value)
if ($Value -lt 0) {
    throw "Value $Value is negative and cannot be squared here."
}
[pscustomobject]@{ Index = $Index; Square = $Value * $Value }
'@

$pool = [runspacefactory]::CreateRunspacePool(1, $throttleLimit)
$tasks = [System.Collections.Generic.List[object]]::new()
$results = [System.Collections.Generic.List[object]]::new()
try {
    $pool.Open()

    foreach ($item in $workItems) {
        $powerShell = [powershell]::Create()
        $powerShell.RunspacePool = $pool
        $null = $powerShell.AddScript($worker)
        $null = $powerShell.AddArgument($item.Index)
        $null = $powerShell.AddArgument($item.Value)
        try {
            # BeginInvoke starts the work asynchronously and returns a handle we
            # keep so EndInvoke can later block for exactly this item's result.
            $handle = $powerShell.BeginInvoke()
            $tasks.Add([pscustomobject]@{
                    PowerShell = $powerShell
                    Handle = $handle
                    Item = $item
                    Disposed = $false
                })
        }
        catch {
            # If scheduling fails, dispose immediately so no instance leaks.
            $powerShell.Dispose()
            throw
        }
    }

    foreach ($task in $tasks) {
        try {
            # EndInvoke blocks for this item. A worker failure may throw here or
            # be recorded in Streams.Error, which the next check also surfaces.
            $output = @($task.PowerShell.EndInvoke($task.Handle))
            # A worker error also lands in the error stream; surface it rather
            # than silently returning a partial success.
            if ($task.PowerShell.HadErrors) {
                throw $task.PowerShell.Streams.Error[0].Exception
            }
            $results.Add([pscustomobject]@{
                    Index = $task.Item.Index
                    Status = 'Succeeded'
                    Square = $output[0].Square
                    Error = $null
                })
        }
        catch {
            # EndInvoke wraps the runspace's terminating error in a
            # MethodInvocationException; unwrap it to report the real message.
            $message = if ($null -ne $_.Exception.InnerException) {
                $_.Exception.InnerException.Message
            }
            else {
                $_.Exception.Message
            }
            $results.Add([pscustomobject]@{
                    Index = $task.Item.Index
                    Status = 'Failed'
                    Square = $null
                    Error = $message
                })
        }
        finally {
            $task.PowerShell.Dispose()
            $task.Disposed = $true
        }
    }

    # Completion order is nondeterministic; sort by the captured index so the
    # emitted sequence is deterministic and reproducible across platforms.
    $results | Sort-Object Index
}
finally {
    # Dispose anything not already disposed (e.g. if scheduling threw), then the
    # pool itself. Cleanup always runs, even on the failure path.
    foreach ($task in $tasks) {
        if (-not $task.Disposed) {
            $task.PowerShell.Dispose()
            $task.Disposed = $true
        }
    }
    $pool.Dispose()
}
