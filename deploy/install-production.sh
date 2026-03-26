#!/usr/bin/env bash
set -euo pipefail

APP_BASE="${APP_BASE:-/opt/slorify}"
APP_DIR="${APP_DIR:-$APP_BASE/app}"
REPO_SRC="${REPO_SRC:-$(pwd)}"
CORE_PORT="${CORE_PORT:-4000}"
DB_NAME="${DB_NAME:-sloraDB}"
DB_USER="${DB_USER:-slora}"
DB_PASS="${DB_PASS:-slorapass}"
DB_HOST="${DB_HOST:-postgrace-db}"
DB_PORT="${DB_PORT:-5432}"
APP_DATA_ROOT="${APP_DATA_ROOT:-/opt/slorify/data}"
SWARM_MODE="${SWARM_MODE:-true}"
SESSION_COOKIE_SECURE="${SESSION_COOKIE_SECURE:-false}"
NODE_ENV="${NODE_ENV:-production}"
USE_DOMAIN="${USE_DOMAIN:-false}"
PANEL_DOMAIN="${PANEL_DOMAIN:-}"
DEFAULT_PANEL_DOMAIN="${DEFAULT_PANEL_DOMAIN:-hpanel.flamenodes.cloud}"
FORCE_ENV_REGENERATE="${FORCE_ENV_REGENERATE:-false}"

log() { printf "[install] %s\n" "$*"; }
err() { printf "[install][error] %s\n" "$*" >&2; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Run this installer as root (sudo)."
    exit 1
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Missing required command: $1"
    exit 1
  }
}

install_base_packages() {
  log "Installing base dependencies"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates curl git rsync
}

install_docker_if_missing() {
  if ! command -v docker >/dev/null 2>&1; then
    log "Installing Docker"
    curl -fsSL https://get.docker.com | sh
  fi

  if ! docker compose version >/dev/null 2>&1; then
    log "Installing Docker Compose plugin"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin
  fi
}

sync_project() {
  log "Syncing project to $APP_DIR"
  mkdir -p "$APP_DIR"

  rsync -a --delete \
    --exclude 'node_modules' \
    --exclude 'slora-core/node_modules' \
    --exclude 'slora-portal/node_modules' \
    --exclude 'slora-core/dev.db' \
    "$REPO_SRC/" "$APP_DIR/"

  if [[ -d "$APP_DIR/.git" ]]; then
    log "Syncing and updating submodules"
    git -C "$APP_DIR" submodule sync --recursive
    git -C "$APP_DIR" submodule update --init --recursive
  fi
}

setup_env() {
  log "Generating .env files for root/slora-core/slora-portal"
  local regen_flag=()
  if [[ "$FORCE_ENV_REGENERATE" == "true" ]]; then
    regen_flag=(--force)
  fi

  env \
    APP_DIR="$APP_DIR" \
    CORE_PORT="$CORE_PORT" \
    DB_NAME="$DB_NAME" \
    DB_USER="$DB_USER" \
    DB_PASS="$DB_PASS" \
    DB_HOST="$DB_HOST" \
    DB_PORT="$DB_PORT" \
    APP_DATA_ROOT="$APP_DATA_ROOT" \
    SWARM_MODE="$SWARM_MODE" \
    SESSION_COOKIE_SECURE="$SESSION_COOKIE_SECURE" \
    NODE_ENV="$NODE_ENV" \
    USE_DOMAIN="$USE_DOMAIN" \
    PANEL_DOMAIN="$PANEL_DOMAIN" \
    DEFAULT_PANEL_DOMAIN="$DEFAULT_PANEL_DOMAIN" \
    bash "$APP_DIR/deploy/generate-env.sh" "${regen_flag[@]}"

  chmod 600 "$APP_DIR/.env" "$APP_DIR/slora-core/.env" "$APP_DIR/slora-portal/.env"
}

disable_nginx_if_present() {
  if systemctl list-unit-files | grep -q '^nginx\.service'; then
    log "Disabling nginx so Slorify is served via Docker on port $CORE_PORT"
    systemctl stop nginx || true
    systemctl disable nginx || true
  fi
}

deploy_stack() {
  log "Starting production stack with docker compose"
  cd "$APP_DIR"
  docker compose pull postgrace-db || true
  docker compose up -d --build
}

install_cli() {
  log "Installing slora CLI"
  install -m 0755 "$APP_DIR/deploy/slora" /usr/local/bin/slora
  install -m 0755 "$APP_DIR/deploy/slora" /usr/local/bin/slorify
}

post_install_summary() {
  log "Installation complete"
  echo ""
  docker compose -f "$APP_DIR/docker-compose.yml" ps || true
  echo ""
  echo "Commands:"
  echo "  slora status"
  echo "  slora logs 200"
  echo "  slora restart"
  echo ""
  echo "Panel/API is served on port $CORE_PORT (no nginx)."
}

main() {
  require_root
  require_cmd bash
  require_cmd curl
  require_cmd git
  require_cmd rsync
  require_cmd sed

  install_base_packages
  install_docker_if_missing
  sync_project
  setup_env
  disable_nginx_if_present
  deploy_stack
  install_cli
  post_install_summary
}

main "$@"
