# Generate Aakaash modern minimalistic icon at all Android mipmap densities.
# Pure System.Drawing — no external tools.
# Output: android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png
#         android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
#         android/app/src/main/res/drawable/ic_launcher_foreground.png (adaptive)

Add-Type -AssemblyName System.Drawing

$resRoot = "D:\Documents\MyWeather\aakaash\android\app\src\main\res"
$sizes = @{ "mdpi" = 48; "hdpi" = 72; "xhdpi" = 96; "xxhdpi" = 144; "xxxhdpi" = 192 }

function New-AakaashIcon([int]$size, [string]$outPath, [bool]$transparent) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    if (-not $transparent) {
        # Background with simple two-stop gradient (top→bottom).
        $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $rect,
            [System.Drawing.Color]::FromArgb(255, 15, 76, 92),
            [System.Drawing.Color]::FromArgb(255, 10, 55, 68),
            90)
        $g.FillRectangle($brush, $rect)
    }

    # Rounded-corner mask (only for bitmaps; for adaptive/foreground it stays sq).
    if (-not $transparent) {
        $radius = [int]($size * 0.1875)  # 96/512
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddArc(0, 0, $radius * 2, $radius * 2, 180, 90)
        $path.AddArc($size - $radius * 2, 0, $radius * 2, $radius * 2, 270, 90)
        $path.AddArc($size - $radius * 2, $size - $radius * 2, $radius * 2, $radius * 2, 0, 90)
        $path.AddArc(0, $size - $radius * 2, $radius * 2, $radius * 2, 90, 90)
        $path.CloseFigure()
        $g.SetClip($path)
    }

    # Sun halo (top-right) — soft white circle behind sun.
    $haloBrush = New-Object System.Drawing.SolidBrush (
        [System.Drawing.Color]::FromArgb(40, 255, 255, 255))
    $haloR = [int]($size * 0.22)
    $haloCx = [int]($size * 0.617)
    $haloCy = [int]($size * 0.351)
    $g.FillEllipse($haloBrush, $haloCx - $haloR, $haloCy - $haloR, $haloR * 2, $haloR * 2)

    # Sun disc.
    $sunBrush = New-Object System.Drawing.SolidBrush (
        [System.Drawing.Color]::FromArgb(255, 255, 214, 107))
    $sunR = [int]($size * 0.14)
    $sunCx = [int]($size * 0.617)
    $sunCy = [int]($size * 0.351)
    $g.FillEllipse($sunBrush, $sunCx - $sunR, $sunCy - $sunR, $sunR * 2, $sunR * 2)

    # Cloud: three overlapping circles + base bar (the "bubble").
    $cloudBrush = New-Object System.Drawing.SolidBrush (
        [System.Drawing.Color]::FromArgb(255, 255, 255, 255))
    $baseY = [int]($size * 0.485)
    $baseH = [int]($size * 0.195)
    $baseX = [int]($size * 0.234)
    $baseW = [int]($size * 0.469)
    $g.FillRectangle($cloudBrush, $baseX, $baseY, $baseW, $baseH)

    $c1R = [int]($size * 0.098)
    $c1Cx = [int]($size * 0.352)
    $c1Cy = $baseY
    $g.FillEllipse($cloudBrush, $c1Cx - $c1R, $c1Cy - $c1R, $c1R * 2, $c1R * 2)

    $c2R = [int]($size * 0.125)
    $c2Cx = [int]($size * 0.578)
    $c2Cy = [int]($size * 0.453)
    $g.FillEllipse($cloudBrush, $c2Cx - $c2R, $c2Cy - $c2R, $c2R * 2, $c2R * 2)

    $c3R = [int]($size * 0.094)
    $c3Cx = [int]($size * 0.648)
    $c3Cy = [int]($size * 0.535)
    $g.FillEllipse($cloudBrush, $c3Cx - $c3R, $c3Cy - $c3R, $c3R * 2, $c3R * 2)

    $g.Dispose()
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# ─────────────────── Flat logo PNGs (no wordmark) ────────────────────
# Same source art, but rounded corners optional and the body is centered.
function New-AakaashLogo([int]$size, [string]$outPath) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    # Vertical gradient background, full bleed (logos are flat squares).
    $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(255, 15, 76, 92),
        [System.Drawing.Color]::FromArgb(255, 10, 55, 68),
        90)
    $g.FillRectangle($brush, $rect)

    # Sun halo + sun disc (top-right).
    $haloBrush = New-Object System.Drawing.SolidBrush (
        [System.Drawing.Color]::FromArgb(40, 255, 255, 255))
    $haloR = [int]($size * 0.22)
    $haloCx = [int]($size * 0.617)
    $haloCy = [int]($size * 0.351)
    $g.FillEllipse($haloBrush, $haloCx - $haloR, $haloCy - $haloR, $haloR * 2, $haloR * 2)

    $sunBrush = New-Object System.Drawing.SolidBrush (
        [System.Drawing.Color]::FromArgb(255, 255, 214, 107))
    $sunR = [int]($size * 0.14)
    $g.FillEllipse($sunBrush, $haloCx - $sunR, $haloCy - $sunR, $sunR * 2, $sunR * 2)

    # Cloud body — same proportions as the launcher.
    $cloudBrush = New-Object System.Drawing.SolidBrush (
        [System.Drawing.Color]::FromArgb(255, 255, 255, 255))
    $baseY = [int]($size * 0.485)
    $baseH = [int]($size * 0.195)
    $baseX = [int]($size * 0.234)
    $baseW = [int]($size * 0.469)
    $g.FillRectangle($cloudBrush, $baseX, $baseY, $baseW, $baseH)

    $c1R = [int]($size * 0.098)
    $c1Cx = [int]($size * 0.352)
    $c1Cy = $baseY
    $g.FillEllipse($cloudBrush, $c1Cx - $c1R, $c1Cy - $c1R, $c1R * 2, $c1R * 2)

    $c2R = [int]($size * 0.125)
    $c2Cx = [int]($size * 0.578)
    $c2Cy = [int]($size * 0.453)
    $g.FillEllipse($cloudBrush, $c2Cx - $c2R, $c2Cy - $c2R, $c2R * 2, $c2R * 2)

    $c3R = [int]($size * 0.094)
    $c3Cx = [int]($size * 0.648)
    $c3Cy = [int]($size * 0.535)
    $g.FillEllipse($cloudBrush, $c3Cx - $c3R, $c3Cy - $c3R, $c3R * 2, $c3R * 2)

    $g.Dispose()
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# Render bitmap launcher icons at all densities.
foreach ($k in $sizes.Keys) {
    $size = $sizes[$k]
    $dir = "$resRoot\mipmap-$k"
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    New-AakaashIcon -size $size -outPath "$dir\ic_launcher.png" -transparent $false
    Write-Host "wrote $dir\ic_launcher.png ($size px)"
}

