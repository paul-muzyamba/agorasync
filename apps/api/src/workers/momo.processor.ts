import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { PrismaService } from '../prisma/prisma.service';
import { Injectable, Logger } from '@nestjs/common';
import { getMomoStatus } from '../modules/chaos/chaos.controller';

class CircuitBreaker {
  private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED';
  private failures = 0;
  private readonly threshold = 3;
  private readonly resetTimeout = 10000;

  async execute<T>(action: () => Promise<T>): Promise<T> {
    if (this.state === 'OPEN') throw new Error('Circuit breaker is OPEN.');
    try {
      const result = await action();
      this.failures = 0;
      this.state = 'CLOSED';
      return result;
    } catch (error) {
      this.failures++;
      if (this.failures >= this.threshold) {
        this.state = 'OPEN';
        setTimeout(() => { this.state = 'HALF_OPEN'; }, this.resetTimeout);
      }
      throw error;
    }
  }
}

@Injectable()
@Processor('momo-processing')
export class MomoProcessor extends WorkerHost {
  private readonly logger = new Logger(MomoProcessor.name);
  private circuitBreaker = new CircuitBreaker();

  constructor(private prisma: PrismaService) { super(); }

  async process(job: Job<any, any, string>): Promise<any> {
    const { transactionId, accountId, amount } = job.data;

    try {
      const momoResponse = await this.circuitBreaker.execute(async () => {
        // Check if we intentionally broke the system
        if (getMomoStatus()) throw new Error('Simulated MoMo API Outage');
        if (Math.random() > 0.7) throw new Error('Random MoMo Gateway Timeout');
        return { reference: `MOMO-${Date.now()}`, status: 'SUCCESSFUL' };
      });

      // SUCCESS: Commit the reservation
      await this.prisma.$transaction(async (tx) => {
        await tx.account.update({
          where: { id: accountId },
          data: { balance: { decrement: amount }, reservedBalance: { decrement: amount } },
        });
        await tx.transaction.update({
          where: { id: transactionId },
          data: { status: 'SUCCESS', momoReference: momoResponse.reference },
        });
      });
      return { success: true };

    } catch (error) {
      this.logger.error(`Transaction ${transactionId} failed: ${error.message}`);

      // SAGA COMPENSATION: Release funds automatically
      await this.prisma.$transaction(async (tx) => {
        await tx.account.update({
          where: { id: accountId },
          data: { reservedBalance: { decrement: amount } },
        });
        await tx.transaction.update({
          where: { id: transactionId },
          data: { status: 'FAILED' },
        });
      });

      if (error.message.includes('Circuit breaker is OPEN') || error.message.includes('Outage')) {
        throw new Error('Fast-failed due to OPEN circuit breaker or simulated outage');
      }
      throw error; // Triggers BullMQ retry
    }
  }
}