# AA分账App — VPS 部署指南（docker compose 单机）

> 首次部署：2026-08-24 · 验证：smoke 22/22 + SSE 实时推送 ✅ · 2026-08-26 **v1.0.5 更新链路已验证**（检查更新 → APK 下载安装）· 2026-08-27 **更新源全自动**（v1.0.7+5000）：`sync-update.sh` 定时任务自动从 GitHub 拉取安装包 + 同步版本接口 ✅

## 一、服务器概况

| 项 | 值 |
|---|---|
| 公网 IP | `103.11.77.228`（Ubuntu 24.04 x86_64，2GB 内存） |
| 主机名 | `www.hotpot1993.top`（域名在 Cloudflare 后面，未接反代） |
| 面板 | 宝塔面板（BT-Panel 24381；nginx 监听 80/888 未使用；MySQL 3306 未使用） |
| Docker | Docker 29.7.2 + Compose v5.5.0（get.docker.com 安装） |
| 部署目录 | `/opt/aa-split`（源码 + `docker-compose.yml` + `.env` + `deploy-env.sh`） |
| 容器 | `aa-postgres`(16-alpine) / `aa-redis`(7-alpine) / `aa-minio`(latest) / `aa-api`(本地构建) / `aa-split-minio-init-1`(一次性建桶) |
| 密钥 | `.env` 由 `deploy-env.sh` 随机生成（PG 密码 / JWT×2 / MINIO×2），chmod 600 |
| 防火墙 | ufw 开放 20/21/22/80 + **3000/tcp**（API 直连） |

> ⚠️ 运维凭据在 `docs/vps.txt`（已 gitignore，**切勿提交/外泄**；建议尽快轮换服务器密码并改 SSH Key）。

## 二、服务端点（公网已验证）

| 地址 | 说明 |
|---|---|
| <http://103.11.77.228:3000/api/v1/health> | 健康检查 ✅ |
| <http://103.11.77.228:3000/api/docs> | Swagger（SWAGGER_ENABLED=true） |
| `GET /api/v1/notifications/stream?access_token=<JWT>` | SSE 推送（25s 心跳）✅ 已实测 |
| <http://103.11.77.228:9001> | MinIO 控制台（未放行 ufw，仅容器网络可用） |

## 三、常用运维命令（SSH root@103.11.77.228）

```bash
cd /opt/aa-split

docker compose ps                          # 状态（api/postgres/redis/minio）
docker compose logs -f --tail 100 api      # API 日志
docker compose restart api                 # 重启
docker compose down                        # 停止（保留数据卷）
docker compose up -d --build api           # 改源码后重建上线
```

升级流程：pscp 上传 `server/` 变更 → `docker compose up -d --build api`（构建含 `npm ci`，本机网络约 10 分钟，请耐心）。

