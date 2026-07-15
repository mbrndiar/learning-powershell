#Requires -Version 7.4

Set-StrictMode -Version Latest

[string] $name = 'Ada'
[int] $completed = 3
[decimal] $rate = 1.5

[pscustomobject]@{
    Greeting = "Hello, $name"
    Literal = 'Hello, $name'
    Total = $completed * $rate
    IsReady = ($completed -ge 3 -and $name -like 'A*')
    UpperName = $name.ToUpperInvariant()
}
