#!/usr/bin/env bash

set -euo pipefail

: "${OH_ROOT:?OH_ROOT must be set before sourcing common.sh}"

OH_STATE_DIR="${OH_HERMES_STATE:-$HOME/.oh-hermes}"
OH_BACKUP_DIR="$OH_STATE_DIR/backups"
OH_LOG_DIR="$OH_STATE_DIR/logs"
OH_REPORT_DIR="$OH_STATE_DIR/reports"
OH_VENDOR_DIR="$OH_STATE_DIR/vendor"
OH_DRY_RUN="${OH_DRY_RUN:-0}"

mkdir -p "$OH_STATE_DIR" "$OH_BACKUP_DIR" "$OH_LOG_DIR" "$OH_REPORT_DIR" "$OH_VENDOR_DIR"

info() { printf '\033[1;36m[oh-hermes]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[oh-hermes]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[oh-hermes]\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

need() {
  have "$1" || die "Missing required command: $1"
}

ts() {
  date -u +%Y%m%dT%H%M%SZ
}

is_tty() {
  [[ -t 0 && -t 1 ]]
}

run() {
  if [[ "$OH_DRY_RUN" == "1" ]]; then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

append_path_once() {
  local file="$1"
  local line="$2"
  if [[ -f "$file" ]] && grep -Fqx "$line" "$file"; then
    return 0
  fi
  run mkdir -p "$(dirname "$file")"
  if [[ "$OH_DRY_RUN" == "1" ]]; then
    printf '[dry-run] append %q to %q\n' "$line" "$file"
  else
    printf '\n%s\n' "$line" >> "$file"
  fi
}

ensure_env_key() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp

  run mkdir -p "$(dirname "$file")"
  if [[ "$OH_DRY_RUN" == "1" ]]; then
    printf '[dry-run] set %s in %s\n' "$key" "$file"
    return 0
  fi

  tmp="$(mktemp)"
  if [[ -f "$file" ]]; then
    awk -v key="$key" -v value="$value" '
      BEGIN { found = 0 }
      index($0, key "=") == 1 {
        print key "=" value
        found = 1
        next
      }
      { print }
      END {
        if (!found) {
          if (NR > 0) print ""
          print key "=" value
        }
      }
    ' "$file" > "$tmp"
  else
    printf '%s=%s\n' "$key" "$value" > "$tmp"
  fi
  chmod 600 "$tmp"
  mv "$tmp" "$file"
}

read_secret() {
  local prompt="$1"
  local value
  printf '%s' "$prompt" >&2
  IFS= read -r -s value
  printf '\n' >&2
  printf '%s' "$value"
}

real_hermes() {
  command -v hermes
}
