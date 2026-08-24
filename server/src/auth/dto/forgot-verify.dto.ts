import { IsString, Length } from 'class-validator';

export class ForgotVerifyDto {
  @IsString()
  @Length(1, 32)
  accountName!: string;

  @IsString()
  @Length(1, 100)
  securityAnswer!: string;
}
