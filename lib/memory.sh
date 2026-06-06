#!/usr/bin/env bash

memory_count_files() {
  local path="$1" depth="${2:-}"
  if [[ -n "$depth" ]]; then
    find "$path" -maxdepth "$depth" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' '
  else
    find "$path" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' '
  fi
}

memory_latest_file() {
  local path="$1"
  find "$path" -type f -name '*.md' 2>/dev/null | sort | tail -n 1
}

memory_status_json() {
  secretary_init >/dev/null
  local dir
  dir="$(secretary_dir)"
  printf '{\n'
  printf '  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "state_dir": '; oh_json_string "$dir"
  printf ',\n  "counts": {\n'
  printf '    "active_lessons": %s,\n' "$(secretary_learn_list --status active 2>/dev/null | tail -n +3 | wc -l | tr -d ' ')"
  printf '    "candidate_lessons": %s,\n' "$(secretary_learn_list --status candidate 2>/dev/null | tail -n +3 | wc -l | tr -d ' ')"
  printf '    "archived_lessons": %s,\n' "$(secretary_learn_list --status archived --all 2>/dev/null | tail -n +3 | wc -l | tr -d ' ')"
  printf '    "decisions": %s,\n' "$(memory_count_files "$dir/decisions")"
  printf '    "worklogs": %s,\n' "$(memory_count_files "$dir/worklog")"
  printf '    "briefings": %s,\n' "$(memory_count_files "$dir/briefings")"
  printf '    "sweeps": %s,\n' "$(memory_count_files "$dir/sweeps")"
  printf '    "audits": %s\n' "$(memory_count_files "$dir/audits")"
  printf '  },\n'
  printf '  "latest": {\n'
  printf '    "briefing": '; oh_json_string "$(memory_latest_file "$dir/briefings")"
  printf ',\n    "learning_review": '; oh_json_string "$(memory_latest_file "$dir/learning/reviews")"
  printf ',\n    "sweep": '; oh_json_string "$(memory_latest_file "$dir/sweeps")"
  printf ',\n    "audit": '; oh_json_string "$(memory_latest_file "$dir/audits")"
  printf '\n  },\n'
  printf '  "improves_with_use": true,\n'
  printf '  "promotion_policy": '; oh_json_string "candidate lessons must be reviewed before promotion"
  printf '\n}\n'
}

memory_status() {
  if [[ "${1:-}" == "--json" ]]; then
    memory_status_json
    return 0
  fi
  printf '# oh-hermes Memory Status\n\n'
  printf -- '- Generated: `%s`\n' "$(date -Is)"
  printf -- '- State: `%s`\n\n' "$(secretary_dir)"
  printf '## Lessons\n\n'
  secretary_learn_list --status active | tail -n +1
  printf '\n## Candidate Lessons\n\n'
  secretary_learn_list --status candidate | tail -n +1
}

memory_digest() {
  secretary_init >/dev/null
  local report
  report="$(secretary_dir)/briefings/memory-digest-$(date +%F).md"
  {
    printf '# Memory Digest\n\n'
    printf -- '- Generated: `%s`\n\n' "$(date -Is)"
    printf '## Active Lessons\n\n'
    secretary_learn_list --status active | tail -n +3 | head -30 | sed 's/^/- /'
    printf '\n## Candidate Lessons\n\n'
    secretary_learn_list --status candidate | tail -n +3 | head -50 | sed 's/^/- /'
    printf '\n## Recent Decisions\n\n'
    secretary_decision_list | tail -n +3 | tail -20 | sed 's/^/- /'
    printf '\n## Recent Worklogs\n\n'
    find "$(secretary_dir)/worklog" -type f -name '*.md' 2>/dev/null | sort | tail -20 | while IFS= read -r file; do
      printf -- '- `%s` %s\n' "$(basename "$file" .md)" "$(sed -n '1s/^# //p' "$file")"
    done
    printf '\n## Next Review Commands\n\n'
    printf -- '- `oh-hermes memory candidates`\n'
    printf -- '- `oh-hermes memory promote-candidates --dry-run`\n'
    printf -- '- `oh-hermes secretary learn review`\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

memory_candidates() {
  secretary_learn_list --status candidate "$@"
}

memory_promote_candidates() {
  local dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      *) die "Unknown memory promote-candidates option: $1" ;;
    esac
  done
  [[ "$dry" == "1" ]] || die "Use --dry-run; bulk promotion requires explicit manual review first"
  printf '# Candidate Lesson Promotion Dry Run\n\n'
  secretary_learn_list --status candidate | tail -n +3 | while IFS= read -r row; do
    [[ -n "$row" ]] || continue
    local id title
    id="$(awk -F' \\| ' '{print $1}' <<< "$row")"
    title="$(awk -F' \\| ' '{print $5}' <<< "$row")"
    printf -- '- Review `%s` (%s): `oh-hermes secretary learn show %s`\n' "$id" "$title" "$id"
    printf -- '  Promote after review: `oh-hermes secretary learn promote %s "Promoted from memory review."`\n' "$id"
  done
}

memory_cmd() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    status) memory_status "$@" ;;
    digest) memory_digest "$@" ;;
    candidates) memory_candidates "$@" ;;
    promote-candidates) memory_promote_candidates "$@" ;;
    *) die "Unknown memory command: $sub" ;;
  esac
}
