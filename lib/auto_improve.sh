#!/usr/bin/env bash

auto_improve() {
  local dry="${1:-0}"
  local report="$OH_REPORT_DIR/auto-improve-$(ts).md"
  info "Writing auto-improvement report to $report"
  if [[ "$OH_DRY_RUN" == "1" ]]; then
    printf '[dry-run] create report %s\n' "$report"
    return 0
  fi
  {
    printf '# oh-hermes Auto-Improve Report\n\n'
    printf -- '- Generated: `%s`\n' "$(date -Is)"
    printf -- '- Mode: `%s`\n\n' "$([[ "$dry" == "1" ]] && printf dry-run || printf propose)"
    printf '## Hermes\n\n'
    hermes version 2>&1 | sed 's/^/- /' || true
    printf '\n## Status\n\n```text\n'
    hermes status 2>&1 || true
    printf '\n```\n\n## Prompt Size\n\n```text\n'
    hermes prompt-size 2>&1 || true
    printf '\n```\n\n## MCP\n\n```text\n'
    hermes mcp list 2>&1 || true
    printf '\n```\n\n## GBrain\n\n```text\n'
    if have gbrain; then
      timeout "${OH_HERMES_GBRAIN_DOCTOR_TIMEOUT:-30}" gbrain doctor --json 2>/dev/null | jq '.' 2>&1 \
        || timeout "${OH_HERMES_GBRAIN_DOCTOR_TIMEOUT:-30}" gbrain doctor 2>&1 \
        || printf 'gbrain doctor timed out or failed\n'
    else
      printf 'gbrain not installed\n'
    fi
    printf '\n```\n\n## Recommendations\n\n'
    printf -- '- Keep self-evolution output as proposals until reviewed.\n'
    printf -- '- Run `oh-hermes redact-check` before publishing.\n'
    printf -- '- Run `oh-hermes doctor` after enabling or updating modules.\n'
    printf -- '- Run `oh-hermes self-review` for a bounded Hermes-authored setup critique.\n'
    printf -- '- Run `oh-hermes evolve-skill oh-auto-improve --dry-run` before any GEPA optimization.\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

report_redact() {
  sed -E \
    -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[redacted-email]/g' \
    -e 's/(sk-[A-Za-z0-9_-]{4})[A-Za-z0-9_-]{12,}/\1...[redacted]/g' \
    -e 's/(sk-or-v1-[A-Za-z0-9_-]{4})[A-Za-z0-9_-]{12,}/\1...[redacted]/g' \
    -e 's/user_[A-Za-z0-9]{8,}/[redacted-user]/g' \
    -e 's/\b[0-9]{15,22}\b/[redacted-id]/g'
}

write_private_report() {
  local path="$1"
  local tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  report_redact < "$tmp" > "$path"
  rm -f "$tmp"
  chmod 600 "$path"
}

self_review() {
  need hermes
  need timeout
  local report="$OH_REPORT_DIR/self-review-$(ts).md"
  local prompt output
  prompt="$(cat <<'EOF'
Inspect the local oh-hermes repository at /home/arch/oh-hermes as your own Hermes setup.

Return a concise self-improvement report with:
1. Safe changes that can be applied automatically in the repo or local services.
2. Risky changes that must remain proposals.
3. Missing tests or observability.
4. Redaction/privacy risks.
5. One prioritized next action.

Do not include secrets, raw env values, raw tokens, private Discord IDs, or private memory content.
EOF
)"
  info "Asking Hermes to self-review this setup; writing $report"
  output="$(timeout --kill-after=10 "${OH_HERMES_SELF_REVIEW_TIMEOUT:-300}" hermes -z "$prompt" 2>&1 || true)"
  if [[ -z "${output//[[:space:]]/}" ]]; then
    output="Hermes self-review returned no text before the timeout. Run again with a larger OH_HERMES_SELF_REVIEW_TIMEOUT or inspect Hermes logs."
  fi
  {
    printf '# oh-hermes Hermes Self-Review\n\n'
    printf -- '- Generated: `%s`\n\n' "$(date -Is)"
    printf '```text\n'
    printf '%s\n' "$output"
    printf '\n```\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

evolve_skill() {
  need timeout
  local skill="${1:-}"
  shift || true
  [[ -n "$skill" ]] || die "Usage: oh-hermes evolve-skill <skill-name> [--dry-run|--run] [--iterations N] [--optimizer-model M] [--eval-model M]"

  local run=0 iterations=2 optimizer_model="${OH_HERMES_EVOLVE_OPTIMIZER_MODEL:-openrouter/openai/gpt-4.1}" eval_model="${OH_HERMES_EVOLVE_EVAL_MODEL:-openrouter/openai/gpt-4.1-mini}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) run=0; shift ;;
      --run) run=1; shift ;;
      --iterations) iterations="${2:-}"; [[ -n "$iterations" ]] || die "--iterations needs a value"; shift 2 ;;
      --optimizer-model) optimizer_model="${2:-}"; [[ -n "$optimizer_model" ]] || die "--optimizer-model needs a value"; shift 2 ;;
      --eval-model) eval_model="${2:-}"; [[ -n "$eval_model" ]] || die "--eval-model needs a value"; shift 2 ;;
      *) die "Unknown evolve-skill option: $1" ;;
    esac
  done

  local evo_dir="$OH_VENDOR_DIR/hermes-agent-self-evolution"
  local py="$evo_dir/.venv/bin/python"
  local env_path
  env_path="$(hermes config env-path 2>/dev/null || printf '%s/.hermes/.env' "$HOME")"
  [[ -x "$py" ]] || die "Self-evolution is not installed; run oh-hermes modules enable self-evolution"

  local report_dir="$OH_REPORT_DIR/evolution"
  local report="$report_dir/${skill}-$(ts).log"
  run mkdir -p "$report_dir"
  if [[ "$run" == "1" ]]; then
    info "Running self-evolution proposal for skill $skill; log: $report"
  else
    info "Validating self-evolution setup for skill $skill; log: $report"
  fi
  (
    if [[ -f "$env_path" ]]; then
      set -a
      # shellcheck source=/dev/null
      source "$env_path"
      set +a
    fi
    cd "$evo_dir"
    timeout --kill-after=10 "${OH_HERMES_EVOLVE_TIMEOUT:-900}" "$py" -m evolution.skills.evolve_skill \
      --skill "$skill" \
      --iterations "$iterations" \
      --eval-source synthetic \
      --optimizer-model "$optimizer_model" \
      --eval-model "$eval_model" \
      --hermes-repo "$OH_ROOT" \
      $([[ "$run" == "0" ]] && printf '%s' '--dry-run')
  ) 2>&1 | write_private_report "$report"
  printf '%s\n' "$report"
}

