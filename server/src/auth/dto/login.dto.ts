import { IsString, Length } from 'class-validator';

export class LoginDto {
  @IsString()
  @Length(1, 32)
  accountName!: string;

  @IsString()
  @Length(1, 100)
  password!: string;
}
