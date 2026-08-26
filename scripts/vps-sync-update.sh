#!/usr/bin/env bash
# =============================================================================
# VPS 更新自动同步（更新源 = VPS 自托管 + GitHub 自动拉取）
#
# 更新流程（与用户确认的目标流程一致）：
#   GitHub 发布新版本（打 v* 标签 → Actions 正式签名构建并发布 Release）
#     → 本脚本（VPS 上 cron 每 15 分钟执行）自动从 GitHub Release 拉取
#       最新 `app-release.apk` 到 nginx `/apk/` 静态目录
#     → 自动更新 /opt/aa-split/.env 的 APP_VERSION_* 并重建 api 容器
#     → 客户端「检查更新」从服务端 /app/version 拿到 VPS 下载 URL 后下载安装
#
# 用法：
#   /opt/aa-split/scripts/sync-update.sh            # 立即同步一次
#   DRY_RUN=1 /opt/aa-split/scripts/sync-update.sh  # 只打印计划（不下载/不改 .env/不重建）
#
# 可覆盖环境变量：REPO / ENV_FILE / APK_DIR / COMPOSE_DIR / API_BASE / LOG / KEEP / DRY_RUN
# 依赖：bash + curl + python3（zip 校验用）；可选 jq、flock（建议安装 util-linux flock）
# =============================================================================
set -uo pipefail

