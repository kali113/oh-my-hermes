#!/usr/bin/env bash

backup_hermes() {
  need hermes
  local stamp dest config env_path
  stamp="$(ts)"
  dest="$OH_BACKUP_DIR/hermes-$stamp"
  config="$(hermes config path 2>/dev/null || printf '%s/.hermes/config.yaml' "$HOME")"
  env_path="$(hermes config env-path 2>/dev/null || printf '%s/.hermes/.env' "$HOME")"

  info "Creating Hermes backup at $dest"
  run mkdir -p "$dest"
  for path in "$config" "$env_path" "$HOME/.hermes/mcp.json" "$HOME/.hermes/SOUL.md"; do
    if [[ -e "$path" ]]; then
      run cp -a "$path" "$dest/"
    fi
  done
  if [[ "$OH_DRY_RUN" != "1" ]]; then
    {
      printf 'created_at=%s\n' "$stamp"
      printf 'hermes=%s\n' "$(real_hermes)"
      printf 'config=%s\n' "$config"
      printf 'env=%s\n' "$env_path"
    } > "$dest/MANIFEST"
    chmod -R go-rwx "$dest"
  fi
  printf '%s\n' "$dest"
}

apply_core_hermes_config() {
  need hermes
  local env_path
  env_path="$(hermes config env-path 2>/dev/null || printf '%s/.hermes/.env' "$HOME")"

  info "Migrating Hermes config and applying oh-hermes defaults"
  run hermes config migrate
  run hermes config set approvals.mode off
  run hermes config set approvals.destructive_slash_confirm false
  run hermes config set privacy.redact_pii true
  run hermes config set hooks_auto_accept true
  ensure_env_key "$env_path" API_SERVER_ENABLED true
  ensure_api_server_key "$env_path"
  ensure_env_key "$env_path" API_SERVER_HOST 127.0.0.1
  ensure_env_key "$env_path" API_SERVER_CORS_ORIGINS "http://127.0.0.1:3000,http://localhost:3000"
}

ensure_api_server_key() {
  local env_path="$1" key
  if [[ -f "$env_path" ]] && grep -q '^API_SERVER_KEY=' "$env_path"; then
    return 0
  fi
  if have openssl; then
    key="$(openssl rand -hex 32)"
  else
    key="$(python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)"
  fi
  ensure_env_key "$env_path" API_SERVER_KEY "$key"
}

configure_provider() {
  need hermes
  need curl
  need jq
  local env_path base_url api_key models selected
  env_path="$(hermes config env-path 2>/dev/null || printf '%s/.hermes/.env' "$HOME")"

  if ! is_tty; then
    die "Provider setup needs a TTY. Export OH_HERMES_MODEL_BASE_URL, OH_HERMES_MODEL_API_KEY, and OH_HERMES_MODEL for non-interactive runs."
  fi

  printf 'OpenAI-compatible base URL [https://openrouter.ai/api/v1]: '
  IFS= read -r base_url
  base_url="${base_url:-https://openrouter.ai/api/v1}"
  api_key="$(read_secret 'API key: ')"
  [[ -n "$api_key" ]] || die "API key cannot be empty"

  info "Fetching model list from $base_url/models"
  models="$(curl -fsS -H "Authorization: Bearer $api_key" "$base_url/models" | jq -r '.data[]?.id' | sed -n '1,40p' || true)"
  if [[ -n "$models" ]]; then
    printf '%s\n' "$models" | nl -w2 -s') '
    printf 'Choose number or type model id: '
    IFS= read -r selected
    if [[ "$selected" =~ ^[0-9]+$ ]]; then
      selected="$(printf '%s\n' "$models" | sed -n "${selected}p")"
    fi
  else
    warn "Could not fetch /models; type the model id manually."
    printf 'Model id: '
    IFS= read -r selected
  fi
  [[ -n "$selected" ]] || die "Model id cannot be empty"

  ensure_env_key "$env_path" OH_HERMES_MODEL_BASE_URL "$base_url"
  ensure_env_key "$env_path" OH_HERMES_MODEL_API_KEY "$api_key"
  ensure_env_key "$env_path" OH_HERMES_MODEL "$selected"
  run hermes config set model.provider custom
  run hermes config set model.base_url '${OH_HERMES_MODEL_BASE_URL}'
  run hermes config set model.api_key '${OH_HERMES_MODEL_API_KEY}'
  run hermes config set model.default '${OH_HERMES_MODEL}'
}

install_distribution_profile() {
  need hermes
  info "Installing local oh-hermes profile distribution"
  run hermes profile install "$OH_ROOT" --name oh-hermes --alias --force -y
}

restart_gateway_if_present() {
  if systemctl list-units --type=service --all 2>/dev/null | grep -q 'hermes-gateway'; then
    info "Restarting system Hermes gateway"
    run hermes gateway restart --system || warn "Gateway restart failed; run hermes gateway status for details."
  else
    info "No system Hermes gateway unit detected; skipping restart"
  fi
}
