import { Category, SplitType } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

export class BillParticipantDto {
  @IsUUID()
  userId!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  shareAmountCents?: number;

  @IsOptional()
  @IsBoolean()
  exempt?: boolean;
}

export class CreateBillDto {
  @IsUUID()
  groupId!: string;

  @IsString()
  @MaxLength(80)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  location?: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  amountCents!: number;

  @IsDateString()
  billDate!: string; // YYYY-MM-DD

  @IsEnum(Category)
  category!: Category;

  @IsEnum(SplitType)
  splitType!: SplitType;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => BillParticipantDto)
  participants!: BillParticipantDto[];

  @IsUUID()
  payerId!: string;

  /** 草稿预上传的暂存凭证 id（拍/选后经 POST /receipts/pre-upload 获取；创建时绑定转正） */
  @IsOptional()
  @IsArray()
  @IsUUID(undefined, { each: true })
  receiptUploadIds?: string[];
}
