#!/usr/bin/env bash

secretary_dir() {
  printf '%s/secretary\n' "$OH_STATE_DIR"
}

secretary_slug() {
  printf '%s' "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-' | cut -c1-64
}

secretary_init() {
  local dir
  dir="$(secretary_dir)"
  run mkdir -p "$dir/inbox" "$dir/tasks" "$dir/briefings" "$dir/worklog" "$dir/decisions" "$dir/reminders" "$dir/integrations"
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
  file="$dir/$(ts)-$(secretary_slug "$title" | cut -c1-48).md"
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

secretary_task_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    index($0, "- " field ":") == 1 {
      sub("^- " field ": *", "")
      gsub("`", "")
      print
      exit
    }
  ' "$file" 2>/dev/null
}

secretary_task_status() {
  local file="$1" status
  status="$(secretary_task_field "$file" "Status")"
  [[ -n "$status" ]] && printf '%s' "$status" || printf 'open'
}

secretary_task_find() {
  local needle="$1" dir file matches=()
  dir="$(secretary_dir)/tasks"
  [[ -n "$needle" ]] || die "Task id/title prefix is required"
  while IFS= read -r file; do
    if [[ "$(basename "$file")" == "$needle"* ]] || grep -qi "^# .*${needle}" "$file"; then
      matches+=("$file")
    fi
  done < <(find "$dir" -type f -name '*.md' 2>/dev/null | sort)
  [[ "${#matches[@]}" -gt 0 ]] || die "No task matched: $needle"
  [[ "${#matches[@]}" -eq 1 ]] || die "Multiple tasks matched: $needle"
  printf '%s\n' "${matches[0]}"
}

secretary_task_add() {
  local title="" body="" due="" priority="normal" project="general" remind="" file
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="${2:-}"; [[ -n "$title" ]] || die "--title needs a value"; shift 2 ;;
      --body) body="${2:-}"; shift 2 ;;
      --due) due="${2:-}"; [[ -n "$due" ]] || die "--due needs a value"; shift 2 ;;
      --priority) priority="${2:-}"; [[ -n "$priority" ]] || die "--priority needs a value"; shift 2 ;;
      --project) project="${2:-}"; [[ -n "$project" ]] || die "--project needs a value"; shift 2 ;;
      --remind) remind="${2:-}"; [[ -n "$remind" ]] || die "--remind needs a value"; shift 2 ;;
      *) body="${body}${body:+ }$1"; shift ;;
    esac
  done
  [[ -n "$title" ]] || die "Usage: oh-hermes secretary task add --title TITLE [--due YYYY-MM-DD] [--priority high|normal|low] [--project NAME] [--remind YYYY-MM-DDTHH:MM]"
  secretary_init >/dev/null
  file="$(secretary_dir)/tasks/$(ts)-$(secretary_slug "$title" | cut -c1-48).md"
  {
    printf '# %s\n\n' "$title"
    printf -- '- Created: `%s`\n' "$(date -Is)"
    printf -- '- Status: `open`\n'
    printf -- '- Priority: `%s`\n' "$priority"
    printf -- '- Project: `%s`\n' "$project"
    [[ -n "$due" ]] && printf -- '- Due: `%s`\n' "$due"
    [[ -n "$remind" ]] && printf -- '- Remind: `%s`\n' "$remind"
    printf '\n## Context\n\n%s\n' "${body:-No context captured yet.}"
  } | write_private_report "$file"
  printf '%s\n' "$file"
}

secretary_task_list() {
  secretary_init >/dev/null
  local all=0 dir file title status due priority project
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all) all=1; shift ;;
      *) die "Unknown task list option: $1" ;;
    esac
  done
  dir="$(secretary_dir)/tasks"
  printf 'ID | Status | Priority | Due | Project | Title\n'
  printf -- '---|---|---|---|---|---\n'
  while IFS= read -r file; do
    status="$(secretary_task_status "$file")"
    [[ "$all" == "1" || "$status" != "done" ]] || continue
    title="$(sed -n '1s/^# //p' "$file")"
    due="$(secretary_task_field "$file" "Due")"
    priority="$(secretary_task_field "$file" "Priority")"
    project="$(secretary_task_field "$file" "Project")"
    printf '%s | %s | %s | %s | %s | %s\n' "$(basename "$file" .md)" "$status" "${priority:-normal}" "${due:--}" "${project:-general}" "$title"
  done < <(find "$dir" -type f -name '*.md' 2>/dev/null | sort)
}

secretary_task_show() {
  local file
  file="$(secretary_task_find "${1:-}")"
  sed -n '1,220p' "$file"
}

