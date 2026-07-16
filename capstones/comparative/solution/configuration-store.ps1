#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$ConfirmPreference = 'None'

function Add-CliJsonString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Text.StringBuilder] $Builder,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value
    )

    $null = $Builder.Append('"')
    for ($index = 0; $index -lt $Value.Length; $index++) {
        $character = $Value[$index]
        switch ([int] $character) {
            0x08 { $null = $Builder.Append('\b'); continue }
            0x09 { $null = $Builder.Append('\t'); continue }
            0x0a { $null = $Builder.Append('\n'); continue }
            0x0c { $null = $Builder.Append('\f'); continue }
            0x0d { $null = $Builder.Append('\r'); continue }
            0x22 { $null = $Builder.Append('\"'); continue }
            0x5c { $null = $Builder.Append('\\'); continue }
        }
        if ([int] $character -lt 0x20) {
            $null = $Builder.AppendFormat(
                [System.Globalization.CultureInfo]::InvariantCulture,
                '\u{0:x4}',
                [int] $character
            )
            continue
        }
        $null = $Builder.Append($character)
    }
    $null = $Builder.Append('"')
}

function Add-CliJsonValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Text.StringBuilder] $Builder,

        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value) {
        $null = $Builder.Append('null')
        return
    }
    if ($Value -is [bool]) {
        $null = $Builder.Append($(if ($Value) { 'true' } else { 'false' }))
        return
    }
    if ($Value -is [string]) {
        Add-CliJsonString -Builder $Builder -Value $Value
        return
    }
    if (
        $Value -is [sbyte] -or $Value -is [byte] -or
        $Value -is [short] -or $Value -is [ushort] -or
        $Value -is [int] -or $Value -is [uint] -or
        $Value -is [long] -or $Value -is [ulong] -or
        $Value -is [System.Numerics.BigInteger]
    ) {
        $null = $Builder.Append(
            ([System.IFormattable] $Value).ToString(
                $null,
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        )
        return
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $null = $Builder.Append('{')
        $first = $true
        foreach ($key in $Value.Keys) {
            if (-not $first) {
                $null = $Builder.Append(',')
            }
            Add-CliJsonString -Builder $Builder -Value ([string] $key)
            $null = $Builder.Append(':')
            Add-CliJsonValue -Builder $Builder -Value $Value[$key]
            $first = $false
        }
        $null = $Builder.Append('}')
        return
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $null = $Builder.Append('[')
        $first = $true
        foreach ($item in $Value) {
            if (-not $first) {
                $null = $Builder.Append(',')
            }
            Add-CliJsonValue -Builder $Builder -Value $item
            $first = $false
        }
        $null = $Builder.Append(']')
        return
    }

    $properties = @($Value.PSObject.Properties | Where-Object MemberType -in NoteProperty, Property)
    if ($properties.Count -eq 0) {
        throw [System.InvalidOperationException]::new('The CLI received an unsupported result value.')
    }
    $null = $Builder.Append('{')
    for ($index = 0; $index -lt $properties.Count; $index++) {
        if ($index -gt 0) {
            $null = $Builder.Append(',')
        }
        Add-CliJsonString -Builder $Builder -Value $properties[$index].Name
        $null = $Builder.Append(':')
        Add-CliJsonValue -Builder $Builder -Value $properties[$index].Value
    }
    $null = $Builder.Append('}')
}

function ConvertTo-CliJson {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Envelope
    )

    $builder = [System.Text.StringBuilder]::new()
    Add-CliJsonValue -Builder $builder -Value $Envelope
    $builder.ToString()
}

function New-CliFailure {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'This private helper only constructs an in-memory error envelope.'
    )]
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    param(
        [Parameter(Mandatory)]
        [string] $Category,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Details
    )

    [ordered]@{
        ok = $false
        error = [ordered]@{
            category = $Category
            details = $Details
        }
    }
}

