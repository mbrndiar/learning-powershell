#Requires -Version 7.4

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseShouldProcessForStateChangingFunctions',
    '',
    Justification = 'Private factories and storage helpers are gated by the exported ShouldProcess commands.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseSingularNouns',
    '',
    Justification = 'Private helper nouns describe collection-valued parameters and results.'
)]
param()

Set-StrictMode -Version Latest

$script:KvSafeIntegerMaximum = 9007199254740991L
$script:KvSafeIntegerMinimum = -9007199254740991L
$script:KvBusyTimeoutMilliseconds = 10000
$script:KvMaximumJsonBytes = 65536
$script:KvMaximumJsonDepth = 32
$script:KvKeyPattern = '^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$'

function New-KvException {
    [CmdletBinding()]
    [OutputType([System.Exception])]
    param(
        [Parameter(Mandatory)]
        [string] $Category,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Details,

        [Parameter(Mandatory)]
        [ValidateSet(2, 3, 4, 5)]
        [int] $ExitCode
    )

    $exception = [System.InvalidOperationException]::new($Category)
    $exception.Data['KvCategory'] = $Category
    $exception.Data['KvDetails'] = $Details
    $exception.Data['KvExitCode'] = $ExitCode
    $exception
}

function Test-KvException {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.Exception] $Exception
    )

    $Exception.Data.Contains('KvCategory')
}

function Test-KvBusyException {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.Exception] $Exception
    )

    $current = $Exception
    while ($null -ne $current) {
        if ($current.GetType().FullName -eq 'System.Data.SQLite.SQLiteException') {
            $resultCode = [int] $current.ResultCode
            if ($resultCode -in 5, 6) {
                return $true
            }
        }
        if ($current.Message -match '(?i)\b(database is locked|database is busy|locked|busy)\b') {
            return $true
        }
        $current = $current.InnerException
    }
    $false
}

function Test-KvCorruptionException {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.Exception] $Exception
    )

    $current = $Exception
    while ($null -ne $current) {
        if ($current.GetType().FullName -eq 'System.Data.SQLite.SQLiteException') {
            if ([int] $current.ResultCode -in 11, 26) {
                return $true
            }
        }
        if ($current.Message -match '(?i)\b(database disk image is malformed|file is not a database)\b') {
            return $true
        }
        $current = $current.InnerException
    }
    $false
}

function ConvertTo-KvStorageException {
    [CmdletBinding()]
    [OutputType([System.Exception])]
    param(
        [Parameter(Mandatory)]
        [System.Exception] $Exception,

        [Parameter(Mandatory)]
        [ValidateSet('open', 'configure', 'initialize', 'migrate', 'read', 'write', 'commit')]
        [string] $Operation
    )

    if (Test-KvException -Exception $Exception) {
        return $Exception
    }
    if (Test-KvCorruptionException -Exception $Exception) {
        return New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
            reason = 'integrity_check_failed'
        })
    }
    if (Test-KvBusyException -Exception $Exception) {
        return New-KvException -Category 'busy' -ExitCode 5 -Details ([ordered]@{
            timeout_ms = $script:KvBusyTimeoutMilliseconds
        })
    }
    New-KvException -Category 'storage_error' -ExitCode 5 -Details ([ordered]@{
        operation = $Operation
        reason = 'storage_failure'
    })
}

function Assert-KvDatabasePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $DatabasePath
    )

    if ($DatabasePath.Length -eq 0) {
        throw (New-KvException -Category 'invalid_argument' -ExitCode 2 -Details ([ordered]@{
            field = 'db'
            reason = 'empty'
        }))
    }
    if ($DatabasePath -eq ':memory:' -or $DatabasePath.StartsWith('file:', [System.StringComparison]::Ordinal)) {
        throw (New-KvException -Category 'invalid_argument' -ExitCode 2 -Details ([ordered]@{
            field = 'db'
            reason = 'unsupported_form'
        }))
    }
}

function Assert-KvKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Key
    )

    if ($Key -cnotmatch $script:KvKeyPattern) {
        throw (New-KvException -Category 'invalid_argument' -ExitCode 2 -Details ([ordered]@{
            field = 'key'
            reason = 'format'
        }))
    }
}

function ConvertFrom-KvExpectation {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Expectation,

        [Parameter(Mandatory)]
        [ValidateSet('set', 'delete')]
        [string] $Command
    )

    if ($Expectation -ceq 'any') {
        return [pscustomobject]@{ Kind = 'any'; Value = $null }
    }
    if ($Command -eq 'set' -and $Expectation -ceq 'absent') {
        return [pscustomobject]@{ Kind = 'absent'; Value = $null }
    }
    if ($Expectation -cmatch '^[1-9][0-9]*$') {
        $revision = 0L
        if (
            [long]::TryParse(
                $Expectation,
                [System.Globalization.NumberStyles]::None,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [ref] $revision
            ) -and
            $revision -le $script:KvSafeIntegerMaximum
        ) {
            return [pscustomobject]@{ Kind = 'exact'; Value = $revision }
        }
    }

    throw (New-KvException -Category 'invalid_argument' -ExitCode 2 -Details ([ordered]@{
        field = 'expect'
        reason = 'format'
    }))
}

