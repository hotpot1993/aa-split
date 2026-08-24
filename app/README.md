# AA分账App — Flutter 客户端

手绘风 AA 分账 App（Flutter + Riverpod + go_router + dio），设计系统见 `packages/aa_design`。

## 运行

```bash
flutter pub get
flutter run            # Demo 模式（默认，无后端可完整走通 31 页原型）
```

### Demo 模式 ⚙️

默认 `AppConfig.useMock = true`：所有数据来自 `lib/data/mock/mock_store.dart`
（演示用户"团子酱"、3 个群、带分摊/已付状态账单、通知、定期账单）。

### 连接真实后端（联调清单）

1. 启动服务端（见 `server/README.md`，需 PostgreSQL 16；`npx prisma db push` 后 `npm run dev`）
2. 关闭 Demo 并指向后端：

```bash
flutter run --dart-define=AA_USE_MOCK=false \
            --dart-define=AA_API_BASE=http://10.0.2.2:3000/api/v1   # Android 模拟器
# iOS 模拟器/真机本机后端：http://127.0.0.1:3000/api/v1
# 真机同局域网：     http://<电脑局域网IP>:3000/api/v1
```

3. 将 `lib/data/repositories/*.dart` 中 `useMock=false` 分支由 `UnsupportedError`
   改为调用 `ApiClient`（端点即服务端 README「API 一览」，客户端模型与
   `{code,message,data}` 信封已就绪，改动为一对一映射）。

## 目录

```
lib/
├── main.dart                 # ProviderScope + MaterialApp.router
├── router/app_router.dart    # go_router：/ /login /register /forgot /home /groups /messages /profile /add /bills/* /groups/* /settings /security /export /about /search
├── core/                     # config（baseUrl/useMock）、api_client（dio+JWT+统一响应）、utils
├── models/                   # User/Group/Bill/SettlementPlan/NotificationItem/...
├── data/
│   ├── mock/                 # Demo 数据
│   └── repositories/         # Auth/Group/Bill/Settlement/Notification
├── providers/                # Riverpod（auth/refresh/data/settings）
└── screens/                  # P01~P60 全部页面
```

## 测试

```bash
flutter analyze   # 0 issues
flutter test      # widget_test（主流程）+ aa_design 组件渲染测试
```
