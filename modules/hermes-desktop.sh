#!/usr/bin/env bash

install_hermes_desktop() {
  need hermes
  if [[ "${OH_HERMES_DESKTOP_LEGACY_SOURCE:-0}" == "1" ]]; then
    need git
    need npm
    local dir="$OH_VENDOR_DIR/hermes-desktop-legacy"
    warn "Installing legacy third-party fathah/hermes-desktop source; official Hermes Desktop is preferred"
    if [[ -d "$dir/.git" ]]; then
      run git -C "$dir" pull --ff-only
    else
      run git clone https://github.com/fathah/hermes-desktop.git "$dir"
    fi
    run npm --prefix "$dir" install
    return 0
  fi
  info "Hermes Desktop is first-party now; launch it with: hermes desktop"
  info "Using existing Hermes config, keys, sessions, skills, and memory"
  if [[ "$OH_DRY_RUN" == "1" ]]; then
    printf '[dry-run] verify hermes desktop command\n'
    return 0
  fi
  if hermes desktop --help >/dev/null 2>&1; then
    printf 'Official Hermes Desktop command is available: hermes desktop\n'
  else
    warn "Current hermes binary did not expose 'hermes desktop --help'; run 'hermes update' if desktop support is missing"
  fi
}

status_hermes_desktop() {
  if have hermes && hermes desktop --help >/dev/null 2>&1; then
    printf 'official command available\n'
  elif [[ -d "$OH_VENDOR_DIR/hermes-desktop-legacy/.git" ]]; then
    printf 'legacy source cloned\n'
  elif [[ -d "$OH_VENDOR_DIR/hermes-desktop/.git" ]]; then
    printf 'legacy source cloned at old path\n'
  else
    printf 'official command missing; run hermes update\n'
  fi
}
