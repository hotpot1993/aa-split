import { IsString, Length, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @IsString()
  @Length(1, 100)
  currentPassword!: string;

  @IsString()
  @MinLength(6)
  newPassword!: string;
}
