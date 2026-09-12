-- AlterTable：非注册成员（占位账号）标记 + 认领合并去向
-- is_placeholder：该 users 行不代表真人，只是「非注册成员」的身份锚点
-- merged_into_user_id：被认领（合并到真实账号）后记录去向；保留行本身不删除，
--   避免迁移遗漏某处引用时外键悬空（见 docs/adr/0001-占位账号承载非注册成员.md）
ALTER TABLE "users" ADD COLUMN "is_placeholder" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "merged_into_user_id" UUID;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_merged_into_user_id_fkey" FOREIGN KEY ("merged_into_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
