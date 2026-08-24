# ============================================================
# AA-split dev database script (Windows, no Docker)
#
# Runs a real local PostgreSQL 16 (portable EDB binaries) for
# server integration: default 127.0.0.1:5432.
#
# Usage (repo root):
#   powershell -ExecutionPolicy Bypass -File scripts\dev-db.ps1 init
#   powershell -ExecutionPolicy Bypass -File scripts\dev-db.ps1 start
#   powershell -ExecutionPolicy Bypass -File scripts\dev-db.ps1 status
#   powershell -ExecutionPolicy Bypass -File scripts\dev-db.ps1 stop
#   powershell -ExecutionPolicy Bypass -File scripts\dev-db.ps1 psql
#
# Binaries + data cached under %LOCALAPPDATA%\aa-dsh-dev (not in repo).
# Credentials match server/.env defaults: aa / aa_dev_password / aa_split
# ============================================================
param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'start', 'stop', 'status', 'psql')]
    [string]$Action = 'status'
)

$ErrorActionPreference = 'Stop'
$dev = Join-Path $env:LOCALAPPDATA 'aa-dsh-dev'
$zip = Join-Path $dev 'postgresql-16.12-binaries.zip'
$url = 'https://get.enterprisedb.com/postgresql/postgresql-16.12-1-windows-x64-binaries.zip'
$pgHome = Join-Path $dev 'pgsql'
$pgData = Join-Path $dev 'pgdata'
$pgLog = Join-Path $dev 'pg.log'
$pwFile = Join-Path $dev 'pgpw.txt'

$superUser = 'aa'
$superPass = 'aa_dev_password'
$dbName = 'aa_split'

function Start-PgServer {
    $pgCtl = Join-Path $pgHome 'bin\pg_ctl.exe'
    $pgIsReady = Join-Path $pgHome 'bin\pg_isready.exe'
    # Start-Process 避免 pwsh 因句柄继承挂起（pg_ctl 启动的子进程不退出）
    $p = Start-Process -FilePath $pgCtl -ArgumentList @('-D', "`"$pgData`"", '-l', "`"$pgLog`"", '-o', '-p 5432', '-w', 'start') `
        -WindowStyle Hidden -PassThru
    $p.WaitForExit()
    # 轮询等待就绪
    for ($i = 0; $i -lt 30; $i++) {
        & $pgIsReady -h 127.0.0.1 -p 5432 | Out-Null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Milliseconds 500
    }
    throw '[dev-db] server not ready; see pg.log'
}

function Invoke-Init {
    if (-not (Test-Path (Join-Path $pgHome 'bin\initdb.exe'))) {
        New-Item -ItemType Directory -Force -Path $dev | Out-Null
        if (-not (Test-Path $zip)) {
            Write-Host '[dev-db] downloading binaries (~370MB, once)...'
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 1800
        }
        Write-Host '[dev-db] extracting...'
        Expand-Archive -Path $zip -DestinationPath $dev -Force
        if (-not (Test-Path $pgHome)) {
            throw "[dev-db] extracted dir not found: $pgHome"
        }
    }

    if (-not (Test-Path (Join-Path $pgData 'PG_VERSION'))) {
        Write-Host "[dev-db] initdb (superuser=$superUser, db=$dbName)..."
        Set-Content -Path $pwFile -Value $superPass -NoNewline -Encoding ascii
        & (Join-Path $pgHome 'bin\initdb.exe') -D $pgData -U $superUser -E UTF8 `
            --locale=C -A scram-sha-256 --pwfile=$pwFile | Out-Host
        if ($LASTEXITCODE -ne 0) { throw '[dev-db] initdb failed' }
        Remove-Item $pwFile -Force
    }

    Start-PgServer

    $env:PGPASSWORD = $superPass
    $psql = Join-Path $pgHome 'bin\psql.exe'
    & $psql -h 127.0.0.1 -p 5432 -U $superUser -d postgres -Atc 'SELECT 1' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw '[dev-db] cannot connect' }

    # allow prisma migrate dev to create its shadow database
    & $psql -h 127.0.0.1 -p 5432 -U $superUser -d postgres -c "ALTER ROLE $superUser CREATEDB" | Out-Host
    $exists = & $psql -h 127.0.0.1 -p 5432 -U $superUser -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname='$dbName'"
    if ($exists -ne '1') {
        & $psql -h 127.0.0.1 -p 5432 -U $superUser -d postgres -c "CREATE DATABASE $dbName" | Out-Host
    }
    Write-Host "[dev-db] ready: postgresql://${superUser}:${superPass}@127.0.0.1:5432/${dbName}"
}

function Invoke-Start {
    $pgCtl = Join-Path $pgHome 'bin\pg_ctl.exe'
    if (-not (Test-Path $pgCtl)) { throw '[dev-db] not initialized; run init first' }
    Start-PgServer
    Write-Host "[dev-db] started (log: $pgLog)"
}

function Invoke-Stop {
    $pgCtl = Join-Path $pgHome 'bin\pg_ctl.exe'
    if (-not (Test-Path $pgCtl)) { return }
    & $pgCtl -D $pgData stop -m fast | Out-Host
}

function Invoke-Status {
    $pgCtl = Join-Path $pgHome 'bin\pg_ctl.exe'
    if (-not (Test-Path $pgCtl)) {
        Write-Host '[dev-db] NOT initialized (run: scripts\dev-db.ps1 init)'
        return
    }
    & $pgCtl -D $pgData status | Out-Host
}

function Invoke-Psql {
    $psql = Join-Path $pgHome 'bin\psql.exe'
    if (-not (Test-Path $psql)) { throw '[dev-db] not initialized' }
    $env:PGPASSWORD = $superPass
    & $psql -h 127.0.0.1 -p 5432 -U $superUser -d $dbName
}

switch ($Action) {
    'init'   { Invoke-Init }
    'start'  { Invoke-Start }
    'stop'   { Invoke-Stop }
    'status' { Invoke-Status }
    'psql'   { Invoke-Psql }
}