god_mode() {
  local install_timer=0 remove_timer=0 once=1 status=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --once) once=1; shift ;;
      --install-timer) install_timer=1; shift ;;
      --remove-timer) remove_timer=1; shift ;;
      --status) status=1; shift ;;
      *) die "Unknown god-mode option: $1" ;;
    esac
  done

  if [[ "$install_timer" == "1" ]]; then
    install_god_mode_timer
    return 0
  fi
  if [[ "$remove_timer" == "1" ]]; then
    remove_god_mode_timer
    return 0
  fi
  if [[ "$status" == "1" ]]; then
    systemctl --user status oh-hermes-god-mode.timer oh-hermes-god-mode.service --no-pager || true
    return 0
  fi
  if [[ "$once" == "1" ]]; then
    god_mode_once
  fi
}

god_mode_once() {
  need hermes
  need jq
  local report="$OH_REPORT_DIR/god-mode-$(ts).md"
  info "Running autonomous god-mode cycle; report: $report"
  {
    printf '# oh-hermes God-Mode Cycle\n\n'
    printf -- '- Generated: `%s`\n\n' "$(date -Is)"

    printf '## Preflight\n\n```text\n'
    backup_hermes || true
    apply_core_hermes_config || true
    printf '\n```\n\n## Services\n\n```text\n'
    god_mode_ensure_services || true
    printf '\n```\n\n## Health\n\n```text\n'
    god_mode_health || true
    printf '\n```\n\n## Reports\n\n```text\n'
    auto_improve 0 || true
    self_review || true
    printf '\n```\n\n## Skill Evolution\n\n```text\n'
    god_mode_evolve_skills || true
    printf '\n```\n\n## Verification\n\n```text\n'
    "$OH_ROOT/bin/oh-hermes" test || true
    if have gbrain; then timeout "${OH_HERMES_GBRAIN_DOCTOR_TIMEOUT:-30}" gbrain doctor --json --fast 2>/dev/null | jq -r '.status' || true; fi
    printf '\n```\n\n## Commit\n\n```text\n'
    god_mode_commit || true
    printf '\n```\n'
  } | write_private_report "$report"
  printf '%s\n' "$report"
}

