#!/usr/bin/env bash

agent_latest_file() {
  local pattern="$1"
  find "$OH_STATE_DIR" -path "$pattern" -type f 2>/dev/null | sort | tail -n 1
}

agent_status() {
  printf '# oh-hermes Agent Status\n\n'
  printf -- '- Generated: `%s`\n\n' "$(date -Is)"
  printf '## Health\n\n```text\n'
  god_mode_health 2>&1 || true
  printf '\n```\n\n## Secretary\n\n```text\n'
  secretary_status 2>&1 || true
  printf '\n```\n\n## Timers\n\n```text\n'
  if have systemctl; then
    systemctl --user list-timers 'oh-hermes*' --no-pager 2>&1 || true
  else
    printf 'systemctl missing\n'
  fi
  printf '\n```\n\n## Services\n\n```text\n'
  if have systemctl; then
    systemctl --user is-active oh-hermes-memos.service oh-hermes-workspace.service oh-hermes-dashboard.service 2>&1 || true
  else
    printf 'systemctl missing\n'
  fi
  printf '\n```\n\n## Repo\n\n```text\n'
  if [[ -d "$OH_ROOT/.git" ]]; then
    git -C "$OH_ROOT" status --short 2>&1 || true
    git -C "$OH_ROOT" log --oneline -5 2>&1 || true
  else
    printf 'not a git repo\n'
  fi
  printf '\n```\n\n## Latest Reports\n\n'
  local latest
  for latest in \
    "$(agent_latest_file '*/reports/god-mode-*.md')" \
    "$(agent_latest_file '*/reports/auto-improve-*.md')" \
    "$(agent_latest_file '*/reports/self-review-*.md')" \
    "$(agent_latest_file '*/secretary/briefings/*.md')" \
    "$(agent_latest_file '*/secretary/reminders/*.md')"; do
    [[ -n "$latest" ]] && printf -- '- `%s`\n' "$latest"
  done
}

agent_report() {
  local report="$OH_REPORT_DIR/agent-status-$(ts).md"
  agent_status | write_private_report "$report"
  printf '%s\n' "$report"
}

agent_cmd() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    status) agent_status "$@" ;;
    report) agent_report "$@" ;;
    *) die "Unknown agent command: $sub" ;;
  esac
}
