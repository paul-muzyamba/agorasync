import { Controller, Post, Body } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Controller('seed')
export class SeedController {
  constructor(private prisma: PrismaService) {}

  @Post('account')
  async createAccount(@Body() body: { accountId: string; merchantId: string; balance: number }) {
    // Upsert: Create if not exists, otherwise do nothing
    return this.prisma.account.upsert({
      where: { id: body.accountId },
      update: {},
      create: {
        id: body.accountId,
        merchantId: body.merchantId,
        balance: body.balance,
        reservedBalance: 0,
      },
    });
  }
}
