#!/usr/bin/env bash

install_memos() {
  need git
  need npm
  local dir
  dir="$OH_VENDOR_DIR/MemOS"
  info "Installing MemOS Hermes local plugin"
  if [[ -d "$dir/.git" ]]; then
    run git -C "$dir" pull --ff-only
  else
    run git clone https://github.com/MemTensor/MemOS.git "$dir"
  fi
  run bash "$dir/apps/memos-local-plugin/install.sh" --agent hermes
}

status_memos() {
  if [[ -d "$HOME/.hermes/plugins/memos-local-plugin" || -d "$HOME/.hermes/memos-plugin" ]]; then
    printf 'installed\n'
  else
    printf 'missing\n'
  fi
}

