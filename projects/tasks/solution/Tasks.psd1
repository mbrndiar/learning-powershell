@{
    RootModule = 'Tasks.psm1'
    ModuleVersion = '1.0.0'
    GUID = '74c66552-9c5b-4818-b870-750a72f19c1d'
    Author = 'learning-powershell'
    Description = 'Reference implementation for the applied PowerShell Tasks project.'
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
