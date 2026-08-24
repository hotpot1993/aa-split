import { IsBoolean, IsUUID } from 'class-validator';

export class MarkPaidDto {
  @IsUUID()
  userId!: string;

  @IsBoolean()
  paid!: boolean;
}
