#Requires -Version 7.4

# This first lesson demonstrates PowerShell's core habit: discover commands
# and inspect what they return instead of guessing. Every command emits .NET
# objects, so even the output below is structured data you can pipe onward.

Set-StrictMode -Version Latest

$edition = $PSVersionTable.PSEdition
$version = $PSVersionTable.PSVersion

# This pscustomobject is written to the output stream as data, not printed
# text; you can pipe it onward or inspect its shape with Get-Member.
[pscustomobject]@{
    Edition = $edition
    Version = $version
    Command = (Get-Command -Name Get-Date).Name
}

# Explore interactively: Get-Help Get-ChildItem -Examples
# Get-Command is itself discovery: it returns command objects you can filter
# and project just like any other pipeline data.
Get-Command -Noun Date | Select-Object -First 3 Name, CommandType
