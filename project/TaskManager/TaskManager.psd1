@{
    RootModule = 'TaskManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = '4f3bf2de-9180-4fc0-85ef-6c4995a9d440'
    Author = 'learning-powershell'
    Description = 'A small JSON-backed task manager for the PowerShell learning course.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('Get-Task', 'Add-Task', 'Set-Task', 'Remove-Task')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
