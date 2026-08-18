# ADR 001: SAGA Pattern for Financial Transactions

## Status
Accepted

## Context
Calling an external Mobile Money (MoMo) API is not an atomic database operation. If the DB updates but the MoMo API fails, the system enters an inconsistent state, potentially locking user funds permanently.

## Decision
We use a local SAGA pattern with automatic compensation:
1. **Step 1 (Reserve)**: Atomically deduct from `balance` and add to `reservedBalance` using PostgreSQL row-level locking.
2. **Step 2 (Execute)**: Push job to BullMQ background worker.
3. **Step 3 (Compensate)**: If the worker exhausts retries (or the Circuit Breaker opens), automatically decrement `reservedBalance` back to `balance` and mark the transaction `FAILED`.

## Consequences
- **Positive**: Funds are never "lost" or permanently locked. The system is self-healing.
- **Negative**: Requires careful monitoring of the Dead Letter Queue (DLQ) for edge cases requiring manual reconciliation.