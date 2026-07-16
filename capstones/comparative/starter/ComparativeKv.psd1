@{
    RootModule = 'ComparativeKv.psm1'
    ModuleVersion = '1.0.0'
    GUID = '9f5aed99-7c14-4890-b85c-427dfef2c38a'
    Author = 'learning-powershell'
    Description = 'PowerShell boundary for the comparative versioned configuration-store capstone.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Set-ConfigurationEntry'
        'Get-ConfigurationEntry'
        'Remove-ConfigurationEntry'
        'Get-ConfigurationStore'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
