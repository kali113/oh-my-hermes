#!/usr/bin/env bash

install_aionui() {
  need curl
  local dir="$OH_VENDOR_DIR/aionui"
  local url="https://github.com/iOfficeAI/AionUi/releases/latest/download/aionui-web-2.1.10-linux-x86_64.tar.gz"
  info "Downloading AionUi Web release to $dir"
  run mkdir -p "$dir"
  if [[ "$OH_DRY_RUN" == "1" ]]; then
    printf '[dry-run] download %s\n' "$url"
    return 0
  fi
  curl -fsSL "$url" | tar -xz -C "$dir" --strip-components=1
}

status_aionui() {
  [[ -d "$OH_VENDOR_DIR/aionui" && -n "$(find "$OH_VENDOR_DIR/aionui" -maxdepth 1 -type f 2>/dev/null | head -1)" ]] && printf 'installed\n' || printf 'missing\n'
}

