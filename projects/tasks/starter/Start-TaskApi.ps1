#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'SimplySql'; RequiredVersion = '2.2.0.106' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', '',
    Justification = 'The guided starter preserves the server launcher signature.'
)]
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('SQLite', 'Markdown')]
    [string] $Backend,

    [Parameter(Mandatory)]
    [ValidateNotNullOrWhiteSpace()]
    [string] $DataPath,

    [uri] $UriPrefix = 'http://127.0.0.1:8080/'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# M4: import Tasks.psd1, initialize the selected repository, validate a
# loopback-only trailing-slash prefix, then own one HttpListener in try/finally.
# Keep routes thin: decode/validate HTTP input, call the shared module, and map
# domain error IDs to the documented JSON/status contract.
$null = $Backend, $DataPath, $UriPrefix
throw [System.NotImplementedException]::new(
    'Start-TaskApi.ps1 is intentionally incomplete in the Tasks project starter.'
)
