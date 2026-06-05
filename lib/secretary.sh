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
  run mkdir -p "$dir/inbox" "$dir/tasks" "$dir/briefings" "$dir/worklog" "$dir/decisions" "$dir/reminders" "$dir/integrations" "$dir/agenda/sources" "$dir/agenda/events" "$dir/agenda/feeds" "$dir/routines" "$dir/routine-runs" "$dir/actions" "$dir/sessions" "$dir/learning" "$dir/learning/reviews" "$dir/sweeps"
  if [[ ! -f "$dir/preferences.md" ]]; then
    run cp "$OH_ROOT/templates/secretary/preferences.md" "$dir/preferences.md"
  fi
  if [[ ! -f "$dir/rules.md" ]]; then
    run cp "$OH_ROOT/templates/secretary/rules.md" "$dir/rules.md"
  fi
  if [[ ! -f "$dir/routines/daily-review.md" && -f "$OH_ROOT/templates/secretary/routines/daily-review.md" ]]; then
    run cp "$OH_ROOT/templates/secretary/routines/daily-review.md" "$dir/routines/daily-review.md"
    chmod 600 "$dir/routines/daily-review.md" 2>/dev/null || true
  fi
  info "Secretary state is at $dir"
}

secretary_notification_env() {
  printf '%s/integrations/notifications.env\n' "$(secretary_dir)"
}

secretary_notifications_init() {
  secretary_integrations_init >/dev/null
  local env_file
  env_file="$(secretary_notification_env)"
  if [[ ! -f "$env_file" ]]; then
    {
      printf 'OH_HERMES_NOTIFY=0\n'
      printf 'OH_HERMES_NOTIFY_BACKEND=notify-send\n'
      printf 'OH_HERMES_NOTIFY_URGENCY=normal\n'
    } > "$env_file"
    chmod 600 "$env_file"
  fi
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

secretary_note_find() {
  local kind="$1" needle="$2" dir file matches=()
  dir="$(secretary_dir)/$kind"
  [[ -n "$needle" ]] || die "$kind id/title prefix is required"
  while IFS= read -r file; do
    if [[ "$(basename "$file")" == "$needle"* ]] || grep -qi "^# .*${needle}" "$file"; then
      matches+=("$file")
    fi
  done < <(find "$dir" -type f -name '*.md' 2>/dev/null | sort)
  [[ "${#matches[@]}" -gt 0 ]] || die "No $kind item matched: $needle"
  [[ "${#matches[@]}" -eq 1 ]] || die "Multiple $kind items matched: $needle"
  printf '%s\n' "${matches[0]}"
}

secretary_inbox_import() {
  secretary_init >/dev/null
  local src="${1:-}" title="" file
  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="${2:-}"; [[ -n "$title" ]] || die "--title needs a value"; shift 2 ;;
      *) die "Unknown inbox import option: $1" ;;
    esac
  done
  [[ -n "$src" ]] || die "Usage: oh-hermes secretary inbox import <file> [--title TITLE]"
  [[ -f "$src" ]] || die "Inbox source is not a file: $src"
  [[ -n "$title" ]] || title="$(basename "$src")"
  file="$(secretary_dir)/inbox/$(ts)-$(secretary_slug "$title" | cut -c1-48).md"
  {
    printf '# %s\n\n' "$title"
    printf -- '- Imported: `%s`\n' "$(date -Is)"
    printf -- '- Source: `%s`\n\n' "$(basename "$src")"
    printf '## Content\n\n'
    sed -n '1,240p' "$src"
  } | write_private_report "$file"
  printf '%s\n' "$file"
}

secretary_inbox_list() {
  secretary_init >/dev/null
  local file
  printf 'ID | Title\n'
  printf -- '---|---\n'
  while IFS= read -r file; do
    printf '%s | %s\n' "$(basename "$file" .md)" "$(sed -n '1s/^# //p' "$file")"
  done < <(find "$(secretary_dir)/inbox" -type f -name '*.md' 2>/dev/null | sort)
}

secretary_inbox_show() {
  local file
  file="$(secretary_note_find inbox "${1:-}")"
  sed -n '1,220p' "$file"
}

secretary_decision_add() {
  secretary_init >/dev/null
  local title="" body="" file
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="${2:-}"; [[ -n "$title" ]] || die "--title needs a value"; shift 2 ;;
      --body) body="${2:-}"; shift 2 ;;
      *) body="${body}${body:+ }$1"; shift ;;
    esac
  done
  [[ -n "$title" ]] || die "Usage: oh-hermes secretary decision add --title TITLE [--body BODY]"
  file="$(secretary_dir)/decisions/$(ts)-$(secretary_slug "$title" | cut -c1-48).md"
  {
    printf '# %s\n\n' "$title"
    printf -- '- Decided: `%s`\n\n' "$(date -Is)"
    printf '## Decision\n\n%s\n' "${body:-No detail captured yet.}"
  } | write_private_report "$file"
  printf '%s\n' "$file"
}

secretary_decision_list() {
  secretary_init >/dev/null
  local file
  printf 'ID | Title\n'
  printf -- '---|---\n'
  while IFS= read -r file; do
    printf '%s | %s\n' "$(basename "$file" .md)" "$(sed -n '1s/^# //p' "$file")"
  done < <(find "$(secretary_dir)/decisions" -type f -name '*.md' 2>/dev/null | sort)
}

secretary_decision_show() {
  local file
  file="$(secretary_note_find decisions "${1:-}")"
  sed -n '1,220p' "$file"
}

secretary_decision() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    add) secretary_decision_add "$@" ;;
    list) secretary_decision_list "$@" ;;
    show) secretary_decision_show "$@" ;;
    *) die "Unknown secretary decision command: $sub" ;;
  esac
}

secretary_learn_field() {
  secretary_task_field "$@"
}

