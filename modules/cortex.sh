#!/usr/bin/env bash

# Cortex adapter module for oh-hermes.
# Cortex is an optional external worker behind the generic worker interface.
# No cortex dependency is required for core oh-hermes tests.
#
# Target Cortex interface (Cortex Headless Workflow Runner):
#   cortex workflow run --preset code|research|review --workdir DIR --goal "..." --output json
#   cortex workflow status --id WORKFLOW_ID --json
#   cortex workflow resume --id WORKFLOW_ID
#   cortex workflow export --id WORKFLOW_ID --format markdown
#
# Until cortex exposes that CLI surface, this module detects the binary,
# reports availability, and provides install/build guidance. The delegate
# and run paths are wired so they work as soon as cortex grows the
# workflow subcommand.

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

# --- status ------------------------------------------------------------

cortex_status_json() {
  local generated bin version available workflow_available install_guide
  generated="$(date -Is)"
  bin="$(cortex_binary_path)"
  version="$(cortex_version)"
  available=false
  workflow_available=false
  install_guide=""

  if [[ -n "$bin" ]]; then
    available=true
    if cortex_has_workflow_cmd; then
      workflow_available=true
    else
      install_guide="cortex binary found but 'cortex workflow' subcommand is not available. Upgrade to a version that supports the headless workflow runner (cortex workflow run --preset ... --output json). See https://github.com/Mateooo93/cortex-cli"
    fi
  else
    install_guide="cortex is not installed. Install via: pip install cortex-cli  (or follow https://github.com/Mateooo93/cortex-cli README for latest instructions). Then verify with: cortex --version"
  fi

  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "available": %s' "$available"
  printf ',\n  "binary": '; oh_json_string "${bin:-null}"
  printf ',\n  "version": '; oh_json_string "${version:-null}"
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

# Map oh-hermes worker modes to cortex workflow presets.
# plan    -> cortex workflow run --preset plan
# research -> cortex workflow run --preset research
# review  -> cortex workflow run --preset review
cortex_preset_for_mode() {
  local mode="$1"
  case "$mode" in
    plan)     printf 'plan' ;;
    research) printf 'research' ;;
    review)   printf 'review' ;;
    workflow) printf 'code' ;;   # generic workflow -> code preset
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

# --- workflow execution ------------------------------------------------

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
      *) shift ;;
    esac
  done

  [[ -n "$mode" ]] || die "--mode is required (plan, research, review)"

  # Check cortex availability
  local bin available
  bin="$(cortex_binary_path)"
  [[ -n "$bin" ]] || {
    if [[ "$output_json" == "1" ]]; then
      printf '{"available":false,"error":"cortex_not_installed","install_guide":"https://github.com/Mateooo93/cortex-cli"}\n'
    else
      die "cortex is not installed. See: https://github.com/Mateooo93/cortex-cli"
    fi
    return 1
  }

  local preset
  preset="$(cortex_preset_for_mode "$mode")"

  # Resolve workdir
  if [[ -z "$workdir" ]]; then
    workdir="$(cortex_worktree_ensure "$card_id")"
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
    printf '{\n'
    printf '  "run": false,\n'
    printf '  "reason": "dry_run",\n'
    printf '  "session_id": '; oh_json_string "$session_id"
    printf ',\n  "command": "cortex workflow run --preset %s --workdir %s --goal ... --output json --save %s/cortex-workflow.json"' "$preset" "$workdir" "$run_dir"
    printf ',\n  "preset": '; oh_json_string "$preset"
    printf ',\n  "workdir": '; oh_json_string "$workdir"
    printf ',\n  "goal": '; oh_json_string "$goal"
    printf '\n}\n'
    return 0
  fi

  # Check for workflow subcommand
  if ! cortex_has_workflow_cmd; then
    if [[ "$output_json" == "1" ]]; then
      printf '{"available":true,"workflow_cmd_available":false,"error":"cortex workflow subcommand not available. Upgrade cortex."}\n'
    else
      warn "cortex workflow subcommand not available; running in legacy mode with 'cortex --help' to verify binary"
    fi
    return 1
  fi

  # Execute cortex workflow
  local start_ts end_ts elapsed exit_code
  local stdout_file="$run_dir/stdout.txt"
  local stderr_file="$run_dir/stderr.txt"
  local result_file="$run_dir/cortex-workflow.json"

  start_ts="$(date +%s)"
  run "$bin" workflow run \
    --preset "$preset" \
    --workdir "$workdir" \
    --goal "$goal" \
    --output json \
    --save "$result_file" \
    > "$stdout_file" 2> "$stderr_file"
  exit_code=$?
  end_ts="$(date +%s)"
  elapsed=$((end_ts - start_ts))

  # Build result summary
  local summary status
  if [[ "$exit_code" == "0" ]]; then
    status="completed"
    summary="cortex workflow $preset completed in ${elapsed}s"
  else
    status="failed"
    summary="cortex workflow $preset failed with exit code $exit_code after ${elapsed}s"
  fi

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
      *) shift ;;
    esac
  done
  cortex_workflow_run --mode plan --card "$card_id" ${dry:+--dry-run} --json
}

cortex_research() {
  local card_id="" dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card) card_id="${2:-}"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) shift ;;
    esac
  done
  cortex_workflow_run --mode research --card "$card_id" ${dry:+--dry-run} --json
}

cortex_review() {
  local card_id="" dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card) card_id="${2:-}"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) shift ;;
    esac
  done
  cortex_workflow_run --mode review --card "$card_id" ${dry:+--dry-run} --json
}

# --- install (module contract) -----------------------------------------

install_cortex() {
  need git
  info "Cortex is an optional worker; it is never vendored into oh-my-hermes."
  if have cortex; then
    info "cortex found at $(cortex_binary_path) — $(cortex_version)"
  else
    info "cortex is not installed."
    info "Install via: pip install cortex-cli"
    info "Or follow: https://github.com/Mateooo93/cortex-cli"
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
