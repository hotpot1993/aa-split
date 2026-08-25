# 图标素材处理流水线（docs/pic -> app/assets/icons + Android/iOS 启动图标）
# 用法：powershell -ExecutionPolicy Bypass -File scripts/process-icons.ps1
# 功能：
#   1) 去除背景色（从四角采样底色，边缘洪水填充 => 透明，兼容近白/奶油/浅紫等底色）
#   2) 仅保留最大连通域（清除"AI生成"水印等孤立像素）
#   3) 内容包围盒裁剪（去余白）-> 512x512 透明底居中
#   4) app图标 -> 全部 Android mipmap 密度（传统全出血 + 自适应前景 62% 安全区）
#
# 素材命名约定：文件名 = 对应 emoji（⏰.png / 🔍.png ...），
# 下方 $map 将该 emoji 映射为资产的 ASCII 文件名（供 Dart 侧引用）。
param(
    [string]$SourceDir = "docs/pic",
    [int]$OutSize = 512
)
$ErrorActionPreference = "Stop"
$root  = Split-Path -Parent $PSScriptRoot
$srcDir = Join-Path $root $SourceDir
$outDir = Join-Path $root "app/assets/icons"
$resDir = Join-Path $root "app/android/app/src/main/res"

# ---------- 名称映射（emoji 文件名 -> 资源名） ----------
$map = [ordered]@{
    '⚙️.png'  = 'settings.png'
    '🔔.png'  = 'notify.png'
    '👥.png'  = 'group.png'
    '✏️.png'  = 'edit.png'
    '📢.png'  = 'broadcast.png'
    '📤.png'  = 'export.png'
    '🧾.png'  = 'receipt.png'
    '🪙.png'  = 'coin.png'
    '💌.png'  = 'mail.png'
    '📮.png'  = 'inbox.png'
    '📱.png'  = 'phone.png'
    '💻.png'  = 'laptop.png'
    '🔑.png'  = 'key.png'
    '🔒.png'  = 'lock.png'
    '🔐.png'  = 'locked.png'
    '📡.png'  = 'signal.png'
    '🎉.png'  = 'party.png'
    '🔥.png'  = 'flame.png'
    '🌙.png'  = 'moon.png'
    '😴.png'  = 'sleep.png'
    '☀️.png'  = 'sun.png'
    '📒.png'  = 'notebook.png'
    '🎧.png'  = 'headphone.png'
    '🎒.png'  = 'bag.png'
    '🌸.png'  = 'flower.png'
    '🥺.png'  = 'sad.png'
    '🕵️.png' = 'detective.png'
    '✨.png'  = 'sparkle.png'
    '🍲.png'  = 'food.png'
    '👑.png'  = 'crown.png'
    '💡.png'  = 'bulb.png'
    '📅.png'  = 'calendar.png'
    '⏰.png'  = 'clock.png'
    '📊.png'  = 'chart.png'
    '📋.png'  = 'clipboard.png'
    '📜.png'  = 'scroll.png'
    '📦.png'  = 'box.png'
    '📷.png'  = 'camera.png'
    '🔍.png'  = 'search.png'
    '🧮.png'  = 'abacus.png'
}