secretary_learn_find() {
  local needle="$1" file matches=()
  [[ -n "$needle" ]] || die "Lesson id/title prefix is required"
  while IFS= read -r file; do
    if [[ "$(basename "$file" .md)" == "$needle"* ]] || grep -qi "^# .*${needle}" "$file"; then
      matches+=("$file")
    fi
  done < <(find "$(secretary_dir)/learning" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
  [[ "${#matches[@]}" -gt 0 ]] || die "No lesson matched: $needle"
  [[ "${#matches[@]}" -eq 1 ]] || die "Multiple lessons matched: $needle"
  printf '%s\n' "${matches[0]}"
}

secretary_learn_add() {
  secretary_init >/dev/null
  local title="" body="" source="manual" confidence="medium" status="active" file
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="${2:-}"; [[ -n "$title" ]] || die "--title needs a value"; shift 2 ;;
      --body) body="${2:-}"; shift 2 ;;
      --source) source="${2:-}"; [[ -n "$source" ]] || die "--source needs a value"; shift 2 ;;
      --confidence) confidence="${2:-}"; [[ -n "$confidence" ]] || die "--confidence needs a value"; shift 2 ;;
      --status) status="${2:-}"; [[ -n "$status" ]] || die "--status needs a value"; shift 2 ;;
      *) body="${body}${body:+ }$1"; shift ;;
    esac
  done
  [[ -n "$title" ]] || die "Usage: oh-hermes secretary learn add --title TITLE [--body BODY] [--source SOURCE] [--confidence low|medium|high] [--status candidate|active]"
  case "$confidence" in low|medium|high) ;; *) die "--confidence must be low, medium, or high" ;; esac
  case "$status" in candidate|active|archived) ;; *) die "--status must be candidate, active, or archived" ;; esac
  file="$(secretary_dir)/learning/$(ts)-$(secretary_slug "$title" | cut -c1-48).md"
  {
    printf '# %s\n\n' "$title"
    printf -- '- Created: `%s`\n' "$(date -Is)"
    printf -- '- Status: `%s`\n' "$status"
    printf -- '- Confidence: `%s`\n' "$confidence"
    printf -- '- Source: `%s`\n\n' "$source"
    printf '## Lesson\n\n%s\n\n' "${body:-No lesson detail captured yet.}"
    printf '## Review Log\n\n'
    printf -- '- `%s` `%s` Captured lesson.\n' "$(date -Is)" "$status"
  } | write_private_report "$file"
  printf '%s\n' "$file"
}

secretary_learn_candidate() {
  local title="$1" source="$2" body="$3" confidence="${4:-medium}"
  secretary_learn_add --title "$title" --source "$source" --body "$body" --confidence "$confidence" --status candidate
}

secretary_learn_list() {
  secretary_init >/dev/null
  local all=0 wanted="" file title status confidence source
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all) all=1; shift ;;
      --status) wanted="${2:-}"; [[ -n "$wanted" ]] || die "--status needs a value"; shift 2 ;;
      *) die "Unknown learn list option: $1" ;;
    esac
  done
  printf 'ID | Status | Confidence | Source | Title\n'
  printf -- '---|---|---|---|---\n'
  while IFS= read -r file; do
    status="$(secretary_learn_field "$file" "Status")"
    [[ -z "$wanted" || "${status:-active}" == "$wanted" ]] || continue
    [[ "$all" == "1" || "${status:-active}" != "archived" ]] || continue
    title="$(sed -n '1s/^# //p' "$file")"
    confidence="$(secretary_learn_field "$file" "Confidence")"
    source="$(secretary_learn_field "$file" "Source")"
    printf '%s | %s | %s | %s | %s\n' "$(basename "$file" .md)" "${status:-active}" "${confidence:-medium}" "${source:-manual}" "$title"
  done < <(find "$(secretary_dir)/learning" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort)
}

secretary_learn_show() {
  local file
  file="$(secretary_learn_find "${1:-}")"
  sed -n '1,260p' "$file"
}

secretary_markdown_set_field() {
  local file="$1" field="$2" value="$3" tmp stamp
  tmp="$(mktemp)"
  stamp="$(date -Is)"
  awk -v field="$field" -v value="$value" -v stamp="$stamp" '
    index($0, "- " field ":") == 1 && !done {
      print "- " field ": `" value "`"
      done = 1
      next
    }
    index($0, "- Updated:") == 1 { next }
    { print }
    END {
      if (!done) {
        print "- " field ": `" value "`"
      }
    }
  ' "$file" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$file"
  if grep -q '^- Updated:' "$file"; then
    return 0
  fi
  awk -v stamp="$stamp" '
    /^- / && !inserted {
      print
      next
    }
    /^$/ && !inserted {
      print "- Updated: `" stamp "`"
      inserted = 1
    }
    { print }
  ' "$file" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$file"
}

secretary_learn_set_status() {
  local id="$1" status="$2" note="${3:-}" file stamp
  [[ -n "$id" ]] || die "Lesson id/title prefix is required"
  case "$status" in candidate|active|archived) ;; *) die "invalid lesson status: $status" ;; esac
  file="$(secretary_learn_find "$id")"
  stamp="$(date -Is)"
  secretary_markdown_set_field "$file" "Status" "$status"
  {
    printf '\n'
    printf -- '- `%s` `%s` %s\n' "$stamp" "$status" "${note:-No note.}"
  } >> "$file"
  printf '%s\n' "$file"
}

secretary_learn_review() {
  secretary_init >/dev/null
  local report
  report="$(secretary_dir)/learning/reviews/$(ts)-learning-review.md"
  {
    printf '# Learning Review\n\n'
    printf -- '- Generated: `%s`\n\n' "$(date -Is)"
    printf '## Active Lessons\n\n'
    secretary_learn_list --status active | tail -n +3 | head -40 | sed 's/^/- /'
    printf '\n## Candidate Lessons\n\n'
    secretary_learn_list --status candidate | tail -n +3 | head -60 | sed 's/^/- /'
    printf '\n## Recent Completed Tasks\n\n'
    find "$(secretary_dir)/tasks" -type f -name '*.md' -mtime -30 -print 2>/dev/null | sort | tail -30 | while IFS= read -r task; do
      [[ "$(secretary_task_status "$task")" == "done" ]] || continue
      printf -- '- `%s` %s\n' "$(basename "$task" .md)" "$(sed -n '1s/^# //p' "$task")"
    done
    printf '\n## Recent Closed Actions\n\n'
    find "$(secretary_dir)/actions" -type f -name '*.md' -mtime -30 -print 2>/dev/null | sort | tail -30 | while IFS= read -r action; do
      case "$(secretary_action_field "$action" "Status")" in
        done|rejected) printf -- '- `%s` `%s` %s\n' "$(basename "$action" .md)" "$(secretary_action_field "$action" "Status")" "$(sed -n '1s/^# //p' "$action")" ;;
      esac
    done
    printf '\n## Review Instructions\n\n'
    printf -- '- Promote durable, reusable candidates with `oh-hermes secretary learn promote <id>`.\n'
    printf -- '- Archive noisy or one-off candidates with `oh-hermes secretary learn archive <id>`.\n'
    printf -- '- Keep active lessons short enough to influence future context packs.\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

secretary_learn() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    add) secretary_learn_add "$@" ;;
    list) secretary_learn_list "$@" ;;
    show) secretary_learn_show "$@" ;;
    promote) secretary_learn_set_status "${1:-}" active "${2:-Promoted for reuse.}" ;;
    archive) secretary_learn_set_status "${1:-}" archived "${2:-Archived.}" ;;
    review) secretary_learn_review "$@" ;;
    *) die "Unknown secretary learn command: $sub" ;;
  esac
}

