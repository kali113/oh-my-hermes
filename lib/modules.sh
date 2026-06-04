#!/usr/bin/env bash

module_script() {
  local name="$1"
  printf '%s/modules/%s.sh' "$OH_ROOT" "$name"
}

module_enable() {
  local name="$1"
  local script
  script="$(module_script "$name")"
  [[ -f "$script" ]] || die "Unknown module: $name"
  # shellcheck source=/dev/null
  source "$script"
  "install_${name//-/_}"
}

module_status_one() {
  local name="$1"
  local script
  script="$(module_script "$name")"
  [[ -f "$script" ]] || die "Unknown module: $name"
  # shellcheck source=/dev/null
  source "$script"
  "status_${name//-/_}"
}

module_list() {
  printf '%s\n' anysearch gbrain workspace memos self-evolution hermes-desktop hermes-web-ui aionui cc-switch clawpanel
}

module_status_all() {
  local name
  for name in $(module_list); do
    printf '%-18s ' "$name"
    if module_status_one "$name"; then
      true
    else
      printf 'unknown\n'
    fi
  done
}

install_default_modules() {
  module_enable anysearch
  module_enable gbrain
  module_enable workspace
  module_enable self-evolution
}