secretary_task_done() {
  local file tmp
  file="$(secretary_task_find "${1:-}")"
  tmp="$(mktemp)"
  if grep -q '^- Status:' "$file"; then
    awk '
      index($0, "- Status:") == 1 && !done {
        print "- Status: `done`"
        print "- Completed: `'"$(date -Is)"'`"
        done = 1
        next
      }
      { print }
    ' "$file" > "$tmp"
  else
    awk '
      NR == 2 && !done {
        print ""
        print "- Status: `done`"
        print "- Completed: `'"$(date -Is)"'`"
        done = 1
      }
      { print }
    ' "$file" > "$tmp"
  fi
  chmod 600 "$tmp"
  mv "$tmp" "$file"
  printf '%s\n' "$file"
}

secretary_task_due() {
  secretary_init >/dev/null
  local dir today file status due title
  dir="$(secretary_dir)/tasks"
  today="$(date +%F)"
  while IFS= read -r file; do
    status="$(secretary_task_status "$file")"
    [[ "$status" != "done" ]] || continue
    due="$(secretary_task_field "$file" "Due")"
    [[ -n "$due" && ( "$due" == "$today" || "$due" < "$today" ) ]] || continue
    title="$(sed -n '1s/^# //p' "$file")"
    printf '%s | %s | %s\n' "$due" "$(basename "$file" .md)" "$title"
  done < <(find "$dir" -type f -name '*.md' 2>/dev/null | sort)
}

secretary_reminders() {
  secretary_init >/dev/null
  local dir report now_stamp today file status due remind title pending=0
  dir="$(secretary_dir)"
  report="$dir/reminders/$(date +%F).md"
  now_stamp="$(date +%Y-%m-%dT%H:%M)"
  today="$(date +%F)"
  {
    printf '# Reminder Check %s\n\n' "$(date -Is)"
    printf '## Due Now\n\n'
    while IFS= read -r file; do
      status="$(secretary_task_status "$file")"
      [[ "$status" != "done" ]] || continue
      due="$(secretary_task_field "$file" "Due")"
      remind="$(secretary_task_field "$file" "Remind")"
      title="$(sed -n '1s/^# //p' "$file")"
      if [[ -n "$due" && ( "$due" == "$today" || "$due" < "$today" ) ]] || [[ -n "$remind" && ( "$remind" == "$now_stamp" || "$remind" < "$now_stamp" ) ]]; then
        pending=$((pending + 1))
        printf -- '- `%s` %s' "$(basename "$file" .md)" "$title"
        [[ -n "$due" ]] && printf ' due `%s`' "$due"
        [[ -n "$remind" ]] && printf ' remind `%s`' "$remind"
        printf '\n'
      fi
    done < <(find "$dir/tasks" -type f -name '*.md' 2>/dev/null | sort)
    [[ "$pending" -gt 0 ]] || printf 'No due reminders.\n'
  } | write_private_report "$report"
  if [[ "$pending" -gt 0 && "${OH_HERMES_NOTIFY:-0}" == "1" ]] && have notify-send; then
    notify-send "oh-hermes reminders" "$pending task(s) need attention" || true
  fi
  printf '%s\n' "$report"
}

secretary_task() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    add) secretary_task_add "$@" ;;
    list) secretary_task_list "$@" ;;
    show) secretary_task_show "$@" ;;
    done) secretary_task_done "$@" ;;
    due) secretary_task_due "$@" ;;
    *) die "Unknown secretary task command: $sub" ;;
  esac
}

secretary_integration_template() {
  local name="$1" provider="$2" mode="$3" file="$4"
  {
    printf '# %s Integration\n\n' "$name"
    printf -- '- Created: `%s`\n' "$(date -Is)"
    printf -- '- Provider: `%s`\n' "$provider"
    printf -- '- Mode: `%s`\n' "$mode"
    printf -- '- Status: `planned`\n'
    printf -- '- Secrets: `external-env-or-keyring-only`\n\n'
    printf '## Allowed Without Asking\n\n'
    printf -- '- Read metadata needed for briefings.\n'
    printf -- '- Draft local summaries and proposed actions.\n\n'
    printf '## Requires Confirmation\n\n'
    printf -- '- Sending messages or emails.\n'
    printf -- '- Creating, editing, or deleting calendar events.\n'
    printf -- '- Mutating tasks in an external service.\n'
    printf -- '- Sharing private data outside the machine.\n\n'
    printf '## Never Allowed\n\n'
    printf -- '- Storing credentials in the repo.\n'
    printf -- '- Publishing raw account exports.\n'
    printf -- '- Performing irreversible account changes without explicit confirmation.\n\n'
    printf '## Setup Notes\n\n'
    printf 'Add provider-specific commands, environment names, and scopes here before enabling.\n'
  } | write_private_report "$file"
}

