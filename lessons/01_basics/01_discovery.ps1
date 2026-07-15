Set-StrictMode -Version Latest

$edition = $PSVersionTable.PSEdition
$version = $PSVersionTable.PSVersion

[pscustomobject]@{
    Edition = $edition
    Version = $version
    Command = (Get-Command -Name Get-Date).Name
}

# Explore interactively: Get-Help Get-ChildItem -Examples
Get-Command -Noun Date | Select-Object -First 3 Name, CommandType
