#!/usr/bin/env bash
set -euo pipefail

APP_USER="${APP_USER:-slorify}"
APP_GROUP="${APP_GROUP:-slorify}"
APP_BASE="${APP_BASE:-/opt/slorify}"
APP_DIR="${APP_DIR:-$APP_BASE/app}"
REPO_SRC="${REPO_SRC:-$(pwd)}"
CORE_PORT="${CORE_PORT:-4000}"
DB_NAME="${DB_NAME:-sloraDB}"
DB_USER="${DB_USER:-slora}"
DB_PASS="${DB_PASS:-slorapass}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"

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

install_system_packages() {
  log "Installing system dependencies"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl ca-certificates gnupg git rsync nginx postgresql postgresql-contrib

  if ! command -v node >/dev/null 2>&1; then
    log "Installing Node.js 20"
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
  fi

  corepack enable
  corepack prepare pnpm@10.28.2 --activate
}

create_app_user() {
  if ! id -u "$APP_USER" >/dev/null 2>&1; then
    log "Creating system user: $APP_USER"
    useradd --system --create-home --home-dir "$APP_BASE" --shell /bin/bash "$APP_USER"
  fi

  if ! getent group "$APP_GROUP" >/dev/null 2>&1; then
    groupadd --system "$APP_GROUP"
  fi

  usermod -a -G "$APP_GROUP" "$APP_USER" || true
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

  chown -R "$APP_USER:$APP_GROUP" "$APP_BASE"
}

prepare_database() {
  log "Configuring PostgreSQL"
  systemctl enable --now postgresql

  local escaped_pass
  escaped_pass=$(printf "%s" "$DB_PASS" | sed "s/'/''/g")

  sudo -u postgres psql <<SQL
DO
\$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$DB_USER') THEN
    CREATE ROLE "$DB_USER" LOGIN PASSWORD '$escaped_pass';
  ELSE
    ALTER ROLE "$DB_USER" WITH LOGIN PASSWORD '$escaped_pass';
  END IF;
END
\$\$;
SQL

  sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 \
    || sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
}

setup_env() {
  log "Generating environment files"
  local generator="$APP_DIR/deploy/generate-env.sh"
  local regen_flag=()

  if [[ "${FORCE_ENV_REGENERATE:-false}" == "true" ]]; then
    regen_flag=(--force)
  fi

  sudo -u "$APP_USER" env \
    APP_DIR="$APP_DIR" \
    CORE_PORT="$CORE_PORT" \
    DB_NAME="$DB_NAME" \
    DB_USER="$DB_USER" \
    DB_PASS="$DB_PASS" \
    DB_HOST="$DB_HOST" \
    DB_PORT="$DB_PORT" \
    APP_URL="${APP_URL:-http://localhost}" \
    APP_DATA_ROOT="${APP_DATA_ROOT:-/opt/slorify/data}" \
    SWARM_MODE="${SWARM_MODE:-true}" \
    SESSION_COOKIE_SECURE="${SESSION_COOKIE_SECURE:-false}" \
    NODE_ENV="${NODE_ENV:-production}" \
    bash "$generator" "${regen_flag[@]}"

  chown "$APP_USER:$APP_GROUP" "$APP_DIR/.env" "$APP_DIR/slora-core/.env"
  chmod 600 "$APP_DIR/.env" "$APP_DIR/slora-core/.env"
}

build_and_migrate() {
  log "Installing dependencies"
  sudo -u "$APP_USER" sh -lc "cd '$APP_DIR' && pnpm install --frozen-lockfile"

  log "Building slora-core and slora-portal"
  sudo -u "$APP_USER" sh -lc "cd '$APP_DIR' && pnpm -r build"

  log "Applying database migrations"
  sudo -u "$APP_USER" sh -lc "cd '$APP_DIR/slora-core' && pnpm exec prisma migrate deploy && pnpm exec prisma generate"
}

install_systemd() {
  log "Installing systemd service"
  install -m 0644 "$APP_DIR/deploy/systemd/slorify-core.service" /etc/systemd/system/slorify-core.service

  sed -i "s|/opt/slorify/app|$APP_DIR|g" /etc/systemd/system/slorify-core.service
  sed -i "s|User=slorify|User=$APP_USER|g" /etc/systemd/system/slorify-core.service
  sed -i "s|Group=slorify|Group=$APP_GROUP|g" /etc/systemd/system/slorify-core.service
  sed -i "s|Environment=PORT=4000|Environment=PORT=$CORE_PORT|g" /etc/systemd/system/slorify-core.service

  systemctl daemon-reload
  systemctl enable --now slorify-core.service
}

install_nginx() {
  log "Installing nginx config"
  install -m 0644 "$APP_DIR/deploy/nginx/slorify.conf" /etc/nginx/sites-available/slorify.conf

  sed -i "s|/opt/slorify/app|$APP_DIR|g" /etc/nginx/sites-available/slorify.conf
  sed -i "s|127.0.0.1:4000|127.0.0.1:$CORE_PORT|g" /etc/nginx/sites-available/slorify.conf

  ln -sf /etc/nginx/sites-available/slorify.conf /etc/nginx/sites-enabled/slorify.conf
  rm -f /etc/nginx/sites-enabled/default

  nginx -t
  systemctl enable --now nginx
  systemctl restart nginx
}

install_cli() {
  log "Installing slorify CLI"
  install -m 0755 "$APP_DIR/deploy/slorify" /usr/local/bin/slorify
}

post_install_summary() {
  log "Installation complete"
  echo ""
  echo "Services:"
  systemctl --no-pager --full status slorify-core.service | sed -n '1,8p' || true
  systemctl --no-pager --full status nginx | sed -n '1,8p' || true
  echo ""
  echo "CLI usage:"
  echo "  slorify status"
  echo "  slorify logs 200"
  echo "  slorify restart"
}

main() {
  require_root
  require_cmd sed
  require_cmd rsync
  require_cmd openssl

  install_system_packages
  create_app_user
  sync_project
  prepare_database
  setup_env
  build_and_migrate
  install_systemd
  install_nginx
  install_cli
  post_install_summary
}

main "$@"
