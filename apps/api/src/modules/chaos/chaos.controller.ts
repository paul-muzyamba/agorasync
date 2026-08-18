import { Controller, Post, Get } from '@nestjs/common';

// Global flag to simulate MoMo API outage
let isMomoDown = false;

@Controller('chaos')
export class ChaosController {
  @Post('fail-momo')
  triggerFailure() {
    isMomoDown = true;
    return { message: 'MoMo API is now simulating 100% failure rate. Circuit breaker will trip.' };
  }

  @Post('restore-momo')
  restoreService() {
    isMomoDown = false;
    return { message: 'MoMo API restored. Circuit breaker will reset on next success.' };
  }

  @Get('status')
  getStatus() {
    return { isMomoDown };
  }
}

// Export the getter for the worker to use
export const getMomoStatus = () => isMomoDown;