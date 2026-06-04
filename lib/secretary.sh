#!/usr/bin/env bash

secretary_dir() {
  printf '%s/secretary\n' "$OH_STATE_DIR"
}

secretary_init() {
  local dir
  dir="$(secretary_dir)"
  run mkdir -p "$dir/inbox" "$dir/tasks" "$dir/briefings" "$dir/worklog" "$dir/decisions"
  if [[ ! -f "$dir/preferences.md" ]]; then
    run cp "$OH_ROOT/templates/secretary/preferences.md" "$dir/preferences.md"
  fi
  if [[ ! -f "$dir/rules.md" ]]; then
    run cp "$OH_ROOT/templates/secretary/rules.md" "$dir/rules.md"
  fi
  info "Secretary state is at $dir"
}

secretary_capture() {
  local kind="inbox" title="" body="" dir file
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --kind) kind="${2:-}"; [[ -n "$kind" ]] || die "--kind needs a value"; shift 2 ;;
      --title) title="${2:-}"; [[ -n "$title" ]] || die "--title needs a value"; shift 2 ;;
      --body) body="${2:-}"; shift 2 ;;
      *) body="${body}${body:+ }$1"; shift ;;
    esac
  done
  [[ -n "$title" ]] || title="Captured note"
  secretary_init >/dev/null
  dir="$(secretary_dir)/$kind"
  run mkdir -p "$dir"
  file="$dir/$(ts)-$(printf '%s' "$title" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-' | cut -c1-48).md"
  {
    printf '# %s\n\n' "$title"
    printf -- '- Captured: `%s`\n' "$(date -Is)"
    printf -- '- Kind: `%s`\n\n' "$kind"
    if [[ -n "$body" ]]; then
      printf '%s\n' "$body"
    else
      cat
    fi
  } | write_private_report "$file"
  printf '%s\n' "$file"
}

secretary_brief() {
  secretary_init >/dev/null
  local dir report today
  dir="$(secretary_dir)"
  today="$(date +%F)"
  report="$dir/briefings/$today.md"
  {
    printf '# Daily Briefing %s\n\n' "$today"
    printf -- '- Generated: `%s`\n\n' "$(date -Is)"
    printf '## Operating Rules\n\n'
    sed -n '1,120p' "$dir/rules.md" 2>/dev/null || true
    printf '\n## Preferences\n\n'
    sed -n '1,160p' "$dir/preferences.md" 2>/dev/null || true
    printf '\n## Open Tasks\n\n'
    find "$dir/tasks" -type f -name '*.md' -mtime -30 -print 2>/dev/null | sort | tail -20 | while IFS= read -r task; do
      printf -- '- `%s` ' "$(basename "$task")"
      sed -n '1p' "$task" 2>/dev/null | sed 's/^# //'
    done
    printf '\n## Recent Inbox\n\n'
    find "$dir/inbox" -type f -name '*.md' -mtime -14 -print 2>/dev/null | sort | tail -20 | while IFS= read -r note; do
      printf -- '- `%s` ' "$(basename "$note")"
      sed -n '1p' "$note" 2>/dev/null | sed 's/^# //'
    done
    printf '\n## Recent Worklog\n\n'
    find "$dir/worklog" -type f -name '*.md' -mtime -14 -print 2>/dev/null | sort | tail -20 | while IFS= read -r log; do
      printf -- '- `%s` ' "$(basename "$log")"
      sed -n '1p' "$log" 2>/dev/null | sed 's/^# //'
    done
    printf '\n## Agent Health\n\n```text\n'
    god_mode_health 2>&1 || true
    printf '\n```\n\n## Next Actions\n\n'
    printf -- '- Review tasks that are older than 7 days.\n'
    printf -- '- Promote reusable facts into GBrain/MemOS during real work sessions.\n'
    printf -- '- Keep account integrations disabled until credentials and action boundaries are explicit.\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

secretary_worklog() {
  local title="${1:-Work session}" file
  shift || true
  secretary_init >/dev/null
  file="$(secretary_dir)/worklog/$(ts)-$(printf '%s' "$title" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-' | cut -c1-48).md"
  {
    printf '# %s\n\n' "$title"
    printf -- '- Started: `%s`\n\n' "$(date -Is)"
    printf '## Goal\n\n%s\n\n' "${*:-TBD}"
    printf '## Notes\n\n'
  } | write_private_report "$file"
  printf '%s\n' "$file"
}

secretary_status() {
  secretary_init >/dev/null
  local dir
  dir="$(secretary_dir)"
  printf 'secretary_dir=%s\n' "$dir"
  printf 'inbox=%s\n' "$(find "$dir/inbox" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'tasks=%s\n' "$(find "$dir/tasks" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'briefings=%s\n' "$(find "$dir/briefings" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'worklog=%s\n' "$(find "$dir/worklog" -type f -name '*.md' 2>/dev/null | wc -l)"
}

install_secretary_timer() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  secretary_init >/dev/null
  info "Installing daily oh-hermes secretary timer"
  run mkdir -p "$user_dir"
  run cp "$OH_ROOT/systemd/user/oh-hermes-secretary.service" "$user_dir/"
  run cp "$OH_ROOT/systemd/user/oh-hermes-secretary.timer" "$user_dir/"
  run systemctl --user daemon-reload
  run systemctl --user enable --now oh-hermes-secretary.timer
}

remove_secretary_timer() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  info "Removing daily oh-hermes secretary timer"
  run systemctl --user disable --now oh-hermes-secretary.timer || true
  run rm -f "$user_dir/oh-hermes-secretary.service" "$user_dir/oh-hermes-secretary.timer"
  run systemctl --user daemon-reload
}
