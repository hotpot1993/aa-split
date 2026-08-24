import { Module } from '@nestjs/common';
import { BillsService } from './bills.service';
import { BillsController, GroupBillsController } from './bills.controller';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [NotificationsModule],
  controllers: [BillsController, GroupBillsController],
  providers: [BillsService],
  exports: [BillsService],
})
export class BillsModule {}
