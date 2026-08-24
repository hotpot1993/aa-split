-- ============================================================
-- AA-split 线上测试数据清理（保留 uimini / TeamAA% 群 / Hotpot 账单及凭证）
-- 会话：按依赖顺序删除（receipts → bills → settlements → notifications
--       → regular_bills → group_members → groups → users）
-- 用法：psql -U aa -d aa_split -f /tmp/cleanup.sql
-- ============================================================
BEGIN;

-- 1) 保留范围：uimini（用户）与 TeamAA% 群（owner=uimini）
CREATE TEMP TABLE _keep_users AS
  SELECT id FROM users WHERE account_name = 'uimini';

CREATE TEMP TABLE _keep_groups AS
  SELECT g.id FROM groups g
  JOIN _keep_users ku ON ku.id = g.owner_id;

-- 2) receipts（先于 bills 删除）
DELETE FROM receipts
WHERE bill_id IN (
  SELECT id FROM bills
  WHERE group_id NOT IN (SELECT id FROM _keep_groups)
);

-- 2.5) bill_participants（先于 bills 删除）
DELETE FROM bill_participants
WHERE bill_id IN (
  SELECT id FROM bills
  WHERE group_id NOT IN (SELECT id FROM _keep_groups)
);

-- 3) bills（非保留群）
DELETE FROM bills
WHERE group_id NOT IN (SELECT id FROM _keep_groups);

-- 4) 结算记录（全清，结算方案可随时重新计算）
DELETE FROM settlements;

-- 5) 通知（全清，均为测试产生）
DELETE FROM notifications;

-- 6) 定期账单（全清）
DELETE FROM regular_bills;

-- 7) 群成员（非保留群）
DELETE FROM group_members
WHERE group_id NOT IN (SELECT id FROM _keep_groups);

-- 8) 群组（非保留）
DELETE FROM groups
WHERE id NOT IN (SELECT id FROM _keep_groups);

-- 9) 用户（保留 uimini 及其它可能存在的真实账号；测试账号全部删除）
DELETE FROM users
WHERE id NOT IN (SELECT id FROM _keep_users);

COMMIT;

-- 10) 汇总（清理后规模）
SELECT 'users' AS t, count(*) FROM users
UNION ALL SELECT 'groups', count(*) FROM groups
UNION ALL SELECT 'bills', count(*) FROM bills
UNION ALL SELECT 'notifications', count(*) FROM notifications
UNION ALL SELECT 'settlements', count(*) FROM settlements
UNION ALL SELECT 'receipts', count(*) FROM receipts;
