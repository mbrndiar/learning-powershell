#Requires -Version 7.4

# This lesson covers branching and loops. The mental model to carry over:
# branch output goes to the success stream, so it can be captured directly
# instead of mutating a variable in every branch.

Set-StrictMode -Version Latest

$score = 82
# The selected branch emits one value, which the assignment captures.
$grade = if ($score -ge 90) { 'A' } elseif ($score -ge 80) { 'B' } else { 'C' }

# switch can run every matching clause; break exits after the first match when
# that is the intended contract.
$label = switch ($grade) {
    'A' { 'excellent'; break }
    'B' { 'passing'; break }
    default { 'keep practicing' }
}

# -Wildcard and -Regex change how each clause label is matched against input.
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
