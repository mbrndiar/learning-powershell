#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0'; MaximumVersion = '6.99.99' }

# This lesson resolves what the earlier injected-text seam only described: a
# real call to Invoke-RestMethod. The mental model has two distinct boundaries:
#   - 01_injected_request.ps1 injects JSON TEXT and calls ConvertFrom-Json, so
#     it teaches schema validation of untrusted text.
#   - Invoke-RestMethod ALREADY deserializes a JSON response into objects, so a
#     wrapper receives objects (not text) and returns them directly.
# Get-RemoteTask calls Invoke-RestMethod directly with an explicit Uri, method,
# timeout, and ErrorAction. It is tested OFFLINE by mocking Invoke-RestMethod
# (the Module 8 boundary-mock technique): there is never a live network call.
# Headers may carry a token, so they are passed through and never logged.

Set-StrictMode -Version Latest

function Get-RemoteTask {
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
        # ErrorAction Stop turns an unsuccessful status or transport failure into
        # a terminating error the caller can catch, instead of a warning stream.
        ErrorAction = 'Stop'
    }
    if ($PSBoundParameters.ContainsKey('Headers') -and $Headers.Count -gt 0) {
        # Forward auth/accept headers but never write them out; they may hold a
        # bearer token.
        $parameters.Headers = $Headers
    }

    # Invoke-RestMethod deserializes the JSON body, so this returns objects.
    Invoke-RestMethod @parameters
}

Describe 'Get-RemoteTask' {
    Context 'with Invoke-RestMethod mocked offline' {
        It 'returns the already-deserialized objects from the response' {
            # The mock returns OBJECTS, mirroring Invoke-RestMethod's own output;
            # no ConvertFrom-Json is needed here (contrast with 01).
            Mock Invoke-RestMethod {
                @(
                    [pscustomobject]@{ Name = 'Read'; Active = $true }
                    [pscustomobject]@{ Name = 'Build'; Active = $false }
                )
            }
            $result = @(Get-RemoteTask -Uri 'https://example.invalid/tasks')
            $result.Count | Should -Be 2
            $result[0].Name | Should -Be 'Read'
        }

        It 'calls Invoke-RestMethod with the explicit request parameters' {
            Mock Invoke-RestMethod { [pscustomobject]@{ Name = 'Read' } }
            Get-RemoteTask -Uri 'https://example.invalid/tasks' -Method Get -TimeoutSec 15 |
                Out-Null
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://example.invalid/tasks' -and
                $Method -eq 'Get' -and
                $TimeoutSec -eq 15 -and
                $ErrorAction -eq 'Stop'
            }
        }

        It 'forwards supplied headers without changing them' {
            Mock Invoke-RestMethod { [pscustomobject]@{ Name = 'Read' } }
            $headers = @{ Authorization = 'Bearer test-token' }
            Get-RemoteTask -Uri 'https://example.invalid/tasks' -Headers $headers |
                Out-Null
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Headers.Authorization -eq 'Bearer test-token'
            }
        }

        It 'propagates a request failure as a terminating error' {
            Mock Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('service unavailable')
            }
            { Get-RemoteTask -Uri 'https://example.invalid/tasks' } |
                Should -Throw '*service unavailable*'
        }
    }
}
