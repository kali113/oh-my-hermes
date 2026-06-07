#!/usr/bin/env bash

# Cortex adapter module for oh-hermes.
# Cortex is an optional external worker behind the generic worker interface.
# No cortex dependency is required for core oh-hermes tests.
#
# Current Cortex headless interface:
#   cortex --workdir DIR -p "prompt"
#
# Cortex has internal workflow/swarm concepts, but the public CLI currently
# exposes one-shot headless prompts. This adapter targets that stable surface
# and keeps workflow fields as future capability detection.

CORTEX_STATE_DIR="$OH_STATE_DIR/cortex"
CORTEX_WORKTREE_ROOT="$OH_STATE_DIR/worktrees"
mkdir -p "$CORTEX_STATE_DIR" "$CORTEX_WORKTREE_ROOT"

# --- detection ---------------------------------------------------------

cortex_binary_path() {
  command -v cortex 2>/dev/null || true
}

cortex_version() {
  local bin
  bin="$(cortex_binary_path)"
  if [[ -n "$bin" ]]; then
    "$bin" --version 2>/dev/null | head -n 1 || printf 'unknown'
  else
    printf ''
  fi
}

cortex_has_workflow_cmd() {
  local bin
  bin="$(cortex_binary_path)"
  if [[ -n "$bin" ]]; then
    "$bin" workflow --help >/dev/null 2>&1 && return 0 || return 1
  fi
  return 1
}

cortex_has_headless_cmd() {
  local bin
  bin="$(cortex_binary_path)"
  if [[ -n "$bin" ]]; then
    "$bin" --help 2>/dev/null | grep -Eq '(^|[[:space:]])-p([[:space:],=]|$)|Run a single prompt|headless' && return 0
  fi
  return 1
}

# --- status ------------------------------------------------------------

cortex_status_json() {
  local generated bin version available workflow_available headless_available install_guide
  generated="$(date -Is)"
  bin="$(cortex_binary_path)"
  version="$(cortex_version)"
  available=false
  workflow_available=false
  headless_available=false
  install_guide=""

  if [[ -n "$bin" ]]; then
    available=true
    if cortex_has_headless_cmd; then
      headless_available=true
    else
      install_guide="cortex binary found, but the documented -p headless prompt flag was not detected. Upgrade from https://github.com/Mateooo93/cortex-cli/releases or rebuild from source."
    fi
    if cortex_has_workflow_cmd; then
      workflow_available=true
    fi
  else
    install_guide="cortex is not installed. Install the latest Linux binary from https://github.com/Mateooo93/cortex-cli/releases or build from source with Go, then verify with: cortex --version"
  fi

  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "available": %s' "$available"
  printf ',\n  "binary": '
  if [[ -n "$bin" ]]; then oh_json_string "$bin"; else printf 'null'; fi
  printf ',\n  "version": '
  if [[ -n "$version" ]]; then oh_json_string "$version"; else printf 'null'; fi
  printf ',\n  "headless_cmd_available": %s' "$headless_available"
  printf ',\n  "workflow_cmd_available": %s' "$workflow_available"
  printf ',\n  "supported_modes": ["plan", "research", "review"]'
  printf ',\n  "disabled_modes": ["implement"]'
  printf ',\n  "homepage": "https://github.com/Mateooo93/cortex-cli"'
  printf ',\n  "install_guide": '; oh_json_string "$install_guide"
  printf '\n}\n'
}

cortex_install_check_json() {
  cortex_status_json
}

# --- preset mapping ----------------------------------------------------

# Map oh-hermes worker modes to prompt instructions.
cortex_preset_for_mode() {
  local mode="$1"
  case "$mode" in
    plan)     printf 'plan' ;;
    research) printf 'research' ;;
    review)   printf 'review' ;;
    workflow) printf 'code' ;;
    *)        printf '%s' "$mode" ;;
  esac
}

# --- worktree management -----------------------------------------------

cortex_worktree_ensure() {
  local card_id="$1"
  local worktree_name worktree_path

  worktree_name="cortex-${card_id:-session}-$(date +%s)"
  worktree_path="$CORTEX_WORKTREE_ROOT/$worktree_name"

  if [[ -d "$OH_ROOT/.git" ]]; then
    if [[ "$OH_DRY_RUN" == "1" ]]; then
      printf '[dry-run] git worktree add --detach %s\n' "$worktree_path"
      printf '%s' "$worktree_path"
      return 0
    fi
    run git -C "$OH_ROOT" worktree add --detach "$worktree_path" HEAD 2>/dev/null || {
      warn "Could not create git worktree at $worktree_path; using temp dir"
      run mkdir -p "$worktree_path"
    }
  else
    run mkdir -p "$worktree_path"
  fi

  printf '%s' "$worktree_path"
}

