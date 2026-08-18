# AgoraSync: Offline-First Payment Engine for Emerging Markets

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![TypeScript](https://img.shields.io/badge/TypeScript-5.3-blue)

> A resilient, distributed payment processing system designed for unreliable networks. Built to handle offline transactions, eventual consistency, and external API failures without losing data or corrupting financial ledgers.

---

## 🎯 What is AgoraSync?

AgoraSync is a **production-grade payment engine** built for field agents in emerging markets where network connectivity is intermittent and unreliable. 

Imagine a field agent in rural Kenya collecting payments via mobile money (like M-Pesa). Network connectivity drops constantly. Standard payment apps would show an error and stop working. 

**AgoraSync doesn't stop.** It accepts transactions, enqueues them locally, handles eventual consistency via a specialized sync engine, and routes transactions securely through Mobile Money APIs once connectivity is restored—guaranteeing that no payment is lost or duplicated.

---

## 👥 Who is this designed for?

### **Tier 1: Field Agents (End Users)**
- **Use Case**: Agricultural buyers, mobile money agents, distribution drivers
- **Environment**: Low-end Android devices, intermittent 2G/3G, high latency
- **Needs**: Offline-first functionality, battery efficiency, silent retry mechanisms

### **Tier 2: Operations & Reconcilers (Back Office)**
- **Use Case**: Monitoring transactions, resolving edge cases, manual interventions
- **Needs**: Complete audit trails, observability dashboards, Dead Letter Queue (DLQ) management

---

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