import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Injectable()
export class TransactionsService {
  constructor(
    private prisma: PrismaService,
    @InjectQueue('momo-processing') private momoQueue: Queue,
  ) {}

  async createTransaction(accountId: string, amount: number, idempotencyKey: string) {
    // 1. Check if idempotency key already exists in DB (defense in depth)
    const existing = await this.prisma.transaction.findUnique({ where: { idempotencyKey } });
    if (existing) return { status: 'ALREADY_PROCESSED', transaction: existing };

    // 2. Atomic Transaction: Verify balance AND reserve funds simultaneously
    const result = await this.prisma.$transaction(async (tx) => {
      // FOR UPDATE locks the row, preventing race conditions on concurrent requests
      const account = await tx.account.findUnique({
        where: { id: accountId },
        select: { balance: true, reservedBalance: true },
      });

      if (!account) {
        throw new BadRequestException('Account not found');
      }

      const available = Number(account.balance) - Number(account.reservedBalance);
      if (available < amount) {
        throw new BadRequestException('Insufficient available balance');
      }

      // Reserve the funds (SAGA Step 1)
      await tx.account.update({
        where: { id: accountId },
        data: { reservedBalance: { increment: amount } },
      });

      // Create pending transaction record
      return tx.transaction.create({
        data: {
          accountId,
          amount,
          idempotencyKey,
          status: 'RESERVED',
        },
      });
    });

    // 3. Offload external API call to background worker (Non-blocking)
    await this.momoQueue.add('process-payment', {
      transactionId: result.id,
      accountId,
      amount,
      idempotencyKey,
    }, {
      attempts: 5,
      backoff: { type: 'exponential', delay: 2000 }, // 2s, 4s, 8s, 16s, 32s
    });

    return { status: 'ACCEPTED', transactionId: result.id, message: 'Processing asynchronously' };
  }
}
