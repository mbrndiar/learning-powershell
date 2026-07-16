#Requires -Version 7.4

Set-StrictMode -Version Latest

$script:ComplianceIdentifierPattern = '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
$script:ComplianceKeyPattern = '^[A-Za-z][A-Za-z0-9_.-]{0,63}$'
$script:MaximumConfigurationBytes = 1MB
$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:Utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
$script:ComplianceModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'ComplianceAudit.psd1'

function Get-ComplianceErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [string] $ErrorId,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorCategory] $Category,

        [Parameter(Mandatory)]
        [string] $Message,

        [AllowNull()]
        [object] $TargetObject,

        [AllowNull()]
        [System.Exception] $InnerException
    )

    $exception = if ($null -eq $InnerException) {
        [System.InvalidOperationException]::new($Message)
    }
    else {
        [System.InvalidOperationException]::new($Message, $InnerException)
    }
    [System.Management.Automation.ErrorRecord]::new(
        $exception,
        $ErrorId,
        $Category,
        $TargetObject
    )
}

function Assert-ExactPropertySet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string[]] $Name,

        [Parameter(Mandatory)]
        [string] $Context
    )

    if ($InputObject -isnot [System.Management.Automation.PSCustomObject]) {
        throw [System.IO.InvalidDataException]::new("$Context must be a JSON object.")
    }

    $actual = @($InputObject.PSObject.Properties | ForEach-Object { $_.Name })
    if ($actual.Count -ne $Name.Count) {
        throw [System.IO.InvalidDataException]::new("$Context has missing or unknown properties.")
    }
    foreach ($propertyName in $Name) {
        if ($actual -cnotcontains $propertyName) {
            throw [System.IO.InvalidDataException]::new(
                "$Context is missing the '$propertyName' property."
            )
        }
    }
}

function Get-ExactPropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Context
    )

    $property = @(
        $InputObject.PSObject.Properties |
            Where-Object { $_.Name -ceq $Name }
    )
    if ($property.Count -ne 1) {
        throw [System.IO.InvalidDataException]::new(
            "$Context is missing the '$Name' property."
        )
    }
    , $property[0].Value
}

function Test-ComplianceInteger {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [object] $Value
    )

    $Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [short] -or
        $Value -is [ushort] -or
        $Value -is [int] -or
        $Value -is [uint] -or
        $Value -is [long] -or
        $Value -is [ulong]
}

function Assert-ComplianceIdentifier {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value,

        [Parameter(Mandatory)]
        [string] $Name
    )

    if ($Value -isnot [string] -or $Value -cnotmatch $script:ComplianceIdentifierPattern) {
        throw [System.IO.InvalidDataException]::new(
            "$Name must match $script:ComplianceIdentifierPattern."
        )
    }
}

function Assert-ComplianceKey {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($Value -isnot [string] -or $Value -cnotmatch $script:ComplianceKeyPattern) {
        throw [System.IO.InvalidDataException]::new(
            "Configuration keys must match $script:ComplianceKeyPattern."
        )
    }
}

function Assert-ComplianceValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value
    )

    if (
        $Value -isnot [string] -or
        $Value.Length -lt 1 -or
        $Value.Length -gt 256 -or
        $Value -cne $Value.Trim() -or
        $Value.Contains('=') -or
        $Value -match '[\p{Cc}]'
    ) {
        throw [System.IO.InvalidDataException]::new(
            'Expected values must be trimmed, control-free strings of 1 through 256 characters without equals signs.'
        )
    }
}

function Assert-ComplianceRelativePath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value
    )

    if (
        $Value -isnot [string] -or
        [string]::IsNullOrEmpty($Value) -or
        $Value.StartsWith('/') -or
        $Value.EndsWith('/') -or
        $Value.Contains('\') -or
        $Value.Contains(':') -or
        $Value -match '[\x00-\x1F\x7F*?\[\]]'
    ) {
        throw [System.IO.InvalidDataException]::new(
            'Relative paths must be provider-independent, non-rooted paths using forward slashes.'
        )
    }

    $segments = @($Value.Split('/'))
    if ($segments.Count -lt 1 -or $segments.Count -gt 16) {
        throw [System.IO.InvalidDataException]::new(
            'Relative paths must contain 1 through 16 segments.'
        )
    }
    foreach ($segment in $segments) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -in '.', '..') {
            throw [System.IO.InvalidDataException]::new(
                'Relative path segments must be non-empty and cannot be dot segments.'
            )
        }
    }
}

