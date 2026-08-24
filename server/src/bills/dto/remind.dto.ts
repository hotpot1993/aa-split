import { ArrayMinSize, IsArray, IsOptional, IsString, MaxLength, IsUUID } from 'class-validator';

export class RemindDto {
  @IsArray()
  @ArrayMinSize(1)
  @IsUUID('4', { each: true })
  userIds!: string[];

  @IsOptional()
  @IsString()
  @MaxLength(200)
  message?: string;
}
