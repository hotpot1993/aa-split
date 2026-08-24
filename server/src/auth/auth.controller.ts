import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { JwtPayload } from '../common/types';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { ForgotVerifyDto } from './dto/forgot-verify.dto';
import { ForgotResetDto } from './dto/forgot-reset.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { SecurityQuestionQueryDto } from './dto/security-question.dto';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Public()
  @Throttle({ default: { limit: 5, ttl: 600000 } }) // 登录单独限流 5 次 / 10 分钟
  @HttpCode(HttpStatus.OK)
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('forgot/verify')
  forgotVerify(@Body() dto: ForgotVerifyDto) {
    return this.authService.forgotVerify(dto);
  }

  /** P04：忘记密码第一步 — 查询账户的安全问题（问题非机密） */
  @Public()
  @Get('security-question')
  securityQuestion(@Query() query: SecurityQuestionQueryDto) {
    return this.authService.getSecurityQuestion(query.accountName);
  }

  @Public()
  @HttpCode(HttpStatus.OK)
  @Post('forgot/reset')
  forgotReset(@Body() dto: ForgotResetDto) {
    return this.authService.forgotReset(dto);
  }

  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @Post('change-password')
  changePassword(
    @CurrentUser() user: JwtPayload,
    @Body() dto: ChangePasswordDto,
  ) {
    return this.authService.changePassword(user.sub, dto);
  }

  @ApiBearerAuth()
  @Get('me')
  me(@CurrentUser() user: JwtPayload) {
    return this.authService.me(user.sub);
  }

  /** P50：编辑个人资料（昵称 / 头像 / 个性签名） */
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @Patch('me')
  updateProfile(@CurrentUser() user: JwtPayload, @Body() dto: UpdateProfileDto) {
    return this.authService.updateProfile(user.sub, dto);
  }

  /**
   * 注销账号（商店合规：应用内删除账号）。
   * 软删除 + 匿名化，群主身份自动转移，旧 token 立即失效。
   */
  @ApiBearerAuth()
  @HttpCode(HttpStatus.OK)
  @Delete('me')
  deleteAccount(@CurrentUser() user: JwtPayload) {
    return this.authService.deleteAccount(user.sub);
  }
}