function ConvertTo-NormalizedRule {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [switch] $Json
    )

    $names = if ($Json) {
        @{
            RuleId = 'ruleId'
            Kind = 'kind'
            RelativePath = 'relativePath'
            Remediation = 'remediation'
            Key = 'key'
            ExpectedValue = 'expectedValue'
            Tool = 'tool'
            MinimumVersion = 'minimumVersion'
        }
    }
    else {
        @{
            RuleId = 'RuleId'
            Kind = 'Kind'
            RelativePath = 'RelativePath'
            Remediation = 'Remediation'
            Key = 'Key'
            ExpectedValue = 'ExpectedValue'
            Tool = 'Tool'
            MinimumVersion = 'MinimumVersion'
        }
    }

    $context = 'Policy rule'
    $ruleId = Get-ExactPropertyValue -InputObject $InputObject -Name $names.RuleId -Context $context
    $kind = Get-ExactPropertyValue -InputObject $InputObject -Name $names.Kind -Context $context
    Assert-ComplianceIdentifier -Value $ruleId -Name 'ruleId'
    if ($kind -isnot [string]) {
        throw [System.IO.InvalidDataException]::new('Rule kind must be a string.')
    }

    $normalized = switch ($kind) {
        'DirectoryExists' {
            Assert-ExactPropertySet -InputObject $InputObject -Name @(
                $names.RuleId
                $names.Kind
                $names.RelativePath
                $names.Remediation
            ) -Context $context
            $relativePath = Get-ExactPropertyValue `
                -InputObject $InputObject `
                -Name $names.RelativePath `
                -Context $context
            $remediation = Get-ExactPropertyValue `
                -InputObject $InputObject `
                -Name $names.Remediation `
                -Context $context
            Assert-ComplianceRelativePath -Value $relativePath
            if ($remediation -isnot [string] -or $remediation -cne 'Create') {
                throw [System.IO.InvalidDataException]::new(
                    'DirectoryExists remediation must be Create.'
                )
            }
            [pscustomobject] [ordered] @{
                RuleId = $ruleId
                Kind = $kind
                RelativePath = $relativePath
                Remediation = $remediation
            }
        }
        'FileSetting' {
            Assert-ExactPropertySet -InputObject $InputObject -Name @(
                $names.RuleId
                $names.Kind
                $names.RelativePath
                $names.Key
                $names.ExpectedValue
                $names.Remediation
            ) -Context $context
            $relativePath = Get-ExactPropertyValue `
                -InputObject $InputObject `
                -Name $names.RelativePath `
                -Context $context
            $key = Get-ExactPropertyValue -InputObject $InputObject -Name $names.Key -Context $context
            $expectedValue = Get-ExactPropertyValue `
                -InputObject $InputObject `
                -Name $names.ExpectedValue `
                -Context $context
            $remediation = Get-ExactPropertyValue `
                -InputObject $InputObject `
                -Name $names.Remediation `
                -Context $context
            Assert-ComplianceRelativePath -Value $relativePath
            Assert-ComplianceKey -Value $key
            Assert-ComplianceValue -Value $expectedValue
            if ($remediation -isnot [string] -or $remediation -cne 'Set') {
                throw [System.IO.InvalidDataException]::new(
                    'FileSetting remediation must be Set.'
                )
            }
            [pscustomobject] [ordered] @{
                RuleId = $ruleId
                Kind = $kind
                RelativePath = $relativePath
                Key = $key
                ExpectedValue = $expectedValue
                Remediation = $remediation
            }
        }
        'ToolVersion' {
            Assert-ExactPropertySet -InputObject $InputObject -Name @(
                $names.RuleId
                $names.Kind
                $names.Tool
                $names.MinimumVersion
                $names.Remediation
            ) -Context $context
            $tool = Get-ExactPropertyValue -InputObject $InputObject -Name $names.Tool -Context $context
            $minimumVersion = Get-ExactPropertyValue `
                -InputObject $InputObject `
                -Name $names.MinimumVersion `
                -Context $context
            $remediation = Get-ExactPropertyValue `
                -InputObject $InputObject `
                -Name $names.Remediation `
                -Context $context
            if ($tool -isnot [string] -or $tool -cne 'pwsh') {
                throw [System.IO.InvalidDataException]::new('ToolVersion tool must be pwsh.')
            }
            if ($minimumVersion -isnot [string]) {
                throw [System.IO.InvalidDataException]::new(
                    'ToolVersion minimumVersion must be a version string.'
                )
            }
            $parsedVersion = [version] '0.0'
            if (-not [version]::TryParse($minimumVersion, [ref] $parsedVersion)) {
                throw [System.IO.InvalidDataException]::new(
                    'ToolVersion minimumVersion is invalid.'
                )
            }
            if ($remediation -isnot [string] -or $remediation -cne 'None') {
                throw [System.IO.InvalidDataException]::new(
                    'ToolVersion remediation must be None.'
                )
            }
            [pscustomobject] [ordered] @{
                RuleId = $ruleId
                Kind = $kind
                Tool = $tool
                MinimumVersion = $parsedVersion.ToString()
                Remediation = $remediation
            }
        }
        default {
            throw [System.IO.InvalidDataException]::new("Unknown rule kind '$kind'.")
        }
    }
    $normalized.PSObject.TypeNames.Insert(0, 'ComplianceAudit.Rule')
    $normalized
}

function ConvertTo-NormalizedPolicy {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [switch] $Json
    )

    if (-not $Json -and $InputObject.PSObject.TypeNames -cnotcontains 'ComplianceAudit.Policy') {
        throw [System.IO.InvalidDataException]::new(
            'Policy must be a ComplianceAudit.Policy object returned by Import-CompliancePolicy.'
        )
    }

    $schemaName = if ($Json) { 'schemaVersion' } else { 'SchemaVersion' }
    $policyIdName = if ($Json) { 'policyId' } else { 'PolicyId' }
    $rulesName = if ($Json) { 'rules' } else { 'Rules' }
    Assert-ExactPropertySet `
        -InputObject $InputObject `
        -Name @($schemaName, $policyIdName, $rulesName) `
        -Context 'Policy'

    $schemaVersion = Get-ExactPropertyValue `
        -InputObject $InputObject `
        -Name $schemaName `
        -Context 'Policy'
    if (-not (Test-ComplianceInteger -Value $schemaVersion)) {
        throw [System.IO.InvalidDataException]::new('schemaVersion must be an integer.')
    }
    if ([long] $schemaVersion -ne 1) {
        throw [System.NotSupportedException]::new(
            "Unsupported compliance policy schemaVersion '$schemaVersion'."
        )
    }

    $policyId = Get-ExactPropertyValue `
        -InputObject $InputObject `
        -Name $policyIdName `
        -Context 'Policy'
    Assert-ComplianceIdentifier -Value $policyId -Name 'policyId'

    $rawRules = Get-ExactPropertyValue `
        -InputObject $InputObject `
        -Name $rulesName `
        -Context 'Policy'
    if ($null -eq $rawRules -or $rawRules -isnot [System.Array]) {
        throw [System.IO.InvalidDataException]::new('rules must be a JSON array.')
    }
    if ($rawRules.Count -lt 1 -or $rawRules.Count -gt 100) {
        throw [System.IO.InvalidDataException]::new('rules must contain 1 through 100 entries.')
    }

    $seenRuleIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    $normalizedRules = foreach ($rawRule in $rawRules) {
        if ($null -eq $rawRule) {
            throw [System.IO.InvalidDataException]::new('rules cannot contain null entries.')
        }
        $normalizedRule = ConvertTo-NormalizedRule -InputObject $rawRule -Json:$Json
        if (-not $seenRuleIds.Add($normalizedRule.RuleId)) {
            throw [System.IO.InvalidDataException]::new(
                "Duplicate ruleId '$($normalizedRule.RuleId)'."
            )
        }
        $normalizedRule
    }

    $policy = [pscustomobject] [ordered] @{
        SchemaVersion = 1
        PolicyId = $policyId
        Rules = @($normalizedRules)
    }
    $policy.PSObject.TypeNames.Insert(0, 'ComplianceAudit.Policy')
    $policy
}

function Test-PathWithinRoot {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [string] $CandidatePath
    )

    $relative = [System.IO.Path]::GetRelativePath($RootPath, $CandidatePath)
    if ([System.IO.Path]::IsPathRooted($relative)) {
        return $false
    }
    if ($relative -eq '..') {
        return $false
    }
    $parentPrefix = '..' + [System.IO.Path]::DirectorySeparatorChar
    -not $relative.StartsWith($parentPrefix, [System.StringComparison]::Ordinal)
}

function Resolve-DefaultRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (-not $item.PSIsContainer -or $item.PSProvider.Name -cne 'FileSystem') {
        throw [System.ArgumentException]::new('RootPath must resolve to one filesystem container.')
    }

    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        $resolved = $item.ResolveLinkTarget($true)
        if ($null -eq $resolved -or -not $resolved.PSIsContainer) {
            throw [System.IO.IOException]::new('RootPath is an unresolved filesystem link.')
        }
        return [System.IO.Path]::GetFullPath($resolved.FullName)
    }
    [System.IO.Path]::GetFullPath($item.FullName)
}

function Resolve-DefaultChildPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $RootPath,

        [Parameter(Mandatory)]
        [string] $RelativePath,

        [Parameter(Mandatory)]
        [bool] $ForWrite
    )

    $null = $ForWrite
    $root = [System.IO.Path]::GetFullPath($RootPath)
    $nativeRelativePath = $RelativePath.Replace(
        [char] '/',
        [System.IO.Path]::DirectorySeparatorChar
    )
    $candidate = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($root, $nativeRelativePath)
    )
    if (-not (Test-PathWithinRoot -RootPath $root -CandidatePath $candidate)) {
        throw [System.UnauthorizedAccessException]::new(
            'Resolved path is outside the target root.'
        )
    }

    $current = $root
    foreach ($segment in $RelativePath.Split('/')) {
        $current = [System.IO.Path]::Combine($current, $segment)
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if (
            $null -ne $item -and
            ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        ) {
            $resolved = $item.ResolveLinkTarget($true)
            if (
                $null -eq $resolved -or
                -not (Test-PathWithinRoot -RootPath $root -CandidatePath $resolved.FullName)
            ) {
                throw [System.UnauthorizedAccessException]::new(
                    'A filesystem link would escape the target root.'
                )
            }
        }
    }
    $candidate
}

function Get-DefaultPathKind {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) {
        return 'Missing'
    }
    if ($item.PSIsContainer) {
        return 'Directory'
    }
    if ($item -is [System.IO.FileInfo]) {
        return 'File'
    }
    'Other'
}

function Read-DefaultFile {
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item -isnot [System.IO.FileInfo]) {
        throw [System.IO.InvalidDataException]::new('Configuration path is not a file.')
    }
    if ($item.Length -gt $script:MaximumConfigurationBytes) {
        throw [System.IO.InvalidDataException]::new('Configuration file exceeds 1 MiB.')
    }
    , [System.IO.File]::ReadAllBytes($item.FullName)
}

function Write-DefaultFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Content
    )

    $parent = [System.IO.Path]::GetDirectoryName($Path)
    if ([string]::IsNullOrEmpty($parent) -or -not [System.IO.Directory]::Exists($parent)) {
        throw [System.IO.DirectoryNotFoundException]::new(
            'The configuration file parent directory does not exist.'
        )
    }

    $candidate = [System.IO.Path]::Combine(
        $parent,
        '.compliance-' + [guid]::NewGuid().ToString('N') + '.tmp'
    )
    try {
        [System.IO.File]::WriteAllText($candidate, $Content, $script:Utf8NoBom)
        [System.IO.File]::Move($candidate, $Path, $true)
    }
    finally {
        if ([System.IO.File]::Exists($candidate)) {
            [System.IO.File]::Delete($candidate)
        }
    }
}

function Get-DefaultToolVersion {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param()

    $command = Get-Command -Name pwsh -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $command.Source
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $startInfo.ArgumentList.Add('-NoLogo')
    $startInfo.ArgumentList.Add('-NoProfile')
    $startInfo.ArgumentList.Add('-NonInteractive')
    $startInfo.ArgumentList.Add('-Command')
    $startInfo.ArgumentList.Add(
        '[Console]::Out.Write($PSVersionTable.PSVersion.ToString())'
    )

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw [System.InvalidOperationException]::new('Could not start the pwsh probe.')
        }
        $standardOutput = $process.StandardOutput.ReadToEndAsync()
        $standardError = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $output = $standardOutput.GetAwaiter().GetResult()
        $null = $standardError.GetAwaiter().GetResult()
        [pscustomobject] [ordered] @{
            ExitCode = $process.ExitCode
            Output = $output
        }
    }
    finally {
        $process.Dispose()
    }
}

function Get-DefaultComplianceAdapter {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param()

    [pscustomobject] [ordered] @{
        ResolveRoot = {
            param($Path)
            Resolve-DefaultRoot -Path $Path
        }
        ResolvePath = {
            param($RootPath, $RelativePath, $ForWrite)
            Resolve-DefaultChildPath `
                -RootPath $RootPath `
                -RelativePath $RelativePath `
                -ForWrite $ForWrite
        }
        GetPathKind = {
            param($Path)
            Get-DefaultPathKind -Path $Path
        }
        ReadFile = {
            param($Path)
            Read-DefaultFile -Path $Path
        }
        WriteFile = {
            param($Path, $Content)
            Write-DefaultFile -Path $Path -Content $Content
        }
        CreateDirectory = {
            param($Path)
            $null = [System.IO.Directory]::CreateDirectory($Path)
        }
        GetToolVersion = {
            Get-DefaultToolVersion
        }
    }
}

