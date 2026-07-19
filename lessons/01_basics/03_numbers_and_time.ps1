#Requires -Version 7.4

# Numeric and time values are boundary choices, not just syntax. This script
# makes widening, precision, instant serialization, and elapsed time observable.

Set-StrictMode -Version Latest

$largestIntLiteral = 2147483647
$firstLongLiteral = 2147483648
# Crossing an Int32 operation's range widens this result to Double. Choose Long
# operands before the operation when the result must remain an exact integer.
$widenedResult = [int]::MaxValue + 1
$exactLongResult = 2147483647L + 1L

[int] $bounded = [int]::MaxValue
$constraintRejectedOverflow = try {
    # The expression widens, then assignment converts back through the Int32
    # constraint. The out-of-range conversion is rejected.
    $bounded += 1
    $false
}
catch {
    $true
}

$binarySum = 0.1 + 0.2
$decimalSum = 0.1d + 0.2d
$identifier = '003'

$start = [DateTimeOffset]::Parse(
    '2026-03-29T00:30:00+00:00',
    [Globalization.CultureInfo]::InvariantCulture
)
$end = [DateTimeOffset]::Parse(
    '2026-03-29T03:00:00+02:00',
    [Globalization.CultureInfo]::InvariantCulture
)
$elapsed = $end - $start
$roundTripText = $start.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
$parsedInstant = [DateTimeOffset]::ParseExact(
    $roundTripText,
    'o',
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::RoundtripKind
)
# DateTimeOffset carries an offset, not a civil zone. Pass a TimeZoneInfo
# explicitly when zone rules matter; UTC is portable evidence of that boundary.
$utcInstant = [TimeZoneInfo]::ConvertTime($start, [TimeZoneInfo]::Utc)

if ($largestIntLiteral -isnot [int] -or $firstLongLiteral -isnot [long]) {
    throw 'Integer literal type selection changed unexpectedly.'
}
if ($widenedResult -isnot [double] -or $exactLongResult -isnot [long]) {
    throw 'Numeric widening evidence failed.'
}
if (-not $constraintRejectedOverflow) {
    throw 'The Int32 constraint did not reject an out-of-range assignment.'
}
if ($binarySum -eq 0.3 -or $decimalSum -ne 0.3d) {
    throw 'Floating-point precision evidence failed.'
}
if ($identifier -ne '003' -or ([int] $identifier).ToString() -ne '3') {
    throw 'Identifier representation evidence failed.'
}
if ($elapsed -isnot [TimeSpan] -or $elapsed.TotalMinutes -ne 30) {
    throw 'Elapsed duration evidence failed.'
}
if (-not $parsedInstant.EqualsExact($start) -or $utcInstant.Offset -ne [TimeSpan]::Zero) {
    throw 'Instant round-trip evidence failed.'
}

[pscustomobject]@{
    IntLiteralType = $largestIntLiteral.GetType().Name
    LongLiteralType = $firstLongLiteral.GetType().Name
    WidenedType = $widenedResult.GetType().Name
    ExactLongType = $exactLongResult.GetType().Name
    IntConstraintRejectedOverflow = $constraintRejectedOverflow
    BinarySum = $binarySum.ToString('R', [Globalization.CultureInfo]::InvariantCulture)
    DecimalSum = $decimalSum
    Identifier = $identifier
    RoundTripInstant = $roundTripText
    ElapsedMinutes = $elapsed.TotalMinutes
}
