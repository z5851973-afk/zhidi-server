# 平台基础与后端 API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭建装修平台首版的业务后端，支撑业主 App、工长 App 和 Web 管理后台的账号、预约、派单、隐私、项目阶段和内容审核基础能力。

**Architecture:** 使用一个自建业务 API 服务作为平台核心，所有 App 和后台都通过它读写数据。后端负责保存真实手机号和完整地址，并按角色返回脱敏后的信息；短信、虚拟号码、图片存储、语音识别后续通过云服务适配层接入。

**Tech Stack:** Node.js, NestJS, PostgreSQL, Prisma, JWT, pnpm, Docker Compose, Jest, Supertest.

---

## Scope

This plan builds the backend foundation only. It does not build the iOS apps, Web admin UI, real-time chat transport, payment, contracts, or cloud vendor production integration.

Included:

- Project scaffolding.
- Database schema.
- Authentication and role model.
- Admin, homeowner, foreman user records.
- City and service area configuration.
- Project categories and stage templates.
- Homeowner booking creation.
- Address and phone privacy rules.
- Foreman profile review.
- Dispatch workflow.
- Construction project creation.
- Stage submission records.
- Daily watermarked photo records.
- Public foreman activity review, likes, and evaluation records.
- API tests for privacy and core state transitions.

## File Structure

Create this structure:

```text
apps/api/
  package.json
  tsconfig.json
  tsconfig.build.json
  nest-cli.json
  .env.example
  docker-compose.yml
  prisma/
    schema.prisma
    seed.ts
  src/
    main.ts
    app.module.ts
    common/
      auth/current-user.decorator.ts
      auth/jwt-auth.guard.ts
      auth/roles.decorator.ts
      auth/roles.guard.ts
      privacy/privacy.service.ts
    modules/
      auth/auth.module.ts
      auth/auth.controller.ts
      auth/auth.service.ts
      catalog/catalog.module.ts
      catalog/catalog.controller.ts
      catalog/catalog.service.ts
      bookings/bookings.module.ts
      bookings/bookings.controller.ts
      bookings/bookings.service.ts
      foremen/foremen.module.ts
      foremen/foremen.controller.ts
      foremen/foremen.service.ts
      dispatch/dispatch.module.ts
      dispatch/dispatch.controller.ts
      dispatch/dispatch.service.ts
      projects/projects.module.ts
      projects/projects.controller.ts
      projects/projects.service.ts
      activity/activity.module.ts
      activity/activity.controller.ts
      activity/activity.service.ts
    prisma/
      prisma.module.ts
      prisma.service.ts
  test/
    jest-e2e.json
    auth.e2e-spec.ts
    booking-privacy.e2e-spec.ts
    dispatch-project.e2e-spec.ts
```

Responsibility boundaries:

- `auth`: phone-code login simulation, JWT issuing, role handling.
- `catalog`: cities, service areas, project categories, stage templates.
- `bookings`: homeowner booking creation and booking status.
- `foremen`: foreman profile and review status.
- `dispatch`: admin dispatch from booking to foreman.
- `projects`: construction project and stage/photo records.
- `activity`: public foreman activity review flow.
- `common/privacy`: address masking and role-based contact visibility.

## Data Model Summary

Core roles:

- `HOMEOWNER`: 业主。
- `FOREMAN`: 工长。
- `ADMIN`: 后台管理员。
- `SUPERVISOR`: 平台监理。
- `CUSTOMER_SERVICE`: 平台客服。

Core state machines:

- Booking status: `SUBMITTED -> CONTACTED -> DISPATCHED -> FOREMAN_ACCEPTED -> COOPERATION_CONFIRMED -> CANCELLED`.
- Foreman review status: `PENDING -> APPROVED -> REJECTED`.
- Dispatch status: `PENDING -> ACCEPTED -> REJECTED -> EXPIRED`.
- Project status: `ACTIVE -> COMPLETED -> CANCELLED`.
- Stage status: `PENDING -> SUBMITTED -> CONFIRMED -> REJECTED`.
- Activity review status: `DRAFT -> SUBMITTED -> APPROVED -> REJECTED -> PUBLISHED`.

## Task 1: Scaffold Backend App

**Files:**

- Create: `apps/api/package.json`
- Create: `apps/api/tsconfig.json`
- Create: `apps/api/tsconfig.build.json`
- Create: `apps/api/nest-cli.json`
- Create: `apps/api/.env.example`
- Create: `apps/api/docker-compose.yml`
- Create: `apps/api/test/jest-e2e.json`
- Create: `apps/api/src/main.ts`
- Create: `apps/api/src/app.module.ts`

- [ ] **Step 1: Create package manifest**

Create `apps/api/package.json`:

```json
{
  "name": "renovation-platform-api",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "start": "nest start",
    "start:dev": "nest start --watch",
    "build": "nest build",
    "lint": "eslint \"src/**/*.ts\" \"test/**/*.ts\"",
    "test": "jest",
    "test:e2e": "jest --config ./test/jest-e2e.json",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev",
    "prisma:seed": "tsx prisma/seed.ts"
  },
  "dependencies": {
    "@nestjs/common": "^10.4.0",
    "@nestjs/config": "^3.2.3",
    "@nestjs/core": "^10.4.0",
    "@nestjs/jwt": "^10.2.0",
    "@nestjs/passport": "^10.0.3",
    "@nestjs/platform-express": "^10.4.0",
    "@prisma/client": "^5.22.0",
    "bcryptjs": "^2.4.3",
    "class-transformer": "^0.5.1",
    "class-validator": "^0.14.1",
    "passport": "^0.7.0",
    "passport-jwt": "^4.0.1",
    "reflect-metadata": "^0.2.2",
    "rxjs": "^7.8.1"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.4.5",
    "@nestjs/schematics": "^10.1.4",
    "@nestjs/testing": "^10.4.0",
    "@types/bcryptjs": "^2.4.6",
    "@types/express": "^4.17.21",
    "@types/jest": "^29.5.13",
    "@types/node": "^22.7.5",
    "@types/passport-jwt": "^4.0.1",
    "@types/supertest": "^6.0.2",
    "@typescript-eslint/eslint-plugin": "^8.8.1",
    "@typescript-eslint/parser": "^8.8.1",
    "eslint": "^9.11.1",
    "jest": "^29.7.0",
    "prisma": "^5.22.0",
    "source-map-support": "^0.5.21",
    "supertest": "^7.0.0",
    "ts-jest": "^29.2.5",
    "tsx": "^4.19.1",
    "typescript": "^5.6.2"
  },
  "prisma": {
    "seed": "tsx prisma/seed.ts"
  }
}
```

- [ ] **Step 2: Create TypeScript and Nest config**

Create `apps/api/tsconfig.json`:

```json
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
    "strict": true,
    "skipLibCheck": true
  }
}
```

Create `apps/api/tsconfig.build.json`:

```json
{
  "extends": "./tsconfig.json",
  "exclude": ["node_modules", "test", "dist", "**/*spec.ts"]
}
```

Create `apps/api/nest-cli.json`:

```json
{
  "$schema": "https://json.schemastore.org/nest-cli",
  "collection": "@nestjs/schematics",
  "sourceRoot": "src"
}
```

Create `apps/api/test/jest-e2e.json`:

```json
{
  "moduleFileExtensions": ["js", "json", "ts"],
  "rootDir": "..",
  "testEnvironment": "node",
  "testRegex": ".e2e-spec.ts$",
  "transform": {
    "^.+\\.(t|j)s$": "ts-jest"
  }
}
```

- [ ] **Step 3: Create environment and database config**

Create `apps/api/.env.example`:

```dotenv
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/renovation_platform?schema=public"
JWT_SECRET="replace-with-local-dev-secret"
PORT=3000
```

