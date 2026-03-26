#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/Slorify/slorify.git}"
REPO_REF="${REPO_REF:-slora-v1}"
TMP_DIR=""

log() { printf "[bootstrap] %s\n" "$*"; }
err() { printf "[bootstrap][error] %s\n" "$*" >&2; }

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Missing required command: $1"
    exit 1
  }
}

ensure_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      log "Re-running with sudo"
      exec sudo -E bash "$0" "$@"
    fi
    err "Please run as root (or install sudo)."
    exit 1
  fi
}

run_install() {
  TMP_DIR="$(mktemp -d /tmp/slorify-install-XXXXXX)"
  log "Cloning $REPO_URL#$REPO_REF into $TMP_DIR"
  git clone --branch "$REPO_REF" --single-branch "$REPO_URL" "$TMP_DIR/repo"

  log "Initializing submodules"
  git -C "$TMP_DIR/repo" submodule sync --recursive
  git -C "$TMP_DIR/repo" submodule update --init --recursive

  log "Running production installer"
  REPO_SRC="$TMP_DIR/repo" bash "$TMP_DIR/repo/deploy/install-production.sh"

  log "Done. Slorify is installed for production on port 4000."
}

main() {
  ensure_root "$@"
  need_cmd git
  need_cmd mktemp
  need_cmd bash
  run_install
}

main "$@"
