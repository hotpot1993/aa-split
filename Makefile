# AA分账App 常用命令
# 用法示例：
#   make server-install  安装服务端依赖
#   make server-dev      启动服务端开发模式
#   make server-test     运行服务端单测（含结算算法）
#   make app-analyze     客户端静态检查
#   make app-run         启动客户端（需已连模拟器/设备）

.PHONY: help server-install server-dev server-build server-test app-pub app-analyze app-test app-run infra-up infra-down

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

infra-up:
	docker compose up -d postgres redis minio

infra-down:
	docker compose down
