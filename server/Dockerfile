# =============================================================
# AA分账App 服务端 Dockerfile（多阶段）
# deps(prisma generate) → build → runtime slim
# =============================================================

# ---- 依赖阶段：安装 + 生成 Prisma Client ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
COPY prisma ./prisma
RUN npm ci
RUN npx prisma generate

# ---- 构建阶段：编译 TS → dist ----
FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# ---- 运行阶段：精简镜像 ----
FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
# 仅拷贝运行时所需
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package*.json ./
COPY prisma ./prisma
# 本地存储默认目录
RUN mkdir -p /app/uploads
EXPOSE 3000
CMD ["node", "dist/main.js"]