function Get-ComplianceAdapterOperation {
    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory)]
        [object] $Adapter,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $value = if ($Adapter -is [System.Collections.IDictionary]) {
        if (-not $Adapter.Contains($Name)) {
            throw [System.ArgumentException]::new("Adapter operation '$Name' is missing.")
        }
        $Adapter[$Name]
    }
    else {
        $property = $Adapter.PSObject.Properties[$Name]
        if ($null -eq $property) {
            throw [System.ArgumentException]::new("Adapter operation '$Name' is missing.")
        }
        $property.Value
    }
    if ($value -isnot [scriptblock]) {
        throw [System.ArgumentException]::new(
            "Adapter operation '$Name' must be a script block."
        )
    }
    $value
}

function Resolve-ComplianceAdapter {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [AllowNull()]
        [object] $Adapter
    )

    $source = if ($null -eq $Adapter) {
        Get-DefaultComplianceAdapter
    }
    else {
        $Adapter
    }

    $state = if ($source -is [System.Collections.IDictionary]) {
        if ($source.Contains('State')) { $source['State'] } else { $null }
    }
    else {
        $stateProperty = $source.PSObject.Properties['State']
        if ($null -eq $stateProperty) { $null } else { $stateProperty.Value }
    }
    $normalized = [pscustomobject] [ordered] @{
        State = $state
    }
    foreach (
        $name in @(
            'ResolveRoot'
            'ResolvePath'
            'GetPathKind'
            'ReadFile'
            'WriteFile'
            'CreateDirectory'
            'GetToolVersion'
        )
    ) {
        $normalized | Add-Member `
            -MemberType NoteProperty `
            -Name $name `
            -Value (Get-ComplianceAdapterOperation -Adapter $source -Name $name)
    }
    $normalized.PSObject.TypeNames.Insert(0, 'ComplianceAudit.Adapter')
    $normalized
}

function Invoke-ComplianceAdapterOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Adapter,

        [Parameter(Mandatory)]
        [string] $Name,

        [AllowEmptyCollection()]
        [object[]] $ArgumentList = @()
    )

    $operation = $Adapter.PSObject.Properties[$Name].Value
    $arguments = @($ArgumentList)
    if ($null -ne $Adapter.State) {
        $arguments += $Adapter.State
    }
    $output = @(& $operation @arguments)
    if ($output.Count -eq 0) {
        return
    }
    if ($output.Count -eq 1) {
        $output[0]
        return
    }
    $output
}

function ConvertFrom-ComplianceFileContent {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [object] $Content
    )

    if ($null -eq $Content) {
        throw [System.IO.InvalidDataException]::new('The adapter returned no file content.')
    }

    if ($Content -is [string]) {
        if ($script:Utf8Strict.GetByteCount($Content) -gt $script:MaximumConfigurationBytes) {
            throw [System.IO.InvalidDataException]::new('Configuration file exceeds 1 MiB.')
        }
        if ($Content.Length -gt 0 -and $Content[0] -eq [char] 0xFEFF) {
            return $Content.Substring(1)
        }
        return $Content
    }

    $bytes = if ($Content -is [byte[]]) {
        $Content
    }
    elseif ($Content -is [System.Array]) {
        try {
            [byte[]] $Content
        }
        catch {
            throw [System.IO.InvalidDataException]::new(
                'The adapter returned an unsupported file-content value.',
                $_.Exception
            )
        }
    }
    else {
        throw [System.IO.InvalidDataException]::new(
            'The adapter returned an unsupported file-content value.'
        )
    }

    if ($bytes.Length -gt $script:MaximumConfigurationBytes) {
        throw [System.IO.InvalidDataException]::new('Configuration file exceeds 1 MiB.')
    }
    $text = $script:Utf8Strict.GetString($bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char] 0xFEFF) {
        return $text.Substring(1)
    }
    $text
}

function Split-ComplianceConfigurationLine {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $position = 0
    while ($position -lt $Content.Length) {
        $lineStart = $position
        while (
            $position -lt $Content.Length -and
            $Content[$position] -ne "`r" -and
            $Content[$position] -ne "`n"
        ) {
            $position++
        }
        $text = $Content.Substring($lineStart, $position - $lineStart)
        $ending = ''
        if ($position -lt $Content.Length) {
            if (
                $Content[$position] -eq "`r" -and
                $position + 1 -lt $Content.Length -and
                $Content[$position + 1] -eq "`n"
            ) {
                $ending = "`r`n"
                $position += 2
            }
            else {
                $ending = [string] $Content[$position]
                $position++
            }
        }
        [pscustomobject] [ordered] @{
            Text = $text
            Ending = $ending
        }
    }
}

function ConvertFrom-ComplianceConfiguration {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $values = [System.Collections.Generic.Dictionary[string, string]]::new(
        [System.StringComparer]::Ordinal
    )
    $lineIndexes = [System.Collections.Generic.Dictionary[string, int]]::new(
        [System.StringComparer]::Ordinal
    )
    $records = @(Split-ComplianceConfigurationLine -Content $Content)
    for ($index = 0; $index -lt $records.Count; $index++) {
        $text = $records[$index].Text
        $trimmed = $text.Trim()
        if ([string]::IsNullOrEmpty($trimmed) -or $text.TrimStart().StartsWith('#')) {
            continue
        }

        $separatorIndex = $text.IndexOf('=')
        if ($separatorIndex -lt 1) {
            throw [System.IO.InvalidDataException]::new(
                'Configuration file contains a malformed line.'
            )
        }
        $key = $text.Substring(0, $separatorIndex).Trim()
        $value = $text.Substring($separatorIndex + 1).Trim()
        Assert-ComplianceKey -Value $key
        Assert-ComplianceValue -Value $value
        if ($values.ContainsKey($key)) {
            throw [System.IO.InvalidDataException]::new(
                'Configuration file contains a duplicate key.'
            )
        }
        $values.Add($key, $value)
        $lineIndexes.Add($key, $index)
    }

    [pscustomobject] [ordered] @{
        Content = $Content
        Records = $records
        Values = $values
        LineIndexes = $lineIndexes
    }
}

function ConvertTo-ComplianceConfigurationContent {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object] $Configuration,

        [Parameter(Mandatory)]
        [string] $Key,

        [Parameter(Mandatory)]
        [string] $ExpectedValue
    )

    if ($Configuration.LineIndexes.ContainsKey($Key)) {
        $lineIndex = $Configuration.LineIndexes[$Key]
        $parts = for ($index = 0; $index -lt $Configuration.Records.Count; $index++) {
            if ($index -eq $lineIndex) {
                "$Key=$ExpectedValue$($Configuration.Records[$index].Ending)"
            }
            else {
                "$($Configuration.Records[$index].Text)$($Configuration.Records[$index].Ending)"
            }
        }
        return $parts -join ''
    }

    $newline = [System.Environment]::NewLine
    if ([string]::IsNullOrEmpty($Configuration.Content)) {
        return "$Key=$ExpectedValue$newline"
    }
    if (
        $Configuration.Content.EndsWith("`r") -or
        $Configuration.Content.EndsWith("`n")
    ) {
        return "$($Configuration.Content)$Key=$ExpectedValue$newline"
    }
    "$($Configuration.Content)$newline$Key=$ExpectedValue$newline"
}

