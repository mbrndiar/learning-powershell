#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

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

Describe 'Get-ActiveRecord' {
    Context 'with an injected request boundary' {
        It 'returns only active records' {
            $request = { '[{"name":"Ada","active":true},{"name":"Lin","active":false}]' }
            $result = @(Get-ActiveRecord -Request $request)
            $result.Count | Should -Be 1
            $result[0].name | Should -Be 'Ada'
        }
        It 'surfaces invalid JSON' {
            { Get-ActiveRecord -Request { '{invalid' } } | Should -Throw
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