god_mode_ensure_services() {
  module_enable anysearch
  module_enable gbrain
  module_enable workspace
  module_enable self-evolution
  if [[ "${OH_HERMES_GOD_ENABLE_MEMOS:-1}" == "1" ]]; then
    module_enable memos </dev/null >"$OH_LOG_DIR/memos-install.log" 2>&1 || cat "$OH_LOG_DIR/memos-install.log"
    install_memos_service || true
  fi
  # shellcheck source=../modules/workspace.sh
  source "$OH_ROOT/modules/workspace.sh"
  start_workspace --background
}

god_mode_service_active() {
  local service="$1"
  have systemctl && systemctl --user is-active --quiet "$service" 2>/dev/null
}

god_mode_systemd_unreachable() {
  local service="$1" output
  have systemctl || return 1
  output="$(systemctl --user is-active "$service" 2>&1 >/dev/null || true)"
  [[ "$output" == *"Operation not permitted"* || "$output" == *"Failed to connect to user scope bus"* ]]
}

god_mode_http_health() {
  local label="$1" service="$2" url="$3" health_timeout="${OH_HERMES_HEALTH_TIMEOUT:-20}"
  shift 3
  printf '%s=' "$label"
  if curl -fsS --max-time "$health_timeout" "$@" "$url" >/dev/null 2>&1; then
    printf 'ok\n'
  elif [[ -n "$service" ]] && god_mode_service_active "$service"; then
    printf 'running-unreachable\n'
  elif [[ -n "$service" ]] && god_mode_systemd_unreachable "$service"; then
    printf 'unknown-unreachable\n'
  else
    printf 'failed\n'
  fi
}

god_mode_health() {
  printf 'hermes_config='
  hermes config check >/dev/null && printf 'ok\n' || printf 'failed\n'
  god_mode_http_health workspace oh-hermes-workspace.service http://127.0.0.1:3000/
  god_mode_http_health dashboard oh-hermes-dashboard.service http://127.0.0.1:9119/
  god_mode_http_health memos oh-hermes-memos.service http://127.0.0.1:18800/
  printf 'api='
  local health_timeout="${OH_HERMES_HEALTH_TIMEOUT:-20}" key
  key="$(awk -F= '/^API_SERVER_KEY=/ {print substr($0, index($0,"=")+1); exit}' "$(hermes config env-path)" 2>/dev/null || true)"
  if [[ -n "$key" ]]; then
    if curl -fsS --max-time "$health_timeout" -H "Authorization: Bearer $key" http://127.0.0.1:8642/health >/dev/null 2>&1; then
      printf 'ok\n'
    elif god_mode_service_active oh-hermes-workspace.service || god_mode_service_active oh-hermes-dashboard.service; then
      printf 'unknown-unreachable\n'
    elif god_mode_systemd_unreachable oh-hermes-workspace.service || god_mode_systemd_unreachable oh-hermes-dashboard.service; then
      printf 'unknown-unreachable\n'
    else
      printf 'failed\n'
    fi
  else
    printf 'missing-key\n'
  fi
}