secretary_action_field() {
  secretary_task_field "$@"
}

secretary_action_find() {
  local needle="$1" dir file matches=()
  dir="$(secretary_dir)/actions"
  [[ -n "$needle" ]] || die "Action id/title prefix is required"
  while IFS= read -r file; do
    if [[ "$(basename "$file" .md)" == "$needle"* ]] || grep -qi "^# .*${needle}" "$file"; then
      matches+=("$file")
    fi
  done < <(find "$dir" -type f -name '*.md' 2>/dev/null | sort)
  [[ "${#matches[@]}" -gt 0 ]] || die "No action matched: $needle"
  [[ "${#matches[@]}" -eq 1 ]] || die "Multiple actions matched: $needle"
  printf '%s\n' "${matches[0]}"
}

secretary_action_add() {
  secretary_init >/dev/null
  local title="" body="" type="local" risk="medium" project="general" approval="1" file
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title) title="${2:-}"; [[ -n "$title" ]] || die "--title needs a value"; shift 2 ;;
      --body) body="${2:-}"; shift 2 ;;
      --type) type="${2:-}"; [[ -n "$type" ]] || die "--type needs a value"; shift 2 ;;
      --risk) risk="${2:-}"; [[ -n "$risk" ]] || die "--risk needs a value"; shift 2 ;;
      --project) project="${2:-}"; [[ -n "$project" ]] || die "--project needs a value"; shift 2 ;;
      --requires-approval) approval="${2:-}"; [[ -n "$approval" ]] || die "--requires-approval needs a value"; shift 2 ;;
      *) body="${body}${body:+ }$1"; shift ;;
    esac
  done
  [[ -n "$title" ]] || die "Usage: oh-hermes secretary action add --title TITLE [--type local|external|message|research|code] [--risk low|medium|high] [--requires-approval 0|1]"
  case "$risk" in low|medium|high) ;; *) die "--risk must be low, medium, or high" ;; esac
  case "$approval" in 0|1) ;; *) die "--requires-approval must be 0 or 1" ;; esac
  file="$(secretary_dir)/actions/$(ts)-$(secretary_slug "$title" | cut -c1-48).md"
  {
    printf '# %s\n\n' "$title"
    printf -- '- Created: `%s`\n' "$(date -Is)"
    printf -- '- Status: `proposed`\n'
    printf -- '- Type: `%s`\n' "$type"
    printf -- '- Risk: `%s`\n' "$risk"
    printf -- '- Project: `%s`\n' "$project"
    printf -- '- Requires Approval: `%s`\n\n' "$approval"
    printf '## Proposed Work\n\n%s\n\n' "${body:-No details captured yet.}"
    printf '## Status Log\n\n'
    printf -- '- `%s` `proposed` Created action proposal.\n' "$(date -Is)"
  } | write_private_report "$file"
  printf '%s\n' "$file"
}

secretary_action_list() {
  secretary_init >/dev/null
  local all=0 file title status type risk project approval
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all) all=1; shift ;;
      *) die "Unknown action list option: $1" ;;
    esac
  done
  printf 'ID | Status | Risk | Approval | Type | Project | Title\n'
  printf -- '---|---|---|---|---|---|---\n'
  while IFS= read -r file; do
    status="$(secretary_action_field "$file" "Status")"
    [[ "$all" == "1" || ( "$status" != "done" && "$status" != "rejected" ) ]] || continue
    title="$(sed -n '1s/^# //p' "$file")"
    type="$(secretary_action_field "$file" "Type")"
    risk="$(secretary_action_field "$file" "Risk")"
    project="$(secretary_action_field "$file" "Project")"
    approval="$(secretary_action_field "$file" "Requires Approval")"
    printf '%s | %s | %s | %s | %s | %s | %s\n' "$(basename "$file" .md)" "${status:-proposed}" "${risk:-medium}" "${approval:-1}" "${type:-local}" "${project:-general}" "$title"
  done < <(find "$(secretary_dir)/actions" -type f -name '*.md' 2>/dev/null | sort)
}

secretary_action_show() {
  local file
  file="$(secretary_action_find "${1:-}")"
  sed -n '1,260p' "$file"
}

secretary_session_field() {
  secretary_task_field "$@"
}

secretary_session_list() {
  secretary_init >/dev/null
  local all=0 file title status action started
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all) all=1; shift ;;
      *) die "Unknown session list option: $1" ;;
    esac
  done
  printf 'ID | Status | Action | Started | Title\n'
  printf -- '---|---|---|---|---\n'
  while IFS= read -r file; do
    status="$(secretary_session_field "$file" "Status")"
    [[ "$all" == "1" || "${status:-active}" == "active" ]] || continue
    title="$(sed -n '1s/^# //p' "$file" | sed 's/^Worker Session: //')"
    action="$(secretary_session_field "$file" "Action")"
    started="$(secretary_session_field "$file" "Started")"
    printf '%s | %s | %s | %s | %s\n' "$(basename "$file" .md)" "${status:-active}" "${action:-unknown}" "${started:--}" "$title"
  done < <(find "$(secretary_dir)/sessions" -type f -name '*.md' 2>/dev/null | sort)
}

secretary_session_find() {
  local needle="$1" file matches=()
  [[ -n "$needle" ]] || die "Session id/title prefix is required"
  while IFS= read -r file; do
    if [[ "$(basename "$file" .md)" == "$needle"* ]] || grep -qi "^# .*${needle}" "$file"; then
      matches+=("$file")
    fi
  done < <(find "$(secretary_dir)/sessions" -type f -name '*.md' 2>/dev/null | sort)
  [[ "${#matches[@]}" -gt 0 ]] || die "No session matched: $needle"
  [[ "${#matches[@]}" -eq 1 ]] || die "Multiple sessions matched: $needle"
  printf '%s\n' "${matches[0]}"
}

secretary_session_show() {
  local file
  file="$(secretary_session_find "${1:-}")"
  sed -n '1,280p' "$file"
}

secretary_session_close_for_action() {
  local action_id="$1" status="$2" note="${3:-}" file stamp
  stamp="$(date -Is)"
  while IFS= read -r file; do
    [[ "$(secretary_session_field "$file" "Action")" == "$action_id" ]] || continue
    [[ "$(secretary_session_field "$file" "Status")" == "active" ]] || continue
    secretary_markdown_set_field "$file" "Status" "closed"
    {
      printf '\n'
      printf -- '- `%s` `%s` %s\n' "$stamp" "$status" "${note:-No note.}"
    } >> "$file"
  done < <(find "$(secretary_dir)/sessions" -type f -name '*.md' 2>/dev/null | sort)
}

