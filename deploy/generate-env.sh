#!/usr/bin/env bash
set -euo pipefail

FORCE_REGENERATE=false
if [[ "${1:-}" == "--force" ]]; then
  FORCE_REGENERATE=true
fi

APP_DIR="${APP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CORE_PORT="${CORE_PORT:-4000}"
DB_NAME="${DB_NAME:-sloraDB}"
DB_USER="${DB_USER:-slora}"
DB_PASS="${DB_PASS:-slorapass}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
APP_URL="${APP_URL:-http://localhost}"
APP_DATA_ROOT="${APP_DATA_ROOT:-/opt/slorify/data}"
SWARM_MODE="${SWARM_MODE:-true}"
SESSION_COOKIE_SECURE="${SESSION_COOKIE_SECURE:-false}"
NODE_ENV="${NODE_ENV:-production}"

ROOT_ENV_FILE="$APP_DIR/.env"
CORE_ENV_FILE="$APP_DIR/slora-core/.env"

log() { printf "[env] %s\n" "$*"; }

ensure_parent_dir() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
}

should_write() {
  local file="$1"
  if [[ "$FORCE_REGENERATE" == "true" ]]; then
    return 0
  fi
  [[ ! -f "$file" ]]
}

write_root_env() {
  if ! should_write "$ROOT_ENV_FILE"; then
    log "Skipping existing $ROOT_ENV_FILE"
    return 0
  fi

  ensure_parent_dir "$ROOT_ENV_FILE"
  log "Writing $ROOT_ENV_FILE"
  cat >"$ROOT_ENV_FILE" <<ENV
NODE_ENV=$NODE_ENV
PORT=$CORE_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
APP_URL=$APP_URL
APP_DATA_ROOT=$APP_DATA_ROOT
SWARM_MODE=$SWARM_MODE
SESSION_COOKIE_SECURE=$SESSION_COOKIE_SECURE
DATABASE_URL=postgres://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME
ENV
}

write_core_env() {
  if ! should_write "$CORE_ENV_FILE"; then
    log "Skipping existing $CORE_ENV_FILE"
    return 0
  fi

  ensure_parent_dir "$CORE_ENV_FILE"
  log "Writing $CORE_ENV_FILE"
  cat >"$CORE_ENV_FILE" <<ENV
NODE_ENV=$NODE_ENV
PORT=$CORE_PORT
SESSION_SECRET=$(openssl rand -hex 24)
APP_URL=$APP_URL
APP_DATA_ROOT=$APP_DATA_ROOT
SWARM_MODE=$SWARM_MODE
SESSION_COOKIE_SECURE=$SESSION_COOKIE_SECURE
DATABASE_URL=postgres://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME
ENV
}

umask 077
write_root_env
write_core_env
log "Environment generation complete."