Create `apps/api/docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: renovation_platform
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

- [ ] **Step 4: Create minimal Nest app**

Create `apps/api/src/main.ts`:

```ts
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const config = app.get(ConfigService);
  const port = config.get<number>('PORT') ?? 3000;
  await app.listen(port);
}

bootstrap();
```

Create `apps/api/src/app.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true })],
})
export class AppModule {}
```

- [ ] **Step 5: Install dependencies**

Run:

```bash
cd apps/api
pnpm install
```

Expected: dependencies install successfully and `pnpm-lock.yaml` is created.

- [ ] **Step 6: Build**

Run:

```bash
cd apps/api
pnpm build
```

Expected: build succeeds with no TypeScript errors.

- [ ] **Step 7: Commit**

```bash
git add apps/api pnpm-lock.yaml
git commit -m "chore: scaffold backend api"
```

## Task 2: Add Prisma Schema and Seed Data

**Files:**

- Create: `apps/api/prisma/schema.prisma`
- Create: `apps/api/prisma/seed.ts`
- Create: `apps/api/src/prisma/prisma.module.ts`
- Create: `apps/api/src/prisma/prisma.service.ts`
- Modify: `apps/api/src/app.module.ts`

- [ ] **Step 1: Create Prisma schema**

Create `apps/api/prisma/schema.prisma`:

```prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum UserRole {
  HOMEOWNER
  FOREMAN
  ADMIN
  SUPERVISOR
  CUSTOMER_SERVICE
}

enum ForemanReviewStatus {
  PENDING
  APPROVED
  REJECTED
}

enum BookingStatus {
  SUBMITTED
  CONTACTED
  DISPATCHED
  FOREMAN_ACCEPTED
  COOPERATION_CONFIRMED
  CANCELLED
}

enum DispatchStatus {
  PENDING
  ACCEPTED
  REJECTED
  EXPIRED
}

enum ProjectStatus {
  ACTIVE
  COMPLETED
  CANCELLED
}

enum StageStatus {
  PENDING
  SUBMITTED
  CONFIRMED
  REJECTED
}

enum ActivityStatus {
  DRAFT
  SUBMITTED
  APPROVED
  REJECTED
  PUBLISHED
}

model User {
  id          String     @id @default(cuid())
  phone       String     @unique
  displayName String?
  roles       UserRole[]
  createdAt   DateTime   @default(now())
  updatedAt   DateTime   @updatedAt

  foremanProfile ForemanProfile?
  bookings        Booking[]        @relation("HomeownerBookings")
  dispatches      Dispatch[]       @relation("ForemanDispatches")
  projectsAsOwner Project[]        @relation("ProjectOwner")
  projectsAsForeman Project[]      @relation("ProjectForeman")
}

model City {
  id        String   @id @default(cuid())
  name      String
  isEnabled Boolean  @default(false)
  districts District[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model District {
  id        String   @id @default(cuid())
  cityId    String
  name      String
  isEnabled Boolean  @default(false)
  city      City     @relation(fields: [cityId], references: [id])
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@unique([cityId, name])
}

model ProjectCategory {
  id          String   @id @default(cuid())
  slug        String   @unique
  name        String
  description String
  isPublished Boolean  @default(false)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  stageTemplates StageTemplate[]
  bookings       Booking[]
}

model StageTemplate {
  id         String   @id @default(cuid())
  categoryId String
  name       String
  sortOrder  Int
  category   ProjectCategory @relation(fields: [categoryId], references: [id])

  @@unique([categoryId, sortOrder])
}

model ForemanProfile {
  id             String              @id @default(cuid())
  userId         String              @unique
  realName       String
  serviceSummary String
  yearsExperience Int
  reviewStatus   ForemanReviewStatus @default(PENDING)
  reviewNote     String?
  user           User                @relation(fields: [userId], references: [id])
  createdAt      DateTime            @default(now())
  updatedAt      DateTime            @updatedAt
}

model Booking {
  id              String        @id @default(cuid())
  homeownerId     String
  categoryId      String
  city            String
  district        String
  community       String
  fullAddress     String
  homeAreaSqm     Decimal
  bedrooms        Int
  livingRooms     Int
  kitchens        Int
  bathrooms       Int
  houseStatus     String
  renovationScope String
  preferredVisitAt DateTime
  note            String?
  status          BookingStatus @default(SUBMITTED)
  createdAt       DateTime      @default(now())
  updatedAt       DateTime      @updatedAt

  homeowner User            @relation("HomeownerBookings", fields: [homeownerId], references: [id])
  category  ProjectCategory @relation(fields: [categoryId], references: [id])
  dispatches Dispatch[]
  project    Project?
}

model Dispatch {
  id          String         @id @default(cuid())
  bookingId   String
  foremanId   String
  status      DispatchStatus @default(PENDING)
  assignedBy  String
  note        String?
  createdAt   DateTime       @default(now())
  updatedAt   DateTime       @updatedAt

  booking Booking @relation(fields: [bookingId], references: [id])
  foreman User    @relation("ForemanDispatches", fields: [foremanId], references: [id])
}

model Project {
  id         String        @id @default(cuid())
  bookingId  String        @unique
  homeownerId String
  foremanId  String
  status     ProjectStatus @default(ACTIVE)
  createdAt  DateTime      @default(now())
  updatedAt  DateTime      @updatedAt

  booking   Booking @relation(fields: [bookingId], references: [id])
  homeowner User    @relation("ProjectOwner", fields: [homeownerId], references: [id])
  foreman   User    @relation("ProjectForeman", fields: [foremanId], references: [id])
  stages    ProjectStage[]
  dailyPhotos DailyWorkPhoto[]
}

model ProjectStage {
  id          String      @id @default(cuid())
  projectId   String
  name        String
  sortOrder   Int
  status      StageStatus @default(PENDING)
  submittedAt DateTime?
  confirmedAt DateTime?
  rejectedAt  DateTime?
  rejectReason String?

  project Project @relation(fields: [projectId], references: [id])
  photos  StagePhoto[]

  @@unique([projectId, sortOrder])
}

model StagePhoto {
  id        String   @id @default(cuid())
  stageId   String
  imageUrl  String
  caption   String?
  createdAt DateTime @default(now())

  stage ProjectStage @relation(fields: [stageId], references: [id])
}

model DailyWorkPhoto {
  id          String   @id @default(cuid())
  projectId   String
  imageUrl    String
  capturedAt  DateTime
  watermark   String
  workContent String
  createdAt   DateTime @default(now())

  project  Project @relation(fields: [projectId], references: [id])
  activity ForemanActivity?
}

model ForemanActivity {
  id             String         @id @default(cuid())
  dailyPhotoId   String         @unique
  foremanId      String
  title          String
  content        String
  status         ActivityStatus @default(SUBMITTED)
  reviewNote     String?
  publishedAt    DateTime?
  createdAt      DateTime       @default(now())
  updatedAt      DateTime       @updatedAt

  dailyPhoto DailyWorkPhoto   @relation(fields: [dailyPhotoId], references: [id])
  likes      ActivityLike[]
  comments   ActivityComment[]
}

model ActivityLike {
  id         String   @id @default(cuid())
  activityId String
  userId     String
  createdAt  DateTime @default(now())

  activity ForemanActivity @relation(fields: [activityId], references: [id])

  @@unique([activityId, userId])
}

model ActivityComment {
  id         String   @id @default(cuid())
  activityId String
  userId     String
  content    String
  createdAt  DateTime @default(now())

  activity ForemanActivity @relation(fields: [activityId], references: [id])
}
```

- [ ] **Step 2: Add Prisma service**

Create `apps/api/src/prisma/prisma.service.ts`:

```ts
import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
```

Create `apps/api/src/prisma/prisma.module.ts`:

```ts
import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
```

Modify `apps/api/src/app.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), PrismaModule],
})
export class AppModule {}
```

- [ ] **Step 3: Seed realistic MVP data**

Create `apps/api/prisma/seed.ts`:

```ts
import { PrismaClient, UserRole } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  await prisma.city.upsert({
    where: { id: 'seed-city-hangzhou' },
    update: {},
    create: {
      id: 'seed-city-hangzhou',
      name: '杭州市',
      isEnabled: true,
      districts: {
        create: [
          { name: '西湖区', isEnabled: true },
          { name: '余杭区', isEnabled: true },
        ],
      },
    },
  });

  const categories = [
    { slug: 'whole-home-renovation', name: '全屋翻新', description: '适合整屋改造和系统装修。' },
    { slug: 'old-home-renovation', name: '旧房翻新', description: '适合老房整体翻新和局部升级。' },
    { slug: 'kitchen-renovation', name: '厨房改造', description: '适合厨房拆改、水电、贴砖和安装。' },
    { slug: 'bathroom-renovation', name: '卫生间改造', description: '适合防水、水电、贴砖和洁具安装。' },
  ];

  for (const category of categories) {
    await prisma.projectCategory.upsert({
      where: { slug: category.slug },
      update: { name: category.name, description: category.description, isPublished: true },
      create: { ...category, isPublished: true },
    });
  }

  const kitchen = await prisma.projectCategory.findUniqueOrThrow({ where: { slug: 'kitchen-renovation' } });
  const kitchenStages = ['拆除', '水电调整', '防水', '贴砖', '吊顶/橱柜衔接', '安装', '验收'];
  for (const [index, name] of kitchenStages.entries()) {
    await prisma.stageTemplate.upsert({
      where: { categoryId_sortOrder: { categoryId: kitchen.id, sortOrder: index + 1 } },
      update: { name },
      create: { categoryId: kitchen.id, name, sortOrder: index + 1 },
    });
  }

  await prisma.user.upsert({
    where: { phone: '18800000001' },
    update: {},
    create: {
      phone: '18800000001',
      displayName: '平台客服',
      roles: [UserRole.ADMIN, UserRole.CUSTOMER_SERVICE],
    },
  });
}