function Skip-KvJsonWhitespace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Context
    )

    $start = $Context.Index
    while ($Context.Index -lt $Context.Length) {
        $character = $Context.Text[$Context.Index]
        if ($character -notin " ", "`t", "`r", "`n") {
            break
        }
        $Context.Index++
    }
    if ($Context.Index -gt $start) {
        $Context.HasWhitespace = $true
    }
}

function New-KvJsonSyntaxException {
    [CmdletBinding()]
    [OutputType([System.Exception])]
    param()

    New-KvException -Category 'invalid_json' -ExitCode 2 -Details ([ordered]@{
        reason = 'syntax'
    })
}

function New-KvJsonValueException {
    [CmdletBinding()]
    [OutputType([System.Exception])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'depth_limit',
            'unpaired_surrogate',
            'non_integral_number',
            'non_finite_number',
            'number_out_of_range'
        )]
        [string] $Reason
    )

    New-KvException -Category 'invalid_value' -ExitCode 2 -Details ([ordered]@{
        reason = $Reason
    })
}

function Read-KvJsonHexCodeUnit {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Context
    )

    if ($Context.Index + 4 -gt $Context.Length) {
        throw (New-KvJsonSyntaxException)
    }
    $hex = $Context.Text.Substring($Context.Index, 4)
    if ($hex -cnotmatch '^[0-9A-Fa-f]{4}$') {
        throw (New-KvJsonSyntaxException)
    }
    $Context.Index += 4
    [Convert]::ToInt32($hex, 16)
}

function Read-KvJsonString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Context
    )

    if ($Context.Index -ge $Context.Length -or $Context.Text[$Context.Index] -ne '"') {
        throw (New-KvJsonSyntaxException)
    }
    $Context.Index++
    $builder = [System.Text.StringBuilder]::new()

    while ($Context.Index -lt $Context.Length) {
        $character = $Context.Text[$Context.Index]
        $Context.Index++
        if ($character -eq '"') {
            return $builder.ToString()
        }
        if ([int] $character -lt 0x20) {
            throw (New-KvJsonSyntaxException)
        }
        if ($character -eq '\') {
            if ($Context.Index -ge $Context.Length) {
                throw (New-KvJsonSyntaxException)
            }
            $escape = $Context.Text[$Context.Index]
            $Context.Index++
            switch -CaseSensitive ($escape) {
                '"' { $null = $builder.Append('"') }
                '\' { $null = $builder.Append('\') }
                '/' { $null = $builder.Append('/') }
                'b' { $null = $builder.Append([char] 0x08) }
                'f' { $null = $builder.Append([char] 0x0c) }
                'n' { $null = $builder.Append("`n") }
                'r' { $null = $builder.Append("`r") }
                't' { $null = $builder.Append("`t") }
                'u' {
                    $codeUnit = Read-KvJsonHexCodeUnit -Context $Context
                    if ($codeUnit -ge 0xd800 -and $codeUnit -le 0xdbff) {
                        if (
                            $Context.Index + 6 -le $Context.Length -and
                            $Context.Text[$Context.Index] -eq '\' -and
                            $Context.Text[$Context.Index + 1] -eq 'u'
                        ) {
                            $lowHex = $Context.Text.Substring($Context.Index + 2, 4)
                            if ($lowHex -cmatch '^[0-9A-Fa-f]{4}$') {
                                $lowCodeUnit = [Convert]::ToInt32($lowHex, 16)
                                if ($lowCodeUnit -ge 0xdc00 -and $lowCodeUnit -le 0xdfff) {
                                    $Context.Index += 6
                                    $scalar = 0x10000 +
                                        (($codeUnit - 0xd800) * 0x400) +
                                        ($lowCodeUnit - 0xdc00)
                                    $null = $builder.Append([char]::ConvertFromUtf32($scalar))
                                    continue
                                }
                            }
                        }
                    }
                    $null = $builder.Append([char] $codeUnit)
                }
                default { throw (New-KvJsonSyntaxException) }
            }
            continue
        }

        $code = [int] $character
        if ($code -ge 0xd800 -and $code -le 0xdbff) {
            if ($Context.Index -lt $Context.Length) {
                $low = [int] $Context.Text[$Context.Index]
                if ($low -ge 0xdc00 -and $low -le 0xdfff) {
                    $null = $builder.Append($character)
                    $null = $builder.Append($Context.Text[$Context.Index])
                    $Context.Index++
                    continue
                }
            }
            $null = $builder.Append($character)
        }
        else {
            $null = $builder.Append($character)
        }
    }

    throw (New-KvJsonSyntaxException)
}

