Set-StrictMode -Version Latest

$score = 82
$grade = if ($score -ge 90) { 'A' } elseif ($score -ge 80) { 'B' } else { 'C' }

$label = switch ($grade) {
    'A' { 'excellent'; break }
    'B' { 'passing'; break }
    default { 'keep practicing' }
}

$fileKind = switch -Wildcard ('tasks.json') {
    '*.json' { 'structured data'; break }
    default { 'other' }
}

$textKind = switch -Regex ('12345') {
    '^\d+$' { 'digits'; break }
    default { 'mixed text' }
}

$sum = 0
foreach ($number in 1..3) {
    $sum += $number
}

$count = 0
while ($count -lt 2) {
    $count++
}

$attempt = 0
do {
    $attempt++
} while ($attempt -lt 2)

[pscustomobject]@{
    Grade = $grade
    Label = $label
    FileKind = $fileKind
    TextKind = $textKind
    Sum = $sum
    Count = $count
    Attempts = $attempt
}
