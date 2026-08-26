-- AlterTable
ALTER TABLE "groups" ADD COLUMN "default_exempt_user_ids" TEXT[] NOT NULL DEFAULT '{}';

-- AlterTable：昵称上限 24 → 32（客户端规则：最多 30 字符 / 16 个汉字）
ALTER TABLE "users" ALTER COLUMN "nickname" SET DATA TYPE VARCHAR(32);
