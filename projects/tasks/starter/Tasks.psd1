@{
    RootModule = 'Tasks.psm1'
    ModuleVersion = '1.0.0'
    GUID = '4b60e5d0-11f7-4d79-951f-555d46f17567'
    Author = 'learning-powershell'
    Description = 'Guided starter module for the applied PowerShell Tasks project.'
    PowerShellVersion = '7.4'
    RequiredModules = @(
        @{
            ModuleName = 'SimplySql'
            RequiredVersion = '2.2.0.106'
        }
    )
    FunctionsToExport = @(
        'Initialize-TaskStore'
        'Add-Task'
        'Get-Task'
        'Set-Task'
        'Remove-Task'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