**发版更新「检查更新」版本**（更新源 = VPS 自托管 + **GitHub 自动拉取**，详见 [发版 SOP](./开发进度.md#十发版-sop每次发行照此执行)：GitHub Release 发布新版本 → VPS 定时任务自动从 GitHub 下载安装包到 `/apk/` 并同步更新版本接口 → App 从 VPS 拉取下载安装；**无任何人工上传步骤**）：

**① 一次性安装自动同步任务**（发版后 ≤15 分钟自动生效；支持手动立即执行）：

```bash
# 脚本落位（仓库已推送到 GitHub 则 raw 直取；否则从本仓库 scripts/vps-sync-update.sh 上传）
mkdir -p /opt/aa-split/scripts /opt/aa-split/logs
curl -fsSL https://raw.githubusercontent.com/hotpot1993/aa-split/master/scripts/vps-sync-update.sh \
  -o /opt/aa-split/scripts/sync-update.sh
chmod +x /opt/aa-split/scripts/sync-update.sh

# 安装定时任务（每 15 分钟；幂等，保留已有 crontab 条目）
( crontab -l 2>/dev/null | grep -vF '/opt/aa-split/scripts/sync-update.sh'
  echo '*/15 * * * * /opt/aa-split/scripts/sync-update.sh' ) | crontab -

# 立即手动同步一次（首次运行会把 VPS 对齐到 GitHub 当前最新版）
/opt/aa-split/scripts/sync-update.sh
tail -n 20 /opt/aa-split/logs/sync-update.log
```

**② 自动同步做什么**：GitHub `releases/latest` 取最新标签 → 版本号（发行版资产 `aa-version.txt` 优先，回退标签提交 `app/pubspec.yaml`）→ 与 `.env` `APP_VERSION_BUILD` 比较（更大才更新，相同直接跳过）→ 下载 `app-release.apk` 到 `/www/wwwroot/api.hotpot1993.top/apk/aa-split-vX.Y.Z-BBBBB.apk`（`.part` 临时文件 + ZIP 完整性校验 + 同源兜底硬链）→ 更新 `.env` 四项（`APP_VERSION_LATEST / BUILD / URL / NOTES`）→ `docker compose up -d api` → 校验 `GET /api/v1/app/version` 返回新版本+新 URL → 清理旧包（保留 6 个）。重复运行无副作用。

**③ 验证**：

```bash
DRY_RUN=1 /opt/aa-split/scripts/sync-update.sh              # 只打印同步计划（不下载/不改配置/不重建）
curl -s https://api.hotpot1993.top/api/v1/app/version       # latestVersion=X.Y.Z build=BBBBB + VPS URL
curl -sIL https://api.hotpot1993.top/apk/aa-split-vX.Y.Z-BBBBB.apk  # HTTP/2 200
```

数据卷：`aa-split_pgdata` / `aa-split_redisdata` / `aa-split_miniodata`（`docker volume ls`）。

远程回归（仓库根目录，域名与直连均可用）：

```bash
AA_API_BASE=https://api.hotpot1993.top/api/v1 node scripts/smoke-api.mjs   # 22/22 全绿
AA_API_BASE=https://api.hotpot1993.top/api/v1 node scripts/sse-check.mjs   # SSE 事件
```

## 四、部署过程踩坑记录（重要）

1. **Prisma × Alpine 3.23 引擎问题**（两段式，均已在仓库修复）：
   - `node:20-alpine` 运行镜像缺 libssl → `Dockerfile` 两阶段均加 `apk add --no-cache openssl libc6-compat`（deps 阶段：让 `prisma generate` 正确检测 musl-openssl；runtime：引擎加载 libssl.so.3）
   - generate 仍只产出 `linux-musl` 引擎、运行时要求 `linux-musl-openssl-3.0.x` → `schema.prisma` generator 增加
     `binaryTargets = ["native", "linux-musl-openssl-3.0.x"]`
2. **.env 生成反斜杠事故**：远程 heredoc 中写 `\$(openssl rand …)`，bash 解析为「反斜杠+值」→ MinIO 签名不匹配 → 改用仓库内 `scripts/deploy-env.sh`（先算变量再展开 heredoc，无转义陷阱）；重来时 `docker compose down -v` 重清库。
3. **compose up 偶发卡住**：api 容器被改名（`52895c…_aa-api`）且状态停在 Created → 杀进程/删容器后手动 `docker start` 或重新 compose up 即可；根因是并发跑了两个 compose 构建。
4. **Server 首次起不来的原因正是本地联调时发现的 Redis 缺陷**：无 Redis 时 `queue.add` 永久等待（已在 `regular-bills.processor.ts` 修复，3s 超时降级）。

## 五、待办 / 建议

1. ~~**接入域名与 HTTPS**~~ ✅ 已完成（2026-08-26）：Cloudflare 解析 `api.hotpot1993.top A 103.11.77.228`（橙云代理），宝塔 nginx 反代 `/www/server/nginx/conf/vhost/aa-split-api.conf`（`proxy_buffering off` + 3600s 超时，SSE 友好），HTTPS + `/apk/` 静态导出均实测可用
2. **备份**：`pgdata` 卷 + `.env`（每周建议快照）。
3. **监控**：`docker compose ps` + 每周跑一次 `node scripts/smoke-api.mjs`；CI（smoke.yml）已备好，推送远端后自动回归。
4. **安全加固**：轮换 root 密码、改 SSH Key 登录、BT 面板 24381 仅白名单 IP。
5. **客户端联调**：真机 APK 已用 `AA_USE_MOCK=false + AA_API_BASE=http://103.11.77.228:3000/api/v1` 构建安装；`test/live_api_test.dart` 可在任何机器对该地址跑全链路回归。