function ConvertTo-ComplianceFinding {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $PolicyId,

        [Parameter(Mandatory)]
        [object] $Target,

        [Parameter(Mandatory)]
        [object] $Rule,

        [Parameter(Mandatory)]
        [ValidateSet('Compliant', 'NonCompliant', 'Error')]
        [string] $Status,

        [AllowNull()]
        [string] $Observed,

        [AllowNull()]
        [string] $Expected,

        [Parameter(Mandatory)]
        [bool] $CanRemediate,

        [Parameter(Mandatory)]
        [string] $Message
    )

    $findingTarget = [pscustomobject] [ordered] @{
        Name = $Target.Name
        RootPath = $Target.RootPath
    }
    $finding = [pscustomobject] [ordered] @{
        PolicyId = $PolicyId
        Target = $findingTarget
        RuleId = $Rule.RuleId
        RuleKind = $Rule.Kind
        Status = $Status
        Observed = $Observed
        Expected = $Expected
        CanRemediate = $CanRemediate
        Message = $Message
    }
    $finding.PSObject.TypeNames.Insert(0, 'ComplianceAudit.Finding')
    $finding
}

function Invoke-DirectoryComplianceCheck {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $PolicyId,

        [Parameter(Mandatory)]
        [object] $Target,

        [Parameter(Mandatory)]
        [object] $Rule,

        [Parameter(Mandatory)]
        [object] $Adapter,

        [Parameter(Mandatory)]
        [bool] $ForRemediation
    )

    try {
        $path = Invoke-ComplianceAdapterOperation `
            -Adapter $Adapter `
            -Name ResolvePath `
            -ArgumentList @($Target.RootPath, $Rule.RelativePath, $ForRemediation)
        if ($path -isnot [string] -or [string]::IsNullOrWhiteSpace($path)) {
            throw [System.IO.InvalidDataException]::new(
                'The adapter returned an invalid resolved path.'
            )
        }
        $kind = Invoke-ComplianceAdapterOperation `
            -Adapter $Adapter `
            -Name GetPathKind `
            -ArgumentList @($path)
        switch ($kind) {
            'Directory' {
                ConvertTo-ComplianceFinding `
                    -PolicyId $PolicyId `
                    -Target $Target `
                    -Rule $Rule `
                    -Status Compliant `
                    -Observed 'Present' `
                    -Expected 'Present' `
                    -CanRemediate $false `
                    -Message 'required directory exists'
            }
            'Missing' {
                ConvertTo-ComplianceFinding `
                    -PolicyId $PolicyId `
                    -Target $Target `
                    -Rule $Rule `
                    -Status NonCompliant `
                    -Observed 'Missing' `
                    -Expected 'Present' `
                    -CanRemediate $true `
                    -Message 'required directory is missing'
            }
            default {
                ConvertTo-ComplianceFinding `
                    -PolicyId $PolicyId `
                    -Target $Target `
                    -Rule $Rule `
                    -Status Error `
                    -Observed 'Present' `
                    -Expected 'Present' `
                    -CanRemediate $false `
                    -Message 'required directory path is not a directory'
            }
        }
    }
    catch {
        Write-Verbose "Directory observation failed for target '$($Target.Name)', rule '$($Rule.RuleId)'."
        ConvertTo-ComplianceFinding `
            -PolicyId $PolicyId `
            -Target $Target `
            -Rule $Rule `
            -Status Error `
            -Observed $null `
            -Expected 'Present' `
            -CanRemediate $false `
            -Message 'required directory path is unsafe or unavailable'
    }
}

function Invoke-FileComplianceCheck {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $PolicyId,

        [Parameter(Mandatory)]
        [object] $Target,

        [Parameter(Mandatory)]
        [object] $Rule,

        [Parameter(Mandatory)]
        [object] $Adapter,

        [Parameter(Mandatory)]
        [bool] $ForRemediation
    )

    try {
        $path = Invoke-ComplianceAdapterOperation `
            -Adapter $Adapter `
            -Name ResolvePath `
            -ArgumentList @($Target.RootPath, $Rule.RelativePath, $ForRemediation)
        if ($path -isnot [string] -or [string]::IsNullOrWhiteSpace($path)) {
            throw [System.IO.InvalidDataException]::new(
                'The adapter returned an invalid resolved path.'
            )
        }
        $kind = Invoke-ComplianceAdapterOperation `
            -Adapter $Adapter `
            -Name GetPathKind `
            -ArgumentList @($path)
        if ($kind -eq 'Missing') {
            $parent = [System.IO.Path]::GetDirectoryName($path)
            $parentKind = Invoke-ComplianceAdapterOperation `
                -Adapter $Adapter `
                -Name GetPathKind `
                -ArgumentList @($parent)
            return ConvertTo-ComplianceFinding `
                -PolicyId $PolicyId `
                -Target $Target `
                -Rule $Rule `
                -Status NonCompliant `
                -Observed $null `
                -Expected $Rule.ExpectedValue `
                -CanRemediate ($parentKind -eq 'Directory') `
                -Message 'configuration file is missing'
        }
        if ($kind -ne 'File') {
            return ConvertTo-ComplianceFinding `
                -PolicyId $PolicyId `
                -Target $Target `
                -Rule $Rule `
                -Status Error `
                -Observed $null `
                -Expected $Rule.ExpectedValue `
                -CanRemediate $false `
                -Message 'configuration path is not a file'
        }

        $rawContent = Invoke-ComplianceAdapterOperation `
            -Adapter $Adapter `
            -Name ReadFile `
            -ArgumentList @($path)
        $content = ConvertFrom-ComplianceFileContent -Content $rawContent
        $configuration = ConvertFrom-ComplianceConfiguration -Content $content
        if (-not $configuration.Values.ContainsKey($Rule.Key)) {
            return ConvertTo-ComplianceFinding `
                -PolicyId $PolicyId `
                -Target $Target `
                -Rule $Rule `
                -Status NonCompliant `
                -Observed $null `
                -Expected $Rule.ExpectedValue `
                -CanRemediate $true `
                -Message 'configuration key is missing'
        }

        $observed = $configuration.Values[$Rule.Key]
        if ($observed -ceq $Rule.ExpectedValue) {
            return ConvertTo-ComplianceFinding `
                -PolicyId $PolicyId `
                -Target $Target `
                -Rule $Rule `
                -Status Compliant `
                -Observed $observed `
                -Expected $Rule.ExpectedValue `
                -CanRemediate $false `
                -Message 'configuration value matches'
        }
        ConvertTo-ComplianceFinding `
            -PolicyId $PolicyId `
            -Target $Target `
            -Rule $Rule `
            -Status NonCompliant `
            -Observed $observed `
            -Expected $Rule.ExpectedValue `
            -CanRemediate $true `
            -Message 'configuration value differs'
    }
    catch {
        Write-Verbose "File observation failed for target '$($Target.Name)', rule '$($Rule.RuleId)'."
        ConvertTo-ComplianceFinding `
            -PolicyId $PolicyId `
            -Target $Target `
            -Rule $Rule `
            -Status Error `
            -Observed $null `
            -Expected $Rule.ExpectedValue `
            -CanRemediate $false `
            -Message 'configuration file is invalid, unsafe, or unavailable'
    }
}

