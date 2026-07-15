Set-StrictMode -Version Latest

function Get-ActiveRecord {
    [CmdletBinding()]
    param([Parameter(Mandatory)][scriptblock] $Request)
    & $Request | ConvertFrom-Json | Where-Object Active
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
    }
}
