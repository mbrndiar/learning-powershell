#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($args.Count -lt 2) {
    exit 1
}

$gatePath = $args[0]
$programPath = $args[1]
$commandArguments = @($args | Select-Object -Skip 2)

while (-not [System.IO.File]::Exists($gatePath)) {
    Start-Sleep -Milliseconds 10
}

& $programPath @commandArguments
exit $LASTEXITCODE
