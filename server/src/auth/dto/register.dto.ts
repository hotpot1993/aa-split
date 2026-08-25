import {
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { DeviceInfoDto } from './device-info.dto';

export class RegisterDto {
  @IsString()
  @Length(3, 32)
  @Matches(/^[a-zA-Z0-9_]+$/, { message: '账户名只能包含字母、数字、下划线' })
  accountName!: string;

  @IsString()
  @MinLength(6)
  @Matches(/(?=.*[A-Za-z])(?=.*\d).{6,}/, {
    message: '密码至少 6 位，且需同时包含字母和数字',
  })
  password!: string;

  @IsOptional()
  @IsString()
  @MaxLength(24)
  nickname?: string;

  @IsString()
  @MaxLength(100)
  securityQuestion!: string;

  @IsString()
  @MaxLength(100)
  securityAnswer!: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => DeviceInfoDto)
  deviceInfo?: DeviceInfoDto;
}
