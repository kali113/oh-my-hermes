#!/usr/bin/env bash

install_hermes_web_ui() {
  need git
  need pnpm
  local dir="$OH_VENDOR_DIR/hermes-web-ui"
  warn "Hermes Web UI is BSL/non-commercial; installing from upstream, not vendoring into oh-hermes"
  if [[ -d "$dir/.git" ]]; then
    run git -C "$dir" pull --ff-only
  else
    run git clone https://github.com/EKKOLearnAI/hermes-web-ui.git "$dir"
  fi
  run pnpm --dir "$dir" install --silent
}

status_hermes_web_ui() {
  [[ -d "$OH_VENDOR_DIR/hermes-web-ui/.git" ]] && printf 'installed\n' || printf 'missing\n'
}

