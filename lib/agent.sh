#!/usr/bin/env bash

agent_latest_file() {
  local pattern="$1"
  find "$OH_STATE_DIR" -path "$pattern" -type f 2>/dev/null | sort | tail -n 1
}

agent_json_string() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '"%s"' "$value"
}

agent_json_kv_object() {
  local line key value first=1
  printf '{'
  while IFS= read -r line; do
    [[ "$line" == *=* ]] || continue
    key="${line%%=*}"
    value="${line#*=}"
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '
    agent_json_string "$key"
    printf ': '
    agent_json_string "$value"
    first=0
  done
  [[ "$first" == "1" ]] || printf '\n  '
  printf '}'
}

agent_latest_reports_json() {
  local latest first=1
  printf '['
  for latest in \
    "$(agent_latest_file '*/reports/god-mode-*.md')" \
    "$(agent_latest_file '*/reports/auto-improve-*.md')" \
    "$(agent_latest_file '*/reports/self-review-*.md')" \
    "$(agent_latest_file '*/secretary/briefings/*.md')" \
    "$(agent_latest_file '*/secretary/learning/reviews/*.md')" \
    "$(agent_latest_file '*/secretary/sweeps/*.md')" \
    "$(agent_latest_file '*/secretary/audits/*.md')" \
    "$(agent_latest_file '*/secretary/reminders/*.md')"; do
    [[ -n "$latest" ]] || continue
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '
    agent_json_string "$latest"
    first=0
  done
  [[ "$first" == "1" ]] || printf '\n  '
  printf ']'
}

agent_status_json() {
  local generated health secretary revision dirty_count
  generated="$(date -Is)"
  health="$(god_mode_health 2>/dev/null || true)"
  secretary="$(secretary_status 2>/dev/null || true)"
  if [[ -d "$OH_ROOT/.git" ]]; then
    revision="$(git -C "$OH_ROOT" rev-parse --short=12 HEAD 2>/dev/null || printf unknown)"
    dirty_count="$(git -C "$OH_ROOT" status --short 2>/dev/null | wc -l | tr -d ' ')"
  else
    revision="not-a-git-repo"
    dirty_count=0
  fi
  printf '{\n'
  printf '  "generated": '
  agent_json_string "$generated"
  printf ',\n  "repo": {\n    "revision": '
  agent_json_string "$revision"
  printf ',\n    "dirty_files": %s\n  },\n' "${dirty_count:-0}"
  printf '  "health": '
  agent_json_kv_object <<< "$health"
  printf ',\n  "secretary": '
  agent_json_kv_object <<< "$secretary"
  printf ',\n  "latest_reports": '
  agent_latest_reports_json
  printf '\n}\n'
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
    "$(agent_latest_file '*/secretary/learning/reviews/*.md')" \
    "$(agent_latest_file '*/secretary/sweeps/*.md')" \
    "$(agent_latest_file '*/secretary/audits/*.md')" \
    "$(agent_latest_file '*/secretary/reminders/*.md')"; do
    [[ -n "$latest" ]] && printf -- '- `%s`\n' "$latest"
  done
}

agent_report() {
  local report="$OH_REPORT_DIR/agent-status-$(ts).md"
  agent_status | write_private_report "$report"
  printf '%s\n' "$report"
}

agent_context_pack() {
  local report="$OH_REPORT_DIR/context-pack-$(ts).md"
  {
    printf '# oh-hermes Context Pack\n\n'
    printf -- '- Generated: `%s`\n\n' "$(date -Is)"
    printf '## Purpose\n\n'
    printf 'Redacted local summary for future agent sessions. Do not treat this as a complete export of private state.\n\n'
    printf '## Agent Status\n\n'
    agent_status
    printf '\n## Open Tasks\n\n'
    secretary_task_list 2>&1 || true
    printf '\n## Inbox\n\n'
    secretary_inbox_list 2>&1 || true
    printf '\n## Decisions\n\n'
    secretary_decision_list 2>&1 || true
    printf '\n## Worker Actions\n\n'
    secretary_action_list 2>&1 || true
    printf '\n## Worker Sessions\n\n'
    secretary_session_list 2>&1 || true
    printf '\n## Active Lessons\n\n'
    secretary_learn_list --status active 2>&1 || true
    printf '\n## Candidate Lessons\n\n'
    secretary_learn_list --status candidate 2>&1 || true
    printf '\n## Latest Maintenance Sweep\n\n'
    local sweep
    sweep="$(agent_latest_file '*/secretary/sweeps/*.md')"
    if [[ -n "$sweep" ]]; then
      sed -n '1,220p' "$sweep"
    else
      printf 'No maintenance sweep has been generated yet.\n'
    fi
    printf '\n## Latest State Audit\n\n'
    local audit
    audit="$(agent_latest_file '*/secretary/audits/*.md')"
    if [[ -n "$audit" ]]; then
      sed -n '1,220p' "$audit"
    else
      printf 'No state audit has been generated yet.\n'
    fi
    printf '\n## Routines\n\n'
    secretary_routine_list 2>&1 || true
    printf '\n## Due Tasks\n\n'
    secretary_task_due 2>&1 || true
    printf '\n## Today Agenda\n\n'
    secretary_agenda_today 2>&1 || true
    printf '\n## Integrations\n\n'
    secretary_integrations_status 2>&1 || true
    printf '\n## Notification Status\n\n'
    secretary_notify status 2>&1 || true
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

agent_cmd() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    status) agent_status "$@" ;;
    json) agent_status_json "$@" ;;
    report) agent_report "$@" ;;
    context-pack) agent_context_pack "$@" ;;
    *) die "Unknown agent command: $sub" ;;
  esac
}
