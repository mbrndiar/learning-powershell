Set-StrictMode -Version Latest

$score = 82
$grade = if ($score -ge 90) { 'A' } elseif ($score -ge 80) { 'B' } else { 'C' }

$label = switch ($grade) {
    'A' { 'excellent'; break }
    'B' { 'passing'; break }
    default { 'keep practicing' }
}

$sum = 0
foreach ($number in 1..3) {
    $sum += $number
}

$count = 0
while ($count -lt 2) {
    $count++
}

[pscustomobject]@{ Grade = $grade; Label = $label; Sum = $sum; Count = $count }
