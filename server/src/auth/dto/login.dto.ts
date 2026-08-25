import { IsOptional, IsString, Length, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { DeviceInfoDto } from './device-info.dto';

export class LoginDto {
  @IsString()
  @Length(1, 32)
  accountName!: string;

  @IsString()
  @Length(1, 100)
  password!: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => DeviceInfoDto)
  deviceInfo?: DeviceInfoDto;
}
