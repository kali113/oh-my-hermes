#!/usr/bin/env bash

install_workspace() {
  need git
  need pnpm
  need hermes
  local dir env_path api_key
  dir="${HERMES_WORKSPACE_DIR:-$HOME/hermes-workspace}"
  env_path="$(hermes config env-path 2>/dev/null || printf '%s/.hermes/.env' "$HOME")"

  info "Installing Hermes Workspace at $dir"
  if [[ -d "$dir/.git" ]]; then
    run git -C "$dir" pull --ff-only
  elif [[ -e "$dir" ]]; then
    die "$dir exists but is not a git repo"
  else
    run git clone https://github.com/outsourc-e/hermes-workspace.git "$dir"
  fi

  ensure_env_key "$env_path" API_SERVER_ENABLED true
  if [[ "$OH_DRY_RUN" != "1" ]]; then
    if [[ ! -f "$dir/.env" && -f "$dir/.env.example" ]]; then
      cp "$dir/.env.example" "$dir/.env"
    fi
  fi
  ensure_env_key "$dir/.env" HERMES_API_URL "http://127.0.0.1:8642"
  ensure_env_key "$dir/.env" HERMES_DASHBOARD_URL "http://127.0.0.1:9119"
  ensure_api_server_key "$env_path"
  api_key="$(awk -F= '/^API_SERVER_KEY=/ {print substr($0, index($0, "=") + 1); exit}' "$env_path" 2>/dev/null || true)"
  [[ -n "$api_key" ]] && ensure_env_key "$dir/.env" HERMES_API_TOKEN "$api_key"
  run pnpm --dir "$dir" install --silent
}

start_workspace() {
  local background=0 remove_service=0 service_status=0 dir
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --background) background=1; shift ;;
      --install-service) background=1; shift ;;
      --remove-service) remove_service=1; shift ;;
      --status) service_status=1; shift ;;
      *) die "Unknown ui option: $1" ;;
    esac
  done
  dir="${HERMES_WORKSPACE_DIR:-$HOME/hermes-workspace}"
  [[ -d "$dir" ]] || die "Hermes Workspace is not installed; run oh-hermes modules enable workspace"

  if [[ "$remove_service" == "1" ]]; then
    remove_workspace_services
    return 0
  fi
  if [[ "$service_status" == "1" ]]; then
    systemctl --user status oh-hermes-dashboard.service oh-hermes-workspace.service --no-pager || true
    return 0
  fi

  info "Starting Hermes dashboard and Workspace"
  if [[ "$background" == "1" ]]; then
    install_workspace_services
  else
    hermes dashboard --no-open >"$OH_LOG_DIR/dashboard.log" 2>&1 &
    (cd "$dir" && pnpm dev --host 127.0.0.1)
  fi
}

install_workspace_services() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  run mkdir -p "$user_dir"
  run cp "$OH_ROOT/systemd/user/oh-hermes-dashboard.service" "$user_dir/"
  run cp "$OH_ROOT/systemd/user/oh-hermes-workspace.service" "$user_dir/"
  run systemctl --user daemon-reload
  run systemctl --user enable --now oh-hermes-dashboard.service oh-hermes-workspace.service
  printf 'Workspace: http://127.0.0.1:3000\n'
  printf 'Dashboard: http://127.0.0.1:9119\n'
}

remove_workspace_services() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  run systemctl --user disable --now oh-hermes-dashboard.service oh-hermes-workspace.service || true
  run rm -f "$user_dir/oh-hermes-dashboard.service" "$user_dir/oh-hermes-workspace.service"
  run systemctl --user daemon-reload
}

status_workspace() {
  local dir="${HERMES_WORKSPACE_DIR:-$HOME/hermes-workspace}"
  if [[ -d "$dir/.git" ]]; then
    printf 'installed at %s\n' "$dir"
  else
    printf 'missing\n'
  fi
}
