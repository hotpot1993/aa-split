import { IsOptional, IsString, MaxLength, Validate } from 'class-validator';
import { IsValidNickname } from '../../common/nickname.validator';

/** P50 编辑资料：昵称 / 头像 / 个性签名（全部可选，只更新传入字段） */
export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @Validate(IsValidNickname)
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
