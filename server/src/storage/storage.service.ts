import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as fs from 'fs';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import * as Minio from 'minio';

export interface StoredFile {
  objectKey: string;
  url: string;
}

/**
 * 对象存储：OBJECT_STORAGE=local（默认，写入 UPLOAD_DIR）| minio（S3 兼容）。
 * MinIO 连接在初始化时 try-catch，失败不影响进程启动（降级仅记录日志）。
 */
@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);
  private readonly mode: 'local' | 'minio';
  private readonly uploadDir: string;
  private readonly minioClient?: Minio.Client;
  private readonly minioBucket?: string;
  private readonly minioPublicEndpoint?: string;

  constructor(private readonly configService: ConfigService) {
    this.mode = (configService.get('OBJECT_STORAGE') || 'local').toLowerCase() as
      | 'local'
      | 'minio';
    this.uploadDir = path.resolve(
      configService.get('UPLOAD_DIR') || './uploads',
    );
    if (this.mode === 'minio') {
      try {
        this.minioClient = new Minio.Client({
          endPoint: configService.get('MINIO_ENDPOINT') || 'localhost',
          port: Number(configService.get('MINIO_PORT') || 9000),
          useSSL: configService.get('MINIO_USE_SSL') === 'true',
          accessKey: configService.get('MINIO_ACCESS_KEY') || 'minioadmin',
          secretKey: configService.get('MINIO_SECRET_KEY') || 'minioadmin',
        });
        this.minioBucket = configService.get('MINIO_BUCKET') || 'aa-split';
        this.minioPublicEndpoint = configService.get('MINIO_PUBLIC_ENDPOINT');
        // 惰性创建 bucket，失败仅记录（不阻塞启动）
        this.ensureBucket().catch((e) =>
          this.logger.warn(`MinIO bucket 初始化失败：${e.message}`),
        );
      } catch (e: any) {
        this.logger.warn(`MinIO 初始化失败，回退本地存储：${e?.message}`);
        this.mode = 'local';
      }
    }
    // 本地模式确保目录存在
    if (this.mode === 'local') {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  private async ensureBucket() {
    if (!this.minioClient || !this.minioBucket) return;
    const exists = await this.minioClient.bucketExists(this.minioBucket);
    if (!exists) await this.minioClient.makeBucket(this.minioBucket);
  }

  /** 上传文件，返回 objectKey 与可访问 url */
  async upload(file: Express.Multer.File): Promise<StoredFile> {
    const ext = path.extname(file.originalname || '').toLowerCase() || '.jpg';
    const key = `${uuidv4()}${ext}`;
    if (this.mode === 'minio' && this.minioClient && this.minioBucket) {
      await this.minioClient.putObject(
        this.minioBucket,
        key,
        file.buffer,
        file.buffer.length,
        { 'Content-Type': file.mimetype },
      );
      const url = this.minioPublicEndpoint
        ? `${this.minioPublicEndpoint}/${this.minioBucket}/${key}`
        : key;
      return { objectKey: key, url };
    }
    // 本地存储
    const dest = path.join(this.uploadDir, key);
    await fs.promises.writeFile(dest, file.buffer);
    return { objectKey: key, url: `/uploads/${key}` };
  }

  /** 由已有 objectKey 构造可访问 URL */
  publicUrl(objectKey: string): string {
    if (objectKey.startsWith('http')) return objectKey;
    if (this.mode === 'minio' && this.minioPublicEndpoint) {
      return `${this.minioPublicEndpoint}/${this.minioBucket}/${objectKey}`;
    }
    return `/uploads/${objectKey}`;
  }

  /** 读取对象字节（供 OCR worker 转发；本地模式读文件，MinIO 模式 getObject） */
  async read(objectKey: string): Promise<Buffer> {
    if (this.mode === 'minio' && this.minioClient && this.minioBucket) {
      const stream = await this.minioClient.getObject(this.minioBucket, objectKey);
      const chunks: Buffer[] = [];
      for await (const chunk of stream) {
        chunks.push(chunk as Buffer);
      }
      return Buffer.concat(chunks);
    }
    return fs.promises.readFile(path.join(this.uploadDir, objectKey));
  }

  /** 删除对象（替换凭证时清理旧图；文件不存在视为成功，不抛错） */
  async remove(objectKey: string): Promise<void> {
    if (!objectKey || objectKey.startsWith('http')) return;
    try {
      if (this.mode === 'minio' && this.minioClient && this.minioBucket) {
        await this.minioClient.removeObject(this.minioBucket, objectKey);
        return;
      }
      await fs.promises.unlink(path.join(this.uploadDir, objectKey));
    } catch (e: any) {
      if (e?.code === 'ENOENT') return;
      this.logger.warn(`删除对象失败（忽略）：${objectKey} ${e?.message}`);
    }
  }
}