function ConvertFrom-KvJsonNumberToken {
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory)]
        [string] $Token,

        [Parameter(Mandatory)]
        [hashtable] $Context
    )

    $binary64 = 0.0
    $parsed = [double]::TryParse(
        $Token,
        [System.Globalization.NumberStyles]::Float,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [ref] $binary64
    )
    if (-not $parsed -or [double]::IsInfinity($binary64) -or [double]::IsNaN($binary64)) {
        throw (New-KvJsonValueException -Reason 'non_finite_number')
    }

    $match = [regex]::Match(
        $Token,
        '^(?<sign>-?)(?<integer>0|[1-9][0-9]*)(?:\.(?<fraction>[0-9]+))?(?:[eE](?<exponent>[+-]?[0-9]+))?$',
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    if (-not $match.Success) {
        throw (New-KvJsonSyntaxException)
    }

    $fraction = $match.Groups['fraction'].Value
    $digits = ($match.Groups['integer'].Value + $fraction).TrimStart('0')
    if ($digits.Length -eq 0) {
        if ($Token -cne '0') {
            $Context.HadNonCanonicalNumber = $true
        }
        return 0L
    }

    $exponentText = $match.Groups['exponent'].Value
    $exponent = 0L
    if ($exponentText.Length -gt 0) {
        if (-not [long]::TryParse(
                $exponentText,
                [System.Globalization.NumberStyles]::AllowLeadingSign,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [ref] $exponent
            )) {
            if ($exponentText.StartsWith('-', [System.StringComparison]::Ordinal)) {
                throw (New-KvJsonValueException -Reason 'non_integral_number')
            }
            throw (New-KvJsonValueException -Reason 'number_out_of_range')
        }
    }
    $scale = $exponent - $fraction.Length
    if ($scale -lt 0) {
        $requiredZeroes = -$scale
        if ($requiredZeroes -gt $digits.Length) {
            throw (New-KvJsonValueException -Reason 'non_integral_number')
        }
        $suffix = $digits.Substring($digits.Length - [int] $requiredZeroes)
        if ($suffix -cnotmatch '^0+$') {
            throw (New-KvJsonValueException -Reason 'non_integral_number')
        }
        $digits = $digits.Substring(0, $digits.Length - [int] $requiredZeroes)
        if ($digits.Length -eq 0) {
            $digits = '0'
        }
    }
    elseif ($scale -gt 0) {
        if ($scale -gt 308) {
            throw (New-KvJsonValueException -Reason 'number_out_of_range')
        }
        $digits += '0' * [int] $scale
    }

    $integer = [System.Numerics.BigInteger]::Parse(
        $digits,
        [System.Globalization.CultureInfo]::InvariantCulture
    )
    if ($match.Groups['sign'].Value -eq '-') {
        $integer = -$integer
    }
    if (
        $integer -lt [System.Numerics.BigInteger] $script:KvSafeIntegerMinimum -or
        $integer -gt [System.Numerics.BigInteger] $script:KvSafeIntegerMaximum
    ) {
        throw (New-KvJsonValueException -Reason 'number_out_of_range')
    }

    $normalized = $integer.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    if ($normalized -cne $Token) {
        $Context.HadNonCanonicalNumber = $true
    }
    [long] $integer
}

function Read-KvJsonNumber {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Context
    )

    $remaining = $Context.Text.Substring($Context.Index)
    $match = [regex]::Match(
        $remaining,
        '^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    if (-not $match.Success) {
        throw (New-KvJsonSyntaxException)
    }
    $Context.Index += $match.Length
    $node = [pscustomobject]@{ Token = $match.Value }
    $node.PSObject.TypeNames.Insert(0, 'ComparativeKv.JsonNumber')
    $node
}

function Read-KvJsonValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Context,

        [Parameter(Mandatory)]
        [int] $Depth
    )

    Skip-KvJsonWhitespace -Context $Context
    if ($Context.Index -ge $Context.Length) {
        throw (New-KvJsonSyntaxException)
    }

    $character = $Context.Text[$Context.Index]
    if ($character -eq '"') {
        return Read-KvJsonString -Context $Context
    }
    if ($character -eq '[') {
        $containerDepth = $Depth + 1
        if ($containerDepth -gt 256) {
            throw (New-KvJsonValueException -Reason 'depth_limit')
        }
        $Context.Index++
        $items = [System.Collections.Generic.List[object]]::new()
        Skip-KvJsonWhitespace -Context $Context
        if ($Context.Index -lt $Context.Length -and $Context.Text[$Context.Index] -eq ']') {
            $Context.Index++
            return ,([object[]] $items.ToArray())
        }
        while ($true) {
            $item = Read-KvJsonValue -Context $Context -Depth $containerDepth
            $items.Add($item)
            Skip-KvJsonWhitespace -Context $Context
            if ($Context.Index -ge $Context.Length) {
                throw (New-KvJsonSyntaxException)
            }
            $separator = $Context.Text[$Context.Index]
            $Context.Index++
            if ($separator -eq ']') {
                return ,([object[]] $items.ToArray())
            }
            if ($separator -ne ',') {
                throw (New-KvJsonSyntaxException)
            }
        }
    }
    if ($character -eq '{') {
        $containerDepth = $Depth + 1
        if ($containerDepth -gt 256) {
            throw (New-KvJsonValueException -Reason 'depth_limit')
        }
        $Context.Index++
        $members = [System.Collections.Generic.Dictionary[string, object]]::new(
            [System.StringComparer]::Ordinal
        )
        Skip-KvJsonWhitespace -Context $Context
        if ($Context.Index -lt $Context.Length -and $Context.Text[$Context.Index] -eq '}') {
            $Context.Index++
            return $members
        }
        while ($true) {
            Skip-KvJsonWhitespace -Context $Context
            $name = Read-KvJsonString -Context $Context
            Skip-KvJsonWhitespace -Context $Context
            if ($Context.Index -ge $Context.Length -or $Context.Text[$Context.Index] -ne ':') {
                throw (New-KvJsonSyntaxException)
            }

            $Context.Index++
            $memberValue = Read-KvJsonValue -Context $Context -Depth $containerDepth
            if ($members.ContainsKey($name)) {
                $null = $members.Remove($name)
                $Context.HadDuplicate = $true
            }
            $members.Add($name, $memberValue)
            Skip-KvJsonWhitespace -Context $Context
            if ($Context.Index -ge $Context.Length) {
                throw (New-KvJsonSyntaxException)
            }
            $separator = $Context.Text[$Context.Index]
            $Context.Index++
            if ($separator -eq '}') {
                return $members
            }
            if ($separator -ne ',') {
                throw (New-KvJsonSyntaxException)
            }
        }
    }
    if (
        $Context.Index + 4 -le $Context.Length -and
        $Context.Text.Substring($Context.Index, 4) -ceq 'true'
    ) {
        $Context.Index += 4
        return $true
    }
    if (
        $Context.Index + 5 -le $Context.Length -and
        $Context.Text.Substring($Context.Index, 5) -ceq 'false'
    ) {
        $Context.Index += 5
        return $false
    }
    if (
        $Context.Index + 4 -le $Context.Length -and
        $Context.Text.Substring($Context.Index, 4) -ceq 'null'
    ) {
        $Context.Index += 4
        return $null
    }
    if ($character -eq '-' -or [char]::IsAsciiDigit($character)) {
        return Read-KvJsonNumber -Context $Context
    }
    throw (New-KvJsonSyntaxException)
}