cortex_worktree_cleanup() {
  local worktree_path="$1"
  if [[ -d "$worktree_path/.git" ]] || git -C "$OH_ROOT" worktree list 2>/dev/null | grep -q "$worktree_path"; then
    run git -C "$OH_ROOT" worktree remove --force "$worktree_path" 2>/dev/null || true
  fi
  run rm -rf "$worktree_path" 2>/dev/null || true
}

# --- prompt execution --------------------------------------------------

cortex_prompt_for_mode() {
  local mode="$1" goal="$2"
  case "$mode" in
    plan)
      printf 'You are acting as a planning-only Cortex worker for oh-my-hermes. Produce an implementation plan only. Do not edit files. Task context:\n\n%s\n' "$goal"
      ;;
    research)
      printf 'You are acting as a research-only Cortex worker for oh-my-hermes. Inspect the task context and produce concise findings, relevant files, risks, and recommendations. Do not edit files. Task context:\n\n%s\n' "$goal"
      ;;
    review)
      printf 'You are acting as a review-only Cortex worker for oh-my-hermes. Review the task context for correctness, risks, missing tests, and next actions. Do not edit files. Task context:\n\n%s\n' "$goal"
      ;;
    *)
      printf 'Execute %s for this oh-my-hermes task without applying changes unless explicitly instructed:\n\n%s\n' "$mode" "$goal"
      ;;
  esac
}

cortex_workflow_run() {
  local mode="" card_id="" goal="" workdir="" dry=0 output_json=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode) mode="${2:-}"; shift 2 ;;
      --card) card_id="${2:-}"; shift 2 ;;
      --goal) goal="${2:-}"; shift 2 ;;
      --workdir) workdir="${2:-}"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      --json) output_json=1; shift ;;
      *) die "Unknown cortex workflow option: $1" ;;
    esac
  done

  [[ -n "$mode" ]] || die "--mode is required (plan, research, review)"

  local preset
  preset="$(cortex_preset_for_mode "$mode")"

  # Resolve workdir
  if [[ -z "$workdir" ]]; then
    if [[ "$dry" == "1" ]]; then
      workdir="$CORTEX_WORKTREE_ROOT/cortex-${card_id:-session}-dry-run"
    else
      workdir="$(cortex_worktree_ensure "$card_id")"
    fi
  fi

  # Build the goal from card context if available
  if [[ -z "$goal" && -n "$card_id" ]]; then
    goal="$(hermes kanban context "$card_id" 2>/dev/null | head -c 2000 || true)"
    [[ -z "$goal" ]] && goal="$(hermes kanban show "$card_id" 2>/dev/null | head -c 2000 || true)"
  fi
  [[ -z "$goal" ]] && goal="Execute $mode for card $card_id"

  local run_dir session_id
  session_id="cortex-$(ts)-$$"
  run_dir="$CORTEX_STATE_DIR/runs/$session_id"
  run mkdir -p "$run_dir"

  if [[ "$dry" == "1" ]]; then
    local prompt
    prompt="$(cortex_prompt_for_mode "$mode" "$goal")"
    printf '{\n'
    printf '  "run": false,\n'
    printf '  "reason": "dry_run",\n'
    printf '  "session_id": '; oh_json_string "$session_id"
    printf ',\n  "command": '; oh_json_string "cortex --workdir $workdir -p <prompt>"
    printf ',\n  "preset": '; oh_json_string "$preset"
    printf ',\n  "workdir": '; oh_json_string "$workdir"
    printf ',\n  "goal": '; oh_json_string "$goal"
    printf ',\n  "prompt_preview": '; oh_json_string "$(printf '%s' "$prompt" | head -c 500)"
    printf '\n}\n'
    return 0
  fi

  # Check cortex availability after dry-run rendering so users can inspect
  # the intended command before installing the optional worker.
  local bin
  bin="$(cortex_binary_path)"
  [[ -n "$bin" ]] || {
    if [[ "$output_json" == "1" ]]; then
      printf '{"available":false,"error":"cortex_not_installed","install_guide":"Install the latest Linux binary from https://github.com/Mateooo93/cortex-cli/releases or build from source with Go."}\n'
    else
      die "cortex is not installed. See: https://github.com/Mateooo93/cortex-cli"
    fi
    return 1
  }

  if ! cortex_has_headless_cmd; then
    if [[ "$output_json" == "1" ]]; then
      printf '{"available":true,"headless_cmd_available":false,"error":"cortex -p headless prompt flag not available. Upgrade cortex."}\n'
    else
      warn "cortex -p headless prompt flag is not available; upgrade cortex"
    fi
    return 1
  fi

  # Execute cortex one-shot headless prompt.
  local start_ts end_ts elapsed exit_code
  local stdout_file="$run_dir/stdout.txt"
  local stderr_file="$run_dir/stderr.txt"
  local result_file="$run_dir/cortex-result.json"
  local prompt
  prompt="$(cortex_prompt_for_mode "$mode" "$goal")"

  start_ts="$(date +%s)"
  set +e
  "$bin" --workdir "$workdir" -p "$prompt" > "$stdout_file" 2> "$stderr_file"
  exit_code=$?
  set -e
  end_ts="$(date +%s)"
  elapsed=$((end_ts - start_ts))

  # Build result summary
  local summary status
  if [[ "$exit_code" == "0" ]]; then
    status="completed"
    summary="cortex $preset prompt completed in ${elapsed}s"
  else
    status="failed"
    summary="cortex $preset prompt failed with exit code $exit_code after ${elapsed}s"
  fi

  python3 - "$result_file" "$session_id" "$status" "$exit_code" "$elapsed" "$preset" "$workdir" "$goal" "$stdout_file" "$stderr_file" "$summary" <<'PY'