# ---------- C# 处理核心（C# 5 兼容：无局部函数） ----------
# 背景判定：与「四角采样出的底色」逐通道差 <= $tol 即可视为背景
# （近白 244+ 由角落采样天然覆盖；兼容奶油/浅紫等非纯白底色）。
$cs = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class IconProcessor {
  const int BG_TOL = 16;
  static bool IsBgNear(byte[] p, int i, int br, int bg, int bb) {
    int r = p[i * 4 + 2], g = p[i * 4 + 1], b = p[i * 4];
    int dr = r - br; if (dr < 0) dr = -dr;
    int dg = g - bg; if (dg < 0) dg = -dg;
    int db = b - bb; if (db < 0) db = -db;
    return dr <= BG_TOL && dg <= BG_TOL && db <= BG_TOL;
  }
  static void PushBg(byte[] p, bool[] v, Queue<int> q, int w, int h, int x, int y, int br, int bg, int bb) {
    int i = y * w + x; if (i < 0 || i >= w * h) return;
    if (!v[i] && IsBgNear(p, i, br, bg, bb)) { v[i] = true; q.Enqueue(i); }
  }
  public static void Cut(string src, string dst, int size) {
    using (var bmp = new Bitmap(src)) {
      var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
      var data = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
      int w = bmp.Width, h = bmp.Height;
      var px = new byte[data.Stride * h]; Marshal.Copy(data.Scan0, px, 0, px.Length);
      // 1) 四角 8x8 采样取底色（取与均值偏差最小的角，抗单角被内容污染）
      long[] sums = new long[12]; int[] cnt = new int[4];
      int[] cs = { 0 * 8, (w - 8) * 8, 0 * 8, (w - 8) * 8 };
      int[] ys = { 0, 0, h - 8, h - 8 };
      for (int k = 0; k < 4; k++) {
        for (int y = ys[k]; y < ys[k] + 8; y++) for (int x = cs[k] / 8; x < cs[k] / 8 + 8; x++) {
          int i = y * w + x; sums[k * 3] += px[i * 4 + 2]; sums[k * 3 + 1] += px[i * 4 + 1]; sums[k * 3 + 2] += px[i * 4];
          cnt[k]++;
        }
      }
      int[] avgs = new int[12];
      for (int k = 0; k < 4; k++) { avgs[k * 3] = (int)(sums[k * 3] / cnt[k]); avgs[k * 3 + 1] = (int)(sums[k * 3 + 1] / cnt[k]); avgs[k * 3 + 2] = (int)(sums[k * 3 + 2] / cnt[k]); }
      // 找两两相差最小的角（内容污染最少）
      int bx = 0, by = 0, bz = 0, bestD = int.MaxValue;
      for (int k = 0; k < 4; k++) {
        for (int j = k + 1; j < 4; j++) {
          int d = Math.Abs(avgs[k*3]-avgs[j*3]) + Math.Abs(avgs[k*3+1]-avgs[j*3+1]) + Math.Abs(avgs[k*3+2]-avgs[j*3+2]);
          if (d < bestD) { bestD = d; bx = (avgs[k*3]+avgs[j*3])/2; by = (avgs[k*3+1]+avgs[j*3+1])/2; bz = (avgs[k*3+2]+avgs[j*3+2])/2; }
        }
      }
      Console.WriteLine("  bg=(" + bx + "," + by + "," + bz + ")");
      // 2) 边缘洪水填充背景 -> alpha 0
      var q = new Queue<int>(); var v1 = new bool[w * h];
      for (int x = 0; x < w; x++) { PushBg(px, v1, q, w, h, x, 0, bx, by, bz); PushBg(px, v1, q, w, h, x, h - 1, bx, by, bz); }
      for (int y = 0; y < h; y++) { PushBg(px, v1, q, w, h, 0, y, bx, by, bz); PushBg(px, v1, q, w, h, w - 1, y, bx, by, bz); }
      while (q.Count > 0) { int i = q.Dequeue(); int x = i % w, y = i / w;
        PushBg(px, v1, q, w, h, x - 1, y, bx, by, bz); PushBg(px, v1, q, w, h, x + 1, y, bx, by, bz);
        PushBg(px, v1, q, w, h, x, y - 1, bx, by, bz); PushBg(px, v1, q, w, h, x, y + 1, bx, by, bz); }
      for (int i = 0; i < w * h; i++) if (v1[i]) px[i * 4 + 3] = 0;
      // 3) 仅保留最大连通域
      var comp = new int[w * h];
      for (int i = 0; i < w * h; i++) comp[i] = -1;
      var v2 = new bool[w * h]; var sizes = new List<long>(); int cid = 0;
      for (int i = 0; i < w * h; i++) {
        if (px[i * 4 + 3] > 12 && !v2[i]) {
          var cc = new Queue<int>(); cc.Enqueue(i); v2[i] = true; comp[i] = cid; long ccnt = 0;
          while (cc.Count > 0) {
            int j = cc.Dequeue(); ccnt++; int x = j % w, y = j / w;
            int jl = j - 1, jr = j + 1, ju = j - w, jd = j + w;
            if (x > 0 && !v2[jl] && px[jl * 4 + 3] > 12) { v2[jl] = true; comp[jl] = cid; cc.Enqueue(jl); }
            if (x < w - 1 && !v2[jr] && px[jr * 4 + 3] > 12) { v2[jr] = true; comp[jr] = cid; cc.Enqueue(jr); }
            if (y > 0 && !v2[ju] && px[ju * 4 + 3] > 12) { v2[ju] = true; comp[ju] = cid; cc.Enqueue(ju); }
            if (y < h - 1 && !v2[jd] && px[jd * 4 + 3] > 12) { v2[jd] = true; comp[jd] = cid; cc.Enqueue(jd); }
          }
          sizes.Add(ccnt); cid++;
        }
      }
      int best = -1; long bestS = -1;
      for (int c = 0; c < sizes.Count; c++) if (sizes[c] > bestS) { bestS = sizes[c]; best = c; }
      for (int i = 0; i < w * h; i++) if (px[i * 4 + 3] > 12 && comp[i] != best) px[i * 4 + 3] = 0;
      int minX = w, minY = h, maxX = -1, maxY = -1;
      for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
        if (comp[y * w + x] == best) {
          if (x < minX) minX = x; if (x > maxX) maxX = x;
          if (y < minY) minY = y; if (y > maxY) maxY = y;
        }
      }
      Marshal.Copy(px, 0, data.Scan0, px.Length); bmp.UnlockBits(data);
      if (maxX < 0) { maxX = w - 1; maxY = h - 1; minX = 0; minY = 0; }
      int cx = Math.Max(0, minX - 8), cy = Math.Max(0, minY - 8);
      int cw = Math.Min(w - 1, maxX + 8) - cx + 1, ch = Math.Min(h - 1, maxY + 8) - cy + 1;
      using (var srcPart = bmp.Clone(new Rectangle(cx, cy, cw, ch), PixelFormat.Format32bppArgb))
      using (var outBmp = new Bitmap(size, size))
      using (var g = Graphics.FromImage(outBmp)) {
        g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.Clear(Color.Transparent);
        float scale = Math.Min((float)(size * 0.92) / cw, (float)(size * 0.92) / ch);
        float dw = cw * scale, dh = ch * scale;
        g.DrawImage(srcPart, (size - dw) / 2, (size - dh) / 2, dw, dh);
        outBmp.Save(dst, ImageFormat.Png);
      }
    }
  }
}
'@
$tmpCs = Join-Path $env:TEMP "aa_icon_processor.cs"
Set-Content -Path $tmpCs -Value $cs -Encoding UTF8
Add-Type -Path $tmpCs -ReferencedAssemblies System.Drawing

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
Write-Host "== 处理界面图标 =="
foreach ($k in $map.Keys) {
    $src = Join-Path $srcDir $k
    if (-not (Test-Path $src)) { Write-Warning "missing source: $k"; continue }
    [IconProcessor]::Cut($src, (Join-Path $outDir $map[$k]), $OutSize)
    Write-Host "  $k -> $($map[$k])"
}