# Render the foreground layer for adaptive icons (transparent background).
$fgSize = 432
$fgDir = "$resRoot\drawable"
New-Item -ItemType Directory -Force -Path $fgDir | Out-Null
New-AakaashIcon -size $fgSize -outPath "$fgDir\ic_launcher_foreground.png" -transparent $true
Write-Host "wrote $fgDir\ic_launcher_foreground.png (adaptive foreground)"

# Render the legacy round launcher at each density (same shape, slightly
# smaller radius applied via mask that the platform renders into a circle).
foreach ($k in $sizes.Keys) {
    $size = $sizes[$k]
    $dir = "$resRoot\mipmap-$k"
    New-AakaashIcon -size $size -outPath "$dir\ic_launcher_round.png" -transparent $false
    Write-Host "wrote $dir\ic_launcher_round.png ($size px)"
}

# Adaptive icon XML (Android 8+).
$anyDir = "$resRoot\mipmap-anydpi-v26"
New-Item -ItemType Directory -Force -Path $anyDir | Out-Null
@"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
"@ | Set-Content -Encoding UTF8 "$anyDir\ic_launcher.xml"
@"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
"@ | Set-Content -Encoding UTF8 "$anyDir\ic_launcher_round.xml"
Write-Host "wrote adaptive icon XML"

# ──────────────────────── Flat logo PNGs (1024→128) ────────────────────────
$logoDir = "D:\Documents\MyWeather\aakaash\assets\logo"
New-Item -ItemType Directory -Force -Path $logoDir | Out-Null
foreach ($size in @(1024, 512, 256, 128)) {
    New-AakaashLogo -size $size -outPath "$logoDir\aakaash_logo_${size}.png"
    Write-Host "wrote $logoDir\aakaash_logo_${size}.png"
}
