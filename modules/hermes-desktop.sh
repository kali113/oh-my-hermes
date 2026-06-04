#!/usr/bin/env bash

install_hermes_desktop() {
  need git
  need npm
  local dir="$OH_VENDOR_DIR/hermes-desktop"
  if [[ -d "$dir/.git" ]]; then
    run git -C "$dir" pull --ff-only
  else
    run git clone https://github.com/fathah/hermes-desktop.git "$dir"
  fi
  run npm --prefix "$dir" install
}

status_hermes_desktop() {
  [[ -d "$OH_VENDOR_DIR/hermes-desktop/.git" ]] && printf 'installed\n' || printf 'missing\n'
}