# ---------- Android 启动图标 ----------
# 优先 docs/pic/app图标.png；缺失时回退商店主视觉（docs/store/icons/_master-1024.png）
$appIcon = Join-Path $srcDir 'app图标.png'
if (-not (Test-Path $appIcon)) {
    $alt = Join-Path $root 'docs/store/icons/_master-1024.png'
    if (Test-Path $alt) { $appIcon = $alt; Write-Host "使用商店主视觉作为启动图标源: $alt" }
}
if (Test-Path $appIcon) {
    Write-Host "== 生成 Android 启动图标 =="
    $legacy = @(@('mipmap-mdpi',48),@('mipmap-hdpi',72),@('mipmap-xhdpi',96),@('mipmap-xxhdpi',144),@('mipmap-xxxhdpi',192))
    $fg = @(@('mipmap-mdpi',108),@('mipmap-hdpi',162),@('mipmap-xhdpi',216),@('mipmap-xxhdpi',324),@('mipmap-xxxhdpi',432))
    function Resize-Icon([string]$In, [string]$Out, [int]$Size, [double]$Inside) {
        $img = [System.Drawing.Bitmap]::FromFile($In)
        $outBmp = New-Object System.Drawing.Bitmap($Size, $Size)
        $g = [System.Drawing.Graphics]::FromImage($outBmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        if ($Inside -gt 0) { $g.Clear([System.Drawing.Color]::Transparent)
            $s = $Size * $Inside; $g.DrawImage($img, [float](($Size - $s) / 2), [float](($Size - $s) / 2), [float]$s, [float]$s) }
        else { $g.DrawImage($img, 0, 0, $Size, $Size) }
        $g.Dispose(); $img.Dispose()
        try { $outBmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png) }
        finally { $outBmp.Dispose() }
    }
    # 传统图标：原图全出血（保留纸米底色方块）
    foreach ($d in $legacy) { Resize-Icon $appIcon (Join-Path $resDir "$($d[0])\ic_launcher.png") $d[1] 0.0 }
    # 自适应前景：先去底转透明，再按 62% 居中（安全区 66/108）
    $fgTmp = Join-Path $env:TEMP "aa_icon_fg_cut.png"
    [IconProcessor]::Cut($appIcon, $fgTmp, 432)
    foreach ($d in $fg) { Resize-Icon $fgTmp (Join-Path $resDir "$($d[0])\ic_launcher_foreground.png") $d[1] 0.62 }
    Remove-Item -Force $fgTmp -ErrorAction SilentlyContinue
    Write-Host "  mipmaps updated"
}
Write-Host "== DONE =="
