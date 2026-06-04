#!/usr/bin/env bash

install_self_evolution() {
  need git
  need uv
  local dir py
  dir="$OH_VENDOR_DIR/hermes-agent-self-evolution"
  py="$HOME/.hermes/hermes-agent/venv/bin/python"
  [[ -x "$py" ]] || py="$(command -v python3)"

  info "Installing Hermes self-evolution lab at $dir"
  if [[ -d "$dir/.git" ]]; then
    remove_self_evolution_patches "$dir"
    run git -C "$dir" pull --ff-only
  else
    run git clone https://github.com/NousResearch/hermes-agent-self-evolution.git "$dir"
  fi
  if [[ ! -x "$dir/.venv/bin/python" ]]; then
    run uv venv --python "$py" "$dir/.venv"
  fi
  run uv pip install --python "$dir/.venv/bin/python" -e "$dir[dev]"
  run uv pip install --python "$dir/.venv/bin/python" optuna
  apply_self_evolution_patches "$dir"
}

remove_self_evolution_patches() {
  local dir="$1"
  local patch="$OH_ROOT/patches/hermes-agent-self-evolution/max-tokens.patch"
  [[ -f "$patch" ]] || return 0
  if git -C "$dir" apply --reverse --check "$patch" >/dev/null 2>&1; then
    run git -C "$dir" apply --reverse "$patch"
  fi
}

apply_self_evolution_patches() {
  local dir="$1"
  local patch="$OH_ROOT/patches/hermes-agent-self-evolution/max-tokens.patch"
  [[ -f "$patch" ]] || return 0
  if git -C "$dir" apply --check "$patch" >/dev/null 2>&1; then
    run git -C "$dir" apply "$patch"
  elif git -C "$dir" apply --reverse --check "$patch" >/dev/null 2>&1; then
    info "Self-evolution max-token patch already applied"
  else
    warn "Self-evolution max-token patch does not apply cleanly; inspect $patch"
  fi
}

status_self_evolution() {
  if [[ -x "$OH_VENDOR_DIR/hermes-agent-self-evolution/.venv/bin/python" ]]; then
    printf 'installed\n'
  else
    printf 'missing\n'
  fi
}
