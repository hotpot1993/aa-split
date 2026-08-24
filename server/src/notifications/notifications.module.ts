import { Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { NotificationSseService } from './notification-sse.service';
import { JpushService } from './jpush.service';

@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService, NotificationSseService, JpushService],
  exports: [NotificationsService, NotificationSseService],
})
export class NotificationsModule {}