function Assert-KvUnicodeScalarString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Value
    )

    for ($index = 0; $index -lt $Value.Length; $index++) {
        $codeUnit = [int] $Value[$index]
        if ($codeUnit -ge 0xd800 -and $codeUnit -le 0xdbff) {
            if ($index + 1 -ge $Value.Length) {
                throw (New-KvJsonValueException -Reason 'unpaired_surrogate')
            }
            $lowCodeUnit = [int] $Value[$index + 1]
            if ($lowCodeUnit -lt 0xdc00 -or $lowCodeUnit -gt 0xdfff) {
                throw (New-KvJsonValueException -Reason 'unpaired_surrogate')
            }
            $index++
        }
        elseif ($codeUnit -ge 0xdc00 -and $codeUnit -le 0xdfff) {
            throw (New-KvJsonValueException -Reason 'unpaired_surrogate')
        }
    }
}

function Resolve-KvJsonValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value,

        [Parameter(Mandatory)]
        [int] $Depth,

        [Parameter(Mandatory)]
        [hashtable] $Context
    )

    if ($null -eq $Value -or $Value -is [bool]) {
        return $Value
    }
    if ($Value -is [string]) {
        Assert-KvUnicodeScalarString -Value $Value
        return $Value
    }
    if ($Value.PSObject.TypeNames -contains 'ComparativeKv.JsonNumber') {
        return ConvertFrom-KvJsonNumberToken -Token ([string] $Value.Token) -Context $Context
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $containerDepth = $Depth + 1
        if ($containerDepth -gt $script:KvMaximumJsonDepth) {
            throw (New-KvJsonValueException -Reason 'depth_limit')
        }
        foreach ($name in @($Value.Keys)) {
            Assert-KvUnicodeScalarString -Value ([string] $name)
            $Value[$name] = Resolve-KvJsonValue `
                -Value $Value[$name] `
                -Depth $containerDepth `
                -Context $Context
        }
        return $Value
    }
    if ($Value -is [object[]]) {
        $containerDepth = $Depth + 1
        if ($containerDepth -gt $script:KvMaximumJsonDepth) {
            throw (New-KvJsonValueException -Reason 'depth_limit')
        }
        for ($index = 0; $index -lt $Value.Length; $index++) {
            $Value[$index] = Resolve-KvJsonValue `
                -Value $Value[$index] `
                -Depth $containerDepth `
                -Context $Context
        }
        return ,$Value
    }
    throw (New-KvJsonSyntaxException)
}

function Add-KvJsonEscapedString {
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

function Add-KvJsonValue {
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
        Add-KvJsonEscapedString -Builder $Builder -Value $Value
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
            Add-KvJsonEscapedString -Builder $Builder -Value ([string] $key)
            $null = $Builder.Append(':')
            Add-KvJsonValue -Builder $Builder -Value $Value[$key]
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
            Add-KvJsonValue -Builder $Builder -Value $item
            $first = $false
        }
        $null = $Builder.Append(']')
        return
    }

    $properties = @($Value.PSObject.Properties | Where-Object MemberType -in NoteProperty, Property)
    if ($properties.Count -gt 0) {
        $null = $Builder.Append('{')
        for ($index = 0; $index -lt $properties.Count; $index++) {
            if ($index -gt 0) {
                $null = $Builder.Append(',')
            }
            Add-KvJsonEscapedString -Builder $Builder -Value $properties[$index].Name
            $null = $Builder.Append(':')
            Add-KvJsonValue -Builder $Builder -Value $properties[$index].Value
        }
        $null = $Builder.Append('}')
        return
    }

    throw [System.InvalidOperationException]::new(
        "Unsupported internal JSON value type '$($Value.GetType().FullName)'."
    )
}

