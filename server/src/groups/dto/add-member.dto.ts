import { IsString, Length } from 'class-validator';

export class AddMemberDto {
  @IsString()
  @Length(1, 32)
  accountName!: string;
}