secretary_session() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    list) secretary_session_list "$@" ;;
    show) secretary_session_show "$@" ;;
    *) die "Unknown secretary session command: $sub" ;;
  esac
}

secretary_action_start() {
  secretary_init >/dev/null
  local id="${1:-}" note="${2:-Started worker session.}" file action_id title status approval risk type project session existing
  file="$(secretary_action_find "$id")"
  action_id="$(basename "$file" .md)"
  title="$(sed -n '1s/^# //p' "$file")"
  status="$(secretary_action_field "$file" "Status")"
  approval="$(secretary_action_field "$file" "Requires Approval")"
  risk="$(secretary_action_field "$file" "Risk")"
  type="$(secretary_action_field "$file" "Type")"
  project="$(secretary_action_field "$file" "Project")"
  case "${status:-proposed}" in
    approved|in_progress) ;;
    proposed)
      [[ "${approval:-1}" == "0" ]] || die "Action requires approval before start: $action_id"
      ;;
    done|rejected) die "Action is already closed: $action_id" ;;
    *) die "Action cannot be started from status: ${status:-proposed}" ;;
  esac
  while IFS= read -r existing; do
    [[ "$(secretary_session_field "$existing" "Action")" == "$action_id" ]] || continue
    [[ "$(secretary_session_field "$existing" "Status")" == "active" ]] || continue
    printf '%s\n' "$existing"
    return 0
  done < <(find "$(secretary_dir)/sessions" -type f -name '*.md' 2>/dev/null | sort)
  session="$(secretary_dir)/sessions/$(ts)-$(secretary_slug "$title" | cut -c1-48).md"
  {
    printf '# Worker Session: %s\n\n' "$title"
    printf -- '- Started: `%s`\n' "$(date -Is)"
    printf -- '- Status: `active`\n'
    printf -- '- Action: `%s`\n' "$action_id"
    printf -- '- Type: `%s`\n' "${type:-local}"
    printf -- '- Risk: `%s`\n' "${risk:-medium}"
    printf -- '- Project: `%s`\n\n' "${project:-general}"
    printf '## Start Note\n\n%s\n\n' "$note"
    printf '## Proposed Work\n\n'
    awk '
      found && /^## / { exit }
      found { print }
      /^## Proposed Work/ { found = 1; next }
    ' "$file"
    printf '\n## Operating Rules\n\n'
    sed -n '1,80p' "$(secretary_dir)/rules.md" 2>/dev/null || true
    printf '\n## Active Lessons\n\n'
    secretary_learn_list --status active | tail -n +3 | head -20 | sed 's/^/- /'
    printf '\n## Work Notes\n\n'
  } | write_private_report "$session"
  secretary_action_set_status "$action_id" in_progress "Started worker session: $(basename "$session")" >/dev/null
  printf '%s\n' "$session"
}

secretary_action_set_status() {
  local id="$1" status="$2" note="${3:-}" file tmp stamp title source
  file="$(secretary_action_find "$id")"
  tmp="$(mktemp)"
  stamp="$(date -Is)"
  title="$(sed -n '1s/^# //p' "$file")"
  awk -v status="$status" -v stamp="$stamp" '
    index($0, "- Status:") == 1 && !done {
      print "- Status: `" status "`"
      print "- Updated: `" stamp "`"
      done = 1
      next
    }
    index($0, "- Updated:") == 1 { next }
    { print }
    END {
      if (!done) {
        print "- Status: `" status "`"
        print "- Updated: `" stamp "`"
      }
    }
  ' "$file" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$file"
  {
    printf '\n'
    printf -- '- `%s` `%s` %s\n' "$stamp" "$status" "${note:-No note.}"
  } >> "$file"
  case "$status" in
    done|rejected)
      secretary_session_close_for_action "$(basename "$file" .md)" "$status" "$note" >/dev/null || true
      source="action:$(basename "$file" .md)"
      secretary_learn_candidate "Action outcome: $title" "$source" "Status: $status"$'\n'"Note: ${note:-No note.}" medium >/dev/null || true
      ;;
  esac
  printf '%s\n' "$file"
}

secretary_action_plan() {
  secretary_init >/dev/null
  local report
  report="$(secretary_dir)/briefings/worker-actions-$(date +%F).md"
  {
    printf '# Worker Action Plan\n\n'
    printf -- '- Generated: `%s`\n\n' "$(date -Is)"
    printf '## Pending Actions\n\n'
    secretary_action_list | tail -n +3 | sed 's/^/- /'
    printf '\n## Active Sessions\n\n'
    secretary_session_list | tail -n +3 | sed 's/^/- /'
    printf '\n## Due Tasks\n\n'
    secretary_task_due | sed 's/^/- /' || true
    printf '\n## Inbox Waiting For Triage\n\n'
    secretary_inbox_list | tail -n +3 | sed 's/^/- /'
    printf '\n## Execution Rules\n\n'
    printf -- '- Proposed actions are planning artifacts, not completed work.\n'
    printf -- '- Approval is required when `Requires Approval` is `1`.\n'
    printf -- '- External messages, purchases, account changes, or destructive operations must remain proposed until explicitly approved.\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

secretary_action() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    add) secretary_action_add "$@" ;;
    list) secretary_action_list "$@" ;;
    show) secretary_action_show "$@" ;;
    start) secretary_action_start "${1:-}" "${2:-Started worker session.}" ;;
    approve) secretary_action_set_status "${1:-}" approved "${2:-Approved by operator.}" ;;
    reject) secretary_action_set_status "${1:-}" rejected "${2:-Rejected by operator.}" ;;
    done) secretary_action_set_status "${1:-}" done "${2:-Completed by worker.}" ;;
    plan) secretary_action_plan "$@" ;;
    sessions) secretary_session_list "$@" ;;
    *) die "Unknown secretary action command: $sub" ;;
  esac
}

