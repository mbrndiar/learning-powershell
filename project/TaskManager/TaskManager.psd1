# Module manifest (.psd1): metadata and the public contract only. The actual
# code lives in the implementation file named by RootModule (TaskManager.psm1).
@{
    RootModule = 'TaskManager.psm1'
    ModuleVersion = '1.0.0'
    GUID = '4f3bf2de-9180-4fc0-85ef-6c4995a9d440'
    Author = 'learning-powershell'
    Description = 'A small JSON-backed task manager for the PowerShell learning course.'
    PowerShellVersion = '7.4'
    # The explicit public surface. Keep this list in sync with the module's
    # Export-ModuleMember call; helpers not listed here stay private.
    FunctionsToExport = @('Get-Task', 'Add-Task', 'Set-Task', 'Remove-Task')
    # Empty arrays mean the module exports nothing else (no cmdlets, variables,
    # or aliases leak into the caller's session).
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
