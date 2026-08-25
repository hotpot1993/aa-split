import { NotificationsService } from './notifications.service';

describe('NotificationsService.pushDataEvent', () => {
  it('静默数据事件：仅推 SSE，不写通知库、不触极光推送', () => {
    const sse = { push: jest.fn() } as any;
    const jpush = { notify: jest.fn() } as any;
    const svc = new NotificationsService({} as any, sse, jpush);

    svc.pushDataEvent('u1', { refType: 'bill', refId: 'b1' });

    expect(sse.push).toHaveBeenCalledWith(
      'u1',
      expect.objectContaining({
        type: 'data',
        title: '',
        body: '',
        refType: 'bill',
        refId: 'b1',
      }),
    );
    expect(jpush.notify).not.toHaveBeenCalled();
  });
});
