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
DB_HOST="${DB_HOST:-postgrace-db}"
DB_PORT="${DB_PORT:-5432}"
APP_DATA_ROOT="${APP_DATA_ROOT:-/opt/slorify/data}"
SWARM_MODE="${SWARM_MODE:-true}"
SESSION_COOKIE_SECURE="${SESSION_COOKIE_SECURE:-false}"
NODE_ENV="${NODE_ENV:-production}"
USE_DOMAIN="${USE_DOMAIN:-false}"
PANEL_DOMAIN="${PANEL_DOMAIN:-}"
DEFAULT_PANEL_DOMAIN="${DEFAULT_PANEL_DOMAIN:-hpanel.flamenodes.cloud}"
PUBLIC_IP="${PUBLIC_IP:-}"
APP_URL="${APP_URL:-}"
VITE_SOCKET_URL="${VITE_SOCKET_URL:-}"

ROOT_ENV_FILE="$APP_DIR/.env"
CORE_ENV_FILE="$APP_DIR/slora-core/.env"
PORTAL_ENV_FILE="$APP_DIR/slora-portal/.env"

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

detect_public_ip() {
  if [[ -n "$PUBLIC_IP" ]]; then
    echo "$PUBLIC_IP"
    return 0
  fi

  for endpoint in "https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com"; do
    local ip
    ip="$(curl -fsSL --max-time 8 "$endpoint" 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$ip"
      return 0
    fi
  done

  echo "127.0.0.1"
}

resolve_socket_and_app_url() {
  local domain="$PANEL_DOMAIN"
  if [[ "$USE_DOMAIN" == "true" && -z "$domain" ]]; then
    domain="$DEFAULT_PANEL_DOMAIN"
  fi

  if [[ -n "$VITE_SOCKET_URL" ]]; then
    RESOLVED_SOCKET_URL="$VITE_SOCKET_URL"
  elif [[ -n "$domain" ]]; then
    if [[ "$domain" =~ ^https?:// ]]; then
      RESOLVED_SOCKET_URL="$domain"
    else
      RESOLVED_SOCKET_URL="https://$domain"
    fi
  else
    local ip
    ip="$(detect_public_ip)"
    RESOLVED_SOCKET_URL="http://$ip:$CORE_PORT"
  fi

  if [[ -n "$APP_URL" ]]; then
    RESOLVED_APP_URL="$APP_URL"
  else
    RESOLVED_APP_URL="$RESOLVED_SOCKET_URL"
  fi
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
APP_URL=$RESOLVED_APP_URL
APP_DATA_ROOT=$APP_DATA_ROOT
SWARM_MODE=$SWARM_MODE
SESSION_COOKIE_SECURE=$SESSION_COOKIE_SECURE
VITE_SOCKET_URL=$RESOLVED_SOCKET_URL
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
APP_URL=$RESOLVED_APP_URL
APP_DATA_ROOT=$APP_DATA_ROOT
SWARM_MODE=$SWARM_MODE
SESSION_COOKIE_SECURE=$SESSION_COOKIE_SECURE
DATABASE_URL=postgres://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME
ENV
}

write_portal_env() {
  if ! should_write "$PORTAL_ENV_FILE"; then
    log "Skipping existing $PORTAL_ENV_FILE"
    return 0
  fi

  ensure_parent_dir "$PORTAL_ENV_FILE"
  log "Writing $PORTAL_ENV_FILE"
  cat >"$PORTAL_ENV_FILE" <<ENV
VITE_SOCKET_URL=$RESOLVED_SOCKET_URL
ENV
}

umask 077
resolve_socket_and_app_url
write_root_env
write_core_env
write_portal_env
log "Environment generation complete."
