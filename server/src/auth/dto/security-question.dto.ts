import { IsString, Length } from 'class-validator';

/** P04 忘记密码第一步：按账户名查询安全问题（问题非机密，仅为答题提示） */
export class SecurityQuestionQueryDto {
  @IsString()
  @Length(3, 32)
  accountName!: string;
}
