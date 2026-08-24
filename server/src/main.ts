import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const config = app.get(ConfigService);

  const origins = (config.get<string>('CORS_ORIGINS') || '*')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  app.enableCors({
    origin: origins.includes('*') ? true : origins,
    credentials: true,
  });

  app.setGlobalPrefix('api/v1');

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // 本地存储模式：托管 uploads 静态目录
  const uploadDir = config.get<string>('UPLOAD_DIR') || './uploads';
  try {
    app.useStaticAssets(uploadDir, { prefix: '/uploads' });
  } catch {
    // 目录尚不存在时忽略（首次启动会创建）
  }

  // Swagger 文档（默认开）
  if (config.get<string>('SWAGGER_ENABLED') !== 'false') {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('AA分账App API')
      .setDescription('AA 分账 App 服务端接口文档（金额单位为分）')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    const document = SwaggerModule.createDocument(app, swaggerConfig);
    SwaggerModule.setup('api/docs', app, document);
  }

  const port = Number(config.get('PORT') || 3000);
  await app.listen(port);
  console.log(`AA分账App 服务已启动: http://localhost:${port}/api/v1`);
}

bootstrap();
