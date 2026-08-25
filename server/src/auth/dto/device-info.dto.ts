import { IsOptional, IsString, MaxLength } from 'class-validator';

/** 登录设备快照（客户端上报；missing 则不记录设备，登录不受影响） */
export class DeviceInfoDto {
  @IsOptional()
  @IsString()
  @MaxLength(64)
  deviceId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(16)
  platform?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  deviceName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  osVersion?: string;
}
