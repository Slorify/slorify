# Docker + Prisma Instructions (Dev)

This documents the exact flow used to remove repeated polkit prompts and run Prisma migrations/generate with your current Docker Compose setup.

## 1) One-time Docker permission setup

Run once on host:

```bash
sudo usermod -aG docker aislx
newgrp docker
```

Verify:

```bash
id
docker ps
```

`id` should show `docker` in groups.

## 2) Start services

```bash
docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.dev.yml ps
```

## 3) Prisma commands

Run migrations (interactive, asks for migration name when schema changed):

```bash
docker compose -f docker-compose.dev.yml exec dev \
  pnpm --filter slora-core prisma:migrate
```

Generate Prisma client:

```bash
docker compose -f docker-compose.dev.yml exec dev \
  pnpm --filter slora-core prisma:generate
```

Or run both:

```bash
docker compose -f docker-compose.dev.yml exec dev npm run prisma:dev
```

## 4) If you get Prisma `P1002` advisory lock timeout

That means another Prisma migrate process is already holding/waiting on the lock.

Safe flow:

```bash
docker compose -f docker-compose.dev.yml stop dev
docker compose -f docker-compose.dev.yml run --rm --no-deps dev npm run prisma:dev
docker compose -f docker-compose.dev.yml up -d dev
```

## 5) Important compose/env consistency

Current project values observed:

- DB service name: `postgrace-db`
- `slora-core/.env` uses: `DATABASE_URL=postgres://slora:slorapass@postgrace-db:5432/sloraDB`

Make sure `docker-compose.dev.yml` uses the same key + host:

- Use `DATABASE_URL` (not `DATABSE_URL`)
- Use host `postgrace-db` (or rename service consistently everywhere)

Example:

```yaml
environment:
  - DATABASE_URL=postgres://slora:slorapass@postgrace-db:5432/sloraDB
```
