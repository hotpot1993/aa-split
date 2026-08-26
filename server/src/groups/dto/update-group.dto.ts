import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { SplitType } from '@prisma/client';

export class UpdateGroupDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  avatarUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  intro?: string;

  @IsOptional()
  @IsEnum(SplitType)
  defaultSplitType?: SplitType;

  /** 默认免分摊人员（userId 列表；服务端校验必须为群内 active 成员） */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(50)
  defaultExemptUserIds?: string[];
}
