# 「随分记账」微信小程序改造实施计划

> 共识产物(2025 经三轮拷问确认)。存量 Flutter App(1.0.10)**并存冻结**,本计划新增第三端原生微信小程序并接入现有 NestJS 后端;所有服务端改动均为**增量**,旧 App 行为零变化。

## 已定档核心决策

| 决策点 | 结论 |
|---|---|
| 定位 | 并存;App 冻结只修致命 bug |
| 技术栈 | 原生小程序 WXML/WXSS/TypeScript,monorepo 根新建 `miniprogram/` |
| 主体 | 个人主体,AppID `wx8940d1fa75403347`,对外名「随分记账」 |
| 登录 | wx.login 一键登录为主;老账号(accountName+密码)登录即绑定 openid(**方案A**:空壳号有数据弹警告后才切);支持解绑与设置密码;忘记密码复用安全问题链路 |
| MVP | 授权登录/绑定、首页账单流、群组(列表/创建/卡片分享进群)、记一笔(手动参与者、均摊/自定义金额)、账单详情编辑删除、结算计算确认、我的(头像昵称补填)、站内消息中心、忘记密码、about |
| 通知 | JPush→站内信全覆盖 + 一次性订阅消息(邀请响应/结算发布/催款 三模板);实时性=onShow 全量拉取+轻量轮询,SSE 不硬扛 |
| 视觉 | aa_design tokens 全迁移;品牌字(ZCOOL快东体/Caveat)子集化打字;custom-tab-bar 保住 4 tab+中央➕;转场简化为标准右滑入/淡入;团团吉祥物与手绘边框用 Canvas/SVG-CSS 重画;结算卡片 Canvas 2d 出图 |
| 部署 | **新开一台境内 VPS**(境外机无法备案),Docker Compose:NestJS+PostgreSQL+Redis+MinIO+Caddy;ICP 备案用户自办(1~4 周),期间开发版联调 |
| 数据模式 | mock 只作 UI 脚手架,API 层第一天按真实契约写 |
| 验收 | 用户装微信开发者工具 + miniprogram-automator 冒烟脚本 + 每里程碑真机预览 |

---

## P0 前置准备(用户侧,全程可并行)

1. ~~注册小程序~~ 已有(wx8940d1fa75403347);补充完成实名认证信息检查。
2. 小程序后台配置:
   - 类目建议「工具 > 效率」;
   - 《用户隐私保护指引》声明:选头像(相册)、摄像头(扫码)、昵称(填写能力);
   - request 合法域名:`https://api.<你的域名>`;downloadFile:`https://uploads.<你的域名>`(备案后再填,开发期勾"不校验合法域名")。
3. 订阅消息模板申请 3 张(个人主体一次性订阅):群邀请、结算发布、催款提醒 —— 拿到 templateId 备用。
4. 境内云购买:轻量应用服务器(2C4G 起)+ 域名;**立即提交 ICP 备案**(最长等待窗口,决定上线日期的其实是它)。
5. 获取微信公众平台 AppSecret,准备填入服务端 `.env`(只发给我方配置文件,勿入 git)。

## P1 服务端增量改造(不动任何旧端点语义)

1. Prisma schema 迁移:`User` 增加 `openid String? @unique`;`passwordHash`/安全问题字段允许为空(微信建号者无密码);补充迁移脚本。
2. 微信模块封装:
   - `code2Session` 客户端(jscode2session);
   - 稳定 access_token(stable_token)+ 订阅消息 `subscribeMessage.send`(单机内存缓存即可);
   - AppID/AppSecret/templateIds 全部走 env,缺省自动禁用(本地零配置可跑)。
3. Auth 新增端点:
   - `POST /auth/wechat/login {code}` → openid upsert 用户(accountName 自动生成 `wx_`+随机、唯一性重试;匿名昵称「团子_xxxx」)→ 签发与现网一致的 JWT;
   - `POST /auth/wechat/bind`(Bearer):校验密码→将当前 openid 写入该 User;若 openid 已挂存在数据的空壳号,返回需二次确认标志;
   - `DELETE /auth/wechat/bind` 解绑;
   - `PATCH /auth/password/init` 给纯微信号设首个密码;
   - 限流沿用 Throttler,login 单独收紧。
4. 通知发送扩展:NotificationsService.create 在 SSE+JPush 之后追加订阅消息通道(refType/refId 约定不变;templateId 未配置则静默跳过)。
5. 生产加固:关闭 Swagger、CORS 白名单、日志轮转;e2e 覆盖新端点 + 跑一遍既有测试保证旧 App 无回归。
6. 微调:`GET /app/version` 对小程序 UA 直接返回「以平台版本为准」的空更新(防止误弹 APK 更新逻辑,若移植了该页)。

## P2 小程序工程骨架(`miniprogram/`)

