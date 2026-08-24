import { Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { NotificationSseService } from './notification-sse.service';

@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService, NotificationSseService],
  exports: [NotificationsService, NotificationSseService],
})
export class NotificationsModule {}
