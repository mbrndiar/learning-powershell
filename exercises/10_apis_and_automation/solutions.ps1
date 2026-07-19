#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

# Reference solution for Module 10. Get-ActiveRecord validates the Active flag
# as a real Boolean before trusting it; Get-SearchUri escapes only the query
# value with EscapeDataString, so the URI separators stay intact; Get-RemoteRecord
# wraps a real Invoke-RestMethod call and returns its already-deserialized
# objects. The wrapper is tested offline by mocking Invoke-RestMethod.

Set-StrictMode -Version Latest

function Get-ActiveRecord {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Request)
    foreach ($record in @((& $Request) | ConvertFrom-Json)) {
        $active = $record.PSObject.Properties['Active']
        if ($null -eq $active -or $active.Value -isnot [bool]) {
            throw 'Each record requires a Boolean Active property.'
        }
        if ($active.Value) { $record }
    }
}

function Get-SearchUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            if (-not $_.IsAbsoluteUri -or $_.Scheme -notin @('http', 'https')) {
                throw 'BaseUri must be an absolute HTTP or HTTPS URI.'
            }
            if (-not [string]::IsNullOrEmpty($_.Query)) {
                throw 'BaseUri must not already contain a query string.'
            }
            $true
        })]
        [uri] $BaseUri,

        [Parameter(Mandatory)]
        [ValidateNotNullOrWhiteSpace()]
        [string] $Query,

        [ValidateRange(1, 100)]
        [int] $Page = 1
    )

    $builder = [System.UriBuilder]::new($BaseUri)
    $builder.Query = "q=$([uri]::EscapeDataString($Query))&page=$Page"
    $builder.Uri
}

function Get-RemoteRecord {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)][uri] $Uri,
        [ValidateSet('Get', 'Post', 'Put', 'Delete', 'Patch')][string] $Method = 'Get',
        [ValidateRange(1, 300)][int] $TimeoutSec = 30,
        [ValidateNotNull()][hashtable] $Headers
    )
    $parameters = @{
        Uri = $Uri
        Method = $Method
        TimeoutSec = $TimeoutSec
        ErrorAction = 'Stop'
    }
    if ($PSBoundParameters.ContainsKey('Headers') -and $Headers.Count -gt 0) {
        # Forward headers but never log them; they may carry a token.
        $parameters.Headers = $Headers
    }
    # Invoke-RestMethod already deserializes the JSON body into objects.
    Invoke-RestMethod @parameters
}

Describe 'Get-ActiveRecord' {
    Context 'with an injected request boundary' {
        It 'returns only the active record from a mixed set' {
            $request = { '[{"name":"Ada","active":true},{"name":"Lin","active":false}]' }
            $result = @(Get-ActiveRecord -Request $request)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be 'Ada'
        }
        It 'returns every active record when several are active' {
            $request = { '[{"name":"Ada","active":true},{"name":"Bo","active":true}]' }
            $result = @(Get-ActiveRecord -Request $request)
            $result.name | Should -Be @('Ada', 'Bo')
        }
        It 'returns nothing when no record is active' {
            $request = { '[{"name":"Ada","active":false},{"name":"Lin","active":false}]' }
            @(Get-ActiveRecord -Request $request).Count | Should -Be 0
        }
        It 'surfaces invalid JSON as a failure rather than an empty result' {
            { Get-ActiveRecord -Request { '{invalid' } } | Should -Throw
        }
        It 'rejects a record missing the Active property' {
            { Get-ActiveRecord -Request { '[{"name":"Ada"}]' } } |
                Should -Throw '*Boolean Active*'
        }
        It 'rejects a truthy string instead of treating it as Boolean true' {
            { Get-ActiveRecord -Request { '[{"name":"Ada","active":"false"}]' } } |
                Should -Throw '*Boolean Active*'
        }
    }
}

Describe 'Get-SearchUri' {
    Context 'with query data' {
        It 'escapes the query value without escaping the complete URI' {
            $uri = Get-SearchUri -BaseUri 'https://example.invalid/items' -Query 'needs review' -Page 2
            $uri.AbsoluteUri | Should -Be 'https://example.invalid/items?q=needs%20review&page=2'
        }
        It 'rejects a base URI that already contains a query' {
            { Get-SearchUri -BaseUri 'https://example.invalid/items?old=1' -Query 'new' } |
                Should -Throw '*must not already contain*'
        }
    }
}

Describe 'Get-RemoteRecord' {
    Context 'with Invoke-RestMethod mocked offline' {
        It 'returns the deserialized objects from the response' {
            Mock Invoke-RestMethod {
                @(
                    [pscustomobject]@{ Name = 'Ada'; Active = $true }
                    [pscustomobject]@{ Name = 'Lin'; Active = $false }
                )
            }
            $result = @(Get-RemoteRecord -Uri 'https://example.invalid/records')
            $result.Count | Should -Be 2
            $result[0].Name | Should -Be 'Ada'
        }
        It 'calls Invoke-RestMethod with the explicit request parameters' {
            Mock Invoke-RestMethod { [pscustomobject]@{ Name = 'Ada' } }
            Get-RemoteRecord -Uri 'https://example.invalid/records' -Method Get -TimeoutSec 20 |
                Out-Null
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://example.invalid/records' -and
                $Method -eq 'Get' -and
                $TimeoutSec -eq 20 -and
                $ErrorAction -eq 'Stop'
            }
        }
        It 'forwards supplied headers without changing them' {
            Mock Invoke-RestMethod { [pscustomobject]@{ Name = 'Ada' } }
            $headers = @{ Authorization = 'Bearer test-token' }
            Get-RemoteRecord -Uri 'https://example.invalid/records' -Headers $headers |
                Out-Null
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Headers.Authorization -eq 'Bearer test-token'
            }
        }
        It 'propagates a request failure as a terminating error' {
            Mock Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('gateway timeout')
            }
            { Get-RemoteRecord -Uri 'https://example.invalid/records' } |
                Should -Throw '*gateway timeout*'
        }
    }
}
