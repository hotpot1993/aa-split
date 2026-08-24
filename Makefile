# AA分账App 常用命令
# 用法示例：
#   make server-install  安装服务端依赖
#   make server-dev      启动服务端开发模式
#   make server-test     运行服务端单测（含结算算法）
#   make app-analyze     客户端静态检查
#   make app-run         启动客户端（需已连模拟器/设备）

.PHONY: help server-install server-dev server-build server-test app-pub app-analyze app-test app-run app-shots app-release infra-up infra-down

help:
	@echo "AA分账App"
	@echo "  make server-install   服务端安装依赖"
	@echo "  make server-dev       服务端开发模式 (:3000/api/v1, Swagger /api/docs)"
	@echo "  make server-build     服务端构建"
	@echo "  make server-test      服务端单元测试(含结算算法)"
	@echo "  make app-pub          客户端安装依赖"
	@echo "  make app-analyze      客户端静态检查"
	@echo "  make app-test         客户端测试"
	@echo "  make app-run          客户端运行"
	@echo "  make app-shots        生成商店截图 (docs/store/screenshots/)"
	@echo "  make app-shots-brand  合成品牌化截图 (需先 make app-shots)"
	@echo "  make app-release      构建上架包 (AAB+APK, dist/release/, 需 key.properties)"
	@echo "  make infra-up         启动 postgres+redis+minio (docker compose)"
	@echo "  make infra-down      停止基础设施"

server-install:
	cd server && npm install

server-dev:
	cd server && npm run dev

server-build:
	cd server && npm run build

server-test:
	cd server && npm test

app-pub:
	cd app && flutter pub get

app-analyze:
	cd app && flutter analyze

app-test:
	cd app && flutter test

app-run:
	cd app && flutter run

app-shots:
	cd app && flutter test --update-goldens test/store_screenshots_test.dart
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts\compose-store-screenshots.ps1

app-shots-brand:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts\compose-store-screenshots.ps1

app-release:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-release.ps1

infra-up:
	docker compose up -d postgres redis minio

infra-down:
	docker compose down
