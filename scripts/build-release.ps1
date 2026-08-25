# AA Split App - release build & packaging (production HTTPS, signed)
# Output: dist/release/  (appbundle + apk + sha256 + info)
# Usage : powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1 [-SplitAbi]
# Requirements: flutter on PATH, app/android/key.properties (release keystore)
param(
    [switch]$SplitAbi,   # also build per-ABI APKs (arm64/armeabi-v7a/x86_64)
    [string]$ApiBase = "https://api.hotpot1993.top/api/v1"
)
$ErrorActionPreference = "Stop"

$root  = Split-Path -Parent $PSScriptRoot
$app   = Join-Path $root "app"
$dist  = Join-Path $root "dist\release"
$version = (Select-String -Path (Join-Path $app "pubspec.yaml") -Pattern "^version:\s*([0-9.]+)\+(\d+)").Matches[0]
$verName = $version.Groups[1].Value; $verCode = $version.Groups[2].Value

# ---------- preflight ----------
if (-not (Test-Path (Join-Path $app "android\key.properties"))) {
    throw "key.properties missing: generate keystore first (see docs/store/listing-manual.md) then re-run. Abort."
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "flutter not found on PATH. Abort."
}

Write-Host "== Preflight =="
Write-Host "  version : $verName ($verCode)"
Write-Host "  api     : $ApiBase"
Write-Host "  signing : release keystore found"
try {
    $r = Invoke-WebRequest -Uri "$ApiBase/health" -TimeoutSec 8 -UseBasicParsing
    Write-Host "  live api: OK ($($r.StatusCode))"
} catch {
    Write-Warning "  live api: NOT REACHABLE ($($_.Exception.Message)) - build continues, but ensure HTTPS + DNS before upload"
}

# ---------- build ----------
$defines = @(
    "--dart-define=AA_USE_MOCK=false",
    "--dart-define=AA_API_BASE=$ApiBase"
)

Write-Host "== Building AAB =="
Push-Location $app
& flutter build appbundle --release @defines
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "appbundle build failed" }

Write-Host "== Building APK (universal) =="
& flutter build apk --release @defines
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "apk build failed" }

if ($SplitAbi) {
    Write-Host "== Building APK (per-abi) =="
    & flutter build apk --release --split-per-abi @defines
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw "per-abi apk build failed" }
}
Pop-Location

# ---------- collect ----------
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$buildDir = Join-Path $app "build\app\outputs"
Get-ChildItem (Join-Path $buildDir "bundle\release") -Filter "*.aab" -ErrorAction SilentlyContinue |
    Copy-Item -Destination $dist -Force
# collect release-variant APKs only (exclude stale debug apk)
Get-ChildItem (Join-Path $buildDir "flutter-apk") -Filter "app-release.apk" -ErrorAction SilentlyContinue |
    Copy-Item -Destination $dist -Force
# per-ABI 分包：仅 -SplitAbi 且本次构建过时才收集，避免旧产物混入
if ($SplitAbi) {
    Get-ChildItem (Join-Path $buildDir "flutter-apk") -Filter "app-*-release.apk" -ErrorAction SilentlyContinue |
        Copy-Item -Destination $dist -Force
} else {
    Get-ChildItem $dist -Filter "app-*-release.apk" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

$files = Get-ChildItem $dist -File
$sha = foreach ($f in $files) {
    $h = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
    "$h  $($f.Name)"
}

$ksPath = Join-Path $app "android\keystore\release.jks"
$ksPass = [regex]::Match((Get-Content (Join-Path $app "android\key.properties") -Raw), "storePassword=(\S+)").Groups[1].Value
$fingerprint = (& keytool -list -v -keystore $ksPath -storepass $ksPass -alias aasplit 2>$null |
    Select-String -Pattern "SHA256:" | Select-Object -First 1).Line.Trim()

$info = @"
AA Split App - release package
  versionName : $verName
  versionCode : $verCode
  applicationId: com.aasplit.app
  apiBase     : $ApiBase
  signedAt    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  signer      : aasplit (RSA 2048, valid 10000 days)
  SHA256 cert : $fingerprint

files:
$(($sha | ForEach-Object { "  $_" }) -join [Environment]::NewLine)
"@
$info | Set-Content (Join-Path $dist "INFO.txt") -Encoding UTF8
Write-Host "== DONE -> $dist =="
Get-ChildItem $dist | Select-Object Name, Length
exit 0