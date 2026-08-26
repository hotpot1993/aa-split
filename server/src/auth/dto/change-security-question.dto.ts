import { IsString, MaxLength } from 'class-validator';

export class ChangeSecurityQuestionDto {
  @IsString()
  @MaxLength(64)
  currentPassword!: string;

  @IsString()
  @MaxLength(100)
  securityQuestion!: string;

  @IsString()
  @MaxLength(100)
  securityAnswer!: string;
}
