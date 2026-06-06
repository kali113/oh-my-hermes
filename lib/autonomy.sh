#!/usr/bin/env bash

autonomy_timer_state() {
  local unit="$1"
  if have systemctl; then
    systemctl --user is-enabled "$unit" 2>/dev/null || printf 'unknown'
  else
    printf 'systemctl-missing'
  fi
}

autonomy_latest_report() {
  find "$OH_REPORT_DIR" -type f \( -name 'god-mode-*.md' -o -name 'auto-improve-*.md' -o -name 'self-review-*.md' \) 2>/dev/null | sort | tail -n 1
}

autonomy_dirty_files() {
  if [[ -d "$OH_ROOT/.git" ]]; then
    git -C "$OH_ROOT" status --short 2>/dev/null | wc -l | tr -d ' '
  else
    printf '0'
  fi
}

autonomy_status_json() {
  printf '{\n'
  printf '  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "mode": '; oh_json_string "guarded-autonomy"
  printf ',\n  "default_run": '; oh_json_string "dry-run"
  printf ',\n  "tracked_dirty_files": %s,\n' "$(autonomy_dirty_files)"
  printf '  "timers": {\n'
  printf '    "god_mode": '; oh_json_string "$(autonomy_timer_state oh-hermes-god-mode.timer)"
  printf ',\n    "auto_improve": '; oh_json_string "$(autonomy_timer_state oh-hermes-auto-improve.timer)"
  printf ',\n    "secretary": '; oh_json_string "$(autonomy_timer_state oh-hermes-secretary.timer)"
  printf '\n  },\n'
  printf '  "latest_report": '; oh_json_string "$(autonomy_latest_report)"
  printf ',\n  "approval_boundaries": [\n'
  printf '    '; oh_json_string "external writes require explicit approval"
  printf ',\n    '; oh_json_string "destructive local changes require explicit approval"
  printf ',\n    '; oh_json_string "bulk memory promotion stays dry-run first"
  printf ',\n    '; oh_json_string "self-evolution applies only after tests pass"
  printf '\n  ]\n}\n'
}

autonomy_status() {
  if [[ "${1:-}" == "--json" ]]; then
    autonomy_status_json
    return 0
  fi
  printf '# oh-hermes Autonomy Status\n\n'
  printf -- '- Generated: `%s`\n' "$(date -Is)"
  printf -- '- Mode: `guarded-autonomy`\n'
  printf -- '- Dirty tracked files: `%s`\n' "$(autonomy_dirty_files)"
  printf -- '- God-mode timer: `%s`\n' "$(autonomy_timer_state oh-hermes-god-mode.timer)"
  printf -- '- Auto-improve timer: `%s`\n' "$(autonomy_timer_state oh-hermes-auto-improve.timer)"
  printf -- '- Secretary timer: `%s`\n' "$(autonomy_timer_state oh-hermes-secretary.timer)"
  local latest
  latest="$(autonomy_latest_report)"
  [[ -n "$latest" ]] && printf -- '- Latest autonomy report: `%s`\n' "$latest"
  return 0
}

autonomy_plan() {
  printf '# oh-hermes Autonomy Plan\n\n'
  printf -- '- Generated: `%s`\n\n' "$(date -Is)"
  printf '## Run Order\n\n'
  printf '1. `oh-hermes command-center --json` for current control-plane state.\n'
  printf '2. `oh-hermes linux doctor --json` for compatibility drift.\n'
  printf '3. `oh-hermes desktop doctor --json` for desktop/runtime drift.\n'
  printf '4. `oh-hermes memory digest` to summarize durable learning state.\n'
  printf '5. `oh-hermes secretary next --json` to choose one safe work item.\n'
  printf '6. `oh-hermes auto-improve --dry-run` for setup proposals.\n'
  printf '7. `oh-hermes test` before any tracked change is considered done.\n'
  printf '8. `oh-hermes publish-ready --json` before publishing or pushing.\n\n'
  printf '## Boundaries\n\n'
  printf -- '- Run dry first.\n'
  printf -- '- Keep private state under `~/.oh-hermes`.\n'
  printf -- '- Keep external sends, purchases, account changes, and destructive actions approval-gated.\n'
}

autonomy_run_dry() {
  local report
  report="$OH_REPORT_DIR/autonomy-dry-run-$(ts).md"
  {
    printf '# oh-hermes Autonomy Dry Run\n\n'
    printf -- '- Generated: `%s`\n\n' "$(date -Is)"
    printf '## Status\n\n```json\n'
    autonomy_status_json
    printf '```\n\n## Command Center\n\n```json\n'
    OH_HERMES_PUBLISH_READY_FAST=1 command_center_json
    printf '```\n\n## Verification\n\n```text\n'
    "$OH_ROOT/bin/oh-hermes" test
    printf '\n```\n\n## Publish Readiness\n\n```json\n'
    OH_HERMES_PUBLISH_READY_FAST=1 publish_ready_json
    printf '```\n\n## Result\n\n'
    printf 'Dry run inspected state and ran local tests. It did not apply tracked-file edits, start external actions, or promote memory candidates.\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

autonomy_run() {
  local dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      *) die "Unknown autonomy run option: $1" ;;
    esac
  done
  [[ "$dry" == "1" ]] || die "Use --dry-run for autonomy run; full autonomy is intentionally routed through god-mode policy"
  autonomy_run_dry
}

autonomy_cmd() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    status) autonomy_status "$@" ;;
    plan) autonomy_plan "$@" ;;
    run) autonomy_run "$@" ;;
    *) die "Unknown autonomy command: $sub" ;;
  esac
}
