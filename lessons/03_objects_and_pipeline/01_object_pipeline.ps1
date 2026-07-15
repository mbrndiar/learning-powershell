Set-StrictMode -Version Latest

$tasks = @(
    [pscustomobject]@{ Name = 'Read'; Minutes = 20; Done = $true }
    [pscustomobject]@{ Name = 'Build'; Minutes = 45; Done = $false }
    [pscustomobject]@{ Name = 'Test'; Minutes = 30; Done = $true }
)

$completed = $tasks |
    Where-Object Done |
    Sort-Object Minutes -Descending |
    Select-Object Name, Minutes

$completed
# Inspect interactively: $completed | Get-Member