function ConvertTo-KvJson {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Value
    )

    $builder = [System.Text.StringBuilder]::new()
    Add-KvJsonValue -Builder $builder -Value $Value
    $builder.ToString()
}

function ConvertFrom-KvRestrictedJson {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Json,

        [switch] $RequireNormalized
    )

    if ([System.Text.Encoding]::UTF8.GetByteCount($Json) -gt $script:KvMaximumJsonBytes) {
        throw (New-KvException -Category 'invalid_value' -ExitCode 2 -Details ([ordered]@{
            reason = 'byte_limit'
        }))
    }

    $context = @{
        Text = $Json
        Index = 0
        Length = $Json.Length
        HasWhitespace = $false
        HadDuplicate = $false
        HadNonCanonicalNumber = $false
    }
    $value = Read-KvJsonValue -Context $context -Depth 0
    Skip-KvJsonWhitespace -Context $context
    if ($context.Index -ne $context.Length) {
        throw (New-KvJsonSyntaxException)
    }
    $value = Resolve-KvJsonValue -Value $value -Depth 0 -Context $context
    if (
        $RequireNormalized -and
        ($context.HasWhitespace -or $context.HadDuplicate -or $context.HadNonCanonicalNumber)
    ) {
        throw (New-KvException -Category 'invalid_value' -ExitCode 2 -Details ([ordered]@{
            reason = 'not_normalized'
        }))
    }

    [pscustomobject]@{
        Value = $value
        Json = ConvertTo-KvJson -Value $value
    }
}

function Add-KvCommandParameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbCommand] $Command,

        [System.Collections.IDictionary] $Parameters
    )

    if ($null -eq $Parameters) {
        return
    }
    foreach ($entry in $Parameters.GetEnumerator()) {
        $value = if ($null -eq $entry.Value) {
            [DBNull]::Value
        }
        else {
            $entry.Value
        }
        $null = $Command.Parameters.AddWithValue("@$($entry.Key)", $value)
    }
}

function New-KvCommand {
    [CmdletBinding()]
    [OutputType([System.Data.Common.DbCommand])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $Sql,

        [System.Collections.IDictionary] $Parameters,

        [System.Data.Common.DbTransaction] $Transaction
    )

    $command = $Connection.CreateCommand()
    $command.CommandText = $Sql
    $command.CommandTimeout = 30
    if ($null -ne $Transaction) {
        $command.Transaction = $Transaction
    }
    Add-KvCommandParameters -Command $command -Parameters $Parameters
    $command
}

function Invoke-KvNonQuery {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $Sql,

        [System.Collections.IDictionary] $Parameters,

        [System.Data.Common.DbTransaction] $Transaction
    )

    $command = New-KvCommand -Connection $Connection -Sql $Sql -Parameters $Parameters -Transaction $Transaction
    try {
        $command.ExecuteNonQuery()
    }
    finally {
        $command.Dispose()
    }
}

function Invoke-KvScalar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $Sql,

        [System.Collections.IDictionary] $Parameters,

        [System.Data.Common.DbTransaction] $Transaction
    )

    $command = New-KvCommand -Connection $Connection -Sql $Sql -Parameters $Parameters -Transaction $Transaction
    try {
        $value = $command.ExecuteScalar()
        if ($value -is [DBNull]) {
            return $null
        }
        $value
    }
    finally {
        $command.Dispose()
    }
}

function Invoke-KvRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $Sql,

        [System.Collections.IDictionary] $Parameters,

        [System.Data.Common.DbTransaction] $Transaction
    )

    $command = New-KvCommand -Connection $Connection -Sql $Sql -Parameters $Parameters -Transaction $Transaction
    $reader = $null
    try {
        $reader = $command.ExecuteReader()
        while ($reader.Read()) {
            $row = [ordered]@{}
            for ($index = 0; $index -lt $reader.FieldCount; $index++) {
                $value = $reader.GetValue($index)
                $row[$reader.GetName($index)] = if ($value -is [DBNull]) { $null } else { $value }
            }
            [pscustomobject] $row
        }
    }
    finally {
        if ($null -ne $reader) {
            $reader.Dispose()
        }
        $command.Dispose()
    }
}

