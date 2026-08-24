import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { RegularBillsService } from './regular-bills.service';
import { RegularBillsController } from './regular-bills.controller';
import { RegularBillsProcessor } from './regular-bills.processor';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    BullModule.registerQueue({ name: 'regular-bills' }),
    NotificationsModule,
  ],
  controllers: [RegularBillsController],
  providers: [RegularBillsService, RegularBillsProcessor],
  exports: [RegularBillsService],
})
export class RegularBillsModule {}
