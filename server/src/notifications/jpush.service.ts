import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * 极光推送（JPush v3 REST API）—— 免费版。
 * 用一个用户唯一的 alias（= userId）做推送目标；
 * 失败仅告警、不阻塞业务（通知本体已写库 + SSE）。
 *
 * 配置：JPUSH_APP_KEY / JPUSH_MASTER_SECRET / JPUSH_ENABLED（默认开，缺 key 自动禁用）
 * 说明：免费版每日 API 调用有限额；本 App 仅记账/催款/结清等低频事件触发。
 */
@Injectable()
export class JpushService {
  private readonly logger = new Logger(JpushService.name);
  private readonly enabled: boolean;
  private readonly appKey: string;
  private readonly masterSecret: string;
  private readonly base = 'https://api.jpush.cn/v3/push';

  constructor(private readonly config: ConfigService) {
    this.appKey = config.get('JPUSH_APP_KEY') || '';
    this.masterSecret = config.get('JPUSH_MASTER_SECRET') || '';
    this.enabled =
      config.get('JPUSH_ENABLED', 'true') !== 'false' &&
      this.appKey.length > 0 &&
      this.masterSecret.length > 0;
    if (!this.enabled) {
      this.logger.warn('极光推送未启用（缺 JPUSH_APP_KEY/JPUSH_MASTER_SECRET 或 JPUSH_ENABLED=false）');
    }
  }

  /**
   * 向单个用户（alias=userId）推送通知。
   * extras 携带 refType/refId 供点击跳转。
   */
  async notify(
    userId: string,
    payload: { title: string; alert: string; refType?: string | null; refId?: string | null },
  ): Promise<void> {
    if (!this.enabled) return;
    try {
      const auth = Buffer.from(`${this.appKey}:${this.masterSecret}`).toString('base64');
      // alias 规范：纯字母数字（UUID 去连字符），与客户端 setAlias 一致
      const alias = userId.replace(/-/g, '');
      const res = await fetch(this.base, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Basic ${auth}`,
        },
        body: JSON.stringify({
          platform: ['android'],
          audience: { alias: [alias] },
          notification: {
            alert: payload.alert,
            android: {
              alert: payload.alert,
              title: payload.title,
              // 前台也展示系统通知（极光要求字符串 '0'/'1'；默认 '0' 仅回调/InApp）
              display_foreground: '1',
              extras: {
                refType: payload.refType ?? '',
                refId: payload.refId ?? '',
              },
            },
          },
          options: { apns_production: false, time_to_live: 86400 },
        }),
      });
      if (!res.ok) {
        const body = await res.text().catch(() => '');
        this.logger.warn(`JPush 推送未成功(${userId}): ${res.status} ${body.slice(0, 200)}`);
      } else {
        const body = await res.text().catch(() => '');
        this.logger.log(`JPush 已推送(${userId}): ${body.slice(0, 120)}`);
      }
    } catch (e: any) {
      this.logger.warn(`JPush 推送异常(${userId}): ${e?.message}`);
    }
  }
}
