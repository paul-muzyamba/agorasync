import { Injectable, NestInterceptor, ExecutionContext, CallHandler, ConflictException, Inject } from '@nestjs/common';
import { Observable, of } from 'rxjs';
import { map } from 'rxjs/operators';
import { Redis } from 'ioredis';

@Injectable()
export class IdempotencyInterceptor implements NestInterceptor {
  constructor(@Inject('REDIS_CLIENT') private readonly redis: Redis) {}

  async intercept(context: ExecutionContext, next: CallHandler): Promise<Observable<any>> {
    const request = context.switchToHttp().getRequest();
    const idempotencyKey = request.headers['x-idempotency-key'];

    if (!idempotencyKey) {
      throw new ConflictException('Missing x-idempotency-key header');
    }

    const cached = await this.redis.get(`idempotency:${idempotencyKey}`);
    if (cached) {
      return of(JSON.parse(cached)); 
    }

    const lockAcquired = await this.redis.set(`lock:${idempotencyKey}`, '1', 'EX', 10, 'NX');
    if (!lockAcquired) {
      throw new ConflictException('Request is currently being processed. Please wait.');
    }

    return next.handle().pipe(
      map(async (data) => {
        await this.redis.set(`idempotency:${idempotencyKey}`, JSON.stringify(data), 'EX', 86400);
        await this.redis.del(`lock:${idempotencyKey}`); 
        return data;
      })
    );
  }
}