secretary_inbox_triage() {
  secretary_init >/dev/null
  local id="" to="" title="" due="" priority="normal" project="inbox" file body out
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --id) id="${2:-}"; [[ -n "$id" ]] || die "--id needs a value"; shift 2 ;;
      --to) to="${2:-}"; [[ -n "$to" ]] || die "--to needs a value"; shift 2 ;;
      --title) title="${2:-}"; [[ -n "$title" ]] || die "--title needs a value"; shift 2 ;;
      --due) due="${2:-}"; [[ -n "$due" ]] || die "--due needs a value"; shift 2 ;;
      --priority) priority="${2:-}"; [[ -n "$priority" ]] || die "--priority needs a value"; shift 2 ;;
      --project) project="${2:-}"; [[ -n "$project" ]] || die "--project needs a value"; shift 2 ;;
      *) die "Unknown inbox triage option: $1" ;;
    esac
  done
  [[ -n "$id" && -n "$to" ]] || die "Usage: oh-hermes secretary inbox triage --id ID --to task|decision|worklog|action [--title TITLE]"
  file="$(secretary_note_find inbox "$id")"
  [[ -n "$title" ]] || title="$(sed -n '1s/^# //p' "$file")"
  body="$(sed -n '/^## Content/,$p' "$file" | tail -n +3)"
  case "$to" in
    task)
      if [[ -n "$due" ]]; then
        out="$(secretary_task_add --title "$title" --body "$body" --due "$due" --priority "$priority" --project "$project")"
      else
        out="$(secretary_task_add --title "$title" --body "$body" --priority "$priority" --project "$project")"
      fi
      ;;
    decision) out="$(secretary_decision_add --title "$title" --body "$body")" ;;
    worklog) out="$(secretary_worklog "$title" "$body")" ;;
    action) out="$(secretary_action_add --title "$title" --body "$body" --type local --risk medium --project "$project" --requires-approval 1)" ;;
    *) die "--to must be task, decision, worklog, or action" ;;
  esac
  mkdir -p "$(secretary_dir)/inbox/triaged"
  mv "$file" "$(secretary_dir)/inbox/triaged/$(basename "$file")"
  printf '%s\n' "$out"
}

secretary_inbox() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    import) secretary_inbox_import "$@" ;;
    list) secretary_inbox_list "$@" ;;
    show) secretary_inbox_show "$@" ;;
    triage) secretary_inbox_triage "$@" ;;
    *) die "Unknown secretary inbox command: $sub" ;;
  esac
}

secretary_sweep() {
  secretary_init >/dev/null
  local task_days=7 action_days=3 session_days=1 report dir
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task-days) task_days="${2:-}"; [[ -n "$task_days" ]] || die "--task-days needs a value"; shift 2 ;;
      --action-days) action_days="${2:-}"; [[ -n "$action_days" ]] || die "--action-days needs a value"; shift 2 ;;
      --session-days) session_days="${2:-}"; [[ -n "$session_days" ]] || die "--session-days needs a value"; shift 2 ;;
      *) die "Unknown sweep option: $1" ;;
    esac
  done
  dir="$(secretary_dir)"
  report="$dir/sweeps/$(ts)-maintenance-sweep.md"
  {
    printf '# Secretary Maintenance Sweep\n\n'
    printf -- '- Generated: `%s`\n' "$(date -Is)"
    printf -- '- Stale task threshold: `%s day(s)`\n' "$task_days"
    printf -- '- Stale action threshold: `%s day(s)`\n' "$action_days"
    printf -- '- Stale session threshold: `%s day(s)`\n\n' "$session_days"
    printf '## Stale Open Tasks\n\n'
    find "$dir/tasks" -type f -name '*.md' -mtime +"$task_days" -print 2>/dev/null | sort | while IFS= read -r task; do
      [[ "$(secretary_task_status "$task")" != "done" ]] || continue
      printf -- '- `%s` %s\n' "$(basename "$task" .md)" "$(sed -n '1s/^# //p' "$task")"
    done
    printf '\n## Stalled Worker Actions\n\n'
    find "$dir/actions" -type f -name '*.md' -mtime +"$action_days" -print 2>/dev/null | sort | while IFS= read -r action; do
      case "$(secretary_action_field "$action" "Status")" in
        done|rejected) continue ;;
      esac
      printf -- '- `%s` `%s` %s\n' "$(basename "$action" .md)" "$(secretary_action_field "$action" "Status")" "$(sed -n '1s/^# //p' "$action")"
    done
    printf '\n## Stale Active Sessions\n\n'
    find "$dir/sessions" -type f -name '*.md' -mtime +"$session_days" -print 2>/dev/null | sort | while IFS= read -r session; do
      [[ "$(secretary_session_field "$session" "Status")" == "active" ]] || continue
      printf -- '- `%s` action `%s` %s\n' "$(basename "$session" .md)" "$(secretary_session_field "$session" "Action")" "$(sed -n '1s/^# //p' "$session" | sed 's/^Worker Session: //')"
    done
    printf '\n## Candidate Lessons Waiting For Review\n\n'
    secretary_learn_list --status candidate | tail -n +3 | sed 's/^/- /'
    printf '\n## Integration Gaps\n\n'
    [[ "$(find "$dir/agenda/feeds" -type f -name '*.env' 2>/dev/null | wc -l)" -gt 0 ]] || printf -- '- No agenda feeds configured.\n'
    [[ "$(find "$dir/integrations" -type f -name '*.md' 2>/dev/null | wc -l)" -gt 0 ]] || printf -- '- Integration policies have not been initialized.\n'
    [[ -f "$(secretary_notification_env)" ]] || printf -- '- Notification preferences are not initialized.\n'
    printf '\n## Recommended Commands\n\n'
    printf -- '- Review stale tasks with `oh-hermes secretary task list --all`.\n'
    printf -- '- Start approved actions with `oh-hermes secretary action start <id>`.\n'
    printf -- '- Close finished sessions with `oh-hermes secretary action done <id>`.\n'
    printf -- '- Promote or archive learning candidates after review.\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
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
  local file tmp note title source
  file="$(secretary_task_find "${1:-}")"
  note="${2:-Completed task.}"
  title="$(sed -n '1s/^# //p' "$file")"
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
  {
    printf '\n## Completion Note\n\n%s\n' "$note"
  } >> "$file"
  source="task:$(basename "$file" .md)"
  secretary_learn_candidate "Task outcome: $title" "$source" "$note" medium >/dev/null || true
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
  if [[ -f "$(secretary_notification_env)" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$(secretary_notification_env)"
    set +a
  fi
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
    notify-send --urgency="${OH_HERMES_NOTIFY_URGENCY:-normal}" "oh-hermes reminders" "$pending task(s) need attention" || true
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

secretary_ics_unescape() {
  sed -E 's/\\n/ /g; s/\\,/,/g; s/\\;/;/g; s/[[:space:]]+/ /g'
}

secretary_ics_date() {
  local raw="$1"
  raw="${raw%%T*}"
  raw="${raw%%Z}"
  if [[ "$raw" =~ ^[0-9]{8}$ ]]; then
    printf '%s-%s-%s' "${raw:0:4}" "${raw:4:2}" "${raw:6:2}"
  else
    printf '%s' "$raw"
  fi
}

secretary_agenda_import_ics() {
  local src="$1" source_name="$2" dir out line in_event=0 summary="" start="" end="" location="" uid="" count=0
  dir="$(secretary_dir)/agenda/events"
  out="$dir/$(ts)-$(secretary_slug "$source_name").md"
  {
    printf '# Agenda Import: %s\n\n' "$source_name"
    printf -- '- Imported: `%s`\n' "$(date -Is)"
    printf -- '- Source: `%s`\n\n' "$source_name"
    printf '## Events\n\n'
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        BEGIN:VEVENT)
          in_event=1; summary=""; start=""; end=""; location=""; uid="" ;;
        END:VEVENT)
          if [[ "$in_event" == "1" ]]; then
            count=$((count + 1))
            printf -- '- `%s` %s' "$(secretary_ics_date "$start")" "${summary:-Untitled event}"
            [[ -n "$end" ]] && printf ' until `%s`' "$(secretary_ics_date "$end")"
            [[ -n "$location" ]] && printf ' at %s' "$location"
            [[ -n "$uid" ]] && printf ' (`%s`)' "$uid"
            printf '\n'
          fi
          in_event=0 ;;
        SUMMARY:*) [[ "$in_event" == "1" ]] && summary="$(printf '%s' "${line#SUMMARY:}" | secretary_ics_unescape)" ;;
        DTSTART*) [[ "$in_event" == "1" ]] && start="${line#*:}" ;;
        DTEND*) [[ "$in_event" == "1" ]] && end="${line#*:}" ;;
        LOCATION:*) [[ "$in_event" == "1" ]] && location="$(printf '%s' "${line#LOCATION:}" | secretary_ics_unescape)" ;;
        UID:*) [[ "$in_event" == "1" ]] && uid="$(printf '%s' "${line#UID:}" | secretary_ics_unescape)" ;;
      esac
    done < "$src"
    [[ "$count" -gt 0 ]] || printf 'No events found.\n'
  } | write_private_report "$out"
  printf '%s\n' "$out"
}

