#Requires -Version 7.4

# Text and bytes are different boundary contracts. Encoding transforms between
# them; raw byte mode preserves values without interpreting them as characters.

Set-StrictMode -Version Latest

$directory = Join-Path -Path $PSScriptRoot -ChildPath ('.scratch-bytes-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $directory -Force
try {
    $textPath = Join-Path -Path $directory -ChildPath 'text-mode.txt'
    $encodedPath = Join-Path -Path $directory -ChildPath 'encoded-utf8.bin'
    $binaryPath = Join-Path -Path $directory -ChildPath 'raw.bin'

    # Build non-ASCII text from code points so this source file itself remains
    # portable ASCII while the file boundary still proves real UTF-8 behavior.
    $text = "caf$([char] 0x00E9) $([char] 0x2211)`nsecond line"
    # Text mode owns the UTF-8 transformation and -Raw restores one string.
    Set-Content -LiteralPath $textPath -Value $text -Encoding utf8 -NoNewline
    $textModeRoundTrip = Get-Content -LiteralPath $textPath -Encoding utf8 -Raw

    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    [byte[]] $encodedBytes = $utf8.GetBytes($text)
    # Byte mode writes the already encoded bytes. Encoding would be meaningless
    # here, so it is deliberately absent.
    Set-Content -LiteralPath $encodedPath -AsByteStream -Value $encodedBytes
    [byte[]] $readEncodedBytes = Get-Content -LiteralPath $encodedPath -AsByteStream -Raw
    $decodedText = $utf8.GetString($readEncodedBytes)

    [byte[]] $binaryBytes = 0, 1, 10, 13, 127, 128, 254, 255
    Set-Content -LiteralPath $binaryPath -AsByteStream -Value $binaryBytes
    [byte[]] $binaryRoundTrip = Get-Content -LiteralPath $binaryPath -AsByteStream -Raw

    if ($textModeRoundTrip -isnot [string] -or $textModeRoundTrip -ne $text) {
        throw 'Text-mode UTF-8 round trip failed.'
    }
    if ($readEncodedBytes -isnot [byte[]] -or
        $readEncodedBytes.Count -ne $encodedBytes.Count -or
        [Convert]::ToHexString($readEncodedBytes) -ne [Convert]::ToHexString($encodedBytes) -or
        $decodedText -ne $text) {
        throw 'Explicit UTF-8 encode/write/read/decode round trip failed.'
    }
    if ($binaryRoundTrip -isnot [byte[]] -or
        $binaryRoundTrip.Count -ne $binaryBytes.Count -or
        [Convert]::ToHexString($binaryRoundTrip) -ne [Convert]::ToHexString($binaryBytes)) {
        throw 'Raw binary round trip failed.'
    }

    [pscustomobject]@{
        TextModeType = $textModeRoundTrip.GetType().Name
        EncodedByteType = $readEncodedBytes.GetType().Name
        EncodedByteCount = $readEncodedBytes.Count
        DecodedTextMatches = $decodedText -eq $text
        BinaryByteCount = $binaryRoundTrip.Count
        BinaryHex = [Convert]::ToHexString($binaryRoundTrip)
    }
}
finally {
    Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
}
