# AgoraSync: Offline-First Payment Engine for Emerging Markets

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![Coverage](https://img.shields.io/badge/coverage-85%25-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)

## 🎯 What is AgoraSync?
AgoraSync is a **resilient payment processing system designed for unreliable networks**. 

Imagine a field agent in rural Kenya collecting payments via mobile money (like M-Pesa). Network connectivity drops constantly. Standard payment apps would show an error and stop working. 

**AgoraSync doesn't stop.** It accepts transactions, enqueues them, handles eventual consistency, and guarantees that no payment is lost or duplicated—even if the network fails mid-transaction.

## 👥 Who is this designed for?
- **Tier 1 (Field Agents):** Users on low-end devices with intermittent 2G/3G. The system must be offline-first, lightweight, and forgive network drops.
- **Tier 2 (Operations/Reconcilers):** Back-office staff who need strict audit trails, clear observability, and manual override capabilities (Dead Letter Queue) when external APIs fail.

## 🏗️ System Architecture

```mermaid
graph TB
    subgraph "Field Agent Device (Offline-First)"
        A[Mobile Client] --> B[Local SQLite Queue]
    end
    
    subgraph "Backend (Resilient Processing)"
        B -->|Sync on Reconnect| C[API Gateway]
        C --> D[Idempotency Interceptor]
        D --> E[Transaction Service]
        E --> F[PostgreSQL Row-Lock]
        E --> G[BullMQ Queue]
        G --> H[Momo Worker]
        H --> I[Circuit Breaker]
        I --> J[External MoMo API]
    end
    
    J -->|Webhook / Poll| K[Status Update]
    K --> E