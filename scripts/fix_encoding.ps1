# fix_encoding.ps1 - repair the two docs-write scripts.
# The script sources contain UTF-8-of-CP1252 mojibake introduced by
# create_file when written through Windows PowerShell 5.1 (no utf8NoBOM).
# Strategy: read each script's bytes, decode as UTF-8 (the file is valid UTF-8;
# it's just UTF-8 of already-corrupted text), then strip all non-ASCII characters
# to leave pure ASCII. The README + API doc body content survives, minus the
# box-drawing art - we'll swap that for ASCII art inline.

$ErrorActionPreference = 'Stop'
$scriptsDir = 'd:\Documents\MyWeather\aakaash\scripts'
$utf8NoBom  = New-Object System.Text.UTF8Encoding($false)

# Map of non-ASCII single chars -> ASCII replacement.
# Multi-char sequences (mojibake trigrams) need to be matched first; the final
# regex fallback strips anything remaining.
$map = [ordered]@{
    "`u{00E2}`u{20AC}`u{201D}" = '--'   # left double quote " -> -- (used as em-dash)
    "`u{00E2}`u{20AC}`u{201C}" = '--'   # right double quote " -> --
    "`u{00E2}`u{20AC}`u{2122}" = "'"    # tm -> '
    "`u{00E2}`u{20AC}`u{02DC}" = "'"    # ' -> '
    "`u{00E2}`u{20AC}`u{0098}" = "'"    # ' alt
    "`u{00E2}`u{20AC}`u{0153}" = 'oe'   # oe ligature
    "`u{00E2}`u{20AC}`u{0161}" = 's'    # s with caron
    "`u{00C2}`u{00B0}"         = 'deg'  # degree
    "`u{00C2}`u{00B3}"         = '^3'   # cubed
    "`u{00C2}`u{00B2}"         = '^2'   # squared
    # Real intended chars that may have slipped in
    "`u{2014}" = '--'   # em dash
    "`u{2013}" = '-'    # en dash
    "`u{2018}" = "'"    # left single quote
    "`u{2019}" = "'"    # right single quote
    "`u{201C}" = '"'    # left double quote
    "`u{201D}" = '"'    # right double quote
    "`u{2026}" = '...'  # ellipsis
    "`u{00B0}" = 'deg'  # degree
    "`u{00B3}" = '^3'   # cubed
    "`u{00B2}" = '^2'   # squared
    "`u{250C}" = '+'; "`u{2510}" = '+'  # corners
    "`u{2514}" = '+'; "`u{2518}" = '+'
    "`u{2500}" = '-'; "`u{2550}" = '-'
    "`u{2502}" = '|'; "`u{2551}" = '|'
    "`u{252C}" = '+'; "`u{2534}" = '+'
    "`u{251C}" = '+'; "`u{2524}" = '+'
    "`u{253C}" = '+'
    "`u{25BC}" = 'v'; "`u{25B2}" = '^'
    "`u{25B6}" = '>'; "`u{25C0}" = '<'
}

foreach ($name in 'write_readme.ps1','write_api_docs.ps1') {
    $path = Join-Path $scriptsDir $name
    Write-Host "--- Repairing $name ---" -ForegroundColor Cyan
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $text  = [System.Text.Encoding]::UTF8.GetString($bytes)

    foreach ($k in $map.Keys) {
        $text = $text.Replace($k, [string]$map[$k])
    }

    # Strip any remaining non-ASCII (Bangla etc.) - the source heredoc already
    # only contains English after our map passes.
    $text = [regex]::Replace($text, '[^\x00-\x7F]', '')

    [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
    Write-Host ('  wrote {0} bytes (ASCII, no BOM)' -f $utf8NoBom.GetByteCount($text))
}

Write-Host "`nDone. Re-running the scripts now writes clean ASCII docs." -ForegroundColor Green