main()
  .finally(async () => {
    await prisma.$disconnect();
  });
```

- [ ] **Step 4: Run database migration**

Run:

```bash
cd apps/api
cp .env.example .env
docker compose up -d
pnpm prisma:generate
pnpm prisma:migrate --name init
pnpm prisma:seed
```

Expected:

- PostgreSQL container starts.
- Prisma client generates.
- Migration creates tables.
- Seed creates city, project categories, stage template, and admin user.

- [ ] **Step 5: Commit**

```bash
git add apps/api
git commit -m "feat: add platform data model"
```

## Task 3: Implement Auth, Current User, and Roles

**Files:**

- Create: `apps/api/src/common/auth/current-user.decorator.ts`
- Create: `apps/api/src/common/auth/jwt-auth.guard.ts`
- Create: `apps/api/src/common/auth/roles.decorator.ts`
- Create: `apps/api/src/common/auth/roles.guard.ts`
- Create: `apps/api/src/modules/auth/auth.module.ts`
- Create: `apps/api/src/modules/auth/auth.controller.ts`
- Create: `apps/api/src/modules/auth/auth.service.ts`
- Modify: `apps/api/src/app.module.ts`
- Test: `apps/api/test/auth.e2e-spec.ts`

- [ ] **Step 1: Write auth e2e test**

Create `apps/api/test/auth.e2e-spec.ts`:

```ts
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Auth', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api');
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('logs in a homeowner with phone code in local dev mode', async () => {
    const response = await request(app.getHttpServer())
      .post('/api/auth/phone-login')
      .send({ phone: '18812345678', code: '000000', role: 'HOMEOWNER' })
      .expect(201);

    expect(response.body.accessToken).toEqual(expect.any(String));
    expect(response.body.user.phone).toBe('18812345678');
    expect(response.body.user.roles).toContain('HOMEOWNER');
  });
});
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
cd apps/api
pnpm test:e2e -- auth.e2e-spec.ts
```

Expected: FAIL because `AuthModule` and `/api/auth/phone-login` do not exist.

- [ ] **Step 3: Implement auth code**

Create `apps/api/src/common/auth/current-user.decorator.ts`:

```ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export type RequestUser = {
  id: string;
  phone: string;
  roles: string[];
};

export const CurrentUser = createParamDecorator((_data: unknown, ctx: ExecutionContext): RequestUser => {
  const request = ctx.switchToHttp().getRequest<{ user: RequestUser }>();
  return request.user;
});
```

Create `apps/api/src/common/auth/roles.decorator.ts`:

```ts
import { SetMetadata } from '@nestjs/common';
import { UserRole } from '@prisma/client';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);
```

Create `apps/api/src/common/auth/jwt-auth.guard.ts`:

```ts
import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(private readonly jwtService: JwtService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<{ headers: Record<string, string>; user?: unknown }>();
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing bearer token');
    }
    const token = header.slice('Bearer '.length);
    request.user = this.jwtService.verify(token);
    return true;
  }
}
```

Create `apps/api/src/common/auth/roles.guard.ts`:

```ts
import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { UserRole } from '@prisma/client';
import { ROLES_KEY } from './roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<UserRole[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredRoles?.length) return true;

    const request = context.switchToHttp().getRequest<{ user?: { roles?: UserRole[] } }>();
    const userRoles = request.user?.roles ?? [];
    const allowed = requiredRoles.some((role) => userRoles.includes(role));
    if (!allowed) throw new ForbiddenException('Insufficient role');
    return true;
  }
}
```

Create `apps/api/src/modules/auth/auth.service.ts`:

```ts
import { BadRequestException, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

type PhoneLoginInput = {
  phone: string;
  code: string;
  role: UserRole;
};

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async phoneLogin(input: PhoneLoginInput) {
    if (input.code !== '000000') {
      throw new BadRequestException('Invalid verification code in local dev mode');
    }

    const user = await this.prisma.user.upsert({
      where: { phone: input.phone },
      update: {
        roles: { set: [input.role] },
      },
      create: {
        phone: input.phone,
        roles: [input.role],
      },
    });

    const accessToken = await this.jwtService.signAsync({
      id: user.id,
      phone: user.phone,
      roles: user.roles,
    });

    return {
      accessToken,
      user: {
        id: user.id,
        phone: user.phone,
        displayName: user.displayName,
        roles: user.roles,
      },
    };
  }
}
```

Create `apps/api/src/modules/auth/auth.controller.ts`:

```ts
import { Body, Controller, Post } from '@nestjs/common';
import { IsEnum, IsPhoneNumber, IsString, Length } from 'class-validator';
import { UserRole } from '@prisma/client';
import { AuthService } from './auth.service';

class PhoneLoginDto {
  @IsPhoneNumber('CN')
  phone!: string;

  @IsString()
  @Length(6, 6)
  code!: string;

  @IsEnum(UserRole)
  role!: UserRole;
}

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('phone-login')
  phoneLogin(@Body() body: PhoneLoginDto) {
    return this.authService.phoneLogin(body);
  }
}
```

Create `apps/api/src/modules/auth/auth.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

