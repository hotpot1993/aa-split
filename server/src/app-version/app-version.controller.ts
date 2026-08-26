import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { Public } from '../common/decorators/public.decorator';

/**
 * App 版本信息（公开接口，供客户端「检查更新」）。
 * 发布新版本时在 VPS .env 中更新：
 *   APP_VERSION_LATEST / APP_VERSION_BUILD / APP_VERSION_URL / APP_VERSION_NOTES
 * 并在 /www/wwwroot/api.hotpot1993.top/apk/ 放置安装包（nginx 静态托管）。
 */
@ApiTags('app-version')
@Controller('app/version')
export class AppVersionController {
  constructor(private readonly cfg: ConfigService) {}

  @Public()
  @Get()
  latest() {
    const latestVersion = this.cfg.get<string>('APP_VERSION_LATEST') || '1.0.3';
    const latestBuild = Number(this.cfg.get('APP_VERSION_BUILD') || 2004);
    const downloadUrl =
      this.cfg.get<string>('APP_VERSION_URL') ||
      `https://api.hotpot1993.top/apk/aa-split-v${latestVersion}.apk`;
    const notes = this.cfg.get<string>('APP_VERSION_NOTES') || '';
    return { latestVersion, latestBuild, downloadUrl, notes };
  }
}
