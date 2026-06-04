#!/usr/bin/env bash

redact_check() {
  need rg
  local target="${1:-$OH_ROOT}"
  local status=0
  info "Scanning $target for publish-blocking secrets"

  local patterns=(
    'sk-or-v1-[A-Za-z0-9_-]{20,}'
    'sk-proj-[A-Za-z0-9_-]{20,}'
    'sk-[A-Za-z0-9_-]{32,}'
    'gh[pousr]_[A-Za-z0-9_]{20,}'
    'xox[baprs]-[A-Za-z0-9-]{20,}'
    'AIza[0-9A-Za-z_-]{20,}'
    'discord(.{0,20})?(token|secret).{0,20}[:=]'
    'SUDO_PASSWORD='
    'OPENROUTER_API_KEY='
    '^API_SERVER_KEY=[A-Za-z0-9_-]{16,}'
    '^HERMES_API_TOKEN=[A-Za-z0-9_-]{16,}'
    'OH_HERMES_MODEL_API_KEY=[^[:space:]]+'
  )

  for pat in "${patterns[@]}"; do
    if rg -n --hidden --glob '!.git/' --glob '!vendor/' --glob '!backups/' --glob '!runtime/' --glob '!node_modules/' --glob '!**/lib/redaction.sh' -i "$pat" "$target"; then
      status=1
    fi
  done

  if [[ "$status" == "0" ]]; then
    info "Redaction check passed"
  else
    die "Redaction check failed; remove or move secret-bearing files before publishing"
  fi
}