REPO=${REPO:-hotpot1993/aa-split}
ENV_FILE=${ENV_FILE:-/opt/aa-split/.env}
APK_DIR=${APK_DIR:-/www/wwwroot/api.hotpot1993.top/apk}
COMPOSE_DIR=${COMPOSE_DIR:-/opt/aa-split}
API_BASE=${API_BASE:-https://api.hotpot1993.top}
LOG=${LOG:-/opt/aa-split/logs/sync-update.log}
LOCK_FILE=${LOCK_FILE:-/var/lock/aa-split-sync.lock}
DOWNLOAD_URL_PREFIX=${DOWNLOAD_URL_PREFIX:-https://github.com/$REPO/releases/download}
KEEP=${KEEP:-6}          # 保留最近 N 个带构建号的安装包（aa-split-v*-*.apk）
DRY_RUN=${DRY_RUN:-0}

mkdir -p "$(dirname "$LOG")" "$APK_DIR" 2>/dev/null || true
log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
fail() { log "ERROR: $*"; exit 1; }

# ---------- 并发保护：上一次同步还没结束就跳过本次 ----------
if [ "$DRY_RUN" != "1" ] && command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE" 2>/dev/null || true
  flock -n 9 2>/dev/null || { log "已有同步在运行，跳过本次"; exit 0; }
fi

log "=== 更新同步开始（DRY_RUN=$DRY_RUN）==="

# ---------- 1. 最新发行版标签（用 releases/latest 重定向，不占 API 限额）----------
LAST_URL=$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null) \
  || fail "GitHub releases/latest 不可达（$REPO）"
TAG=${LAST_URL##*/tag/}
if [ -z "$TAG" ] || [ "${TAG#v}" = "$TAG" ]; then
  fail "无法解析最新标签（$LAST_URL）"
fi
log "GitHub 最新发行版: $TAG"

# ---------- 2. 版本号：优先发行版 aa-version.txt 元数据（与安装包同批构建），
#            否则回退解析该标签提交的 app/pubspec.yaml ----------
VER=""; BUILD=""
META=$(curl -fsSL "$DOWNLOAD_URL_PREFIX/$TAG/aa-version.txt" 2>/dev/null || true)
if [ -n "$META" ]; then
  VER=$(printf '%s' "$META" | sed -n 's/^versionName=//p' | tr -d '\r' | head -1)
  BUILD=$(printf '%s' "$META" | sed -n 's/^versionCode=//p' | tr -d '\r' | head -1)
fi
if [ -z "$VER" ] || [ -z "$BUILD" ]; then
  SPEC=$(curl -fsSL "https://raw.githubusercontent.com/$REPO/$TAG/app/pubspec.yaml" 2>/dev/null | grep -m1 '^version:' || true)
  if [ -n "$SPEC" ]; then
    SPEC=${SPEC#version:}; SPEC=${SPEC//[[:space:]]/}
    VER=${SPEC%%+*}; BUILD=${SPEC#*+}
  fi
fi
[ -n "$VER" ] || fail "无法从 $TAG 解析版本名"
case "$BUILD" in *[!0-9]*|'') fail "构建号非法: '$BUILD'";; esac
BUILD=$((10#$BUILD))   # 规范化十进制（防前导零被当八进制，如 08/09）
log "发行版版本: $VER+$BUILD"

# ---------- 3. 与当前 .env 比较（构建号升则同步；相同/更低跳过）----------
[ -f "$ENV_FILE" ] || fail "未找到 $ENV_FILE（请先按部署指南完成 server 部署）"
CUR_BUILD=$(grep -E '^APP_VERSION_BUILD=' "$ENV_FILE" | tail -1 | cut -d= -f2- | tr -d '"' | tr -d ' ')
CUR_BUILD=${CUR_BUILD:-0}
case "$CUR_BUILD" in *[!0-9]*) CUR_BUILD=0;; esac
if [ "$BUILD" -le "$CUR_BUILD" ]; then
  log "已是最新（.env build=$CUR_BUILD ≥ GitHub $TAG build=$BUILD），跳过"
  exit 0
fi
log "检测到新版本: .env build=$CUR_BUILD → $TAG build=$BUILD"

# ---------- 4. 下载安装包到 nginx /apk/ ----------
FILE="$APK_DIR/aa-split-v$VER-$BUILD.apk"
URL="$API_BASE/apk/aa-split-v$VER-$BUILD.apk"
if [ "$DRY_RUN" = "1" ]; then
  log "DRY_RUN 计划：下载 $DOWNLOAD_URL_PREFIX/$TAG/app-release.apk → $FILE；.env 更新为 $VER+$BUILD，URL=$URL；docker compose up -d api"
  exit 0
fi
if [ ! -f "$FILE" ] || [ "$(stat -c%s "$FILE" 2>/dev/null || echo 0)" -lt 5000000 ]; then
  log "下载 app-release.apk（$TAG，请稍候 ~90MB）…"
  curl -fL --retry 3 --retry-delay 5 -o "$FILE.part" "$DOWNLOAD_URL_PREFIX/$TAG/app-release.apk" \
    || { rm -f "$FILE.part"; fail "APK 下载失败"; }
  SIZE=$(stat -c%s "$FILE.part" 2>/dev/null || echo 0)
  [ "$SIZE" -lt 5000000 ] && { rm -f "$FILE.part"; fail "下载文件过小（${SIZE} 字节），疑似错误页，已放弃"; }
  mv "$FILE.part" "$FILE"
fi
# 完整性校验：ZIP 魔数 + AndroidManifest.xml + dex/so + CRC
python3 - "$FILE" <<'PY' || fail "安装包校验失败: $FILE"
import sys, zipfile
f = sys.argv[1]
with open(f, 'rb') as fh:
    assert fh.read(2) == b'PK', 'not a zip file'
z = zipfile.ZipFile(f)
names = z.namelist()
assert 'AndroidManifest.xml' in names, 'no AndroidManifest.xml'
assert any(n.startswith(('classes', 'lib/')) for n in names), 'no dex/so'
assert z.testzip() is None, 'zip corrupt'
PY
log "下载/校验完成: $FILE ($(du -h "$FILE" | cut -f1))"
# 兜底同源文件名（客户端 downloadUrl 缺失时 fallback 到 /apk/aa-split-v<版本>.apk）
ln -f "$FILE" "$APK_DIR/aa-split-v$VER.apk" 2>/dev/null || cp -f "$FILE" "$APK_DIR/aa-split-v$VER.apk"

# ---------- 5. 更新说明：优先取该标签提交信息（习惯写法 = chore(release): 新版本 x（说明）），
#            其次保留 .env 现有 NOTES，最后给默认文案 ----------
NOTES=$(curl -fsSL "https://api.github.com/repos/$REPO/commits/$TAG" 2>/dev/null | python3 -c '
import sys, json
try:
    msg = json.load(sys.stdin)["commit"]["message"]
except Exception:
    msg = ""
line = (msg or "").split("\n")[0].strip()
for p in ("chore(release):", "docs(release):"):
    if line.startswith(p):
        line = line[len(p):].strip(); break
print(line[:200])' 2>/dev/null || true)
[ -n "$NOTES" ] || NOTES=$(grep -E '^APP_VERSION_NOTES=' "$ENV_FILE" | tail -1 | cut -d= -f2- | tr -d '"' || true)
[ -n "$NOTES" ] || NOTES="自动同步自 GitHub Release $TAG"

# ---------- 6. 写入 .env（APP_VERSION_LATEST / BUILD / URL / NOTES；缺行则追加）----------
set_env() {
  local key=$1 val=$2 esc
  esc=$(printf '%s' "$val" | sed 's/[\\&|]/\\&/g')
  if grep -qE "^$key=" "$ENV_FILE"; then
    sed -i "s|^$key=.*|$key=$esc|" "$ENV_FILE" || fail "写入 $key 失败"
  else
    printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE" || fail "追加 $key 失败"
  fi
}
set_env APP_VERSION_LATEST "$VER"
set_env APP_VERSION_BUILD "$BUILD"
set_env APP_VERSION_URL "$URL"
set_env APP_VERSION_NOTES "$NOTES"
log "已更新 $ENV_FILE: $VER+$BUILD → $URL"

# ---------- 7. 重建 api 容器让 .env 生效 ----------
(cd "$COMPOSE_DIR" && docker compose up -d api >>"$LOG" 2>&1) || fail "docker compose up -d api 失败（详见日志）"
log "api 容器已重建"

# ---------- 8. 验证线上版本接口 ----------
sleep 10
RESP=$(curl -fsS "$API_BASE/api/v1/app/version" 2>/dev/null || true)
if printf '%s' "$RESP" | grep -q "\"latestBuild\":$BUILD" && printf '%s' "$RESP" | grep -qF "$URL"; then
  log "验证通过：$RESP"
else
  fail "验证未通过（/app/version 未返回 $BUILD/$URL）：${RESP:-（无响应）}"
fi

# ---------- 9. 清理旧安装包（仅带构建号的文件，保留最近 KEEP 个）----------
if [ "$KEEP" -gt 0 ]; then
  ls -1t "$APK_DIR"/aa-split-v*-*.apk 2>/dev/null | tail -n "+$((KEEP + 1))" | xargs -r rm -f -- 2>/dev/null || true
fi

log "=== 同步完成 $VER+$BUILD ==="