function Invoke-ToolComplianceCheck {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $PolicyId,

        [Parameter(Mandatory)]
        [object] $Target,

        [Parameter(Mandatory)]
        [object] $Rule,

        [Parameter(Mandatory)]
        [object] $Adapter
    )

    try {
        $probe = Invoke-ComplianceAdapterOperation `
            -Adapter $Adapter `
            -Name GetToolVersion
        if ($probe -isnot [System.Management.Automation.PSCustomObject]) {
            throw [System.IO.InvalidDataException]::new(
                'The tool adapter returned an invalid result.'
            )
        }
        Assert-ExactPropertySet `
            -InputObject $probe `
            -Name @('ExitCode', 'Output') `
            -Context 'Tool probe'
        if (-not (Test-ComplianceInteger -Value $probe.ExitCode) -or [int] $probe.ExitCode -ne 0) {
            throw [System.InvalidOperationException]::new('The pwsh version probe failed.')
        }
        if ($probe.Output -isnot [string]) {
            throw [System.IO.InvalidDataException]::new(
                'The pwsh version probe returned invalid output.'
            )
        }
        $observedVersion = [version] '0.0'
        if (-not [version]::TryParse($probe.Output.Trim(), [ref] $observedVersion)) {
            throw [System.IO.InvalidDataException]::new(
                'The pwsh version probe returned invalid output.'
            )
        }
        $minimumVersion = [version] $Rule.MinimumVersion
        $status = if ($observedVersion -ge $minimumVersion) {
            'Compliant'
        }
        else {
            'NonCompliant'
        }
        $message = if ($status -eq 'Compliant') {
            'PowerShell version meets the minimum'
        }
        else {
            'PowerShell version is below the minimum'
        }
        ConvertTo-ComplianceFinding `
            -PolicyId $PolicyId `
            -Target $Target `
            -Rule $Rule `
            -Status $status `
            -Observed $observedVersion.ToString() `
            -Expected $minimumVersion.ToString() `
            -CanRemediate $false `
            -Message $message
    }
    catch {
        Write-Verbose "Tool observation failed for target '$($Target.Name)', rule '$($Rule.RuleId)'."
        ConvertTo-ComplianceFinding `
            -PolicyId $PolicyId `
            -Target $Target `
            -Rule $Rule `
            -Status Error `
            -Observed $null `
            -Expected ([version] $Rule.MinimumVersion).ToString() `
            -CanRemediate $false `
            -Message 'PowerShell version could not be observed'
    }
}

function Invoke-ComplianceRule {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string] $PolicyId,

        [Parameter(Mandatory)]
        [object] $Target,

        [Parameter(Mandatory)]
        [object] $Rule,

        [Parameter(Mandatory)]
        [object] $Adapter,

        [bool] $ForRemediation = $false
    )

    switch ($Rule.Kind) {
        'DirectoryExists' {
            Invoke-DirectoryComplianceCheck `
                -PolicyId $PolicyId `
                -Target $Target `
                -Rule $Rule `
                -Adapter $Adapter `
                -ForRemediation $ForRemediation
        }
        'FileSetting' {
            Invoke-FileComplianceCheck `
                -PolicyId $PolicyId `
                -Target $Target `
                -Rule $Rule `
                -Adapter $Adapter `
                -ForRemediation $ForRemediation
        }
        'ToolVersion' {
            Invoke-ToolComplianceCheck `
                -PolicyId $PolicyId `
                -Target $Target `
                -Rule $Rule `
                -Adapter $Adapter
        }
    }
}

function ConvertTo-NormalizedTarget {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [object] $Adapter
    )

    if ($InputObject -isnot [System.Management.Automation.PSCustomObject]) {
        throw [System.ArgumentException]::new('Target must be an object with Name and RootPath.')
    }
    $nameProperty = $InputObject.PSObject.Properties['Name']
    $rootProperty = $InputObject.PSObject.Properties['RootPath']
    if ($null -eq $nameProperty -or $null -eq $rootProperty) {
        throw [System.ArgumentException]::new('Target must contain Name and RootPath properties.')
    }
    if (
        $nameProperty.MemberType -ne [System.Management.Automation.PSMemberTypes]::NoteProperty -or
        $rootProperty.MemberType -ne [System.Management.Automation.PSMemberTypes]::NoteProperty
    ) {
        throw [System.ArgumentException]::new(
            'Target Name and RootPath must be note properties.'
        )
    }
    Assert-ComplianceIdentifier -Value $nameProperty.Value -Name 'Target Name'
    if (
        $rootProperty.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace($rootProperty.Value)
    ) {
        throw [System.ArgumentException]::new('Target RootPath must be a non-empty string.')
    }

    $resolvedRoot = Invoke-ComplianceAdapterOperation `
        -Adapter $Adapter `
        -Name ResolveRoot `
        -ArgumentList @($rootProperty.Value)
    if ($resolvedRoot -isnot [string] -or [string]::IsNullOrWhiteSpace($resolvedRoot)) {
        throw [System.ArgumentException]::new(
            'Target RootPath did not resolve to one container.'
        )
    }
    [pscustomobject] [ordered] @{
        Name = $nameProperty.Value
        RootPath = $resolvedRoot
    }
}

function Invoke-ComplianceAuditParallel {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object[]] $WorkItem,

        [Parameter(Mandatory)]
        [object] $Adapter,

        [Parameter(Mandatory)]
        [bool] $UseDefaultAdapter,

        [Parameter(Mandatory)]
        [ValidateRange(2, 32)]
        [int] $ThrottleLimit
    )

    $pool = [runspacefactory]::CreateRunspacePool(1, $ThrottleLimit)
    $tasks = [System.Collections.Generic.List[object]]::new()
    $adapterDefinition = if ($UseDefaultAdapter) {
        $null
    }
    else {
        [pscustomobject] [ordered] @{
            State = $Adapter.State
            ResolveRoot = $Adapter.ResolveRoot.ToString()
            ResolvePath = $Adapter.ResolvePath.ToString()
            GetPathKind = $Adapter.GetPathKind.ToString()
            ReadFile = $Adapter.ReadFile.ToString()
            WriteFile = $Adapter.WriteFile.ToString()
            CreateDirectory = $Adapter.CreateDirectory.ToString()
            GetToolVersion = $Adapter.GetToolVersion.ToString()
        }
    }
    try {
        $pool.Open()
        foreach ($item in $WorkItem) {
            $powerShell = [powershell]::Create()
            $powerShell.RunspacePool = $pool
            $null = $powerShell.AddScript(@'
param($ModulePath, $Target, $Policy, $RuleId, $AdapterDefinition)
Import-Module -Name $ModulePath -Force -ErrorAction Stop
$parameters = @{
    Policy = $Policy
    RuleId = $RuleId
    ThrottleLimit = 1
}
if ($null -ne $AdapterDefinition) {
    $workerAdapter = [pscustomobject]@{
        State = $AdapterDefinition.State
        ResolveRoot = [scriptblock]::Create($AdapterDefinition.ResolveRoot)
        ResolvePath = [scriptblock]::Create($AdapterDefinition.ResolvePath)
        GetPathKind = [scriptblock]::Create($AdapterDefinition.GetPathKind)
        ReadFile = [scriptblock]::Create($AdapterDefinition.ReadFile)
        WriteFile = [scriptblock]::Create($AdapterDefinition.WriteFile)
        CreateDirectory = [scriptblock]::Create($AdapterDefinition.CreateDirectory)
        GetToolVersion = [scriptblock]::Create($AdapterDefinition.GetToolVersion)
    }
    $parameters.Adapter = $workerAdapter
}
$Target | Test-Compliance @parameters
'@)
            $null = $powerShell.AddArgument($script:ComplianceModulePath)
            $null = $powerShell.AddArgument($item.Target)
            $null = $powerShell.AddArgument($item.Policy)
            $null = $powerShell.AddArgument($item.Rule.RuleId)
            $null = $powerShell.AddArgument($adapterDefinition)
            try {
                $handle = $powerShell.BeginInvoke()
                $tasks.Add([pscustomobject] @{
                    PowerShell = $powerShell
                    Handle = $handle
                    WorkItem = $item
                    Disposed = $false
                })
            }
            catch {
                $powerShell.Dispose()
                throw
            }
        }

        foreach ($task in $tasks) {
            try {
                $result = @($task.PowerShell.EndInvoke($task.Handle))
                if ($result.Count -ne 1) {
                    throw [System.InvalidOperationException]::new(
                        'An audit worker did not return exactly one finding.'
                    )
                }
                $result[0]
            }
            catch {
                ConvertTo-ComplianceFinding `
                    -PolicyId $task.WorkItem.PolicyId `
                    -Target $task.WorkItem.Target `
                    -Rule $task.WorkItem.Rule `
                    -Status Error `
                    -Observed $null `
                    -Expected $null `
                    -CanRemediate $false `
                    -Message 'audit worker failed'
            }
            finally {
                $task.PowerShell.Dispose()
                $task.Disposed = $true
            }
        }
    }
    finally {
        foreach ($task in $tasks) {
            if (-not $task.Disposed) {
                $task.PowerShell.Dispose()
                $task.Disposed = $true
            }
        }
        $pool.Dispose()
    }
}

