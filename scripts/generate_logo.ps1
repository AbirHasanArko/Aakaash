# Generates the Aakaash logo as a high-quality PNG at multiple sizes.
# Run from PowerShell:  pwsh scripts/generate_logo.ps1
Add-Type -AssemblyName System.Drawing

function New-AakaashLogo([int]$size, [string]$outPath) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $s = [float]$size

    # 1. Rounded-square gradient background (sky)
    $radius = [int]($s * 0.22)
    $rect = New-Object System.Drawing.Rectangle(0, 0, [int]$s, [int]$s)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = [int]($radius * 2)
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc([int]($s - $d), 0, $d, $d, 270, 90)
    $path.AddArc([int]($s - $d), [int]($s - $d), $d, $d, 0, 90)
    $path.AddArc(0, [int]($s - $d), $d, $d, 90, 90)
    $path.CloseFigure()
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(255, 127, 214, 255),
        [System.Drawing.Color]::FromArgb(255, 26, 79, 160),
        [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
    $g.FillPath($bgBrush, $path)

    # 2. Sun rays (8 thin rectangles)
    $cx = $s * 0.5
    $cy = $s * 0.41
    $sunR = $s * 0.17
    $rayInner = $sunR + $s * 0.04
    $rayOuter = $rayInner + $s * 0.07
    $rayWidth = [Math]::Max(2, [int]($s * 0.025))
    $rayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 255, 227, 154))
    $rayPen = New-Object System.Drawing.Pen($rayBrush, [float]$rayWidth)
    $rayPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $rayPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    for ($i = 0; $i -lt 8; $i++) {
        $angle = ($i * 45.0) * [Math]::PI / 180.0
        $x1 = $cx + [Math]::Cos($angle) * $rayInner
        $y1 = $cy + [Math]::Sin($angle) * $rayInner
        $x2 = $cx + [Math]::Cos($angle) * $rayOuter
        $y2 = $cy + [Math]::Sin($angle) * $rayOuter
        $g.DrawLine($rayPen, [float]$x1, [float]$y1, [float]$x2, [float]$y2)
    }

    # 3. Sun body — radial gradient (cream → gold → orange)
    $sunRect = New-Object System.Drawing.RectangleF(
        [float]($cx - $sunR), [float]($cy - $sunR),
        [float]($sunR * 2), [float]($sunR * 2))
    $sunPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $sunPath.AddEllipse($sunRect)
    $sunBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($sunPath)
    $sunBrush.CenterPoint = New-Object System.Drawing.PointF([float]$cx, [float]$cy)
    $sunBrush.CenterColor = [System.Drawing.Color]::FromArgb(255, 255, 245, 200)
    $sunBrush.SurroundColors = @(
        [System.Drawing.Color]::FromArgb(255, 255, 138, 61)
    )
    $g.FillEllipse($sunBrush, $sunRect)

    # 4. Cloud — stacked ellipses
    $cloudColor = [System.Drawing.Color]::FromArgb(245, 255, 255, 255)
    $cloudShadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 200, 218, 235))
    $cloudBrush  = New-Object System.Drawing.SolidBrush($cloudColor)

    $cloudY = $s * 0.70
    $cloudRect = New-Object System.Drawing.RectangleF(
        [float]($s * 0.10), [float]($cloudY - $s * 0.08),
        [float]($s * 0.80), [float]($s * 0.30))
    # Soft shadow ellipse
    $g.FillEllipse($cloudShadow, $cloudRect)
    # Cloud puffs
    $g.FillEllipse($cloudBrush, [float]($s*0.18), [float]($s*0.55), [float]($s*0.30), [float]($s*0.20))
    $g.FillEllipse($cloudBrush, [float]($s*0.36), [float]($s*0.50), [float]($s*0.32), [float]($s*0.24))
    $g.FillEllipse($cloudBrush, [float]($s*0.55), [float]($s*0.55), [float]($s*0.30), [float]($s*0.20))
    $g.FillEllipse($cloudBrush, [float]($s*0.22), [float]($s*0.62), [float]($s*0.56), [float]($s*0.16))
    $g.FillEllipse($cloudBrush, [float]($s*0.20), [float]($s*0.66), [float]($s*0.60), [float]($s*0.14))

    # 5. Tiny stars
    $starBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 255, 255, 255))
    foreach ($star in @(
        @{x = 0.16; y = 0.24; r = 0.012},
        @{x = 0.84; y = 0.18; r = 0.010},
        @{x = 0.24; y = 0.16; r = 0.008},
        @{x = 0.78; y = 0.32; r = 0.011}
    )) {
        $rr = $s * $star.r
        $g.FillEllipse($starBrush,
            [float]($s * $star.x - $rr),
            [float]($s * $star.y - $rr),
            [float]($rr * 2), [float]($rr * 2))
    }

    # 6. Outer rounded mask — clip everything to the rounded square
    $g.Dispose()
    $finalBmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g2 = [System.Drawing.Graphics]::FromImage($finalBmp)
    $g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g2.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $clip = New-Object System.Drawing.Region($path)
    $g2.SetClip($clip, [System.Drawing.Drawing2D.CombineMode]::Replace)
    $g2.DrawImage($bmp, 0, 0)
    $g2.Dispose()
    $bmp.Dispose()

    $finalBmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $finalBmp.Dispose()
}

# Output paths
$root = "d:\Documents\MyWeather\my_weather_app"
$androidRes = "$root\android\app\src\main\res"
$dirs = @{
    "mdpi"    = "$androidRes\mipmap-mdpi"
    "hdpi"    = "$androidRes\mipmap-hdpi"
    "xhdpi"   = "$androidRes\mipmap-xhdpi"
    "xxhdpi"  = "$androidRes\mipmap-xxhdpi"
    "xxxhdpi" = "$androidRes\mipmap-xxxhdpi"
}
$sizes = @{
    "mdpi"    = 48
    "hdpi"    = 72
    "xhdpi"   = 96
    "xxhdpi"  = 144
    "xxxhdpi" = 192
}

foreach ($k in $dirs.Keys) {
    if (-not (Test-Path $dirs[$k])) {
        New-Item -ItemType Directory -Force -Path $dirs[$k] | Out-Null
    }
    New-AakaashLogo -size $sizes[$k] -outPath "$($dirs[$k])\ic_launcher.png"
    New-AakaashLogo -size $sizes[$k] -outPath "$($dirs[$k])\ic_launcher_round.png"
    Write-Host "Generated $($dirs[$k])\ic_launcher.png ($($sizes[$k])px)"
}

# Also drop a high-quality 512x512 master PNG for marketing / Play Store
$marketingDir = "$root\assets\logo"
if (-not (Test-Path $marketingDir)) { New-Item -ItemType Directory -Force -Path $marketingDir | Out-Null }
New-AakaashLogo -size 512 -outPath "$marketingDir\aakaash_logo_512.png"
New-AakaashLogo -size 256 -outPath "$marketingDir\aakaash_logo_256.png"
New-AakaashLogo -size 128 -outPath "$marketingDir\aakaash_logo_128.png"
New-AakaashLogo -size 1024 -outPath "$root\assets\logo\aakaash_logo_1024.png"
Write-Host "Generated marketing PNGs in $marketingDir"

Write-Host "Done."