secretary_agenda_import_markdown() {
  local src="$1" source_name="$2" out
  out="$(secretary_dir)/agenda/events/$(ts)-$(secretary_slug "$source_name").md"
  {
    printf '# Agenda Import: %s\n\n' "$source_name"
    printf -- '- Imported: `%s`\n' "$(date -Is)"
    printf -- '- Source: `%s`\n\n' "$source_name"
    printf '## Events\n\n'
    sed -n '1,200p' "$src"
  } | write_private_report "$out"
  printf '%s\n' "$out"
}

secretary_agenda_import() {
  secretary_init >/dev/null
  local src="${1:-}" copied source_name ext
  [[ -n "$src" ]] || die "Usage: oh-hermes secretary agenda import <file.ics|file.md>"
  [[ -f "$src" ]] || die "Agenda source is not a file: $src"
  source_name="$(basename "$src")"
  copied="$(secretary_dir)/agenda/sources/$(ts)-$(secretary_slug "$source_name")"
  cp "$src" "$copied"
  chmod 600 "$copied"
  ext="${source_name##*.}"
  if grep -q '^BEGIN:VCALENDAR' "$copied"; then
    secretary_agenda_import_ics "$copied" "$source_name"
  else
    case "$ext" in
      ics|ICS) secretary_agenda_import_ics "$copied" "$source_name" ;;
      md|MD|txt|TXT) secretary_agenda_import_markdown "$copied" "$source_name" ;;
      *) die "Unsupported agenda file type: $ext" ;;
    esac
  fi
}

secretary_agenda_feed_add() {
  secretary_init >/dev/null
  local name="" source="" type="auto" file
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="${2:-}"; [[ -n "$name" ]] || die "--name needs a value"; shift 2 ;;
      --source) source="${2:-}"; [[ -n "$source" ]] || die "--source needs a value"; shift 2 ;;
      --type) type="${2:-}"; [[ -n "$type" ]] || die "--type needs a value"; shift 2 ;;
      *) die "Unknown agenda feed add option: $1" ;;
    esac
  done
  [[ -n "$name" && -n "$source" ]] || die "Usage: oh-hermes secretary agenda feed add --name NAME --source PATH_OR_URL [--type ics|markdown|auto]"
  file="$(secretary_dir)/agenda/feeds/$(secretary_slug "$name").env"
  {
    printf 'NAME=%q\n' "$name"
    printf 'SOURCE=%q\n' "$source"
    printf 'TYPE=%q\n' "$type"
    printf 'ENABLED=1\n'
  } > "$file"
  chmod 600 "$file"
  printf '%s\n' "$file"
}

