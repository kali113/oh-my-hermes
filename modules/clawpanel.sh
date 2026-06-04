#!/usr/bin/env bash

install_clawpanel() {
  need git
  need npm
  local dir="$OH_VENDOR_DIR/clawpanel"
  warn "ClawPanel is AGPL-3.0 and OpenClaw-centered; installing as optional upstream source"
  if [[ -d "$dir/.git" ]]; then
    run git -C "$dir" pull --ff-only
  else
    run git clone https://github.com/qingchencloud/clawpanel.git "$dir"
  fi
  run npm --prefix "$dir" install
}

status_clawpanel() {
  [[ -d "$OH_VENDOR_DIR/clawpanel/.git" ]] && printf 'installed\n' || printf 'missing\n'
}

