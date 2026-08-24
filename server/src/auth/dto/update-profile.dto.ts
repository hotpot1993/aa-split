import { IsOptional, IsString, MaxLength } from 'class-validator';

/** P50 编辑资料：昵称 / 头像 / 个性签名（全部可选，只更新传入字段） */
export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(24)
  nickname?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  bio?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2048)
  avatarUrl?: string;
}
