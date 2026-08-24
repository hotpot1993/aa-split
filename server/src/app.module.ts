import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { BullModule } from '@nestjs/bullmq';

import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';

import { PrismaModule } from './prisma/prisma.module';
import { StorageModule } from './storage/storage.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { GroupsModule } from './groups/groups.module';
import { BillsModule } from './bills/bills.module';
import { SettlementModule } from './settlement/settlement.module';
import { NotificationsModule } from './notifications/notifications.module';
import { RegularBillsModule } from './regular-bills/regular-bills.module';
import { ExportModule } from './export/export.module';
import { StatisticsModule } from './statistics/statistics.module';
import { HealthModule } from './health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
    // 全局限流：默认 100 次/分钟；/auth/login 单独 5 次/10 分钟（@Throttle 覆盖）
    ThrottlerModule.forRoot([
      { name: 'default', ttl: 60000, limit: 100 },
    ]),
    // JWT 全局注册（默认为 access secret；refresh 在签名时覆盖）
    JwtModule.registerAsync({
      global: true,
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        secret: cfg.get<string>('JWT_ACCESS_SECRET') || 'dev-access-secret',
      }),
    }),
    // BullMQ（Redis 连接失败不阻塞启动；处理器惰性降级）
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        connection: {
          host: cfg.get('REDIS_HOST') || 'localhost',
          port: Number(cfg.get('REDIS_PORT') || 6379),
          maxRetriesPerRequest: null,
        },
      }),
    }),

    PrismaModule,
    StorageModule,
    AuthModule,
    UsersModule,
    GroupsModule,
    BillsModule,
    SettlementModule,
    NotificationsModule,
    RegularBillsModule,
    ExportModule,
    StatisticsModule,
    HealthModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_INTERCEPTOR, useClass: TransformInterceptor },
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
  ],
})
export class AppModule {}
