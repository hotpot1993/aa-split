import { IsEnum, IsOptional, IsString, Length, MaxLength } from 'class-validator';
import { SplitType } from '@prisma/client';

export class CreateGroupDto {
  @IsString()
  @Length(1, 50)
  name!: string;

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