function Open-KvConnection {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $DatabasePath
    )

    $connectionName = 'comparative-kv-{0}-{1}' -f $PID, [guid]::NewGuid().ToString('N')
    $opened = $false
    try {
        $fullPath = [System.IO.Path]::GetFullPath($DatabasePath)
        $parent = [System.IO.Path]::GetDirectoryName($fullPath)
        if ([string]::IsNullOrEmpty($parent) -or -not [System.IO.Directory]::Exists($parent)) {
            throw [System.IO.DirectoryNotFoundException]::new('The database parent directory does not exist.')
        }

        Open-SQLiteConnection `
            -DataSource $DatabasePath `
            -ConnectionName $connectionName `
            -CommandTimeout 30 `
            -Additional @{
                BusyTimeout = $script:KvBusyTimeoutMilliseconds
                WaitTimeout = $script:KvBusyTimeoutMilliseconds
                DefaultTimeout = 10
                ForeignKeys = $true
                Pooling = $false
            } `
            -WarningAction SilentlyContinue |
            Out-Null
        $opened = $true
        $connection = Get-SqlConnection -ConnectionName $connectionName
        [pscustomobject]@{
            Name = $connectionName
            Connection = $connection
        }
    }
    catch {
        if ($opened) {
            Close-SqlConnection -ConnectionName $connectionName -ErrorAction SilentlyContinue
        }
        throw (ConvertTo-KvStorageException -Exception $_.Exception -Operation 'open')
    }
}

function Close-KvConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context
    )

    Close-SqlConnection -ConnectionName $Context.Name -ErrorAction SilentlyContinue
}

function Initialize-KvConnectionConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection
    )

    try {
        $null = Invoke-KvNonQuery -Connection $Connection -Sql (
            'PRAGMA busy_timeout = {0}' -f $script:KvBusyTimeoutMilliseconds
        )
        $null = Invoke-KvNonQuery -Connection $Connection -Sql 'PRAGMA foreign_keys = ON'
        $journalMode = [string] (Invoke-KvScalar -Connection $Connection -Sql 'PRAGMA journal_mode = WAL')
        if ($journalMode -cne 'wal') {
            throw [System.InvalidOperationException]::new('SQLite did not enable WAL mode.')
        }
    }
    catch {
        throw (ConvertTo-KvStorageException -Exception $_.Exception -Operation 'configure')
    }
}

function ConvertTo-KvSchemaFingerprint {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Sql
    )

    (($Sql.ToLowerInvariant() -replace '["`\[\]]', '') -replace '\s+', '')
}

function Get-KvApplicationObjects {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [System.Data.Common.DbTransaction] $Transaction
    )

    @(
        Invoke-KvRows -Connection $Connection -Transaction $Transaction -Sql @'
SELECT type, name, sql
FROM sqlite_schema
WHERE name NOT LIKE 'sqlite_%'
  AND type IN ('table', 'index', 'trigger', 'view')
ORDER BY type COLLATE BINARY, name COLLATE BINARY
'@
    )
}

function Get-KvFutureSchemaVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Objects,

        [System.Data.Common.DbTransaction] $Transaction
    )

    $metadataTable = @(
        $Objects | Where-Object { $_.type -ceq 'table' -and $_.name -ceq 'store_metadata' }
    )
    if ($metadataTable.Count -ne 1) {
        return $null
    }
    try {
        $rows = @(
            Invoke-KvRows -Connection $Connection -Transaction $Transaction -Sql @'
SELECT singleton, schema_version, global_revision
FROM store_metadata
'@
        )
        if ($rows.Count -eq 1) {
            $version = [long] $rows[0].schema_version
            if ($version -gt 1) {
                return $version
            }
        }
    }
    catch {
        return $null
    }
    $null
}

function Get-KvSchemaKind {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Objects
    )

    if ($Objects.Count -eq 0) {
        return 'fresh'
    }

    $v0Entries = 'createtableentries(keytextprimarykeycollatebinary,value_jsontextnotnull)'
    if (
        $Objects.Count -eq 1 -and
        $Objects[0].type -ceq 'table' -and
        $Objects[0].name -ceq 'entries' -and
        (ConvertTo-KvSchemaFingerprint -Sql ([string] $Objects[0].sql)) -ceq $v0Entries
    ) {
        return 'v0'
    }

    if ($Objects.Count -eq 2) {
        $byName = @{}
        foreach ($object in $Objects) {
            if ($object.type -cne 'table') {
                return 'malformed'
            }
            $byName[[string] $object.name] = ConvertTo-KvSchemaFingerprint -Sql ([string] $object.sql)
        }
        $metadata = 'createtablestore_metadata(singletonintegerprimarykeycheck(singleton=1),schema_versionintegernotnullcheck(schema_version=1),global_revisionintegernotnullcheck(global_revisionbetween0and9007199254740991))'
        $entries = 'createtableentries(keytextprimarykeycollatebinary,value_jsontextnotnullcheck(json_valid(value_json)),revisionintegernotnullcheck(revisionbetween1and9007199254740991))'
        if (
            $byName.Count -eq 2 -and
            $byName.ContainsKey('store_metadata') -and
            $byName.ContainsKey('entries') -and
            $byName['store_metadata'] -ceq $metadata -and
            $byName['entries'] -ceq $entries
        ) {
            return 'v1'
        }
    }
    'malformed'
}

function Assert-KvIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [System.Data.Common.DbTransaction] $Transaction
    )

    $rows = @(Invoke-KvRows -Connection $Connection -Transaction $Transaction -Sql 'PRAGMA integrity_check')
    if ($rows.Count -ne 1 -or [string] $rows[0].integrity_check -cne 'ok') {
        throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
            reason = 'integrity_check_failed'
        }))
    }
}