function ConvertTo-NormalizedFinding {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object] $InputObject
    )

    if ($InputObject.PSObject.TypeNames -cnotcontains 'ComplianceAudit.Finding') {
        throw [System.ArgumentException]::new(
            'Finding must be a ComplianceAudit.Finding object.'
        )
    }
    Assert-ExactPropertySet -InputObject $InputObject -Name @(
        'PolicyId'
        'Target'
        'RuleId'
        'RuleKind'
        'Status'
        'Observed'
        'Expected'
        'CanRemediate'
        'Message'
    ) -Context 'Finding'
    Assert-ComplianceIdentifier -Value $InputObject.PolicyId -Name 'Finding PolicyId'
    Assert-ComplianceIdentifier -Value $InputObject.RuleId -Name 'Finding RuleId'
    if ($InputObject.RuleKind -notin 'DirectoryExists', 'FileSetting', 'ToolVersion') {
        throw [System.ArgumentException]::new('Finding RuleKind is invalid.')
    }
    if ($InputObject.Status -notin 'Compliant', 'NonCompliant', 'Error') {
        throw [System.ArgumentException]::new('Finding Status is invalid.')
    }
    if ($InputObject.CanRemediate -isnot [bool]) {
        throw [System.ArgumentException]::new('Finding CanRemediate must be Boolean.')
    }
    if ($InputObject.Message -isnot [string]) {
        throw [System.ArgumentException]::new('Finding Message must be a string.')
    }
    if ($InputObject.Target -isnot [System.Management.Automation.PSCustomObject]) {
        throw [System.ArgumentException]::new('Finding Target is invalid.')
    }
    Assert-ExactPropertySet `
        -InputObject $InputObject.Target `
        -Name @('Name', 'RootPath') `
        -Context 'Finding Target'
    Assert-ComplianceIdentifier -Value $InputObject.Target.Name -Name 'Finding Target Name'
    if (
        $InputObject.Target.RootPath -isnot [string] -or
        [string]::IsNullOrWhiteSpace($InputObject.Target.RootPath)
    ) {
        throw [System.ArgumentException]::new('Finding Target RootPath is invalid.')
    }

    $finding = [pscustomobject] [ordered] @{
        PolicyId = $InputObject.PolicyId
        Target = [pscustomobject] [ordered] @{
            Name = $InputObject.Target.Name
            RootPath = $InputObject.Target.RootPath
        }
        RuleId = $InputObject.RuleId
        RuleKind = $InputObject.RuleKind
        Status = $InputObject.Status
        Observed = if ($null -eq $InputObject.Observed) { $null } else { [string] $InputObject.Observed }
        Expected = if ($null -eq $InputObject.Expected) { $null } else { [string] $InputObject.Expected }
        CanRemediate = $InputObject.CanRemediate
        Message = $InputObject.Message
    }
    $finding.PSObject.TypeNames.Insert(0, 'ComplianceAudit.Finding')
    $finding
}

function Test-ComplianceShouldProcess {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSShouldProcess',
        '',
        Justification = 'Delegates approval to the owning public cmdlet.'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet] $Cmdlet,

        [Parameter(Mandatory)]
        [string] $Target,

        [Parameter(Mandatory)]
        [string] $Action
    )

    $Cmdlet.ShouldProcess($Target, $Action)
}

function Resolve-ComplianceReportPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $provider = $null
    $drive = $null
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $Path,
        [ref] $provider,
        [ref] $drive
    )
    if ($provider.Name -cne 'FileSystem') {
        throw [System.ArgumentException]::new('Report Path must use the FileSystem provider.')
    }
    $fullPath = [System.IO.Path]::GetFullPath($resolved)
    if ([System.IO.Directory]::Exists($fullPath)) {
        throw [System.ArgumentException]::new('Report Path cannot be a directory.')
    }
    $parent = [System.IO.Path]::GetDirectoryName($fullPath)
    if ([string]::IsNullOrEmpty($parent) -or -not [System.IO.Directory]::Exists($parent)) {
        throw [System.IO.DirectoryNotFoundException]::new(
            'Report parent directory does not exist.'
        )
    }
    $fullPath
}

function Write-ComplianceReportFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateSet('Json', 'Csv')]
        [string] $Format,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Row
    )

    $parent = [System.IO.Path]::GetDirectoryName($Path)
    $candidate = [System.IO.Path]::Combine(
        $parent,
        '.compliance-report-' + [guid]::NewGuid().ToString('N') + '.tmp'
    )
    try {
        if ($Format -eq 'Json') {
            $document = [ordered] @{
                schemaVersion = 1
                findings = @($Row)
            }
            $content = ConvertTo-Json -InputObject $document -Depth 6
            [System.IO.File]::WriteAllText($candidate, $content, $script:Utf8NoBom)
        }
        elseif ($Row.Count -gt 0) {
            $Row | Export-Csv `
                -LiteralPath $candidate `
                -NoTypeInformation `
                -Encoding utf8
        }
        else {
            $template = [pscustomobject] [ordered] @{
                policyId = ''
                target = ''
                ruleId = ''
                ruleKind = ''
                status = ''
                observed = ''
                expected = ''
                canRemediate = $false
                message = ''
            }
            $header = @($template | ConvertTo-Csv -NoTypeInformation)[0]
            [System.IO.File]::WriteAllText(
                $candidate,
                $header + [System.Environment]::NewLine,
                $script:Utf8NoBom
            )
        }
        [System.IO.File]::Move($candidate, $Path, $true)
    }
    finally {
        if ([System.IO.File]::Exists($candidate)) {
            [System.IO.File]::Delete($candidate)
        }
    }
}