function Assert-CliGrammar {
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]] $Arguments
    )

    if ($Arguments.Count -lt 3 -or $Arguments[0] -cne '--db') {
        throw [System.Management.Automation.PSInvalidOperationException]::new('invalid_cli')
    }
    $databasePath = $Arguments[1]
    $command = $Arguments[2]
    switch -CaseSensitive ($command) {
        'list' {
            if ($Arguments.Count -ne 3) {
                throw [System.Management.Automation.PSInvalidOperationException]::new('invalid_cli')
            }
            return [ordered]@{
                DatabasePath = $databasePath
                Command = $command
            }
        }
        'get' {
            if ($Arguments.Count -ne 4) {
                throw [System.Management.Automation.PSInvalidOperationException]::new('invalid_cli')
            }
            return [ordered]@{
                DatabasePath = $databasePath
                Command = $command
                Key = $Arguments[3]
            }
        }
        'set' {
            if (
                $Arguments.Count -notin 6, 8 -or
                $Arguments[4] -cne '--value-json' -or
                ($Arguments.Count -eq 8 -and $Arguments[6] -cne '--expect')
            ) {
                throw [System.Management.Automation.PSInvalidOperationException]::new('invalid_cli')
            }
            return [ordered]@{
                DatabasePath = $databasePath
                Command = $command
                Key = $Arguments[3]
                ValueJson = $Arguments[5]
                Expect = if ($Arguments.Count -eq 8) { $Arguments[7] } else { 'any' }
            }
        }
        'delete' {
            if (
                $Arguments.Count -notin 4, 6 -or
                ($Arguments.Count -eq 6 -and $Arguments[4] -cne '--expect')
            ) {
                throw [System.Management.Automation.PSInvalidOperationException]::new('invalid_cli')
            }
            return [ordered]@{
                DatabasePath = $databasePath
                Command = $command
                Key = $Arguments[3]
                Expect = if ($Arguments.Count -eq 6) { $Arguments[5] } else { 'any' }
            }
        }
        default {
            throw [System.Management.Automation.PSInvalidOperationException]::new('invalid_cli')
        }
    }
}

$exitCode = 5
$envelope = $null
try {
    $arguments = @($args)
    try {
        $invocation = Assert-CliGrammar -Arguments $arguments
    }
    catch {
        if ($_.Exception.Message -ceq 'invalid_cli') {
            throw [System.ArgumentException]::new('invalid_cli')
        }
        throw
    }

    if ([string] $invocation.DatabasePath -ceq '') {
        $envelope = New-CliFailure -Category 'invalid_argument' -Details ([ordered]@{
            field = 'db'
            reason = 'empty'
        })
        $exitCode = 2
    }
    elseif (
        [string] $invocation.DatabasePath -ceq ':memory:' -or
        ([string] $invocation.DatabasePath).StartsWith('file:', [System.StringComparison]::Ordinal)
    ) {
        $envelope = New-CliFailure -Category 'invalid_argument' -Details ([ordered]@{
            field = 'db'
            reason = 'unsupported_form'
        })
        $exitCode = 2
    }
    else {
        Import-Module `
            -Name (Join-Path -Path $PSScriptRoot -ChildPath 'ComparativeKv.psd1') `
            -RequiredVersion 1.0.0 `
            -Force `
            -WarningAction SilentlyContinue |
            Out-Null

        $result = switch ($invocation.Command) {
            'set' {
                Set-ConfigurationEntry `
                    -DatabasePath $invocation.DatabasePath `
                    -Key $invocation.Key `
                    -ValueJson $invocation.ValueJson `
                    -Expect $invocation.Expect `
                    -Confirm:$false
            }
            'get' {
                Get-ConfigurationEntry `
                    -DatabasePath $invocation.DatabasePath `
                    -Key $invocation.Key
            }
            'delete' {
                Remove-ConfigurationEntry `
                    -DatabasePath $invocation.DatabasePath `
                    -Key $invocation.Key `
                    -Expect $invocation.Expect `
                    -Confirm:$false
            }
            'list' {
                Get-ConfigurationStore -DatabasePath $invocation.DatabasePath
            }
        }
        $envelope = [ordered]@{
            ok = $true
            result = $result
        }
        $exitCode = 0
    }
}
catch {
    $exception = $_.Exception
    if ($exception.Message -ceq 'invalid_cli') {
        $envelope = New-CliFailure -Category 'usage' -Details ([ordered]@{
            reason = 'invalid_cli'
        })
        $exitCode = 2
    }
    elseif ($exception.Data.Contains('KvCategory')) {
        $envelope = New-CliFailure `
            -Category ([string] $exception.Data['KvCategory']) `
            -Details ([System.Collections.IDictionary] $exception.Data['KvDetails'])
        $exitCode = [int] $exception.Data['KvExitCode']
    }
    else {
        $envelope = New-CliFailure -Category 'storage_error' -Details ([ordered]@{
            operation = 'open'
            reason = 'storage_failure'
        })
        $exitCode = 5
    }
}

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::Out.Write((ConvertTo-CliJson -Envelope $envelope))
[Console]::Out.Write("`n")
exit $exitCode
