import { Transform } from 'class-transformer';
import { IsString, IsUUID, Length } from 'class-validator';

/**
 * 非注册成员（占位账号）相关 DTO。
 *
 * 名称规则（技术方案 §4.2）：长度 1–32、服务端 trim 并去除换行与控制字符；
 * 群内不可重名（与全体成员显示名比对，含已退出成员）；单群上限 50 人。
 */

/** 去除换行与控制字符后 trim —— 群主填写的显示名一律经过此净化 */
export function sanitizeDisplayName(raw: unknown): string {
  return String(raw ?? '')
    // eslint-disable-next-line no-control-regex
    .replace(/[\u0000-\u001f\u007f]/g, '')
    .trim();
}

/** 添加 / 改名共用：displayName */
export class PlaceholderMemberNameDto {
  @Transform(({ value }) => sanitizeDisplayName(value))
  @IsString()
  @Length(1, 32, { message: '名称长度需为 1–32 个字符' })
  displayName!: string;
}

/** 认领：把占位账号合并到目标真实账号 */
export class ClaimPlaceholderMemberDto {
  @IsUUID()
  targetUserId!: string;
}

/** 认领前预览（只读）：确认弹窗需要「将合并 N 笔账单、M 条历史结算」 */
export class ClaimPreviewQueryDto {
  @IsUUID()
  targetUserId!: string;
}
