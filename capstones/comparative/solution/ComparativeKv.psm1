#Requires -Version 7.4

Set-StrictMode -Version Latest

. (Join-Path -Path $PSScriptRoot -ChildPath 'ComparativeKv.Internal.ps1')

function Set-ConfigurationEntry {
    <#
    .SYNOPSIS
    Sets one versioned configuration entry.

    .DESCRIPTION
    Implements the comparative contract's set operation for one literal
    database path, validated key, restricted JSON value, and expectation.
    Values are validated and normalized before the SQLite file is opened. The
    mutation uses a global revision and an immediate transaction.

    .PARAMETER DatabasePath
    The literal local SQLite database path supplied after --db.

    .PARAMETER Key
    The case-sensitive configuration key.

    .PARAMETER ValueJson
    The exact JSON text supplied after --value-json.

    .PARAMETER Expect
    The set expectation: any, absent, or a canonical exact revision.

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .EXAMPLE
    Set-ConfigurationEntry -DatabasePath ./store.db -Key app/mode -ValueJson '"safe"' -Expect absent
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $DatabasePath,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Key,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $ValueJson,

        [AllowEmptyString()]
        [string] $Expect = 'any'
    )

    Assert-KvDatabasePath -DatabasePath $DatabasePath
    Assert-KvKey -Key $Key
    $expectation = ConvertFrom-KvExpectation -Expectation $Expect -Command set
    $normalized = ConvertFrom-KvRestrictedJson -Json $ValueJson
    if (-not $PSCmdlet.ShouldProcess($DatabasePath, "set configuration entry '$Key'")) {
        return
    }

    $context = $null
    $transaction = $null
    $operation = 'open'
    try {
        $context = Open-KvConnection -DatabasePath $DatabasePath
        Assert-KvStoreReady -Connection $context.Connection

        $operation = 'write'
        $transaction = $context.Connection.BeginTransaction(
            [System.Data.IsolationLevel]::Serializable,
            $false
        )
        $entry = Get-KvEntryRow `
            -Connection $context.Connection `
            -Key $Key `
            -Transaction $transaction
        $actualRevision = if ($null -eq $entry) { $null } else { [long] $entry.revision }
        $expectationMatches = switch ($expectation.Kind) {
            'any' { $true }
            'absent' { $null -eq $entry }
            'exact' { $null -ne $entry -and $actualRevision -eq $expectation.Value }
        }
        if (-not $expectationMatches) {
            throw (New-KvConflictException `
                -Key $Key `
                -Expectation $expectation `
                -Actual $actualRevision)
        }

        $globalRevision = Get-KvGlobalRevision `
            -Connection $context.Connection `
            -Transaction $transaction
        if ($globalRevision -eq $script:KvSafeIntegerMaximum) {
            throw (New-KvRevisionExhaustedException)
        }
        $revision = $globalRevision + 1
        $null = Invoke-KvNonQuery `
            -Connection $context.Connection `
            -Transaction $transaction `
            -Sql @'
UPDATE store_metadata
SET global_revision = @revision
WHERE singleton = 1
'@ `
            -Parameters @{ revision = $revision }
        $null = Invoke-KvNonQuery `
            -Connection $context.Connection `
            -Transaction $transaction `
            -Sql @'
INSERT INTO entries(key, value_json, revision)
VALUES (@key, @value_json, @revision)
ON CONFLICT(key) DO UPDATE SET
    value_json = excluded.value_json,
    revision = excluded.revision
'@ `
            -Parameters @{
                key = $Key
                value_json = $normalized.Json
                revision = $revision
            }

        $operation = 'commit'
        $transaction.Commit()
        $transaction.Dispose()
        $transaction = $null
        [ordered]@{
            key = $Key
            value = $normalized.Value
            revision = [long] $revision
            created = $null -eq $entry
        }
    }
    catch {
        if ($null -ne $transaction) {
            try { $transaction.Rollback() } catch { $null = $_ }
        }
        throw (ConvertTo-KvStorageException -Exception $_.Exception -Operation $operation)
    }
    finally {
        if ($null -ne $transaction) {
            $transaction.Dispose()
        }
        if ($null -ne $context) {
            Close-KvConnection -Context $context
        }
    }
}

function Get-ConfigurationEntry {
    <#
    .SYNOPSIS
    Gets one versioned configuration entry.

    .DESCRIPTION
    Implements the comparative contract's get operation for one literal
    database path and validated key. Stored data is validated against the frozen
    schema and restricted JSON contract before it is returned.

    .PARAMETER DatabasePath
    The literal local SQLite database path supplied after --db.

    .PARAMETER Key
    The case-sensitive configuration key.

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .EXAMPLE
    Get-ConfigurationEntry -DatabasePath ./store.db -Key app/mode
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $DatabasePath,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Key
    )

    Assert-KvDatabasePath -DatabasePath $DatabasePath
    Assert-KvKey -Key $Key

    $context = $null
    try {
        $context = Open-KvConnection -DatabasePath $DatabasePath
        Assert-KvStoreReady -Connection $context.Connection
        $entry = Get-KvEntryRow -Connection $context.Connection -Key $Key
        if ($null -eq $entry) {
            throw (New-KvNotFoundException -Key $Key)
        }
        $normalized = ConvertFrom-KvRestrictedJson -Json ([string] $entry.value_json) -RequireNormalized
        [ordered]@{
            key = $Key
            value = $normalized.Value
            revision = [long] $entry.revision
        }
    }
    catch {
        throw (ConvertTo-KvStorageException -Exception $_.Exception -Operation 'read')
    }
    finally {
        if ($null -ne $context) {
            Close-KvConnection -Context $context
        }
    }
}