function Import-CompliancePolicy {
    <#
    .SYNOPSIS
    Imports and validates one compliance policy.

    .DESCRIPTION
    Reads exactly one UTF-8 JSON policy object, rejects unsupported or malformed
    data, and returns a normalized ComplianceAudit.Policy object.

    .PARAMETER Path
    The literal path to the UTF-8 JSON policy document.

    .OUTPUTS
    ComplianceAudit.Policy

    .EXAMPLE
    $policy = Import-CompliancePolicy -Path ./policy.json
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($item -isnot [System.IO.FileInfo] -or $item.PSProvider.Name -cne 'FileSystem') {
            throw [System.IO.IOException]::new('Policy Path must identify one filesystem file.')
        }
        $bytes = [System.IO.File]::ReadAllBytes($item.FullName)
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (Get-ComplianceErrorRecord `
                -ErrorId CompliancePolicyReadFailed `
                -Category ReadError `
                -Message 'The compliance policy could not be read.' `
                -TargetObject $Path `
                -InnerException $_.Exception)
        )
    }

    try {
        $json = $script:Utf8Strict.GetString($bytes)
        $decoded = ConvertFrom-Json `
            -InputObject $json `
            -Depth 8 `
            -NoEnumerate `
            -ErrorAction Stop
        $policy = ConvertTo-NormalizedPolicy -InputObject $decoded -Json
        Write-Verbose "Imported compliance policy '$($policy.PolicyId)'."
        $policy
    }
    catch [System.NotSupportedException] {
        $PSCmdlet.ThrowTerminatingError(
            (Get-ComplianceErrorRecord `
                -ErrorId CompliancePolicyUnsupported `
                -Category NotImplemented `
                -Message 'The compliance policy schema version is unsupported.' `
                -TargetObject $Path `
                -InnerException $_.Exception)
        )
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (Get-ComplianceErrorRecord `
                -ErrorId CompliancePolicyInvalid `
                -Category InvalidData `
                -Message 'The compliance policy is invalid.' `
                -TargetObject $Path `
                -InnerException $_.Exception)
        )
    }
}

function Test-Compliance {
    <#
    .SYNOPSIS
    Audits supplied targets against a compliance policy.

    .DESCRIPTION
    Accepts target objects by value or pipeline, validates their explicit roots,
    and emits one ordered ComplianceAudit.Finding per selected target and rule.

    .PARAMETER Target
    One or more target objects with Name and RootPath properties.

    .PARAMETER Policy
    A normalized ComplianceAudit.Policy object.

    .PARAMETER RuleId
    One or more rule IDs to select without changing policy order.

    .PARAMETER ThrottleLimit
    The maximum number of independent audits, from 1 through 32.

    .PARAMETER Adapter
    An optional injected capability object containing ResolveRoot, ResolvePath,
    GetPathKind, ReadFile, WriteFile, CreateDirectory, and GetToolVersion script
    blocks. An optional State property is passed as the final operation argument
    and enables thread-safe shared test state during throttled auditing.

    .OUTPUTS
    ComplianceAudit.Finding

    .EXAMPLE
    $targets | Test-Compliance -Policy $policy

    .EXAMPLE
    Test-Compliance -Target $targets -Policy $policy -RuleId safe-mode -ThrottleLimit 4
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [object] $Target,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Policy,

        [ValidateNotNullOrEmpty()]
        [string[]] $RuleId,

        [ValidateRange(1, 32)]
        [int] $ThrottleLimit = 1,

        [Parameter(DontShow)]
        [ValidateNotNull()]
        [object] $Adapter
    )

    begin {
        try {
            $normalizedPolicy = ConvertTo-NormalizedPolicy -InputObject $Policy
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (Get-ComplianceErrorRecord `
                    -ErrorId CompliancePolicyInvalid `
                    -Category InvalidData `
                    -Message 'Policy is not a valid normalized compliance policy.' `
                    -TargetObject $Policy `
                    -InnerException $_.Exception)
            )
        }
        try {
            $useDefaultAdapter = -not $PSBoundParameters.ContainsKey('Adapter')
            $normalizedAdapter = Resolve-ComplianceAdapter -Adapter $Adapter
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (Get-ComplianceErrorRecord `
                    -ErrorId ComplianceAdapterFailed `
                    -Category InvalidArgument `
                    -Message 'The compliance adapter is invalid.' `
                    -TargetObject $Adapter `
                    -InnerException $_.Exception)
            )
        }
        $targetInputs = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($inputTarget in @($Target)) {
            $targetInputs.Add($inputTarget)
        }
    }

    end {
        $requestedRules = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::Ordinal
        )
        if ($null -ne $RuleId) {
            foreach ($requestedRuleId in $RuleId) {
                if ([string]::IsNullOrWhiteSpace($requestedRuleId)) {
                    $PSCmdlet.ThrowTerminatingError(
                        (Get-ComplianceErrorRecord `
                            -ErrorId ComplianceRuleNotFound `
                            -Category ObjectNotFound `
                            -Message 'A requested compliance rule was not found.' `
                            -TargetObject $requestedRuleId `
                            -InnerException $null)
                    )
                }
                $null = $requestedRules.Add($requestedRuleId)
            }
        }
        $policyRuleIds = @($normalizedPolicy.Rules | ForEach-Object { $_.RuleId })
        foreach ($requestedRuleId in $requestedRules) {
            if ($policyRuleIds -cnotcontains $requestedRuleId) {
                $PSCmdlet.ThrowTerminatingError(
                    (Get-ComplianceErrorRecord `
                        -ErrorId ComplianceRuleNotFound `
                        -Category ObjectNotFound `
                        -Message "Compliance rule '$requestedRuleId' was not found." `
                        -TargetObject $requestedRuleId `
                        -InnerException $null)
                )
            }
        }
        $selectedRules = if ($requestedRules.Count -eq 0) {
            @($normalizedPolicy.Rules)
        }
        else {
            @($normalizedPolicy.Rules | Where-Object { $requestedRules.Contains($_.RuleId) })
        }

        $normalizedTargets = [System.Collections.Generic.List[object]]::new()
        $targetNames = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::Ordinal
        )
        foreach ($inputTarget in $targetInputs) {
            try {
                $normalizedTarget = ConvertTo-NormalizedTarget `
                    -InputObject $inputTarget `
                    -Adapter $normalizedAdapter
                if (-not $targetNames.Add($normalizedTarget.Name)) {
                    throw [System.ArgumentException]::new(
                        "Duplicate target name '$($normalizedTarget.Name)'."
                    )
                }
                $normalizedTargets.Add($normalizedTarget)
            }
            catch {
                $PSCmdlet.ThrowTerminatingError(
                    (Get-ComplianceErrorRecord `
                        -ErrorId ComplianceTargetInvalid `
                        -Category InvalidArgument `
                        -Message 'A compliance target is invalid.' `
                        -TargetObject $inputTarget `
                        -InnerException $_.Exception)
                )
            }
        }

        $workItems = [System.Collections.Generic.List[object]]::new()
        foreach ($normalizedTarget in $normalizedTargets) {
            foreach ($selectedRule in $selectedRules) {
                $workItems.Add([pscustomobject] @{
                    PolicyId = $normalizedPolicy.PolicyId
                    Policy = $normalizedPolicy
                    Target = $normalizedTarget
                    Rule = $selectedRule
                })
            }
        }

        if ($ThrottleLimit -eq 1) {
            foreach ($workItem in $workItems) {
                Invoke-ComplianceRule `
                    -PolicyId $workItem.PolicyId `
                    -Target $workItem.Target `
                    -Rule $workItem.Rule `
                    -Adapter $normalizedAdapter
            }
        }
        elseif ($workItems.Count -gt 0) {
            Invoke-ComplianceAuditParallel `
                -WorkItem @($workItems) `
                -Adapter $normalizedAdapter `
                -UseDefaultAdapter $useDefaultAdapter `
                -ThrottleLimit $ThrottleLimit
        }
    }
}