god_mode_evolve_skills() {
  local skill path before latest metrics improved evolved backup
  for path in "$OH_ROOT"/skills/*/SKILL.md; do
    skill="$(basename "$(dirname "$path")")"
    [[ -n "$skill" ]] || continue
    printf 'evolving %s\n' "$skill"
    HERMES_EVOLUTION_MAX_TOKENS="${HERMES_EVOLUTION_MAX_TOKENS:-2048}" \
      OH_HERMES_EVOLVE_TIMEOUT="${OH_HERMES_EVOLVE_TIMEOUT:-300}" \
      evolve_skill "$skill" --run --iterations "${OH_HERMES_GOD_EVOLVE_ITERATIONS:-1}" || true
    latest="$(find "$OH_VENDOR_DIR/hermes-agent-self-evolution/output/$skill" -maxdepth 2 -name metrics.json -type f 2>/dev/null | sort | tail -n 1 || true)"
    [[ -n "$latest" ]] || continue
    metrics="$(dirname "$latest")"
    evolved="$metrics/evolved_skill.md"
    [[ -f "$evolved" ]] || continue
    improved="$(jq -r '(.constraints_passed == true) and (.improvement > 0)' "$latest" 2>/dev/null || printf false)"
    if [[ "$improved" == "true" ]] && ! cmp -s "$path" "$evolved"; then
      backup="$OH_REPORT_DIR/evolution/${skill}-pre-apply-$(ts).md"
      cp "$path" "$backup"
      cp "$evolved" "$path"
      if "$OH_ROOT/bin/oh-hermes" test >/dev/null 2>&1; then
        printf 'applied evolved skill %s from %s\n' "$skill" "$metrics"
      else
        cp "$backup" "$path"
        printf 'reverted evolved skill %s because tests failed\n' "$skill"
      fi
    else
      printf 'kept %s unchanged (no positive diff to apply)\n' "$skill"
    fi
  done
}

god_mode_commit() {
  [[ "${OH_HERMES_GOD_COMMIT:-1}" == "1" ]] || { printf 'auto-commit disabled\n'; return 0; }
  [[ -d "$OH_ROOT/.git" ]] || { printf 'not a git repo\n'; return 0; }
  if ! (redact_check "$OH_ROOT") >/dev/null; then
    printf 'redaction check blocked commit\n'
    return 0
  fi
  git -C "$OH_ROOT" add .
  if git -C "$OH_ROOT" diff --cached --quiet; then
    printf 'nothing to commit\n'
    return 0
  fi
  if ! git -C "$OH_ROOT" config user.email >/dev/null || ! git -C "$OH_ROOT" config user.name >/dev/null; then
    git -C "$OH_ROOT" config user.email "oh-hermes@localhost"
    git -C "$OH_ROOT" config user.name "oh-hermes"
  fi
  git -C "$OH_ROOT" commit -m "oh-hermes autonomous improvement cycle"
}

install_god_mode_timer() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  info "Installing oh-hermes god-mode timer"
  run mkdir -p "$user_dir"
  if [[ -f "$OH_ROOT/systemd/user/oh-hermes-memos.service" ]]; then
    install_memos_service || true
  fi
  run cp "$OH_ROOT/systemd/user/oh-hermes-god-mode.service" "$user_dir/"
  run cp "$OH_ROOT/systemd/user/oh-hermes-god-mode.timer" "$user_dir/"
  run systemctl --user daemon-reload
  run systemctl --user enable --now oh-hermes-god-mode.timer
}

remove_god_mode_timer() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  info "Removing oh-hermes god-mode timer"
  run systemctl --user disable --now oh-hermes-god-mode.timer || true
  run rm -f "$user_dir/oh-hermes-god-mode.service" "$user_dir/oh-hermes-god-mode.timer"
  run systemctl --user daemon-reload
}

install_memos_service() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  [[ -d "$HOME/.hermes/memos-plugin" ]] || return 0
  run mkdir -p "$user_dir"
  run cp "$OH_ROOT/systemd/user/oh-hermes-memos.service" "$user_dir/"
  run systemctl --user daemon-reload
  run systemctl --user enable --now oh-hermes-memos.service
}

install_auto_improve_timer() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  info "Installing weekly oh-hermes auto-improvement timer"
  run mkdir -p "$user_dir"
  run cp "$OH_ROOT/systemd/user/oh-hermes-auto-improve.service" "$user_dir/"
  run cp "$OH_ROOT/systemd/user/oh-hermes-auto-improve.timer" "$user_dir/"
  run systemctl --user daemon-reload
  run systemctl --user enable --now oh-hermes-auto-improve.timer
  info "Timer installed. Reports will be written to $OH_REPORT_DIR"
}

remove_auto_improve_timer() {
  need systemctl
  local user_dir="$HOME/.config/systemd/user"
  info "Removing weekly oh-hermes auto-improvement timer"
  run systemctl --user disable --now oh-hermes-auto-improve.timer || true
  run rm -f "$user_dir/oh-hermes-auto-improve.service" "$user_dir/oh-hermes-auto-improve.timer"
  run systemctl --user daemon-reload
}