secretary_integrations_init() {
  secretary_init >/dev/null
  local dir
  dir="$(secretary_dir)/integrations"
  run mkdir -p "$dir"
  [[ -f "$dir/email.md" ]] || secretary_integration_template "Email" "unset" "read-only-until-approved" "$dir/email.md"
  [[ -f "$dir/calendar.md" ]] || secretary_integration_template "Calendar" "unset" "read-only-until-approved" "$dir/calendar.md"
  [[ -f "$dir/notifications.md" ]] || secretary_integration_template "Notifications" "local-only" "notify-only" "$dir/notifications.md"
  [[ -f "$dir/tasks.md" ]] || secretary_integration_template "External Tasks" "local" "local-first" "$dir/tasks.md"
  info "Integration policies are at $dir"
}

secretary_integrations_status() {
  secretary_integrations_init >/dev/null
  local file name provider mode status
  printf 'Integration | Provider | Mode | Status\n'
  printf -- '---|---|---|---\n'
  while IFS= read -r file; do
    name="$(sed -n '1s/^# //;1s/ Integration$//p' "$file")"
    provider="$(secretary_task_field "$file" "Provider")"
    mode="$(secretary_task_field "$file" "Mode")"
    status="$(secretary_task_field "$file" "Status")"
    printf '%s | %s | %s | %s\n' "$name" "${provider:-unset}" "${mode:-unset}" "${status:-planned}"
  done < <(find "$(secretary_dir)/integrations" -type f -name '*.md' 2>/dev/null | sort)
}

secretary_integrations_plan() {
  secretary_integrations_init >/dev/null
  local report
  report="$(secretary_dir)/briefings/integration-plan-$(date +%F).md"
  {
    printf '# Secretary Integration Plan\n\n'
    printf -- '- Generated: `%s`\n\n' "$(date -Is)"
    printf '## Current Policies\n\n'
    secretary_integrations_status
    printf '\n## Recommended Order\n\n'
    printf '1. Local notifications via `notify-send` or an explicitly configured NTFY topic.\n'
    printf '2. Calendar read-only sync for daily briefings.\n'
    printf '3. Email read-only triage summaries.\n'
    printf '4. External task sync after local task semantics are stable.\n'
    printf '5. Write actions only after per-provider approval rules are documented.\n\n'
    printf '## Required User Decisions\n\n'
    printf -- '- Provider names and accounts.\n'
    printf -- '- Read-only vs write access per provider.\n'
    printf -- '- Which actions can be automatic.\n'
    printf -- '- Which actions must always ask first.\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

secretary_integrations() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    init) secretary_integrations_init "$@" ;;
    status) secretary_integrations_status "$@" ;;
    plan) secretary_integrations_plan "$@" ;;
    *) die "Unknown secretary integrations command: $sub" ;;
  esac
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
    secretary_task_list | tail -n +3 | head -20 | while IFS= read -r task; do
      printf -- '- %s\n' "$task"
    done
    printf '\n## Due Tasks\n\n'
    secretary_task_due | sed 's/^/- /' || true
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
    printf -- '- Check integration policies with `oh-hermes secretary integrations status`.\n'
    printf -- '- Promote reusable facts into GBrain/MemOS during real work sessions.\n'
    printf -- '- Keep account integrations disabled until credentials and action boundaries are explicit.\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

secretary_worklog() {
  local title="${1:-Work session}" file
  shift || true
  secretary_init >/dev/null
  file="$(secretary_dir)/worklog/$(ts)-$(secretary_slug "$title" | cut -c1-48).md"
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
  printf 'open_tasks=%s\n' "$(secretary_task_list 2>/dev/null | tail -n +3 | wc -l)"
  printf 'due_tasks=%s\n' "$(secretary_task_due 2>/dev/null | wc -l)"
  printf 'briefings=%s\n' "$(find "$dir/briefings" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'worklog=%s\n' "$(find "$dir/worklog" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'integrations=%s\n' "$(find "$dir/integrations" -type f -name '*.md' 2>/dev/null | wc -l)"
}

install_secretary_timer() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  secretary_init >/dev/null
  info "Installing daily oh-hermes secretary timer"
  run mkdir -p "$user_dir"
  run cp "$OH_ROOT/systemd/user/oh-hermes-secretary.service" "$user_dir/"
  run cp "$OH_ROOT/systemd/user/oh-hermes-secretary.timer" "$user_dir/"
  run cp "$OH_ROOT/systemd/user/oh-hermes-reminders.service" "$user_dir/"
  run cp "$OH_ROOT/systemd/user/oh-hermes-reminders.timer" "$user_dir/"
  run systemctl --user daemon-reload
  run systemctl --user enable --now oh-hermes-secretary.timer
  run systemctl --user enable --now oh-hermes-reminders.timer
}

remove_secretary_timer() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  info "Removing daily oh-hermes secretary timer"
  run systemctl --user disable --now oh-hermes-secretary.timer || true
  run systemctl --user disable --now oh-hermes-reminders.timer || true
  run rm -f "$user_dir/oh-hermes-secretary.service" "$user_dir/oh-hermes-secretary.timer" "$user_dir/oh-hermes-reminders.service" "$user_dir/oh-hermes-reminders.timer"
  run systemctl --user daemon-reload
}
