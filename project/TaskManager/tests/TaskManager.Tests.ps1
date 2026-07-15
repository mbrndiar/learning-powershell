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
}