secretary_agenda_feed_list() {
  secretary_init >/dev/null
  local file name source type enabled
  printf 'Name | Type | Enabled | Source\n'
  printf -- '---|---|---|---\n'
  for file in "$(secretary_dir)"/agenda/feeds/*.env; do
    [[ -f "$file" ]] || continue
    name=""; source=""; type=""; enabled=""
    # shellcheck source=/dev/null
    source "$file"
    printf '%s | %s | %s | %s\n' "${NAME:-$(basename "$file" .env)}" "${TYPE:-auto}" "${ENABLED:-1}" "${SOURCE:-}"
  done
}

secretary_agenda_feed_fetch() {
  local source="$1" name="$2" out
  out="$(secretary_dir)/agenda/sources/$(ts)-$(secretary_slug "$name")"
  case "$source" in
    http://*|https://*)
      if have curl; then
        curl -fsSL --max-time "${OH_HERMES_AGENDA_FETCH_TIMEOUT:-20}" "$source" -o "$out"
      else
        die "curl is required to sync URL agenda feeds"
      fi
      ;;
    *)
      [[ -f "$source" ]] || die "Agenda feed source missing: $source"
      cp "$source" "$out"
      ;;
  esac
  chmod 600 "$out"
  printf '%s\n' "$out"
}

secretary_agenda_feed_sync() {
  secretary_init >/dev/null
  local file name source type enabled fetched report count=0
  report="$(secretary_dir)/agenda/sync-$(ts).md"
  {
    printf '# Agenda Feed Sync\n\n'
    printf -- '- Generated: `%s`\n\n' "$(date -Is)"
    for file in "$(secretary_dir)"/agenda/feeds/*.env; do
      [[ -f "$file" ]] || continue
      NAME=""; SOURCE=""; TYPE="auto"; ENABLED="1"
      # shellcheck source=/dev/null
      source "$file"
      name="${NAME:-$(basename "$file" .env)}"
      source="${SOURCE:-}"
      type="${TYPE:-auto}"
      enabled="${ENABLED:-1}"
      if [[ "$enabled" != "1" ]]; then
        printf -- '- skipped `%s` disabled\n' "$name"
        continue
      fi
      if [[ -z "$source" ]]; then
        printf -- '- skipped `%s` missing source\n' "$name"
        continue
      fi
      if fetched="$(secretary_agenda_feed_fetch "$source" "$name" 2>&1)"; then
        count=$((count + 1))
        case "$type" in
          ics) secretary_agenda_import_ics "$fetched" "$name" >/dev/null ;;
          markdown|md|txt) secretary_agenda_import_markdown "$fetched" "$name" >/dev/null ;;
          auto)
            if grep -q '^BEGIN:VCALENDAR' "$fetched"; then
              secretary_agenda_import_ics "$fetched" "$name" >/dev/null
            else
              secretary_agenda_import_markdown "$fetched" "$name" >/dev/null
            fi
            ;;
          *) printf -- '- `%s` fetched but unknown type `%s`\n' "$name" "$type"; continue ;;
        esac
        printf -- '- synced `%s`\n' "$name"
      else
        printf -- '- failed `%s`: %s\n' "$name" "$fetched"
      fi
    done
    [[ "$count" -gt 0 ]] || printf 'No feeds synced.\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

secretary_agenda_feed() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    add) secretary_agenda_feed_add "$@" ;;
    list) secretary_agenda_feed_list "$@" ;;
    sync) secretary_agenda_feed_sync "$@" ;;
    *) die "Unknown secretary agenda feed command: $sub" ;;
  esac
}

secretary_agenda_list() {
  secretary_init >/dev/null
  local file
  for file in "$(secretary_dir)"/agenda/events/*.md; do
    [[ -f "$file" ]] || continue
    printf '## %s\n' "$(basename "$file")"
    sed -n '/^## Events/,$p' "$file" | tail -n +3 | head -40
    printf '\n'
  done
}

secretary_agenda_today() {
  secretary_init >/dev/null
  local today file
  today="$(date +%F)"
  for file in "$(secretary_dir)"/agenda/events/*.md; do
    [[ -f "$file" ]] || continue
    grep -F "\`$today\`" "$file" || true
  done
}

secretary_agenda() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    import) secretary_agenda_import "$@" ;;
    feed) secretary_agenda_feed "$@" ;;
    list) secretary_agenda_list "$@" ;;
    today) secretary_agenda_today "$@" ;;
    *) die "Unknown secretary agenda command: $sub" ;;
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

secretary_notify() {
  local sub="${1:-status}" env_file enabled backend urgency
  shift || true
  secretary_notifications_init
  env_file="$(secretary_notification_env)"
  case "$sub" in
    status)
      enabled="$(awk -F= '/^OH_HERMES_NOTIFY=/ {print $2; exit}' "$env_file")"
      backend="$(awk -F= '/^OH_HERMES_NOTIFY_BACKEND=/ {print $2; exit}' "$env_file")"
      urgency="$(awk -F= '/^OH_HERMES_NOTIFY_URGENCY=/ {print $2; exit}' "$env_file")"
      printf 'enabled=%s\n' "${enabled:-0}"
      printf 'backend=%s\n' "${backend:-notify-send}"
      printf 'urgency=%s\n' "${urgency:-normal}"
      printf 'notify_send=%s\n' "$(have notify-send && printf available || printf missing)"
      printf 'env_file=%s\n' "$env_file"
      ;;
    enable-local)
      {
        printf 'OH_HERMES_NOTIFY=1\n'
        printf 'OH_HERMES_NOTIFY_BACKEND=notify-send\n'
        printf 'OH_HERMES_NOTIFY_URGENCY=%s\n' "${1:-normal}"
      } > "$env_file"
      chmod 600 "$env_file"
      printf '%s\n' "$env_file"
      ;;
    disable)
      {
        printf 'OH_HERMES_NOTIFY=0\n'
        printf 'OH_HERMES_NOTIFY_BACKEND=notify-send\n'
        printf 'OH_HERMES_NOTIFY_URGENCY=normal\n'
      } > "$env_file"
      chmod 600 "$env_file"
      printf '%s\n' "$env_file"
      ;;
    test)
      if ! have notify-send; then
        printf 'notify-send missing\n'
        return 0
      fi
      if [[ "${1:-}" == "--send" ]]; then
        notify-send --urgency=normal "oh-hermes" "Notification integration test" || true
      fi
      printf 'notify-send available\n'
      ;;
    *) die "Unknown secretary notify command: $sub" ;;
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
    printf '\n## Active Lessons\n\n'
    secretary_learn_list --status active | tail -n +3 | head -20 | sed 's/^/- /'
    printf '\n## Open Tasks\n\n'
    secretary_task_list | tail -n +3 | head -20 | while IFS= read -r task; do
      printf -- '- %s\n' "$task"
    done
    printf '\n## Due Tasks\n\n'
    secretary_task_due | sed 's/^/- /' || true
    printf '\n## Worker Actions\n\n'
    secretary_action_list | tail -n +3 | head -20 | sed 's/^/- /'
    printf '\n## Active Worker Sessions\n\n'
    secretary_session_list | tail -n +3 | head -20 | sed 's/^/- /'
    printf '\n## Today Agenda\n\n'
    secretary_agenda_today | sed 's/^/- /' || true
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
    printf '\n## Recent Decisions\n\n'
    find "$dir/decisions" -type f -name '*.md' -mtime -30 -print 2>/dev/null | sort | tail -20 | while IFS= read -r decision; do
      printf -- '- `%s` ' "$(basename "$decision")"
      sed -n '1p' "$decision" 2>/dev/null | sed 's/^# //'
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

secretary_routine_add() {
  secretary_init >/dev/null
  local name="" schedule="manual" body="" file
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="${2:-}"; [[ -n "$name" ]] || die "--name needs a value"; shift 2 ;;
      --schedule) schedule="${2:-}"; [[ -n "$schedule" ]] || die "--schedule needs a value"; shift 2 ;;
      --body) body="${2:-}"; shift 2 ;;
      *) body="${body}${body:+ }$1"; shift ;;
    esac
  done
  [[ -n "$name" ]] || die "Usage: oh-hermes secretary routine add --name NAME [--schedule daily|weekly|manual] [--body CHECKLIST]"
  file="$(secretary_dir)/routines/$(secretary_slug "$name").md"
  {
    printf '# %s\n\n' "$name"
    printf -- '- Created: `%s`\n' "$(date -Is)"
    printf -- '- Schedule: `%s`\n' "$schedule"
    printf -- '- Enabled: `1`\n\n'
    printf '## Checklist\n\n'
    if [[ -n "$body" ]]; then
      printf '%s\n' "$body"
    else
      printf -- '- [ ] Review open tasks\n'
      printf -- '- [ ] Review due reminders\n'
      printf -- '- [ ] Review today agenda\n'
      printf -- '- [ ] Capture follow-up tasks\n'
    fi
  } | write_private_report "$file"
  printf '%s\n' "$file"
}

secretary_routine_list() {
  secretary_init >/dev/null
  local file schedule enabled
  printf 'ID | Enabled | Schedule | Name\n'
  printf -- '---|---|---|---\n'
  while IFS= read -r file; do
    schedule="$(secretary_task_field "$file" "Schedule")"
    enabled="$(secretary_task_field "$file" "Enabled")"
    printf '%s | %s | %s | %s\n' "$(basename "$file" .md)" "${enabled:-1}" "${schedule:-manual}" "$(sed -n '1s/^# //p' "$file")"
  done < <(find "$(secretary_dir)/routines" -type f -name '*.md' 2>/dev/null | sort)
}

secretary_routine_find() {
  local needle="$1" file matches=()
  [[ -n "$needle" ]] || die "Routine id/name is required"
  while IFS= read -r file; do
    if [[ "$(basename "$file" .md)" == "$needle"* ]] || grep -qi "^# .*${needle}" "$file"; then
      matches+=("$file")
    fi
  done < <(find "$(secretary_dir)/routines" -type f -name '*.md' 2>/dev/null | sort)
  [[ "${#matches[@]}" -gt 0 ]] || die "No routine matched: $needle"
  [[ "${#matches[@]}" -eq 1 ]] || die "Multiple routines matched: $needle"
  printf '%s\n' "${matches[0]}"
}

secretary_routine_run_one() {
  local file="$1" name run_report
  name="$(sed -n '1s/^# //p' "$file")"
  run_report="$(secretary_dir)/routine-runs/$(ts)-$(secretary_slug "$name").md"
  {
    printf '# Routine Run: %s\n\n' "$name"
    printf -- '- Ran: `%s`\n' "$(date -Is)"
    printf -- '- Source: `%s`\n\n' "$(basename "$file")"
    sed -n '/^## Checklist/,$p' "$file"
    printf '\n## Context Snapshot\n\n'
    printf '### Open Tasks\n\n'
    secretary_task_list | tail -n +3 | head -20 | sed 's/^/- /'
    printf '\n### Due Tasks\n\n'
    secretary_task_due | sed 's/^/- /' || true
    printf '\n### Today Agenda\n\n'
    secretary_agenda_today | sed 's/^/- /' || true
  } | write_private_report "$run_report"
  printf '%s\n' "$run_report"
}

secretary_routine_run() {
  secretary_init >/dev/null
  local target="${1:-daily}" file schedule enabled count=0
  if [[ "$target" != "daily" && "$target" != "weekly" && "$target" != "all" ]]; then
    file="$(secretary_routine_find "$target")"
    secretary_routine_run_one "$file"
    return 0
  fi
  for file in "$(secretary_dir)"/routines/*.md; do
    [[ -f "$file" ]] || continue
    schedule="$(secretary_task_field "$file" "Schedule")"
    enabled="$(secretary_task_field "$file" "Enabled")"
    [[ "${enabled:-1}" == "1" ]] || continue
    [[ "$target" == "all" || "${schedule:-manual}" == "$target" ]] || continue
    secretary_routine_run_one "$file"
    count=$((count + 1))
  done
  [[ "$count" -gt 0 ]] || printf 'No %s routines to run.\n' "$target"
}

secretary_routine() {
  local sub="${1:-list}"
  shift || true
  case "$sub" in
    add) secretary_routine_add "$@" ;;
    list) secretary_routine_list "$@" ;;
    run) secretary_routine_run "${1:-daily}" ;;
    *) die "Unknown secretary routine command: $sub" ;;
  esac
}

secretary_status() {
  secretary_init >/dev/null
  local dir
  dir="$(secretary_dir)"
  printf 'secretary_dir=%s\n' "$dir"
  printf 'inbox=%s\n' "$(find "$dir/inbox" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'triaged_inbox=%s\n' "$(find "$dir/inbox/triaged" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'tasks=%s\n' "$(find "$dir/tasks" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'open_tasks=%s\n' "$(secretary_task_list 2>/dev/null | tail -n +3 | wc -l)"
  printf 'due_tasks=%s\n' "$(secretary_task_due 2>/dev/null | wc -l)"
  printf 'briefings=%s\n' "$(find "$dir/briefings" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'worklog=%s\n' "$(find "$dir/worklog" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'decisions=%s\n' "$(find "$dir/decisions" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'actions=%s\n' "$(find "$dir/actions" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'open_actions=%s\n' "$(secretary_action_list 2>/dev/null | tail -n +3 | wc -l)"
  printf 'sessions=%s\n' "$(find "$dir/sessions" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'active_sessions=%s\n' "$(secretary_session_list 2>/dev/null | tail -n +3 | wc -l)"
  printf 'lessons=%s\n' "$(find "$dir/learning" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'candidate_lessons=%s\n' "$(secretary_learn_list --status candidate 2>/dev/null | tail -n +3 | wc -l)"
  printf 'learning_reviews=%s\n' "$(find "$dir/learning/reviews" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'sweeps=%s\n' "$(find "$dir/sweeps" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'routines=%s\n' "$(find "$dir/routines" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'routine_runs=%s\n' "$(find "$dir/routine-runs" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'integrations=%s\n' "$(find "$dir/integrations" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'agenda_imports=%s\n' "$(find "$dir/agenda/events" -type f -name '*.md' 2>/dev/null | wc -l)"
  printf 'agenda_feeds=%s\n' "$(find "$dir/agenda/feeds" -type f -name '*.env' 2>/dev/null | wc -l)"
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
  run cp "$OH_ROOT/systemd/user/oh-hermes-agenda-sync.service" "$user_dir/"
  run cp "$OH_ROOT/systemd/user/oh-hermes-agenda-sync.timer" "$user_dir/"
  run cp "$OH_ROOT/systemd/user/oh-hermes-routines.service" "$user_dir/"
  run cp "$OH_ROOT/systemd/user/oh-hermes-routines.timer" "$user_dir/"
  run systemctl --user daemon-reload
  run systemctl --user enable --now oh-hermes-secretary.timer
  run systemctl --user enable --now oh-hermes-reminders.timer
  run systemctl --user enable --now oh-hermes-agenda-sync.timer
  run systemctl --user enable --now oh-hermes-routines.timer
}

remove_secretary_timer() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  info "Removing daily oh-hermes secretary timer"
  run systemctl --user disable --now oh-hermes-secretary.timer || true
  run systemctl --user disable --now oh-hermes-reminders.timer || true
  run systemctl --user disable --now oh-hermes-agenda-sync.timer || true
  run systemctl --user disable --now oh-hermes-routines.timer || true
  run rm -f "$user_dir/oh-hermes-secretary.service" "$user_dir/oh-hermes-secretary.timer" "$user_dir/oh-hermes-reminders.service" "$user_dir/oh-hermes-reminders.timer" "$user_dir/oh-hermes-agenda-sync.service" "$user_dir/oh-hermes-agenda-sync.timer" "$user_dir/oh-hermes-routines.service" "$user_dir/oh-hermes-routines.timer"
  run systemctl --user daemon-reload
}
