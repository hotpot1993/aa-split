# 图标/吉祥物素材处理流水线
# 用法：powershell -ExecutionPolicy Bypass -File scripts/process-icons.ps1
#
# 2026-08 素材源升级：docs/pic 为「ASCII 命名的 iconfont 矢量 SVG」（透明底、多色），
# 本脚本用无头 Chrome/Edge 光栅化为透明 PNG：
#   1) docs/pic/*.svg        -> app/assets/icons/<名>.png        （512x512 界面图标）
#   2) docs/pic/tuantuan.svg -> app/assets/mascot/tuantuan.png   （512x512 吉祥物团团）
#   3) 启动图标（传统 + 自适应前景 62%）由商店主视觉生成
param(
    [string]$SourceDir = "docs/pic",
    [int]$OutSize = 512
)
$ErrorActionPreference = "Stop"
$root  = Split-Path -Parent $PSScriptRoot
$srcDir = Join-Path $root $SourceDir
$outDir = Join-Path $root "app/assets/icons"
$resDir = Join-Path $root "app/android/app/src/main/res"

# ---------- 无头浏览器（Chrome 优先，Edge 兜底） ----------
$browser = $null
foreach ($p in @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe")) {
    if (Test-Path $p) { $browser = $p; break }
}
if (-not $browser) {
    Write-Error "未找到 Chrome/Edge，无法光栅化 SVG。请安装任意 .exe 浏览器后重试。"
    exit 1
}
Write-Host "== SVG 光栅化（$browser）=="

$profile    = Join-Path $env:TEMP ("aa_icon_chrome_" + $PID)
$tmpHtml    = Join-Path $env:TEMP "aa_icon_frame.html"
$prevEap    = $ErrorActionPreference
$ErrorActionPreference = "Continue"   # Chrome 会把进度写到 stderr，需忽略

