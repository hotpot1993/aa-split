/**
 * 占位账号（「非注册成员」的身份锚点）共用常量。
 * 设计背景见 CONTEXT.md「非注册成员」/「占位账号」与
 * docs/adr/0001-占位账号承载非注册成员.md。
 */

/**
 * 账户名前缀。注册规则为 `^[a-zA-Z0-9_]+$`（auth/dto/register.dto.ts），
 * 因此真人从结构上无法注册出同名账户 —— 这只是第二道防线，
 * 真正的隔离靠 `isPlaceholder` 过滤（模糊搜索能命中子串）。
 */
export const PLACEHOLDER_PREFIX = '~guest_';

/**
 * 占位账号的密码 / 安全问题哈希：bcrypt(12) 一个已丢弃的随机串，
 * 任何输入都无法匹配。配合「登录 / 找回密码显式拒绝占位账号」构成双重保险。
 */
export const PLACEHOLDER_SECRET_HASH =
  '$2a$12$s3yN8/2Y/niA026Qy8pTVuQ4eppgPVDbkFrVInCda0FbLkFf/Betq';
