# Slorify

A comprehensive cloud application and database operator/manager that streamlines deployment, monitoring, and management of cloud infrastructure.

## Overview

Slorify provides a unified platform for managing cloud applications and databases with automated deployment pipelines, container orchestration, and real-time monitoring capabilities.

## Features

- **Git Integration** - Direct deployment from Git repositories
- **Code Deployment** - Automated CI/CD pipelines
- **Database Management** - Multi-database support and operations
- **Application Orchestration** - Full application lifecycle management
- **Docker Support** - Container-based deployments
- **Docker Compose** - Multi-container application management
- **Cloud Integration** - Native cloud provider support
- **Real-time Monitoring** - Application and infrastructure metrics
- **Auto-scaling** - Dynamic resource allocation
- **Load Balancing** - Traffic distribution and management
- **Backup & Recovery** - Automated data protection
- **Security Management** - Built-in security protocols

## Architecture

- **slora-core** - Core engine and orchestration logic
- **slora-portal** - Web-based management interface

## Production Installer and CLI

This repository now includes production automation under `deploy/`:

- `deploy/install-production.sh`
- `deploy/slorify`
- `deploy/systemd/slorify-core.service`

### Install whole panel (build + migrate + services)

Run from the repo root on an Ubuntu/Debian server:

```bash
sudo bash deploy/install-production.sh
```

Optional installer overrides (example):

```bash
sudo APP_URL="http://your-vps-ip" CORE_PORT=4000 DB_PASS="strong-pass" bash deploy/install-production.sh
```

What it does:

- Installs system dependencies (Node.js, pnpm, PostgreSQL)
- Copies project to `/opt/slorify/app`
- Builds `slora-core` and `slora-portal`
- Applies Prisma migrations
- Installs and starts `slorify-core` systemd service
- Disables nginx service if present, so Slorify runs directly on port `4000`
- Installs `slorify` CLI to `/usr/local/bin/slorify`
- Auto-generates `/opt/slorify/app/.env` and `/opt/slorify/app/slora-core/.env`

### Auto-generate `.env` files manually

From repo root (or `/opt/slorify/app` in VPS):

```bash
bash deploy/generate-env.sh
```

Force regenerate:

```bash
bash deploy/generate-env.sh --force
```

### Manage production

```bash
sudo slorify status
sudo slorify logs 200
sudo slorify restart
sudo slorify update
```

`slorify update` now also:
- syncs submodules before update
- auto-generates env files if missing

Session cookie secure mode is forced to `false` in backend config.

## License

ISC

---

Developed by [aislxflames](https://github.com/aislxflames)