# SVG -> [Size]x[Size] 透明底 PNG（BoxFit contain，等比居中）
function Rasterize-Svg([string]$InPath, [string]$OutPath, [int]$Size) {
    $fc = "file:///" + ($InPath.Replace('\', '/'))
    $html = '<!doctype html><html><head><meta charset="utf-8">' +
        '<style>html,body{margin:0;padding:0;width:' + $Size + 'px;height:' + $Size + 'px;overflow:hidden}' +
        'img{width:' + $Size + 'px;height:' + $Size + 'px;display:block}</style></head>' +
        '<body><img src="' + $fc + '"></body></html>'
    [System.IO.File]::WriteAllText($tmpHtml, $html, [System.Text.UTF8Encoding]::new($false))
    $tmp = Join-Path $env:TEMP ("aa_raster_" + [System.IO.Path]::GetFileNameWithoutExtension($InPath) + ".png")
    & $browser --headless=new --disable-gpu --no-first-run --disable-extensions `
        --hide-scrollbars --default-background-color=00000000 `
        --window-size=$Size,$Size --force-device-scale-factor=1 `
        --user-data-dir=$profile --screenshot=$tmp ("file:///" + $tmpHtml.Replace('\', '/')) 2>$null | Out-Null
    if (Test-Path $tmp) {
        Copy-Item -Force $tmp $OutPath
        Remove-Item -Force $tmp
        return $true
    }
    return $false
}

# ---------- 1) 界面图标 ----------
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
$ok = 0; $fail = @()
foreach ($svg in Get-ChildItem $srcDir -Filter *.svg | Where-Object { $_.Name -ne 'tuantuan.svg' } | Sort-Object Name) {
    $dst = Join-Path $outDir ($svg.BaseName + ".png")
    if (Rasterize-Svg $svg.FullName $dst $OutSize) {
        $ok++
        Write-Host "  $($svg.Name) -> $($svg.BaseName).png"
    } else {
        $fail += $svg.Name
    }
}
if ($fail.Count -gt 0) { Write-Warning "光栅化失败: $($fail -join ', ')" }
Write-Host "  rasterized $ok / $($ok + $fail.Count)"

# ---------- 2) 吉祥物团团 ----------
$mascotSvg = Join-Path $srcDir 'tuantuan.svg'
if (Test-Path $mascotSvg) {
    $mascotDir = Join-Path $root 'app/assets/mascot'
    if (-not (Test-Path $mascotDir)) { New-Item -ItemType Directory -Force -Path $mascotDir | Out-Null }
    $mascotPng = Join-Path $mascotDir 'tuantuan.png'
    # tuantuan.svg 首路径为覆盖全画布的白色舞台（M0 0 L1101 0 ...），
    # 光栅化前将其透明化，保证与 App 纸米背景自然融合
    $mascotClean = Join-Path $env:TEMP 'aa_tuantuan_stage_free.svg'
    $svgText = [System.IO.File]::ReadAllText($mascotSvg, [System.Text.UTF8Encoding]::new($false))
    # 全画布白色舞台路径（d="M 0.60 0.00 L 1101.20 ... Z" fill="#ffffff"）-> fill="none"
    $svgText = [regex]::Replace(
        $svgText,
        '<path\s+d="\s*M\s*0\.60\s*0\.00\s*L\s*1101\.20\s*0\.00\s*L\s*1101\.20\s*1024\.00\s*L\s*0\.60\s*1024\.00\s*Z"\s*fill="#ffffff"',
        '<path d="M 0 0 L 0 0 L 0 0 L 0 0 Z" fill="none"',
        [System.Text.RegularExpressions.RegexOptions]::None)
    [System.IO.File]::WriteAllText($mascotClean, $svgText, [System.Text.UTF8Encoding]::new($false))
    if (Rasterize-Svg $mascotClean $mascotPng $OutSize) {
        Write-Host "  tuantuan.svg -> app/assets/mascot/tuantuan.png（白舞台已移除）"
    } else {
        Write-Warning "吉祥物光栅化失败: tuantuan.svg"
    }
}
$ErrorActionPreference = $prevEap

# ---------- 3) Android 启动图标 ----------
# 优先 docs/pic/app图标.svg；其次 docs/pic/app图标.png；再回退商店主视觉（_master-1024.png）
$appIcon = Join-Path $srcDir 'app图标.svg'
if (-not (Test-Path $appIcon)) {
    $appIconPng = Join-Path $srcDir 'app图标.png'
    if (Test-Path $appIconPng) { $appIcon = $appIconPng }
}
if (-not (Test-Path $appIcon)) {
    $alt = Join-Path $root 'docs/store/icons/_master-1024.png'
    if (Test-Path $alt) { $appIcon = $alt; Write-Host "使用商店主视觉作为启动图标源: $alt" }
}
if (Test-Path $appIcon) {
    Write-Host "== 生成 Android 启动图标 =="
    Add-Type -AssemblyName System.Drawing
    $legacy = @(@('mipmap-mdpi',48),@('mipmap-hdpi',72),@('mipmap-xhdpi',96),@('mipmap-xxhdpi',144),@('mipmap-xxxhdpi',192))
    $fg = @(@('mipmap-mdpi',108),@('mipmap-hdpi',162),@('mipmap-xhdpi',216),@('mipmap-xxhdpi',324),@('mipmap-xxxhdpi',432))
    function Resize-Icon([string]$In, [string]$Out, [int]$Size, [double]$Inside) {
        $img = [System.Drawing.Bitmap]::FromFile($In)
        $outBmp = New-Object System.Drawing.Bitmap($Size, $Size)
        $g = [System.Drawing.Graphics]::FromImage($outBmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        if ($Inside -gt 0) {
            $g.Clear([System.Drawing.Color]::Transparent)
            $s = $Size * $Inside
            $g.DrawImage($img, [float](($Size - $s) / 2), [float](($Size - $s) / 2), [float]$s, [float]$s)
        } else { $g.DrawImage($img, 0, 0, $Size, $Size) }
        $g.Dispose(); $img.Dispose()
        try { $outBmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png) }
        finally { $outBmp.Dispose() }
    }
    foreach ($d in $legacy) { Resize-Icon $appIcon (Join-Path $resDir "$($d[0])\ic_launcher.png") $d[1] 0.0 }
    foreach ($d in $fg)     { Resize-Icon $appIcon (Join-Path $resDir "$($d[0])\ic_launcher_foreground.png") $d[1] 0.62 }
    Write-Host "  mipmaps updated"
}
Write-Host "== DONE =="
