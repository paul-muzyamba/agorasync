#!/bin/bash
set -e # Exit immediately if a command fails

echo "🚀 Starting AgoraSync Monorepo Bootstrap..."

# ==========================================
# 1. CREATE DIRECTORY STRUCTURE
# ==========================================
echo "📁 Creating directory structure..."
mkdir -p apps/api/src/{common/{decorators,filters,guards,interceptors},modules/{accounts,auth,sync,transactions,momo},workers,health}
mkdir -p apps/api/test
mkdir -p apps/mobile/src/{api,db,features/{payment,sync-status},store,utils}
mkdir -p packages/{database/{prisma,src},types/src,config/{eslint,prettier,typescript}}
mkdir -p infra/docker
mkdir -p scripts
mkdir -p docs/{DECISIONS,RUNBOOKS,diagrams}

# ==========================================
# 2. ROOT CONFIGURATION
# ==========================================
echo "⚙️  Creating root configuration..."

cat << 'EOF' > package.json
{
  "name": "agorasync",
  "version": "1.0.0",
  "private": true,
  "workspaces": [
    "apps/*",
    "packages/*"
  ],
  "scripts": {
    "dev": "npm run dev --workspaces --if-present",
    "build": "npm run build --workspaces --if-present",
    "test": "npm run test --workspaces --if-present"
  }
}
EOF

cat << 'EOF' > .gitignore
node_modules/
dist/
build/
.env
.env.local
.dockerignore
*.log
.DS_Store
Thumbs.db
packages/database/prisma/migrations/
pg_data/
redis_data/
EOF

cat << 'EOF' > Makefile
.PHONY: setup infra-up infra-down migrate dev test clean

setup:
	npm install
	cd packages/database && npm run generate

infra-up:
	docker-compose -f infra/docker-compose.yml up -d

infra-down:
	docker-compose -f infra/docker-compose.yml down

migrate:
	cd packages/database && npm run migrate

dev:
	npm run dev

test:
	npm run test

clean:
	docker-compose -f infra/docker-compose.yml down -v
	rm -rf node_modules apps/*/node_modules packages/*/node_modules
	rm -rf pg_data redis_data
EOF

# ==========================================
# 3. INFRASTRUCTURE (Docker)
# ==========================================
echo "🐳 Creating Docker infrastructure..."

cat << 'EOF' > infra/docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: agora
      POSTGRES_PASSWORD: agora_secret
      POSTGRES_DB: agorasync
    ports:
      - "5432:5432"
    volumes:
      - ../../pg_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - ../../redis_data:/data

volumes:
  pg_data:
  redis_data:
EOF

# ==========================================
# 4. DATABASE PACKAGE
# ==========================================
echo "🗄️  Setting up Database package..."

cat << 'EOF' > packages/database/package.json
{
  "name": "@agorasync/database",
  "version": "1.0.0",
  "main": "src/index.ts",
  "scripts": {
    "generate": "prisma generate",
    "migrate": "prisma migrate dev",
    "studio": "prisma studio"
  },
  "dependencies": {
    "@prisma/client": "^5.10.0"
  },
  "devDependencies": {
    "prisma": "^5.10.0"
  }
}
EOF

cat << 'EOF' > packages/database/.env
DATABASE_URL="postgresql://agora:agora_secret@localhost:5432/agorasync?schema=public"
EOF

cat << 'EOF' > packages/database/prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum TransactionStatus {
  PENDING
  RESERVED
  SUCCESS
  FAILED
}

model Account {
  id              String   @id @default(uuid())
  merchantId      String   @unique
  balance         Decimal  @db.Decimal(15, 2) @default(0)
  reservedBalance Decimal  @db.Decimal(15, 2) @default(0)
  transactions    Transaction[]
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt
}