@Module({
  imports: [
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET') ?? 'local-dev-secret',
        signOptions: { expiresIn: '30d' },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService],
  exports: [JwtModule],
})
export class AuthModule {}
```

Modify `apps/api/src/app.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), PrismaModule, AuthModule],
})
export class AppModule {}
```

- [ ] **Step 4: Run auth test**

Run:

```bash
cd apps/api
pnpm test:e2e -- auth.e2e-spec.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/api
git commit -m "feat: add phone auth and roles"
```

## Task 4: Implement Catalog APIs

**Files:**

- Create: `apps/api/src/modules/catalog/catalog.module.ts`
- Create: `apps/api/src/modules/catalog/catalog.controller.ts`
- Create: `apps/api/src/modules/catalog/catalog.service.ts`
- Modify: `apps/api/src/app.module.ts`

- [ ] **Step 1: Implement catalog service**

Create `apps/api/src/modules/catalog/catalog.service.ts`:

```ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  listEnabledCities() {
    return this.prisma.city.findMany({
      where: { isEnabled: true },
      include: { districts: { where: { isEnabled: true }, orderBy: { name: 'asc' } } },
      orderBy: { name: 'asc' },
    });
  }

  listPublishedCategories() {
    return this.prisma.projectCategory.findMany({
      where: { isPublished: true },
      include: { stageTemplates: { orderBy: { sortOrder: 'asc' } } },
      orderBy: { name: 'asc' },
    });
  }
}
```

- [ ] **Step 2: Implement catalog controller**

Create `apps/api/src/modules/catalog/catalog.controller.ts`:

```ts
import { Controller, Get } from '@nestjs/common';
import { CatalogService } from './catalog.service';

@Controller('catalog')
export class CatalogController {
  constructor(private readonly catalogService: CatalogService) {}

  @Get('cities')
  listCities() {
    return this.catalogService.listEnabledCities();
  }

  @Get('project-categories')
  listCategories() {
    return this.catalogService.listPublishedCategories();
  }
}
```

Create `apps/api/src/modules/catalog/catalog.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { CatalogController } from './catalog.controller';
import { CatalogService } from './catalog.service';

@Module({
  controllers: [CatalogController],
  providers: [CatalogService],
})
export class CatalogModule {}
```

Modify `apps/api/src/app.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { CatalogModule } from './modules/catalog/catalog.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), PrismaModule, AuthModule, CatalogModule],
})
export class AppModule {}
```

- [ ] **Step 3: Verify seeded catalog**

Run:

```bash
cd apps/api
pnpm start:dev
curl http://localhost:3000/api/catalog/project-categories
```

Expected: response includes `全屋翻新`, `旧房翻新`, `厨房改造`, and `卫生间改造`.

- [ ] **Step 4: Commit**

```bash
git add apps/api
git commit -m "feat: add public catalog api"
```

## Task 5: Implement Booking Creation with Privacy Output

**Files:**

- Create: `apps/api/src/common/privacy/privacy.service.ts`
- Create: `apps/api/src/modules/bookings/bookings.module.ts`
- Create: `apps/api/src/modules/bookings/bookings.controller.ts`
- Create: `apps/api/src/modules/bookings/bookings.service.ts`
- Modify: `apps/api/src/app.module.ts`
- Test: `apps/api/test/booking-privacy.e2e-spec.ts`

- [ ] **Step 1: Write privacy test**

Create `apps/api/test/booking-privacy.e2e-spec.ts`:

```ts
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Booking privacy', () => {
  let app: INestApplication;
  let homeownerToken: string;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api');
    await app.init();

    const login = await request(app.getHttpServer())
      .post('/api/auth/phone-login')
      .send({ phone: '18812345679', code: '000000', role: 'HOMEOWNER' });
    homeownerToken = login.body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('creates a booking and returns masked address in public-safe summary', async () => {
    const categories = await request(app.getHttpServer()).get('/api/catalog/project-categories');
    const categoryId = categories.body[0].id;

    const response = await request(app.getHttpServer())
      .post('/api/bookings')
      .set('Authorization', `Bearer ${homeownerToken}`)
      .send({
        categoryId,
        city: '杭州市',
        district: '西湖区',
        community: '未来小区',
        fullAddress: '杭州市西湖区未来小区 3 幢 1201',
        homeAreaSqm: 88,
        bedrooms: 3,
        livingRooms: 2,
        kitchens: 1,
        bathrooms: 1,
        houseStatus: '旧房',
        renovationScope: '全改',
        preferredVisitAt: '2026-07-01T02:00:00.000Z',
        note: '希望先看厨房和卫生间'
      })
      .expect(201);

    expect(response.body.maskedAddress).toBe('杭州市 西湖区 未来小区');
    expect(JSON.stringify(response.body)).not.toContain('1201');
  });
});
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
cd apps/api
pnpm test:e2e -- booking-privacy.e2e-spec.ts
```

Expected: FAIL because bookings API does not exist.

- [ ] **Step 3: Implement privacy service**

Create `apps/api/src/common/privacy/privacy.service.ts`:

```ts
import { Injectable } from '@nestjs/common';

@Injectable()
export class PrivacyService {
  maskAddress(input: { city: string; district: string; community: string }) {
    return `${input.city} ${input.district} ${input.community}`;
  }

  buildVirtualPhoneLabel() {
    return '虚拟号码联系';
  }
}
```

- [ ] **Step 4: Implement booking service**

Create `apps/api/src/modules/bookings/bookings.service.ts`:

```ts
import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrivacyService } from '../../common/privacy/privacy.service';
import { PrismaService } from '../../prisma/prisma.service';

type CreateBookingInput = {
  homeownerId: string;
  categoryId: string;
  city: string;
  district: string;
  community: string;
  fullAddress: string;
  homeAreaSqm: number;
  bedrooms: number;
  livingRooms: number;
  kitchens: number;
  bathrooms: number;
  houseStatus: string;
  renovationScope: string;
  preferredVisitAt: string;
  note?: string;
};

@Injectable()
export class BookingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly privacy: PrivacyService,
  ) {}

  async create(input: CreateBookingInput) {
    const booking = await this.prisma.booking.create({
      data: {
        homeownerId: input.homeownerId,
        categoryId: input.categoryId,
        city: input.city,
        district: input.district,
        community: input.community,
        fullAddress: input.fullAddress,
        homeAreaSqm: new Prisma.Decimal(input.homeAreaSqm),
        bedrooms: input.bedrooms,
        livingRooms: input.livingRooms,
        kitchens: input.kitchens,
        bathrooms: input.bathrooms,
        houseStatus: input.houseStatus,
        renovationScope: input.renovationScope,
        preferredVisitAt: new Date(input.preferredVisitAt),
        note: input.note,
      },
    });

    return {
      id: booking.id,
      status: booking.status,
      maskedAddress: this.privacy.maskAddress(booking),
      virtualPhone: this.privacy.buildVirtualPhoneLabel(),
      createdAt: booking.createdAt,
    };
  }
}
```

- [ ] **Step 5: Implement booking controller and module**

Create `apps/api/src/modules/bookings/bookings.controller.ts`:

```ts
import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { IsDateString, IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { CurrentUser, RequestUser } from '../../common/auth/current-user.decorator';
import { JwtAuthGuard } from '../../common/auth/jwt-auth.guard';
import { BookingsService } from './bookings.service';

class CreateBookingDto {
  @IsString()
  categoryId!: string;

  @IsString()
  city!: string;

  @IsString()
  district!: string;

  @IsString()
  community!: string;

  @IsString()
  fullAddress!: string;

  @IsNumber()
  @Min(1)
  homeAreaSqm!: number;

  @IsInt()
  bedrooms!: number;

  @IsInt()
  livingRooms!: number;

  @IsInt()
  kitchens!: number;

  @IsInt()
  bathrooms!: number;

  @IsString()
  houseStatus!: string;

  @IsString()
  renovationScope!: string;

  @IsDateString()
  preferredVisitAt!: string;

  @IsOptional()
  @IsString()
  note?: string;
}

@UseGuards(JwtAuthGuard)
@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  @Post()
  create(@CurrentUser() user: RequestUser, @Body() body: CreateBookingDto) {
    return this.bookingsService.create({ homeownerId: user.id, ...body });
  }
}
```

Create `apps/api/src/modules/bookings/bookings.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { PrivacyService } from '../../common/privacy/privacy.service';
import { BookingsController } from './bookings.controller';
import { BookingsService } from './bookings.service';