function Remove-ConfigurationEntry {
    <#
    .SYNOPSIS
    Deletes one versioned configuration entry.

    .DESCRIPTION
    Implements the comparative contract's delete operation for one literal
    database path, validated key, and expectation. Missing-key and expectation
    checks occur while an immediate SQLite transaction holds the writer lock.

    .PARAMETER DatabasePath
    The literal local SQLite database path supplied after --db.

    .PARAMETER Key
    The case-sensitive configuration key.

    .PARAMETER Expect
    The delete expectation: any or a canonical exact revision.

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .EXAMPLE
    Remove-ConfigurationEntry -DatabasePath ./store.db -Key app/mode -Expect 3
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $DatabasePath,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Key,

        [AllowEmptyString()]
        [string] $Expect = 'any'
    )

    Assert-KvDatabasePath -DatabasePath $DatabasePath
    Assert-KvKey -Key $Key
    $expectation = ConvertFrom-KvExpectation -Expectation $Expect -Command delete
    if (-not $PSCmdlet.ShouldProcess($DatabasePath, "remove configuration entry '$Key'")) {
        return
    }

    $context = $null
    $transaction = $null
    $operation = 'open'
    try {
        $context = Open-KvConnection -DatabasePath $DatabasePath
        Assert-KvStoreReady -Connection $context.Connection

        $operation = 'write'
        $transaction = $context.Connection.BeginTransaction(
            [System.Data.IsolationLevel]::Serializable,
            $false
        )
        $entry = Get-KvEntryRow `
            -Connection $context.Connection `
            -Key $Key `
            -Transaction $transaction
        if ($null -eq $entry) {
            throw (New-KvNotFoundException -Key $Key)
        }
        $actualRevision = [long] $entry.revision
        if ($expectation.Kind -eq 'exact' -and $actualRevision -ne $expectation.Value) {
            throw (New-KvConflictException `
                -Key $Key `
                -Expectation $expectation `
                -Actual $actualRevision)
        }

        $globalRevision = Get-KvGlobalRevision `
            -Connection $context.Connection `
            -Transaction $transaction
        if ($globalRevision -eq $script:KvSafeIntegerMaximum) {
            throw (New-KvRevisionExhaustedException)
        }
        $revision = $globalRevision + 1
        $null = Invoke-KvNonQuery `
            -Connection $context.Connection `
            -Transaction $transaction `
            -Sql @'
UPDATE store_metadata
SET global_revision = @revision
WHERE singleton = 1
'@ `
            -Parameters @{ revision = $revision }
        $null = Invoke-KvNonQuery `
            -Connection $context.Connection `
            -Transaction $transaction `
            -Sql 'DELETE FROM entries WHERE key = @key' `
            -Parameters @{ key = $Key }

        $operation = 'commit'
        $transaction.Commit()
        $transaction.Dispose()
        $transaction = $null
        [ordered]@{
            key = $Key
            deleted_revision = $actualRevision
            revision = [long] $revision
        }
    }
    catch {
        if ($null -ne $transaction) {
            try { $transaction.Rollback() } catch { $null = $_ }
        }
        throw (ConvertTo-KvStorageException -Exception $_.Exception -Operation $operation)
    }
    finally {
        if ($null -ne $transaction) {
            $transaction.Dispose()
        }
        if ($null -ne $context) {
            Close-KvConnection -Context $context
        }
    }
}

function Get-ConfigurationStore {
    <#
    .SYNOPSIS
    Lists all versioned configuration entries.

    .DESCRIPTION
    Implements the comparative contract's list operation for one literal
    database path. Entries use SQLite BINARY order and include the current
    global revision from the same read transaction.

    .PARAMETER DatabasePath
    The literal local SQLite database path supplied after --db.

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .EXAMPLE
    Get-ConfigurationStore -DatabasePath ./store.db
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $DatabasePath
    )

    Assert-KvDatabasePath -DatabasePath $DatabasePath

    $context = $null
    $transaction = $null
    try {
        $context = Open-KvConnection -DatabasePath $DatabasePath
        Assert-KvStoreReady -Connection $context.Connection
        $transaction = $context.Connection.BeginTransaction($true)
        $rows = @(
            Invoke-KvRows -Connection $context.Connection -Transaction $transaction -Sql @'
SELECT key, value_json, revision
FROM entries
ORDER BY key COLLATE BINARY
'@
        )
        $entries = @(
            foreach ($row in $rows) {
                $normalized = ConvertFrom-KvRestrictedJson `
                    -Json ([string] $row.value_json) `
                    -RequireNormalized
                [ordered]@{
                    key = [string] $row.key
                    value = $normalized.Value
                    revision = [long] $row.revision
                }
            }
        )
        $globalRevision = Get-KvGlobalRevision `
            -Connection $context.Connection `
            -Transaction $transaction
        $transaction.Commit()
        $transaction.Dispose()
        $transaction = $null
        [ordered]@{
            entries = $entries
            global_revision = $globalRevision
        }
    }
    catch {
        if ($null -ne $transaction) {
            try { $transaction.Rollback() } catch { $null = $_ }
        }
        throw (ConvertTo-KvStorageException -Exception $_.Exception -Operation 'read')
    }
    finally {
        if ($null -ne $transaction) {
            $transaction.Dispose()
        }
        if ($null -ne $context) {
            Close-KvConnection -Context $context
        }
    }
}

Export-ModuleMember -Function @(
    'Set-ConfigurationEntry'
    'Get-ConfigurationEntry'
    'Remove-ConfigurationEntry'
    'Get-ConfigurationStore'
)
