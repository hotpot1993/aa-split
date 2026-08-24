import { Injectable } from '@nestjs/common';
import { Response } from 'express';

export interface SsePayload {
  type: string;
  title: string;
  body: string;
  refType: string | null;
  refId: string | null;
  createdAt?: string;
}

/**
 * 内存 SSE 订阅器：userId -> Response[]
 * 手写 Map 实现（不引入 event-emitter / WebSocket）。
 */
@Injectable()
export class NotificationSseService {
  private readonly subscribers = new Map<string, Set<Response>>();

  subscribe(userId: string, res: Response) {
    if (!this.subscribers.has(userId)) {
      this.subscribers.set(userId, new Set());
    }
    this.subscribers.get(userId)!.add(res);

    // 断开时自动清理
    res.on('close', () => {
      this.unsubscribe(userId, res);
    });
  }

  unsubscribe(userId: string, res: Response) {
    const set = this.subscribers.get(userId);
    if (set) {
      set.delete(res);
      if (set.size === 0) this.subscribers.delete(userId);
    }
  }

  /** 向单个用户的所有连接推送一条事件 */
  push(userId: string, data: SsePayload) {
    const set = this.subscribers.get(userId);
    if (!set || set.size === 0) return;
    const frame = `data: ${JSON.stringify(data)}\n\n`;
    for (const res of set) {
      try {
        res.write(frame);
      } catch {
        this.unsubscribe(userId, res);
      }
    }
  }

  count(userId: string): number {
    return this.subscribers.get(userId)?.size ?? 0;
  }
}