model Transaction {
  id              String            @id @default(uuid())
  idempotencyKey  String            @unique
  accountId       String
  account         Account           @relation(fields: [accountId], references: [id])
  amount          Decimal           @db.Decimal(15, 2)
  status          TransactionStatus @default(PENDING)
  momoReference   String?
  createdAt       DateTime          @default(now())
  updatedAt       DateTime          @updatedAt

  @@index([idempotencyKey])
}

model IdempotencyRecord {
  key        String   @id
  response   String   @db.Text
  expiresAt  DateTime @db.Timestamp(6)
}
EOF

cat << 'EOF' > packages/database/src/index.ts
import { PrismaClient } from '@prisma/client';

const globalForPrisma = global as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ||
  new PrismaClient({
    log: ['query'],
  });

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;

export * from '@prisma/client';
EOF

# ==========================================
# 5. API PACKAGE (NestJS)
# ==========================================
echo "🔧 Setting up API package..."

cat << 'EOF' > apps/api/package.json
{
  "name": "@agorasync/api",
  "version": "1.0.0",
  "scripts": {
    "dev": "nest start --watch",
    "build": "nest build",
    "start": "node dist/main",
    "test": "jest"
  },
  "dependencies": {
    "@nestjs/common": "^10.3.0",
    "@nestjs/core": "^10.3.0",
    "@nestjs/platform-express": "^10.3.0",
    "@nestjs/bullmq": "^10.1.0",
    "bullmq": "^5.4.0",
    "ioredis": "^5.3.2",
    "reflect-metadata": "^0.2.1",
    "rxjs": "^7.8.1",
    "uuid": "^9.0.1",
    "@agorasync/database": "*"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.3.0",
    "@nestjs/schematics": "^10.1.0",
    "@types/node": "^20.11.0",
    "@types/uuid": "^9.0.7",
    "typescript": "^5.3.3",
    "ts-node": "^10.9.2"
  }
}
EOF

cat << 'EOF' > apps/api/tsconfig.json
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strictNullChecks": true,
    "noImplicitAny": false,
    "strictBindCallApply": false,
    "forceConsistentCasingInFileNames": false,
    "noFallthroughCasesInSwitch": false
  }
}
EOF

cat << 'EOF' > apps/api/nest-cli.json
{
  "$schema": "https://json.schemastore.org/nest-cli",
  "collection": "@nestjs/schematics",
  "sourceRoot": "src",
  "compilerOptions": {
    "deleteOutDir": true
  }
}
EOF

cat << 'EOF' > apps/api/src/main.ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(3000);
  console.log('🚀 AgoraSync API running on http://localhost:3000');
}
bootstrap();
EOF

cat << 'EOF' > apps/api/src/app.module.ts
import { Module } from '@nestjs/common';

@Module({
  imports: [],
  controllers: [],
  providers: [],
})
export class AppModule {}
EOF

# ==========================================
# 6. DOCUMENTATION
# ==========================================
echo "📚 Creating Documentation..."

cat << 'EOF' > README.md
# AgoraSync: Offline-First Payment Engine

AgoraSync is a payment processing system designed for unreliable networks, built for field agents in emerging markets.

## 🚀 Quick Start

1. Start infrastructure: \`make infra-up\`
2. Install dependencies: \`make setup\`
3. Run migrations: \`make migrate\`
4. Start development: \`make dev\`

See the \`docs/\` folder for architecture decisions and runbooks.
EOF

# ==========================================
# 7. INSTALL & INITIALIZE
# ==========================================
echo "📦 Installing dependencies (this may take a minute)..."
npm install

echo "⚙️  Generating Prisma Client..."
cd packages/database && npm run generate && cd ../..

echo "🐳 Starting Docker containers (Postgres + Redis)..."
make infra-up

echo ""
echo "✅ BOOTSTRAP COMPLETE!"
echo ""
echo "Next steps:"
echo "  1. Run database migrations: make migrate"
echo "  2. Start the development server: make dev"
echo "  3. Check Docker status: docker ps"
echo ""