1. TS 工程 + eslint;构建脚本含 `env.js` 注入(API_BASE/USE_MOCK/APP_NAME)。
2. 分包规划:主包仅 tabBar 四页 + 登录;`packageGroup/*`、`packageAdd/*` 其余全部分包。
3. `custom-tab-bar`:4 tab(首页/群组/消息/我的)+ 中央 ➕ 浮出(半屏弹层挂根,支持预选群参数);图标直接复用 `app/assets` 现 PNG;未读数徽标接消息 store。
4. 设计系统迁移:
   - aa_colors/aa_tokens → WXSS CSS variables(纸米底 #FBF3E4、coral、不对称圆角、胶带色);
   - 字体子集化脚本(fonttools/pyftsubset,常用 3500 字+ASCII):ZCOOLKuaiLe、Caveat 子集 TTF 入包,正文系统字体栈;
   - 基础组件:paper_card、doodle_button、hand_text_field/hand_toggle/hand_tag/hand_amount、sketchy_border(SVG background)、grid_paper、empty_state、TuanTuan(Canvas 版);
   - 手绘翻页转场降级为标准右滑入/淡入(已定档)。
5. API 层:统一 `request`(信封 `{code,message,data}` 解析、Bearer 注入、401→wx.login 静默重登一次、错误码→中文文案映射表对齐 dio 版);mock 开关及 `mock_store.dart` 种子数据的 JS 形状移植(仅开发期生效)。
6. 状态管理:轻量全局 store(ts 显式订阅或 mobx-miniprogram-bindings 任一,倾向前者少依赖);登录守卫=首页 onShow 检查 token。

## P3 MVP 功能实现(按依赖分四批交付)

**批次①身份链路**:授权登录页(wx.login 静默 + 团团迎宾)、密码登录/绑定页、忘记密码页(答问题→resetToken→设新密)、首登引导补填提示(chooseAvatar + type=nickname,直传 `/uploads` 同链路)。*验收点:两条登录路径 + 解绑/设密闭环。*

**批次②记账主干**:首页账单流(群维度切换)、记一笔(参与者手输/群成员多选、均摊/自定义金额,整数分规则与服务端校验一致)、账单详情(mark-paid 编辑删除)。*验收点:记一笔到详情全流程可用。*

**批次③群组与结算**:群组列表/创建、邀请入口三件套(转发卡片 shareAppMessage 带 `scene`=inviteCode、扫一扫 `wx.scanCode` 顺手保留、粘贴口令页——parseInviteCode 宽容解析移植复用)、结算页(净值/最少转账方案/复制文案/**Canvas 收款卡图**保存相册/mark-paid/settle-all)。*验收点:两台手机互邀进群并完成一笔结算。*

**批次④消息与我**:消息中心(onShow 全量拉取 + 30s 可配轮询 + 角标;订阅消息授权请求在关键动作按钮上触发 wx.requestSubscribeMessage)、我的页(资料补填、账号安全:绑定状态/设置密码/修改密码、关于/协议静态页)。*验收点:个人主体审核所需页面齐备。*

## P4 生产部署(境内新机,Docker Compose 一键栈)

1. 目录 `deploy/`:`docker-compose.yml`(api/postgres/redis/minio/caddy)、`Caddyfile`(自动 HTTPS)、`.env.production.example`。
2. 域名规划:`api.<域>` 反代 NestJS(`/uploads` 文件由 api 直出或 `uploads.<域>` 指 MinIO,后者更优但要配公开桶策略)。
3. MinIO 桶 `aa-split` 沿用,bucketPolicy 公读;对象 URL 改为 MINIO_PUBLIC_ENDPOINT 绝对地址(前端 downloadFile 白名单指向它)。
4. 上线手册 README:初始化、prisma migrate deploy、seed、备份 cron(pg_dump+mc mirror)、故障排查。
5. 备案下发前全部走开发版联调;下发后在小程序后台补三个合法域名 → 体验版 → 提审。

## P5 联调、回归与提审

1. `miniprogram-automator` 冒烟:登录→建群→记一笔→结算 四步断言,CI/本地皆可跑。
2. Android 真机回归旧 App(重点:登录/记账/推送不受服务端改动影响)。
3. 提审材料:功能截图×5、演示短视频、类目证明、隐私声明一致性核对(声明的能力=实际使用的能力)。

## 本期明确不做

统计页、多币种汇率、全局搜索、定期账单、小票拍照上传与 OCR、Excel/CSV 导出、深色模式、WebSocket 实时通道、Redis pub/sub 化 SSE、iOS 相关(APK 自更新等)。

## 里程碑与顺序依赖

```
P0(你:备案+模板ID)───────────────┐
P1 服务端 ──► P2 骨架 ──► P3① ──► P3② ──► P3③ ──► P3④ ──► P4 部署 ──► P5 提审
              (P2 与 P1 可并行;P4 可与 P3③ 并行;P5 最终收口)
```
