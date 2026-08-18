import { Controller, Post, Body, Headers, UseInterceptors } from '@nestjs/common';
import { TransactionsService } from './transactions.service';
import { IdempotencyInterceptor } from '../../common/interceptors/idempotency.interceptor';

@Controller('transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  @Post()
  @UseInterceptors(IdempotencyInterceptor)
  async createTransaction(
    @Body() body: { accountId: string; amount: number },
    @Headers('x-idempotency-key') idempotencyKey: string,
  ) {
    return this.transactionsService.createTransaction(
      body.accountId,
      body.amount,
      idempotencyKey,
    );
  }
}