@Module({
  controllers: [BookingsController],
  providers: [BookingsService, PrivacyService],
})
export class BookingsModule {}
```

Modify `apps/api/src/app.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { BookingsModule } from './modules/bookings/bookings.module';
import { CatalogModule } from './modules/catalog/catalog.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), PrismaModule, AuthModule, CatalogModule, BookingsModule],
})
export class AppModule {}
```

- [ ] **Step 6: Run privacy test**

Run:

```bash
cd apps/api
pnpm test:e2e -- booking-privacy.e2e-spec.ts
```

Expected: PASS and response never exposes the door number.

- [ ] **Step 7: Commit**

```bash
git add apps/api
git commit -m "feat: add privacy-safe booking api"
```

## Task 6: Implement Foreman Review and Dispatch-to-Project Workflow

**Files:**

- Create: `apps/api/src/modules/foremen/foremen.module.ts`
- Create: `apps/api/src/modules/foremen/foremen.controller.ts`
- Create: `apps/api/src/modules/foremen/foremen.service.ts`
- Create: `apps/api/src/modules/dispatch/dispatch.module.ts`
- Create: `apps/api/src/modules/dispatch/dispatch.controller.ts`
- Create: `apps/api/src/modules/dispatch/dispatch.service.ts`
- Create: `apps/api/test/dispatch-project.e2e-spec.ts`
- Modify: `apps/api/src/app.module.ts`

- [ ] **Step 1: Write dispatch e2e test**

Create `apps/api/test/dispatch-project.e2e-spec.ts`:

```ts
import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Dispatch to project', () => {
  let app: INestApplication;
  let adminToken: string;
  let homeownerToken: string;
  let foremanToken: string;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api');
    await app.init();

    adminToken = (await request(app.getHttpServer()).post('/api/auth/phone-login').send({ phone: '18800000001', code: '000000', role: 'ADMIN' })).body.accessToken;
    homeownerToken = (await request(app.getHttpServer()).post('/api/auth/phone-login').send({ phone: '18812345680', code: '000000', role: 'HOMEOWNER' })).body.accessToken;
    foremanToken = (await request(app.getHttpServer()).post('/api/auth/phone-login').send({ phone: '18812345681', code: '000000', role: 'FOREMAN' })).body.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('creates project stages only after foreman acceptance and homeowner cooperation confirmation', async () => {
    const foremanProfile = await request(app.getHttpServer())
      .post('/api/foremen/profile')
      .set('Authorization', `Bearer ${foremanToken}`)
      .send({ realName: '张工长', serviceSummary: '擅长厨房和卫生间改造', yearsExperience: 12 })
      .expect(201);

    await request(app.getHttpServer())
      .post(`/api/foremen/${foremanProfile.body.id}/approve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(201);

    const categories = await request(app.getHttpServer()).get('/api/catalog/project-categories');
    const kitchenCategory = categories.body.find((item: { slug: string }) => item.slug === 'kitchen-renovation');
    const booking = await request(app.getHttpServer())
      .post('/api/bookings')
      .set('Authorization', `Bearer ${homeownerToken}`)
      .send({
        categoryId: kitchenCategory.id,
        city: '杭州市',
        district: '西湖区',
        community: '未来小区',
        fullAddress: '杭州市西湖区未来小区 3 幢 1201',
        homeAreaSqm: 88,
        bedrooms: 3,
        livingRooms: 2,
        kitchens: 1,
        bathrooms: 1,
        houseStatus: '旧房',
        renovationScope: '全改',
        preferredVisitAt: '2026-07-01T02:00:00.000Z'
      });

    const dispatch = await request(app.getHttpServer())
      .post('/api/dispatches')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ bookingId: booking.body.id, foremanUserId: foremanProfile.body.userId, note: '客服已确认' })
      .expect(201);

    const acceptedDispatch = await request(app.getHttpServer())
      .post(`/api/dispatches/${dispatch.body.id}/accept`)
      .set('Authorization', `Bearer ${foremanToken}`)
      .expect(201);

    expect(acceptedDispatch.body.status).toBe('ACCEPTED');

    const project = await request(app.getHttpServer())
      .post(`/api/dispatches/${dispatch.body.id}/confirm-cooperation`)
      .set('Authorization', `Bearer ${homeownerToken}`)
      .expect(201);

    expect(project.body.status).toBe('ACTIVE');
    expect(project.body.stages.length).toBeGreaterThan(0);
  });
});
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
cd apps/api
pnpm test:e2e -- dispatch-project.e2e-spec.ts
```

Expected: FAIL because foreman and dispatch APIs do not exist.

- [ ] **Step 3: Implement foreman module**

Create `apps/api/src/modules/foremen/foremen.service.ts`:

```ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { ForemanReviewStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class ForemenService {
  constructor(private readonly prisma: PrismaService) {}

  createProfile(userId: string, input: { realName: string; serviceSummary: string; yearsExperience: number }) {
    return this.prisma.foremanProfile.upsert({
      where: { userId },
      update: { ...input, reviewStatus: ForemanReviewStatus.PENDING },
      create: { userId, ...input },
    });
  }

  async approve(profileId: string) {
    const profile = await this.prisma.foremanProfile.findUnique({ where: { id: profileId } });
    if (!profile) throw new NotFoundException('Foreman profile not found');
    return this.prisma.foremanProfile.update({
      where: { id: profileId },
      data: { reviewStatus: ForemanReviewStatus.APPROVED, reviewNote: null },
    });
  }
}
```

Create `apps/api/src/modules/foremen/foremen.controller.ts`:

```ts
import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { IsInt, IsString, Min } from 'class-validator';
import { UserRole } from '@prisma/client';
import { CurrentUser, RequestUser } from '../../common/auth/current-user.decorator';
import { JwtAuthGuard } from '../../common/auth/jwt-auth.guard';
import { Roles } from '../../common/auth/roles.decorator';
import { RolesGuard } from '../../common/auth/roles.guard';
import { ForemenService } from './foremen.service';

class CreateForemanProfileDto {
  @IsString()
  realName!: string;

  @IsString()
  serviceSummary!: string;

  @IsInt()
  @Min(0)
  yearsExperience!: number;
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('foremen')
export class ForemenController {
  constructor(private readonly foremenService: ForemenService) {}

  @Post('profile')
  @Roles(UserRole.FOREMAN)
  createProfile(@CurrentUser() user: RequestUser, @Body() body: CreateForemanProfileDto) {
    return this.foremenService.createProfile(user.id, body);
  }

  @Post(':profileId/approve')
  @Roles(UserRole.ADMIN, UserRole.CUSTOMER_SERVICE)
  approve(@Param('profileId') profileId: string) {
    return this.foremenService.approve(profileId);
  }
}
```

Create `apps/api/src/modules/foremen/foremen.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/auth/jwt-auth.guard';
import { RolesGuard } from '../../common/auth/roles.guard';
import { AuthModule } from '../auth/auth.module';
import { ForemenController } from './foremen.controller';
import { ForemenService } from './foremen.service';

@Module({
  imports: [AuthModule],
  controllers: [ForemenController],
  providers: [ForemenService, JwtAuthGuard, RolesGuard],
})
export class ForemenModule {}
```

- [ ] **Step 4: Implement dispatch module**

Create `apps/api/src/modules/dispatch/dispatch.service.ts`:

```ts
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { BookingStatus, DispatchStatus, ForemanReviewStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class DispatchService {
  constructor(private readonly prisma: PrismaService) {}

  async create(input: { bookingId: string; foremanUserId: string; assignedBy: string; note?: string }) {
    const foreman = await this.prisma.foremanProfile.findUnique({ where: { userId: input.foremanUserId } });
    if (!foreman || foreman.reviewStatus !== ForemanReviewStatus.APPROVED) {
      throw new BadRequestException('Foreman must be approved before dispatch');
    }

    const dispatch = await this.prisma.dispatch.create({
      data: {
        bookingId: input.bookingId,
        foremanId: input.foremanUserId,
        assignedBy: input.assignedBy,
        note: input.note,
      },
    });

    await this.prisma.booking.update({
      where: { id: input.bookingId },
      data: { status: BookingStatus.DISPATCHED },
    });

    return dispatch;
  }

  async accept(dispatchId: string, foremanUserId: string) {
    const dispatch = await this.prisma.dispatch.findUnique({
      where: { id: dispatchId },
    });
    if (!dispatch) throw new NotFoundException('Dispatch not found');
    if (dispatch.foremanId !== foremanUserId) throw new BadRequestException('Dispatch belongs to another foreman');

    const acceptedDispatch = await this.prisma.dispatch.update({
      where: { id: dispatchId },
      data: { status: DispatchStatus.ACCEPTED },
    });
    await this.prisma.booking.update({
      where: { id: dispatch.bookingId },
      data: { status: BookingStatus.FOREMAN_ACCEPTED },
    });

    return acceptedDispatch;
  }

  async confirmCooperation(dispatchId: string, homeownerId: string) {
    const dispatch = await this.prisma.dispatch.findUnique({
      where: { id: dispatchId },
      include: {
        booking: {
          include: {
            category: { include: { stageTemplates: { orderBy: { sortOrder: 'asc' } } } },
          },
        },
      },
    });
    if (!dispatch) throw new NotFoundException('Dispatch not found');
    if (dispatch.status !== DispatchStatus.ACCEPTED) {
      throw new BadRequestException('Foreman must accept before cooperation can be confirmed');
    }
    if (dispatch.booking.homeownerId !== homeownerId) {
      throw new BadRequestException('Only the booking homeowner can confirm cooperation');
    }

    await this.prisma.booking.update({
      where: { id: dispatch.bookingId },
      data: { status: BookingStatus.COOPERATION_CONFIRMED },
    });

    return this.prisma.project.create({
      data: {
        bookingId: dispatch.bookingId,
        homeownerId: dispatch.booking.homeownerId,
        foremanId: dispatch.foremanId,
        stages: {
          create: dispatch.booking.category.stageTemplates.map((template) => ({
            name: template.name,
            sortOrder: template.sortOrder,
          })),
        },
      },
      include: { stages: { orderBy: { sortOrder: 'asc' } } },
    });
  }
}
```

Create `apps/api/src/modules/dispatch/dispatch.controller.ts`:

```ts
import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { IsOptional, IsString } from 'class-validator';
import { UserRole } from '@prisma/client';
import { CurrentUser, RequestUser } from '../../common/auth/current-user.decorator';
import { JwtAuthGuard } from '../../common/auth/jwt-auth.guard';
import { Roles } from '../../common/auth/roles.decorator';
import { RolesGuard } from '../../common/auth/roles.guard';
import { DispatchService } from './dispatch.service';

class CreateDispatchDto {
  @IsString()
  bookingId!: string;

  @IsString()
  foremanUserId!: string;

  @IsOptional()
  @IsString()
  note?: string;
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('dispatches')
export class DispatchController {
  constructor(private readonly dispatchService: DispatchService) {}

  @Post()
  @Roles(UserRole.ADMIN, UserRole.CUSTOMER_SERVICE)
  create(@CurrentUser() user: RequestUser, @Body() body: CreateDispatchDto) {
    return this.dispatchService.create({ ...body, assignedBy: user.id });
  }

  @Post(':dispatchId/accept')
  @Roles(UserRole.FOREMAN)
  accept(@CurrentUser() user: RequestUser, @Param('dispatchId') dispatchId: string) {
    return this.dispatchService.accept(dispatchId, user.id);
  }

  @Post(':dispatchId/confirm-cooperation')
  @Roles(UserRole.HOMEOWNER)
  confirmCooperation(@CurrentUser() user: RequestUser, @Param('dispatchId') dispatchId: string) {
    return this.dispatchService.confirmCooperation(dispatchId, user.id);
  }
}
```

Create `apps/api/src/modules/dispatch/dispatch.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/auth/jwt-auth.guard';
import { RolesGuard } from '../../common/auth/roles.guard';
import { AuthModule } from '../auth/auth.module';
import { DispatchController } from './dispatch.controller';
import { DispatchService } from './dispatch.service';

@Module({
  imports: [AuthModule],
  controllers: [DispatchController],
  providers: [DispatchService, JwtAuthGuard, RolesGuard],
})
export class DispatchModule {}
```

Modify `apps/api/src/app.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { BookingsModule } from './modules/bookings/bookings.module';
import { CatalogModule } from './modules/catalog/catalog.module';
import { DispatchModule } from './modules/dispatch/dispatch.module';
import { ForemenModule } from './modules/foremen/foremen.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    CatalogModule,
    BookingsModule,
    ForemenModule,
    DispatchModule,
  ],
})
export class AppModule {}
```

- [ ] **Step 5: Run dispatch test**

Run:

```bash
cd apps/api
pnpm test:e2e -- dispatch-project.e2e-spec.ts
```

Expected: PASS; foreman acceptance only changes the booking to `FOREMAN_ACCEPTED`, and homeowner confirmation creates an active project with category stages.

- [ ] **Step 6: Commit**

```bash
git add apps/api
git commit -m "feat: add foreman review and dispatch workflow"
```

## Task 7: Add Project Stage, Daily Photo, and Activity Review APIs

**Files:**

- Create: `apps/api/src/modules/projects/projects.module.ts`
- Create: `apps/api/src/modules/projects/projects.controller.ts`
- Create: `apps/api/src/modules/projects/projects.service.ts`
- Create: `apps/api/src/modules/activity/activity.module.ts`
- Create: `apps/api/src/modules/activity/activity.controller.ts`
- Create: `apps/api/src/modules/activity/activity.service.ts`
- Modify: `apps/api/src/app.module.ts`

- [ ] **Step 1: Implement project service**

Create `apps/api/src/modules/projects/projects.service.ts`:

```ts
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { StageStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class ProjectsService {
  constructor(private readonly prisma: PrismaService) {}

  listForUser(userId: string) {
    return this.prisma.project.findMany({
      where: { OR: [{ homeownerId: userId }, { foremanId: userId }] },
      include: { stages: { orderBy: { sortOrder: 'asc' } }, dailyPhotos: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async submitStage(stageId: string, foremanId: string, input: { imageUrl: string; caption?: string }) {
    const stage = await this.prisma.projectStage.findUnique({ where: { id: stageId }, include: { project: true } });
    if (!stage) throw new NotFoundException('Stage not found');
    if (stage.project.foremanId !== foremanId) throw new BadRequestException('Only assigned foreman can submit stage');

    await this.prisma.stagePhoto.create({ data: { stageId, imageUrl: input.imageUrl, caption: input.caption } });
    return this.prisma.projectStage.update({
      where: { id: stageId },
      data: { status: StageStatus.SUBMITTED, submittedAt: new Date() },
      include: { photos: true },
    });
  }

  async confirmStage(stageId: string, homeownerId: string) {
    const stage = await this.prisma.projectStage.findUnique({ where: { id: stageId }, include: { project: true } });
    if (!stage) throw new NotFoundException('Stage not found');
    if (stage.project.homeownerId !== homeownerId) throw new BadRequestException('Only homeowner can confirm stage');

    return this.prisma.projectStage.update({
      where: { id: stageId },
      data: { status: StageStatus.CONFIRMED, confirmedAt: new Date(), rejectReason: null },
    });
  }

  async rejectStage(stageId: string, homeownerId: string, rejectReason: string) {
    const stage = await this.prisma.projectStage.findUnique({ where: { id: stageId }, include: { project: true } });
    if (!stage) throw new NotFoundException('Stage not found');
    if (stage.project.homeownerId !== homeownerId) throw new BadRequestException('Only homeowner can reject stage');

    return this.prisma.projectStage.update({
      where: { id: stageId },
      data: { status: StageStatus.REJECTED, rejectedAt: new Date(), rejectReason },
    });
  }

  async addDailyPhoto(projectId: string, foremanId: string, input: { imageUrl: string; capturedAt: string; watermark: string; workContent: string }) {
    const project = await this.prisma.project.findUnique({ where: { id: projectId } });
    if (!project) throw new NotFoundException('Project not found');
    if (project.foremanId !== foremanId) throw new BadRequestException('Only assigned foreman can upload daily photos');

    return this.prisma.dailyWorkPhoto.create({
      data: {
        projectId,
        imageUrl: input.imageUrl,
        capturedAt: new Date(input.capturedAt),
        watermark: input.watermark,
        workContent: input.workContent,
      },
    });
  }
}
```

- [ ] **Step 2: Implement project controller and module**

Create `apps/api/src/modules/projects/projects.controller.ts`:

```ts
import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { IsDateString, IsString } from 'class-validator';
import { UserRole } from '@prisma/client';
import { CurrentUser, RequestUser } from '../../common/auth/current-user.decorator';
import { JwtAuthGuard } from '../../common/auth/jwt-auth.guard';
import { Roles } from '../../common/auth/roles.decorator';
import { RolesGuard } from '../../common/auth/roles.guard';
import { ProjectsService } from './projects.service';

class SubmitStageDto {
  @IsString()
  imageUrl!: string;

  @IsString()
  caption?: string;
}

class RejectStageDto {
  @IsString()
  rejectReason!: string;
}

class AddDailyPhotoDto {
  @IsString()
  imageUrl!: string;

  @IsDateString()
  capturedAt!: string;

  @IsString()
  watermark!: string;

  @IsString()
  workContent!: string;
}

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('projects')
export class ProjectsController {
  constructor(private readonly projectsService: ProjectsService) {}

  @Get()
  listMine(@CurrentUser() user: RequestUser) {
    return this.projectsService.listForUser(user.id);
  }

  @Post('stages/:stageId/submit')
  @Roles(UserRole.FOREMAN)
  submitStage(@CurrentUser() user: RequestUser, @Param('stageId') stageId: string, @Body() body: SubmitStageDto) {
    return this.projectsService.submitStage(stageId, user.id, body);
  }

  @Post('stages/:stageId/confirm')
  @Roles(UserRole.HOMEOWNER)
  confirmStage(@CurrentUser() user: RequestUser, @Param('stageId') stageId: string) {
    return this.projectsService.confirmStage(stageId, user.id);
  }

  @Post('stages/:stageId/reject')
  @Roles(UserRole.HOMEOWNER)
  rejectStage(@CurrentUser() user: RequestUser, @Param('stageId') stageId: string, @Body() body: RejectStageDto) {
    return this.projectsService.rejectStage(stageId, user.id, body.rejectReason);
  }

  @Post(':projectId/daily-photos')
  @Roles(UserRole.FOREMAN)
  addDailyPhoto(@CurrentUser() user: RequestUser, @Param('projectId') projectId: string, @Body() body: AddDailyPhotoDto) {
    return this.projectsService.addDailyPhoto(projectId, user.id, body);
  }
}
```

Create `apps/api/src/modules/projects/projects.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/auth/jwt-auth.guard';
import { RolesGuard } from '../../common/auth/roles.guard';
import { AuthModule } from '../auth/auth.module';
import { ProjectsController } from './projects.controller';
import { ProjectsService } from './projects.service';

@Module({
  imports: [AuthModule],
  controllers: [ProjectsController],
  providers: [ProjectsService, JwtAuthGuard, RolesGuard],
})
export class ProjectsModule {}
```

- [ ] **Step 3: Implement activity review module**

Create `apps/api/src/modules/activity/activity.service.ts`:

```ts
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ActivityStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class ActivityService {
  constructor(private readonly prisma: PrismaService) {}

  async submitFromDailyPhoto(foremanId: string, input: { dailyPhotoId: string; title: string; content: string }) {
    const photo = await this.prisma.dailyWorkPhoto.findUnique({ where: { id: input.dailyPhotoId }, include: { project: true } });
    if (!photo) throw new NotFoundException('Daily photo not found');
    if (photo.project.foremanId !== foremanId) throw new BadRequestException('Only assigned foreman can submit this photo');

    return this.prisma.foremanActivity.create({
      data: {
        dailyPhotoId: input.dailyPhotoId,
        foremanId,
        title: input.title,
        content: input.content,
        status: ActivityStatus.SUBMITTED,
      },
    });
  }

  approve(activityId: string) {
    return this.prisma.foremanActivity.update({
      where: { id: activityId },
      data: { status: ActivityStatus.PUBLISHED, publishedAt: new Date(), reviewNote: null },
    });
  }

  reject(activityId: string, reviewNote: string) {
    return this.prisma.foremanActivity.update({
      where: { id: activityId },
      data: { status: ActivityStatus.REJECTED, reviewNote },
    });
  }

  listPublished() {
    return this.prisma.foremanActivity.findMany({
      where: { status: ActivityStatus.PUBLISHED },
      include: { dailyPhoto: true, likes: true, comments: true },
      orderBy: { publishedAt: 'desc' },
    });
  }

  like(activityId: string, userId: string) {
    return this.prisma.activityLike.upsert({
      where: { activityId_userId: { activityId, userId } },
      update: {},
      create: { activityId, userId },
    });
  }

  comment(activityId: string, userId: string, content: string) {
    return this.prisma.activityComment.create({
      data: { activityId, userId, content },
    });
  }
}
```

Create `apps/api/src/modules/activity/activity.controller.ts`:

```ts
import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { IsString } from 'class-validator';
import { UserRole } from '@prisma/client';
import { CurrentUser, RequestUser } from '../../common/auth/current-user.decorator';
import { JwtAuthGuard } from '../../common/auth/jwt-auth.guard';
import { Roles } from '../../common/auth/roles.decorator';
import { RolesGuard } from '../../common/auth/roles.guard';
import { ActivityService } from './activity.service';

class SubmitActivityDto {
  @IsString()
  dailyPhotoId!: string;

  @IsString()
  title!: string;

  @IsString()
  content!: string;
}

class RejectActivityDto {
  @IsString()
  reviewNote!: string;
}

class CommentActivityDto {
  @IsString()
  content!: string;
}

@Controller('activities')
export class ActivityController {
  constructor(private readonly activityService: ActivityService) {}

  @Get('public')
  listPublished() {
    return this.activityService.listPublished();
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Post()
  @Roles(UserRole.FOREMAN)
  submit(@CurrentUser() user: RequestUser, @Body() body: SubmitActivityDto) {
    return this.activityService.submitFromDailyPhoto(user.id, body);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Post(':activityId/approve')
  @Roles(UserRole.ADMIN, UserRole.CUSTOMER_SERVICE)
  approve(@Param('activityId') activityId: string) {
    return this.activityService.approve(activityId);
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Post(':activityId/reject')
  @Roles(UserRole.ADMIN, UserRole.CUSTOMER_SERVICE)
  reject(@Param('activityId') activityId: string, @Body() body: RejectActivityDto) {
    return this.activityService.reject(activityId, body.reviewNote);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':activityId/like')
  like(@CurrentUser() user: RequestUser, @Param('activityId') activityId: string) {
    return this.activityService.like(activityId, user.id);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':activityId/comments')
  comment(@CurrentUser() user: RequestUser, @Param('activityId') activityId: string, @Body() body: CommentActivityDto) {
    return this.activityService.comment(activityId, user.id, body.content);
  }
}
```

Create `apps/api/src/modules/activity/activity.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/auth/jwt-auth.guard';
import { RolesGuard } from '../../common/auth/roles.guard';
import { AuthModule } from '../auth/auth.module';
import { ActivityController } from './activity.controller';
import { ActivityService } from './activity.service';

@Module({
  imports: [AuthModule],
  controllers: [ActivityController],
  providers: [ActivityService, JwtAuthGuard, RolesGuard],
})
export class ActivityModule {}
```

Modify `apps/api/src/app.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ActivityModule } from './modules/activity/activity.module';
import { AuthModule } from './modules/auth/auth.module';
import { BookingsModule } from './modules/bookings/bookings.module';
import { CatalogModule } from './modules/catalog/catalog.module';
import { DispatchModule } from './modules/dispatch/dispatch.module';
import { ForemenModule } from './modules/foremen/foremen.module';
import { ProjectsModule } from './modules/projects/projects.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    CatalogModule,
    BookingsModule,
    ForemenModule,
    DispatchModule,
    ProjectsModule,
    ActivityModule,
  ],
})
export class AppModule {}
```

- [ ] **Step 4: Build and test**

Run:

```bash
cd apps/api
pnpm build
pnpm test:e2e
```

Expected: build passes and all e2e tests pass.

- [ ] **Step 5: Commit**

```bash
git add apps/api
git commit -m "feat: add project proof and activity review api"
```

## Task 8: Add Cloud Vendor Adapter Interfaces

**Files:**

- Create: `apps/api/src/common/cloud/cloud.module.ts`
- Create: `apps/api/src/common/cloud/sms.service.ts`
- Create: `apps/api/src/common/cloud/virtual-phone.service.ts`
- Create: `apps/api/src/common/cloud/storage.service.ts`
- Create: `apps/api/src/common/cloud/speech.service.ts`
- Modify: `apps/api/src/app.module.ts`

- [ ] **Step 1: Create cloud service adapters**

Create `apps/api/src/common/cloud/sms.service.ts`:

```ts
import { Injectable } from '@nestjs/common';

@Injectable()
export class SmsService {
  async sendLoginCode(phone: string, code: string) {
    return {
      provider: 'local-dev',
      phone,
      code,
      sent: true,
    };
  }
}
```

Create `apps/api/src/common/cloud/virtual-phone.service.ts`:

```ts
import { Injectable } from '@nestjs/common';

@Injectable()
export class VirtualPhoneService {
  async bindCall(input: { homeownerPhone: string; foremanPhone: string; expiresAt: Date }) {
    return {
      provider: 'local-dev',
      virtualNumber: 'local-dev-virtual-number',
      homeownerPhone: input.homeownerPhone,
      foremanPhone: input.foremanPhone,
      expiresAt: input.expiresAt,
    };
  }
}
```

Create `apps/api/src/common/cloud/storage.service.ts`:

```ts
import { Injectable } from '@nestjs/common';

@Injectable()
export class StorageService {
  createObjectUrl(path: string) {
    return `local://storage/${path}`;
  }
}
```

Create `apps/api/src/common/cloud/speech.service.ts`:

```ts
import { Injectable } from '@nestjs/common';

@Injectable()
export class SpeechService {
  async transcribeLocalPlaceholder(input: { audioUrl: string }) {
    return {
      audioUrl: input.audioUrl,
      text: '本地测试语音文本',
    };
  }
}
```

Create `apps/api/src/common/cloud/cloud.module.ts`:

```ts
import { Global, Module } from '@nestjs/common';
import { SmsService } from './sms.service';
import { SpeechService } from './speech.service';
import { StorageService } from './storage.service';
import { VirtualPhoneService } from './virtual-phone.service';

@Global()
@Module({
  providers: [SmsService, SpeechService, StorageService, VirtualPhoneService],
  exports: [SmsService, SpeechService, StorageService, VirtualPhoneService],
})
export class CloudModule {}
```

Modify `apps/api/src/app.module.ts` to import `CloudModule`:

```ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CloudModule } from './common/cloud/cloud.module';
import { ActivityModule } from './modules/activity/activity.module';
import { AuthModule } from './modules/auth/auth.module';
import { BookingsModule } from './modules/bookings/bookings.module';
import { CatalogModule } from './modules/catalog/catalog.module';
import { DispatchModule } from './modules/dispatch/dispatch.module';
import { ForemenModule } from './modules/foremen/foremen.module';
import { ProjectsModule } from './modules/projects/projects.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    CloudModule,
    AuthModule,
    CatalogModule,
    BookingsModule,
    ForemenModule,
    DispatchModule,
    ProjectsModule,
    ActivityModule,
  ],
})
export class AppModule {}
```

- [ ] **Step 2: Build**

Run:

```bash
cd apps/api
pnpm build
```

Expected: build passes. Production cloud vendors are not connected yet; adapters provide stable interfaces for later integration.

- [ ] **Step 3: Commit**

```bash
git add apps/api
git commit -m "chore: add cloud service adapter interfaces"
```

## Task 9: Final Backend Verification

**Files:**

- Modify only if verification exposes bugs.

- [ ] **Step 1: Run full backend checks**

Run:

```bash
cd apps/api
pnpm build
pnpm test:e2e
```

Expected:

- TypeScript build passes.
- Auth e2e test passes.
- Booking privacy e2e test passes.
- Dispatch-to-project e2e test passes.

- [ ] **Step 2: Manual API smoke check**

Run:

```bash
cd apps/api
pnpm start:dev
```

In another terminal:

```bash
curl http://localhost:3000/api/catalog/cities
curl http://localhost:3000/api/catalog/project-categories
```

Expected:

- Cities endpoint returns enabled cities and districts.
- Project categories endpoint returns published renovation categories and stage templates.

- [ ] **Step 3: Commit any verification fixes**

If fixes were required:

```bash
git add apps/api
git commit -m "fix: stabilize backend foundation"
```

If no fixes were required, do not create an empty commit.

## Real-World Logic Added Proactively

These business details were added because they are needed for real homeowner and foreman workflows:

- Bookings keep full address internally but return masked address by default.
- Dispatch requires approved foreman profile.
- Foreman acceptance does not create a project; the homeowner must separately confirm cooperation.
- Homeowner cooperation confirmation creates the construction project.
- Construction project stages are generated from category templates.
- Only the assigned foreman can submit stage and daily work photos.
- Only the homeowner can confirm or reject stages.
- Public foreman activity is not automatically published; it requires review.
- Published activity supports likes and comments/evaluations.
- Cloud services are abstracted behind adapters so the first backend can run locally while production can later use Alibaba Cloud or Tencent Cloud services for SMS, virtual numbers, storage, and speech recognition.

## Later Plans

Separate plans should be written after this backend foundation:

1. Web 管理后台实施计划。
2. 业主端 iOS App 实施计划。
3. 工长端 iOS App 实施计划。
4. 实时聊天、群聊和消息推送实施计划。
5. 水印相机、图片审核和师傅动态增强实施计划。
