#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'

if ($args.Count -ne 3) {
    exit 1
}

$databasePath = $args[0]
$readyPath = $args[1]
$releasePath = $args[2]
$connectionName = 'comparative-lock-{0}-{1}' -f $PID, [guid]::NewGuid().ToString('N')
$transaction = $null
$opened = $false

try {
    Import-Module SimplySql -RequiredVersion 2.2.0.106 -Force -WarningAction SilentlyContinue
    Open-SQLiteConnection `
        -DataSource $databasePath `
        -ConnectionName $connectionName `
        -CommandTimeout 30 `
        -Additional @{
            BusyTimeout = 10000
            WaitTimeout = 10000
            DefaultTimeout = 10
            ForeignKeys = $true
            Pooling = $false
        } `
        -WarningAction SilentlyContinue |
        Out-Null
    $opened = $true
    $connection = Get-SqlConnection -ConnectionName $connectionName
    $command = $connection.CreateCommand()
    try {
        $command.CommandText = 'PRAGMA busy_timeout = 10000'
        $null = $command.ExecuteNonQuery()
    }
    finally {
        $command.Dispose()
    }

    $transaction = $connection.BeginTransaction(
        [System.Data.IsolationLevel]::Serializable,
        $false
    )
    [System.IO.File]::WriteAllText($readyPath, 'ready')
    while (-not [System.IO.File]::Exists($releasePath)) {
        Start-Sleep -Milliseconds 10
    }
    $transaction.Rollback()
    $transaction.Dispose()
    $transaction = $null
    exit 0
}
catch {
    exit 1
}
finally {
    if ($null -ne $transaction) {
        try { $transaction.Rollback() } catch { $null = $_ }
        $transaction.Dispose()
    }
    if ($opened) {
        Close-SqlConnection -ConnectionName $connectionName -ErrorAction SilentlyContinue
    }
}
