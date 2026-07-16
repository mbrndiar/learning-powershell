@{
    RootModule = 'ComplianceAudit.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'd334a88b-2277-44f9-9969-72c72c67cc0f'
    Author = 'learning-powershell'
    Description = 'A fixture-oriented compliance audit and safe remediation capstone module.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @(
        'Import-CompliancePolicy'
        'Test-Compliance'
        'Repair-Compliance'
        'Export-ComplianceReport'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