function Assert-KvV1Data {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [System.Data.Common.DbTransaction] $Transaction
    )

    $metadataRows = @(
        Invoke-KvRows -Connection $Connection -Transaction $Transaction -Sql @'
SELECT singleton, schema_version, global_revision
FROM store_metadata
'@
    )
    if ($metadataRows.Count -ne 1) {
        throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
            reason = 'revision_invariant'
        }))
    }
    $metadata = $metadataRows[0]
    try {
        $singleton = [long] $metadata.singleton
        $schemaVersion = [long] $metadata.schema_version
        $globalRevision = [long] $metadata.global_revision
    }
    catch {
        throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
            reason = 'revision_invariant'
        }))
    }
    if (
        $singleton -ne 1 -or
        $schemaVersion -ne 1 -or
        $globalRevision -lt 0 -or
        $globalRevision -gt $script:KvSafeIntegerMaximum
    ) {
        throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
            reason = 'revision_invariant'
        }))
    }

    $seenRevisions = [System.Collections.Generic.HashSet[long]]::new()
    $entries = @(
        Invoke-KvRows -Connection $Connection -Transaction $Transaction -Sql @'
SELECT key, value_json, revision
FROM entries
ORDER BY key COLLATE BINARY
'@
    )
    foreach ($entry in $entries) {
        $key = [string] $entry.key
        try {
            Assert-KvKey -Key $key
        }
        catch {
            throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
                reason = 'invalid_key'
                key = $key
            }))
        }
        try {
            $null = ConvertFrom-KvRestrictedJson -Json ([string] $entry.value_json) -RequireNormalized
        }
        catch {
            throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
                reason = 'invalid_value'
                key = $key
            }))
        }

        try {
            $revision = [long] $entry.revision
        }
        catch {
            throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
                reason = 'revision_invariant'
            }))
        }
        if (
            $revision -lt 1 -or
            $revision -gt $globalRevision -or
            -not $seenRevisions.Add($revision)
        ) {
            throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
                reason = 'revision_invariant'
            }))
        }
    }
}

function New-KvV1Schema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [Parameter(Mandatory)]
        [System.Data.Common.DbTransaction] $Transaction
    )

    $null = Invoke-KvNonQuery -Connection $Connection -Transaction $Transaction -Sql @'
CREATE TABLE store_metadata (
    singleton       INTEGER PRIMARY KEY CHECK (singleton = 1),
    schema_version  INTEGER NOT NULL CHECK (schema_version = 1),
    global_revision INTEGER NOT NULL
                    CHECK (global_revision BETWEEN 0 AND 9007199254740991)
)
'@
    $null = Invoke-KvNonQuery -Connection $Connection -Transaction $Transaction -Sql @'
CREATE TABLE entries (
    key        TEXT PRIMARY KEY COLLATE BINARY,
    value_json TEXT NOT NULL CHECK (json_valid(value_json)),
    revision   INTEGER NOT NULL
               CHECK (revision BETWEEN 1 AND 9007199254740991)
)
'@
}

function Initialize-KvFreshStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [Parameter(Mandatory)]
        [System.Data.Common.DbTransaction] $Transaction
    )

    New-KvV1Schema -Connection $Connection -Transaction $Transaction
    $null = Invoke-KvNonQuery -Connection $Connection -Transaction $Transaction -Sql @'
INSERT INTO store_metadata(singleton, schema_version, global_revision)
VALUES (1, 1, 0)
'@
}

function Convert-KvV0Store {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [Parameter(Mandatory)]
        [System.Data.Common.DbTransaction] $Transaction
    )

    $legacyRows = @(
        Invoke-KvRows -Connection $Connection -Transaction $Transaction -Sql @'
SELECT key, value_json
FROM entries
ORDER BY key COLLATE BINARY
'@
    )
    $normalizedRows = [System.Collections.Generic.List[object]]::new()
    foreach ($row in $legacyRows) {
        $key = [string] $row.key
        try {
            Assert-KvKey -Key $key
        }
        catch {
            throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
                reason = 'invalid_key'
                key = $key
            }))
        }
        try {
            $normalized = ConvertFrom-KvRestrictedJson -Json ([string] $row.value_json)
        }
        catch {
            throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
                reason = 'invalid_value'
                key = $key
            }))
        }
        $normalizedRows.Add([pscustomobject]@{
            Key = $key
            Json = $normalized.Json
        })
    }

    $null = Invoke-KvNonQuery -Connection $Connection -Transaction $Transaction -Sql (
        'ALTER TABLE entries RENAME TO entries_v0'
    )
    New-KvV1Schema -Connection $Connection -Transaction $Transaction

    $revision = 0L
    foreach ($row in $normalizedRows) {
        $revision++
        $null = Invoke-KvNonQuery -Connection $Connection -Transaction $Transaction -Sql @'
INSERT INTO entries(key, value_json, revision)
VALUES (@key, @value_json, @revision)
'@ -Parameters @{
            key = $row.Key
            value_json = $row.Json
            revision = $revision
        }
    }
    $null = Invoke-KvNonQuery -Connection $Connection -Transaction $Transaction -Sql @'