function Repair-Compliance {
    <#
    .SYNOPSIS
    Repairs remediable noncompliant findings.

    .DESCRIPTION
    Accepts ComplianceAudit.Finding objects, re-observes current state, and
    performs at most one idempotent DirectoryExists or FileSetting mutation
    through ShouldProcess. ToolVersion findings are audit-only.

    .PARAMETER Finding
    A ComplianceAudit.Finding object to consider for remediation.

    .PARAMETER Policy
    The normalized policy that produced the finding.

    .PARAMETER Adapter
    An optional injected capability object with the same operations accepted by
    Test-Compliance.

    .OUTPUTS
    ComplianceAudit.RemediationResult

    .EXAMPLE
    $findings | Repair-Compliance -Policy $policy -WhatIf

    .EXAMPLE
    $findings | Repair-Compliance -Policy $policy -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [object] $Finding,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object] $Policy,

        [Parameter(DontShow)]
        [ValidateNotNull()]
        [object] $Adapter
    )

    begin {
        try {
            $normalizedPolicy = ConvertTo-NormalizedPolicy -InputObject $Policy
            $normalizedAdapter = Resolve-ComplianceAdapter -Adapter $Adapter
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (Get-ComplianceErrorRecord `
                    -ErrorId ComplianceFindingInvalid `
                    -Category InvalidArgument `
                    -Message 'Repair setup is invalid.' `
                    -TargetObject $Policy `
                    -InnerException $_.Exception)
            )
        }
    }

    process {
        foreach ($inputFinding in @($Finding)) {
            try {
                $normalizedFinding = ConvertTo-NormalizedFinding -InputObject $inputFinding
                if ($normalizedFinding.PolicyId -cne $normalizedPolicy.PolicyId) {
                    throw [System.ArgumentException]::new(
                        'Finding PolicyId does not match the supplied policy.'
                    )
                }
                $rule = @(
                    $normalizedPolicy.Rules |
                        Where-Object RuleId -CEQ $normalizedFinding.RuleId
                )
                if (
                    $rule.Count -ne 1 -or
                    $rule[0].Kind -cne $normalizedFinding.RuleKind
                ) {
                    throw [System.ArgumentException]::new(
                        'Finding rule does not match the supplied policy.'
                    )
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError(
                    (Get-ComplianceErrorRecord `
                        -ErrorId ComplianceFindingInvalid `
                        -Category InvalidArgument `
                        -Message 'A remediation finding is invalid.' `
                        -TargetObject $inputFinding `
                        -InnerException $_.Exception)
                )
            }

            if ($normalizedFinding.Status -cne 'NonCompliant') {
                continue
            }
            $selectedRule = $rule[0]
            if ($selectedRule.Kind -eq 'ToolVersion') {
                continue
            }

            try {
                $resolvedRoot = Invoke-ComplianceAdapterOperation `
                    -Adapter $normalizedAdapter `
                    -Name ResolveRoot `
                    -ArgumentList @($normalizedFinding.Target.RootPath)
                $currentTarget = [pscustomobject] [ordered] @{
                    Name = $normalizedFinding.Target.Name
                    RootPath = $resolvedRoot
                }
                $before = Invoke-ComplianceRule `
                    -PolicyId $normalizedPolicy.PolicyId `
                    -Target $currentTarget `
                    -Rule $selectedRule `
                    -Adapter $normalizedAdapter `
                    -ForRemediation $true
                if ($before.Status -eq 'Compliant') {
                    continue
                }
                if ($before.Status -eq 'Error' -or -not $before.CanRemediate) {
                    continue
                }

                $shouldProcessTarget = '{0}:{1}' -f (
                    $currentTarget.Name,
                    $selectedRule.RelativePath
                )
                $action = if ($selectedRule.Kind -eq 'DirectoryExists') {
                    'Create required directory'
                }
                else {
                    "Set configuration value $($selectedRule.Key)"
                }
                if (
                    -not (Test-ComplianceShouldProcess `
                        -Cmdlet $PSCmdlet `
                        -Target $shouldProcessTarget `
                        -Action $action)
                ) {
                    continue
                }

                $path = Invoke-ComplianceAdapterOperation `
                    -Adapter $normalizedAdapter `
                    -Name ResolvePath `
                    -ArgumentList @(
                        $currentTarget.RootPath
                        $selectedRule.RelativePath
                        $true
                    )
                if ($selectedRule.Kind -eq 'DirectoryExists') {
                    $null = Invoke-ComplianceAdapterOperation `
                        -Adapter $normalizedAdapter `
                        -Name CreateDirectory `
                        -ArgumentList @($path)
                }
                else {
                    $kind = Invoke-ComplianceAdapterOperation `
                        -Adapter $normalizedAdapter `
                        -Name GetPathKind `
                        -ArgumentList @($path)
                    $content = if ($kind -eq 'Missing') {
                        $parent = [System.IO.Path]::GetDirectoryName($path)
                        $parentKind = Invoke-ComplianceAdapterOperation `
                            -Adapter $normalizedAdapter `
                            -Name GetPathKind `
                            -ArgumentList @($parent)
                        if ($parentKind -ne 'Directory') {
                            throw [System.IO.DirectoryNotFoundException]::new(
                                'The configuration parent directory does not exist.'
                            )
                        }
                        "$($selectedRule.Key)=$($selectedRule.ExpectedValue)$([System.Environment]::NewLine)"
                    }
                    elseif ($kind -eq 'File') {
                        $rawContent = Invoke-ComplianceAdapterOperation `
                            -Adapter $normalizedAdapter `
                            -Name ReadFile `
                            -ArgumentList @($path)
                        $text = ConvertFrom-ComplianceFileContent -Content $rawContent
                        $configuration = ConvertFrom-ComplianceConfiguration -Content $text
                        ConvertTo-ComplianceConfigurationContent `
                            -Configuration $configuration `
                            -Key $selectedRule.Key `
                            -ExpectedValue $selectedRule.ExpectedValue
                    }
                    else {
                        throw [System.IO.InvalidDataException]::new(
                            'The configuration path is not a file.'
                        )
                    }
                    $null = Invoke-ComplianceAdapterOperation `
                        -Adapter $normalizedAdapter `
                        -Name WriteFile `
                        -ArgumentList @($path, $content)
                }

                $after = Invoke-ComplianceRule `
                    -PolicyId $normalizedPolicy.PolicyId `
                    -Target $currentTarget `
                    -Rule $selectedRule `
                    -Adapter $normalizedAdapter `
                    -ForRemediation $true
                if ($after.Status -ne 'Compliant') {
                    throw [System.InvalidOperationException]::new(
                        'Remediation did not achieve compliance.'
                    )
                }
                $result = [pscustomobject] [ordered] @{
                    PolicyId = $normalizedPolicy.PolicyId
                    Target = [pscustomobject] [ordered] @{
                        Name = $currentTarget.Name
                        RootPath = $currentTarget.RootPath
                    }
                    RuleId = $selectedRule.RuleId
                    Action = $action
                    Changed = $true
                    Before = $before.Observed
                    After = $after.Observed
                }
                $result.PSObject.TypeNames.Insert(0, 'ComplianceAudit.RemediationResult')
                $result
            }
            catch {
                $PSCmdlet.WriteError(
                    (Get-ComplianceErrorRecord `
                        -ErrorId ComplianceRemediationFailed `
                        -Category WriteError `
                        -Message (
                            "Remediation failed for target '$($normalizedFinding.Target.Name)', rule '$($normalizedFinding.RuleId)'."
                        ) `
                        -TargetObject $normalizedFinding `
                        -InnerException $_.Exception)
                )
            }
        }
    }
}

function Export-ComplianceReport {
    <#
    .SYNOPSIS
    Exports compliance findings as JSON or CSV.

    .DESCRIPTION
    Collects pipeline findings in received order, removes root-path and adapter
    details, and atomically writes deterministic JSON or CSV through
    ShouldProcess.

    .PARAMETER Finding
    A ComplianceAudit.Finding object to include in the report.

    .PARAMETER Path
    The filesystem destination for the report.

    .PARAMETER Format
    The report format: Json or Csv.

    .PARAMETER Force
    Allows replacement of an existing report.

    .OUTPUTS
    None.

    .EXAMPLE
    $findings | Export-ComplianceReport -Path ./report.json -Format Json

    .EXAMPLE
    $findings | Export-ComplianceReport -Path ./report.csv -Format Csv -Force
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNull()]
        [object] $Finding,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateSet('Json', 'Csv')]
        [string] $Format,

        [switch] $Force
    )

    begin {
        $findings = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($PSBoundParameters.ContainsKey('Finding')) {
            foreach ($inputFinding in @($Finding)) {
                try {
                    $findings.Add((ConvertTo-NormalizedFinding -InputObject $inputFinding))
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError(
                        (Get-ComplianceErrorRecord `
                            -ErrorId ComplianceReportWriteFailed `
                            -Category InvalidData `
                            -Message 'A report finding is invalid.' `
                            -TargetObject $inputFinding `
                            -InnerException $_.Exception)
                    )
                }
            }
        }
    }

    end {
        try {
            $resolvedPath = Resolve-ComplianceReportPath -Path $Path
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (Get-ComplianceErrorRecord `
                    -ErrorId ComplianceReportWriteFailed `
                    -Category InvalidArgument `
                    -Message 'The compliance report destination is invalid.' `
                    -TargetObject $Path `
                    -InnerException $_.Exception)
            )
        }
        if ([System.IO.File]::Exists($resolvedPath) -and -not $Force) {
            $PSCmdlet.ThrowTerminatingError(
                (Get-ComplianceErrorRecord `
                    -ErrorId ComplianceReportExists `
                    -Category ResourceExists `
                    -Message 'The compliance report already exists. Use -Force to replace it.' `
                    -TargetObject $Path `
                    -InnerException $null)
            )
        }

        $rows = foreach ($normalizedFinding in $findings) {
            [pscustomobject] [ordered] @{
                policyId = $normalizedFinding.PolicyId
                target = $normalizedFinding.Target.Name
                ruleId = $normalizedFinding.RuleId
                ruleKind = $normalizedFinding.RuleKind
                status = $normalizedFinding.Status
                observed = $normalizedFinding.Observed
                expected = $normalizedFinding.Expected
                canRemediate = $normalizedFinding.CanRemediate
                message = $normalizedFinding.Message
            }
        }
        if (-not $PSCmdlet.ShouldProcess($resolvedPath, "Export compliance report as $Format")) {
            return
        }
        try {
            Write-ComplianceReportFile `
                -Path $resolvedPath `
                -Format $Format `
                -Row @($rows)
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (Get-ComplianceErrorRecord `
                    -ErrorId ComplianceReportWriteFailed `
                    -Category WriteError `
                    -Message 'The compliance report could not be written.' `
                    -TargetObject $Path `
                    -InnerException $_.Exception)
            )
        }
    }
}

Export-ModuleMember -Function @(
    'Import-CompliancePolicy'
    'Test-Compliance'
    'Repair-Compliance'
    'Export-ComplianceReport'
)
