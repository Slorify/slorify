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
- `deploy/slora`
- `deploy/slorify`

### Install whole panel (build + migrate + services)

Run from the repo root on an Ubuntu/Debian server:

```bash
sudo bash deploy/install-production.sh
```

Or run direct bootstrap from anywhere (auto-clones to `/tmp` and runs production install):

```bash
curl -fsSL https://raw.githubusercontent.com/Slorify/slorify/refs/heads/slora-v1/scripts/install-uninstall.sh | sudo bash
```

Optional installer overrides (example):

```bash
sudo USE_DOMAIN=true PANEL_DOMAIN="hpanel.flamenodes.cloud" CORE_PORT=4000 DB_PASS="strong-pass" bash deploy/install-production.sh
```

What it does:

- Installs Docker + Docker Compose if missing
- Copies project to `/opt/slorify/app`
- Starts `postgrace-db` and `slorify` with `docker compose up -d --build`
- Disables nginx service if present, so Slorify runs directly on port `4000`
- Installs `slora` CLI to `/usr/local/bin/slora` (and `slorify` alias)
- Auto-generates:
  - `/opt/slorify/app/.env`
  - `/opt/slorify/app/slora-core/.env`
  - `/opt/slorify/app/slora-portal/.env`

### Auto-generate `.env` files manually

From repo root (or `/opt/slorify/app` in VPS):

```bash
bash deploy/generate-env.sh
```

Force regenerate:

```bash
bash deploy/generate-env.sh --force
```

`VITE_SOCKET_URL` behavior:
- If `USE_DOMAIN=true`, it uses `https://$PANEL_DOMAIN`
  - If `PANEL_DOMAIN` is not provided, default is `https://hpanel.flamenodes.cloud`
- If no domain is configured, it auto-detects VPS public IP and uses `http://<public-ip>:4000`

### Manage production

```bash
sudo slora status
sudo slora start
sudo slora stop
sudo slora logs 200
sudo slora restart
sudo slora update
```

`slora update` also syncs submodules and regenerates env files.

Session cookie secure mode is forced to `false` in backend config.

## License

ISC

---

Developed by [aislxflames](https://github.com/aislxflames)
