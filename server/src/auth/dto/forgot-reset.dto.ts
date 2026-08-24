import { IsString, Length, MinLength } from 'class-validator';

export class ForgotResetDto {
  @IsString()
  @Length(6, 100)
  resetToken!: string;

  @IsString()
  @MinLength(6)
  newPassword!: string;
}
