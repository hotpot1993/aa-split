import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { JpushService } from './jpush.service';

describe('JpushService', () => {
  let service: JpushService;
  const configMock = (vals: Record<string, string>) => ({
    get: jest.fn((k: string, d?: string) => vals[k] ?? d),
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('未配置密钥时禁用（不发起请求）', async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        JpushService,
        { provide: ConfigService, useValue: configMock({}) },
      ],
    }).compile();
    service = moduleRef.get(JpushService);
    const spy = jest.spyOn(globalThis, 'fetch');
    await service.notify('u1', { title: 't', alert: 'a' });
    expect(spy).not.toHaveBeenCalled();
  });

  it('配置后按 alias 推送正确载荷；失败仅告警不抛错', async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        JpushService,
        {
          provide: ConfigService,
          useValue: configMock({
            JPUSH_APP_KEY: 'appkey123',
            JPUSH_MASTER_SECRET: 'master-secret',
          }),
        },
      ],
    }).compile();
    service = moduleRef.get(JpushService);

    const fetchMock = jest.fn().mockResolvedValue({ ok: true, status: 200 });
    jest.spyOn(globalThis, 'fetch').mockImplementation(fetchMock);

    await service.notify('u1', {
      title: '催款提醒',
      alert: '快还钱呀',
      refType: 'bill',
      refId: 'b1',
    });

    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe('https://api.jpush.cn/v3/push');
    expect(init.method).toBe('POST');
    const auth = Buffer.from('appkey123:master-secret').toString('base64');
    expect(init.headers.Authorization).toBe(`Basic ${auth}`);
    const body = JSON.parse(init.body);
    expect(body.audience).toEqual({ alias: ['u1'] });
    expect(body.notification.android.extras).toEqual({ refType: 'bill', refId: 'b1' });
    expect(body.notification.title).toBe('催款提醒');

    // 失败不抛（fire-and-forget 语义）
    const failMock = jest.fn().mockResolvedValue({ ok: false, status: 429, text: async () => 'limit' });
    jest.spyOn(globalThis, 'fetch').mockImplementation(failMock);
    await expect(
      service.notify('u1', { title: 't', alert: 'a' }),
    ).resolves.toBeUndefined();
  });
});
