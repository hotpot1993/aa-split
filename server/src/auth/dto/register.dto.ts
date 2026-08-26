import {
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
  MinLength,
  Validate,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { DeviceInfoDto } from './device-info.dto';
import { IsValidNickname } from '../../common/nickname.validator';

export class RegisterDto {
  @IsString()
  @Length(3, 16)
  @Matches(/^[a-zA-Z0-9_]+$/, { message: '账户名只能包含字母、数字、下划线' })
  accountName!: string;

  @IsString()
  @MinLength(8)
  @Matches(/(?=.*[A-Za-z])(?=.*\d).{8,}/, {
    message: '密码至少 8 位，且需同时包含字母和数字',
  })
  password!: string;

  @IsOptional()
  @IsString()
  @Validate(IsValidNickname)
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