import json
import sys

path, session_id, status, exit_code, elapsed, preset, workdir, goal, stdout_path, stderr_path, summary = sys.argv[1:12]
payload = {
    "session_id": session_id,
    "status": status,
    "exit_code": int(exit_code),
    "elapsed_seconds": int(elapsed),
    "preset": preset,
    "workdir": workdir,
    "goal": goal,
    "stdout_path": stdout_path,
    "stderr_path": stderr_path,
    "summary": summary,
}
json.dump(payload, open(path, "w"), indent=2)
PY

  printf '{\n'
  printf '  "session_id": '; oh_json_string "$session_id"
  printf ',\n  "status": '; oh_json_string "$status"
  printf ',\n  "exit_code": %s' "$exit_code"
  printf ',\n  "elapsed_seconds": %s' "$elapsed"
  printf ',\n  "preset": '; oh_json_string "$preset"
  printf ',\n  "workdir": '; oh_json_string "$workdir"
  printf ',\n  "goal": '; oh_json_string "$goal"
  printf ',\n  "stdout_path": '; oh_json_string "$stdout_file"
  printf ',\n  "stderr_path": '; oh_json_string "$stderr_file"
  printf ',\n  "result_path": '; oh_json_string "$result_file"
  printf ',\n  "summary": '; oh_json_string "$summary"
  printf '\n}\n'
}

# --- plan / research / review shortcuts --------------------------------

cortex_plan() {
  local card_id="" dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card) card_id="${2:-}"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) die "Unknown cortex plan option: $1" ;;
    esac
  done
  local args=(--mode plan --card "$card_id" --json)
  [[ "$dry" == "1" ]] && args+=(--dry-run)
  cortex_workflow_run "${args[@]}"
}

cortex_research() {
  local card_id="" dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card) card_id="${2:-}"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) die "Unknown cortex research option: $1" ;;
    esac
  done
  local args=(--mode research --card "$card_id" --json)
  [[ "$dry" == "1" ]] && args+=(--dry-run)
  cortex_workflow_run "${args[@]}"
}

cortex_review() {
  local card_id="" dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card) card_id="${2:-}"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) die "Unknown cortex review option: $1" ;;
    esac
  done
  local args=(--mode review --card "$card_id" --json)
  [[ "$dry" == "1" ]] && args+=(--dry-run)
  cortex_workflow_run "${args[@]}"
}

# --- install (module contract) -----------------------------------------

install_cortex() {
  need git
  info "Cortex is an optional worker; it is never vendored into oh-my-hermes."
  if have cortex; then
    info "cortex found at $(cortex_binary_path) — $(cortex_version)"
  else
    info "cortex is not installed."
    info "Install the latest Linux binary from https://github.com/Mateooo93/cortex-cli/releases"
    info "Or build from source with Go using the upstream README."
  fi
  info "Cortex state dir: $CORTEX_STATE_DIR"
}

status_cortex() {
  cortex_status_json
}

# --- command dispatch --------------------------------------------------

cortex_cmd() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    status) cortex_status_json "$@" ;;
    install-check) cortex_install_check_json "$@" ;;
    plan) cortex_plan "$@" ;;
    research) cortex_research "$@" ;;
    review) cortex_review "$@" ;;
    *) die "Unknown cortex command: $sub" ;;
  esac
}
