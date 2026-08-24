# AA Split App - Store icon generator (re-runnable)
# Hand-drawn style: paper bg + TuanTuan panda head + lemon halo + berry blush + "CAI" antenna
# Output: docs/store/icons/* (store sizes) + Android launch/adaptive icons + iOS AppIcon
# Usage: powershell -ExecutionPolicy Bypass -File scripts\generate-app-icons.ps1
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$master = Join-Path $root "docs\store\icons\_master-1024.png"

function Col([string]$hex, [int]$alpha = 255) {
    return [System.Drawing.Color]::FromArgb($alpha,
        [Convert]::ToInt32($hex.Substring(0, 2), 16),
        [Convert]::ToInt32($hex.Substring(2, 2), 16),
        [Convert]::ToInt32($hex.Substring(4, 2), 16))
}
$paper     = Col "FBF3E4"
$cardWhite = Col "FFFDF8"
$ink       = Col "443A32"
$lemon     = Col "FFD166"
$berry     = Col "F49CB4"

function New-Solid([System.Drawing.Color]$c) { return (New-Object System.Drawing.SolidBrush $c) }
function New-PenW([System.Drawing.Color]$c, [float]$w) { $p = New-Object System.Drawing.Pen $c, $w; $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round; $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round; return $p }

function Draw-Master([string]$path) {
    $bmp = New-Object System.Drawing.Bitmap 1024, 1024
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear($paper)
    $g.TranslateTransform(0, 36)   # balance: shift whole art down a bit

    # lemon halo
    $halo = New-Solid ([System.Drawing.Color]::FromArgb(95, $lemon))
    $g.FillEllipse($halo, [float](512-330), [float](520-300), 660, 600)

    # ears (ink filled, behind head)
    $g.FillEllipse((New-Solid $ink), [float](300-105), [float](250-105), 210, 210)
    $g.FillEllipse((New-Solid $ink), [float](724-105), [float](250-105), 210, 210)

    # head (white face + ink outline)
    $headPen = New-PenW $ink 16
    $g.FillEllipse((New-Solid $cardWhite), [float](512-300), [float](520-280), 600, 560)
    $g.DrawEllipse($headPen, [float](512-300), [float](520-280), 600, 560)

    # eyes: tilted ink patches + white highlight
    function Eye([float]$cx, [float]$cy, [float]$angle) {
        $state = $g.Save()
        $g.TranslateTransform($cx, $cy); $g.RotateTransform($angle)
        $g.FillEllipse((New-Solid $ink), -80, -60, 160, 120)
        $g.Restore($state)
        $g.FillEllipse((New-Solid $cardWhite), $cx-22, $cy-34, 34, 34)
    }
    Eye 408 492 -18
    Eye 616 492 18

    # nose
    $g.FillEllipse((New-Solid $ink), [float](512-26), [float](556-22), 52, 44)

    # smile
    $mouthPen = New-PenW $ink 12
    $g.DrawArc($mouthPen, [float](512-60), [float](575-10), 120, 78, 25, 130)

    # blush
    $blush = New-Solid ([System.Drawing.Color]::FromArgb(165, $berry))
    $g.FillEllipse($blush, [float](335-48), [float](588-28), 96, 56)
    $g.FillEllipse($blush, [float](689-48), [float](588-28), 96, 56)

    # antenna ("CAI" = fortune) - ink curve
    $ant = New-PenW $ink 16
    $g.DrawBezier($ant, [float]512, [float]240, [float]496, [float]200, [float]508, [float]170, [float]498, [float]138)

    # CAI glyph in brand font
    $fontDir = Join-Path $root "app\packages\aa_design\assets\fonts"
    $pfc = New-Object System.Drawing.Text.PrivateFontCollection
    $pfc.AddFontFile((Join-Path $fontDir "ZCOOLKuaiLe-Regular.ttf"))
    $font = New-Object System.Drawing.Font($pfc.Families[0], 118, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $inkBr = New-Solid $ink
    $g.DrawString([char]0x8D22, $font, $inkBr, (New-Object System.Drawing.RectangleF (452, 12, 120, 118)), $sf)
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Save-Scaled([string]$src, [int]$size, [string]$dest) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $img = [System.Drawing.Image]::FromFile($src)
    $g.DrawImage($img, 0, 0, $size, $size)
    $img.Dispose(); $g.Dispose()
    $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# master + store sizes
New-Item -ItemType Directory -Force -Path (Split-Path $master) | Out-Null
Draw-Master $master
$iconsDir = Split-Path $master
foreach ($sz in @(1024, 512, 432, 216, 192, 144, 96, 72, 48)) {
    Save-Scaled $master $sz (Join-Path $iconsDir ("icon-$sz.png"))
}

# Android legacy mipmap
$resDir = Join-Path $root "app\android\app\src\main\res"
foreach ($m in @(@("mdpi",48), @("hdpi",72), @("xhdpi",96), @("xxhdpi",144), @("xxxhdpi",192))) {
    $dir = Join-Path $resDir ("mipmap-" + $m[0])
    Save-Scaled $master ([int]$m[1]) (Join-Path $dir "ic_launcher.png")
}

# Android adaptive icon
$anydpi = Join-Path $resDir "mipmap-anydpi-v26"
New-Item -ItemType Directory -Force -Path $anydpi | Out-Null
$xml1 = '<?xml version="1.0" encoding="utf-8"?>' + [Environment]::NewLine +
  '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">' + [Environment]::NewLine +
  '    <background android:drawable="@color/ic_launcher_background"/>' + [Environment]::NewLine +
  '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>' + [Environment]::NewLine +
  '</adaptive-icon>' + [Environment]::NewLine
[System.IO.File]::WriteAllText((Join-Path $anydpi "ic_launcher.xml"), $xml1, (New-Object System.Text.UTF8Encoding $false))
foreach ($m in @(@("mdpi",108), @("hdpi",162), @("xhdpi",216), @("xxhdpi",324), @("xxxhdpi",432))) {
    $dir = Join-Path $resDir ("mipmap-" + $m[0])
    Save-Scaled $master ([int]$m[1]) (Join-Path $dir "ic_launcher_foreground.png")
}
$values = Join-Path $resDir "values"
$xml2 = '<?xml version="1.0" encoding="utf-8"?>' + [Environment]::NewLine +
  '<resources>' + [Environment]::NewLine +
  '    <color name="ic_launcher_background">#FBF3E4</color>' + [Environment]::NewLine +
  '</resources>' + [Environment]::NewLine
[System.IO.File]::WriteAllText((Join-Path $values "ic_launcher_background.xml"), $xml2, (New-Object System.Text.UTF8Encoding $false))

# iOS AppIcon (filenames match Contents.json: base*scale)
$appiconset = Join-Path $root "app\ios\Runner\Assets.xcassets\AppIcon.appiconset"
Get-ChildItem (Join-Path $appiconset "Icon-App-*.png") | ForEach-Object {
    if ($_.BaseName -match "^Icon-App-(\d+(?:\.\d+)?)x\d+@(\d)x$") {
        $px = [int][math]::Round([double]$Matches[1] * [int]$Matches[2])
        Save-Scaled $master $px $_.FullName
    }
}

Write-Host "OK: icons generated -> $(Split-Path $master)"