#Requires -Version 7.4

# This lesson shows constrained variables, string quoting, and operators. The
# key mental model: values carry .NET types, while an optional variable type
# constraint converts or rejects each value assigned at that boundary.

Set-StrictMode -Version Latest

[string] $name = 'Ada'
[int] $completed = 3
[decimal] $rate = 1.5

[pscustomobject]@{
    # Double quotes interpolate $name; single quotes are literal text.
    Greeting = "Hello, $name"
    Literal = 'Hello, $name'
    # Because one operand is decimal, PowerShell produces a decimal result.
    Total = $completed * $rate
    IsReady = ($completed -ge 3 -and $name -like 'A*')
    UpperName = $name.ToUpperInvariant()
}
