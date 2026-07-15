BeforeAll {
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath '../TaskManager.psd1'
    Import-Module -Name $modulePath -Force
}

Describe 'TaskManager' {
    BeforeEach {
        $script:store = Join-Path -Path $TestDrive -ChildPath (
            'tasks-{0}.json' -f [guid]::NewGuid()
        )
    }

    It 'adds and returns an object task' {
        $task = Add-Task -LiteralPath $script:store -Title 'Read docs' -Confirm:$false
        $task.Title | Should -Be 'Read docs'
        $task.Done | Should -BeFalse
        $task.Id | Should -Match '^[0-9a-f-]{36}$'
    }

    It 'persists tasks and changes completion state' {
        $created = Add-Task -LiteralPath $script:store -Title 'Write test' -Confirm:$false
        $updated = Set-Task -LiteralPath $script:store -Id $created.Id -Done $true -Confirm:$false
        $updated.Done | Should -BeTrue
        @(Get-Task -LiteralPath $script:store -Done).Count | Should -Be 1
    }

    It 'does not persist a WhatIf addition' {
        Add-Task -LiteralPath $script:store -Title 'Preview' -WhatIf
        Test-Path -LiteralPath $script:store | Should -BeFalse
    }

    It 'removes a task and returns the removed object' {
        $created = Add-Task -LiteralPath $script:store -Title 'Delete me' -Confirm:$false
        $removed = Remove-Task -LiteralPath $script:store -Id $created.Id -Confirm:$false
        $removed.Id | Should -Be $created.Id
        @(Get-Task -LiteralPath $script:store).Count | Should -Be 0
    }

    It 'throws an actionable error for an unknown task' {
        { Set-Task -LiteralPath $script:store -Id '00000000-0000-0000-0000-000000000000' -Done $true -Confirm:$false } |
            Should -Throw '*was not found*'
    }

    It 'rejects a blank task store path' {
        { Get-Task -LiteralPath '   ' } | Should -Throw '*must not be empty*'
    }

    It 'rejects a directory as a task store' {
        { Add-Task -LiteralPath $TestDrive -Title 'Invalid target' -Confirm:$false } |
            Should -Throw '*points to a directory*'
    }

    It 'requires a top-level JSON array' {
        Set-Content -LiteralPath $script:store -Value '{"Name":"not an array"}' -Encoding utf8
        { Get-Task -LiteralPath $script:store } | Should -Throw '*top-level JSON array*'
    }

    It 'validates every stored task field' {
        $invalid = @(
            [pscustomobject]@{
                Id = [guid]::NewGuid().ToString()
                Title = 42
                Done = 'yes'
                CreatedAt = 'not-a-timestamp'
            }
        )
        ConvertTo-Json -InputObject $invalid |
            Set-Content -LiteralPath $script:store -Encoding utf8
        { Get-Task -LiteralPath $script:store } | Should -Throw '*title must be a non-empty string*'
    }

    It 'rejects duplicate stored task IDs' {
        $id = [guid]::NewGuid().ToString()
        $duplicate = @(
            [pscustomobject]@{
                Id = $id
                Title = 'First'
                Done = $false
                CreatedAt = [datetime]::UtcNow.ToString('O')
            }
            [pscustomobject]@{
                Id = $id
                Title = 'Second'
                Done = $false
                CreatedAt = [datetime]::UtcNow.ToString('O')
            }
        )
        ConvertTo-Json -InputObject $duplicate |
            Set-Content -LiteralPath $script:store -Encoding utf8
        { Get-Task -LiteralPath $script:store } | Should -Throw '*duplicate task IDs*'
    }

    It 'rejects null task entries' {
        Set-Content -LiteralPath $script:store -Value '[null]' -Encoding utf8
        { Get-Task -LiteralPath $script:store } | Should -Throw '*null task entries*'
    }

    It 'requires an ISO 8601 timestamp' {
        $id = [guid]::NewGuid().ToString()
        $json = @"
[{"Id":"$id","Title":"Invalid date","Done":false,"CreatedAt":"July 15, 2026"}]
"@
        Set-Content -LiteralPath $script:store -Value $json -Encoding utf8
        { Get-Task -LiteralPath $script:store } | Should -Throw '*CreatedAt value*invalid*'
    }

    It 'keeps CreatedAt in one UTC round-trip format' {
        $created = Add-Task -LiteralPath $script:store -Title 'Stable date' -Confirm:$false
        $loaded = Get-Task -LiteralPath $script:store
        $loaded.CreatedAt | Should -Be $created.CreatedAt
        $loaded.CreatedAt | Should -Match 'Z$'
    }
}
