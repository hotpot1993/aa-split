import { IsEnum, IsOptional, IsString, MaxLength } from 'class-validator';
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
}
