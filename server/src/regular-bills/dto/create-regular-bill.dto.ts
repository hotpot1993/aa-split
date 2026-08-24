import { Category, SplitType } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { BillCycle } from '@prisma/client';
import { BillParticipantDto } from '../../bills/dto/create-bill.dto';

export class CreateRegularBillDto {
  @IsUUID()
  groupId!: string;

  @IsString()
  @MaxLength(80)
  title!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  amountCents!: number;

  @IsEnum(Category)
  category!: Category;

  @IsEnum(SplitType)
  splitType!: SplitType;

  @IsEnum(BillCycle)
  cycle!: BillCycle;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(6)
  dayOfWeek?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(31)
  dayOfMonth?: number;

  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => BillParticipantDto)
  participants!: BillParticipantDto[];
}
