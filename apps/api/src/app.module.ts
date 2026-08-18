import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { Redis } from 'ioredis';
import { PrismaService } from './prisma/prisma.service';
import { TransactionsService } from './modules/transactions/transactions.service';
import { TransactionsController } from './modules/transactions/transactions.controller';
import { SeedController } from './modules/seed/seed.controller';
import { ChaosController } from './modules/chaos/chaos.controller';
import { MomoProcessor } from './workers/momo.processor';

export const redisProvider = {
  provide: 'REDIS_CLIENT',
  useFactory: () => new Redis({ host: 'localhost', port: 6379 }),
};

@Module({
  imports: [
    BullModule.forRoot({ connection: { host: 'localhost', port: 6379 } }),
    BullModule.registerQueue({ name: 'momo-processing' }),
  ],
  controllers: [TransactionsController, SeedController, ChaosController],
  providers: [PrismaService, redisProvider, TransactionsService, MomoProcessor],
  exports: [PrismaService, redisProvider],
})
export class AppModule {}