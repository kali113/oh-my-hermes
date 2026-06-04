#!/usr/bin/env bash

install_cc_switch() {
  if have yay; then
    warn "cc-switch is optional and may not exist in AUR on every sync; falling back to source clone if package lookup fails"
    if yay -Ss '^cc-switch-bin$' >/dev/null 2>&1; then
      run yay -S --needed cc-switch-bin
      return 0
    fi
  fi
  need git
  local dir="$OH_VENDOR_DIR/cc-switch"
  if [[ -d "$dir/.git" ]]; then
    run git -C "$dir" pull --ff-only
  else
    run git clone https://github.com/farion1231/cc-switch.git "$dir"
  fi
}

status_cc_switch() {
  if have cc-switch; then
    printf 'binary installed\n'
  elif [[ -d "$OH_VENDOR_DIR/cc-switch/.git" ]]; then
    printf 'source cloned\n'
  else
    printf 'missing\n'
  fi
}