INSERT INTO store_metadata(singleton, schema_version, global_revision)
VALUES (1, 1, @global_revision)
'@ -Parameters @{ global_revision = $revision }
    $null = Invoke-KvNonQuery -Connection $Connection -Transaction $Transaction -Sql (
        'DROP TABLE entries_v0'
    )
}

function Assert-KvStoreReady {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection
    )

    Initialize-KvConnectionConfiguration -Connection $Connection

    try {
        $objects = @(Get-KvApplicationObjects -Connection $Connection)
        $futureVersion = Get-KvFutureSchemaVersion -Connection $Connection -Objects $objects
        if ($null -ne $futureVersion) {
            throw (New-KvException -Category 'unsupported_schema' -ExitCode 5 -Details ([ordered]@{
                found = [long] $futureVersion
                supported = 1
            }))
        }
        $kind = Get-KvSchemaKind -Objects $objects
    }
    catch {
        throw (ConvertTo-KvStorageException -Exception $_.Exception -Operation 'read')
    }

    if ($kind -eq 'v1') {
        $transaction = $null
        try {
            $transaction = $Connection.BeginTransaction($true)
            Assert-KvIntegrity -Connection $Connection -Transaction $transaction
            Assert-KvV1Data -Connection $Connection -Transaction $transaction
            $transaction.Commit()
            return
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
        }
    }

    if ($kind -eq 'malformed') {
        try {
            Assert-KvIntegrity -Connection $Connection
        }
        catch {
            throw (ConvertTo-KvStorageException -Exception $_.Exception -Operation 'read')
        }
        throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
            reason = 'malformed_schema'
        }))
    }

    $transaction = $null
    $operation = if ($kind -eq 'v0') { 'migrate' } else { 'initialize' }
    try {
        $transaction = $Connection.BeginTransaction(
            [System.Data.IsolationLevel]::Serializable,
            $false
        )
        $objects = @(Get-KvApplicationObjects -Connection $Connection -Transaction $transaction)
        $futureVersion = Get-KvFutureSchemaVersion `
            -Connection $Connection `
            -Objects $objects `
            -Transaction $transaction
        if ($null -ne $futureVersion) {
            throw (New-KvException -Category 'unsupported_schema' -ExitCode 5 -Details ([ordered]@{
                found = [long] $futureVersion
                supported = 1
            }))
        }
        Assert-KvIntegrity -Connection $Connection -Transaction $transaction
        $kind = Get-KvSchemaKind -Objects $objects
        switch ($kind) {
            'fresh' {
                $operation = 'initialize'
                Initialize-KvFreshStore -Connection $Connection -Transaction $transaction
            }
            'v0' {
                $operation = 'migrate'
                Convert-KvV0Store -Connection $Connection -Transaction $transaction
            }
            'v1' {
                Assert-KvV1Data -Connection $Connection -Transaction $transaction
            }
            default {
                throw (New-KvException -Category 'invalid_storage' -ExitCode 5 -Details ([ordered]@{
                    reason = 'malformed_schema'
                }))
            }
        }
        $transaction.Commit()
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
    }
}

function Get-KvEntryRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [Parameter(Mandatory)]
        [string] $Key,

        [System.Data.Common.DbTransaction] $Transaction
    )

    $rows = @(
        Invoke-KvRows -Connection $Connection -Transaction $Transaction -Sql @'
SELECT key, value_json, revision
FROM entries
WHERE key = @key COLLATE BINARY
'@ -Parameters @{ key = $Key }
    )
    if ($rows.Count -eq 0) {
        return $null
    }
    $rows[0]
}

function Get-KvGlobalRevision {
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory)]
        [System.Data.Common.DbConnection] $Connection,

        [System.Data.Common.DbTransaction] $Transaction
    )

    [long] (Invoke-KvScalar -Connection $Connection -Transaction $Transaction -Sql @'
SELECT global_revision
FROM store_metadata
WHERE singleton = 1
'@)
}

function New-KvConflictException {
    [CmdletBinding()]
    [OutputType([System.Exception])]
    param(
        [Parameter(Mandatory)]
        [string] $Key,

        [Parameter(Mandatory)]
        [object] $Expectation,

        [AllowNull()]
        [object] $Actual
    )

    $expected = if ($Expectation.Kind -eq 'absent') {
        'absent'
    }
    else {
        [long] $Expectation.Value
    }
    New-KvException -Category 'conflict' -ExitCode 3 -Details ([ordered]@{
        key = $Key
        expected = $expected
        actual = $Actual
    })
}

function New-KvNotFoundException {
    [CmdletBinding()]
    [OutputType([System.Exception])]
    param(
        [Parameter(Mandatory)]
        [string] $Key
    )

    New-KvException -Category 'not_found' -ExitCode 4 -Details ([ordered]@{
        key = $Key
    })
}

function New-KvRevisionExhaustedException {
    [CmdletBinding()]
    [OutputType([System.Exception])]
    param()

    New-KvException -Category 'revision_exhausted' -ExitCode 5 -Details ([ordered]@{
        maximum = $script:KvSafeIntegerMaximum
    })
}
