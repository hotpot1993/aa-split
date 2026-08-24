import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';
import { JwtPayload } from '../types';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * 全局 JWT 鉴权守卫：校验 Authorization: Bearer <accessToken>，
 * 并把载荷挂到 req.user。用 @Public() 放行公开路由。
 * 额外校验用户仍存在且未注销（注销后旧 token 立即失效）。
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest<Request>();
    const token = this.extractToken(request);
    if (!token) {
      throw new UnauthorizedException('未登录或登录已过期');
    }

    try {
      const payload = this.jwtService.verify<JwtPayload>(token, {
        secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
      });
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
        select: { id: true, deletedAt: true },
      });
      // 用户已删除 / 已注销 → token 失效（账号删除后旧登录态不可用）
      if (!user) {
        throw new UnauthorizedException('账号不存在或已注销');
      }
      if (user.deletedAt) {
        throw new UnauthorizedException('登录已过期，请重新登录');
      }
      (request as any).user = payload;
    } catch {
      throw new UnauthorizedException('登录已过期，请重新登录');
    }
    return true;
  }

  /** 从 Bearer 头或 ?access_token= 查询参数提取 token（供 SSE 等场景使用） */
  extractToken(request: Request): string | null {
    const header = request.headers.authorization;
    if (header && header.startsWith('Bearer ')) {
      return header.substring(7).trim();
    }
    const queryToken = request.query?.access_token;
    if (typeof queryToken === 'string' && queryToken) {
      return queryToken;
    }
    return null;
  }
}
