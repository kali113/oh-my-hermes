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
  printf '%s\n' anysearch gbrain workspace memos self-evolution hermes-desktop hermes-web-ui aionui cc-switch clawpanel cortex
}

module_source_url() {
  case "$1" in
    anysearch) printf 'https://github.com/anysearch-ai/anysearch-skill\n' ;;
    gbrain) printf 'https://github.com/garrytan/gbrain\n' ;;
    workspace) printf 'https://github.com/outsourc-e/hermes-workspace\n' ;;
    memos) printf 'https://github.com/MemTensor/MemOS\n' ;;
    self-evolution) printf 'https://github.com/NousResearch/hermes-agent-self-evolution\n' ;;
    hermes-desktop) printf 'https://hermes-agent.nousresearch.com/docs/user-guide/desktop\n' ;;
    hermes-web-ui) printf 'https://github.com/EKKOLearnAI/hermes-web-ui\n' ;;
    aionui) printf 'https://github.com/iOfficeAI/AionUi\n' ;;
    cc-switch) printf 'https://github.com/farion1231/cc-switch\n' ;;
    clawpanel) printf 'https://github.com/qingchencloud/clawpanel\n' ;;
    cortex) printf 'https://github.com/Mateooo93/cortex-cli\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

module_tier() {
  case "$1" in
    anysearch|gbrain|workspace|self-evolution) printf 'default\n' ;;
    memos) printf 'recommended\n' ;;
    cortex) printf 'worker\n' ;;
    *) printf 'optional\n' ;;
  esac
}

module_role() {
  case "$1" in
    anysearch) printf 'current-search skill\n' ;;
    gbrain) printf 'durable brain MCP\n' ;;
    workspace) printf 'visual cockpit\n' ;;
    memos) printf 'local memory viewer\n' ;;
    self-evolution) printf 'guarded skill evolution lab\n' ;;
    hermes-desktop) printf 'official desktop app command\n' ;;
    hermes-web-ui) printf 'alternate web UI source\n' ;;
    aionui) printf 'alternate agent UI release\n' ;;
    cc-switch) printf 'Claude Code profile switcher source\n' ;;
    clawpanel) printf 'OpenClaw panel source\n' ;;
    cortex) printf 'optional Cortex worker adapter\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

module_status_value() {
  local name="$1" value
  value="$(module_status_one "$name" 2>&1 || printf 'unknown')"
  printf '%s\n' "$value" | tr '\n' ' ' | sed -E 's/[[:space:]]+$//'
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

module_status_json() {
  local name first=1
  printf '{\n  "generated": '
  oh_json_string "$(date -Is)"
  printf ',\n  "modules": ['
  for name in $(module_list); do
    [[ "$first" == "1" ]] || printf ','
    printf '\n    {\n      "name": '
    oh_json_string "$name"
    printf ',\n      "tier": '
    oh_json_string "$(module_tier "$name")"
    printf ',\n      "role": '
    oh_json_string "$(module_role "$name")"
    printf ',\n      "source": '
    oh_json_string "$(module_source_url "$name")"
    printf ',\n      "status": '
    oh_json_string "$(module_status_value "$name")"
    printf '\n    }'
    first=0
  done
  printf '\n  ]\n}\n'
}

install_default_modules() {
  module_enable anysearch
  module_enable gbrain
  module_enable workspace
  module_enable self-evolution
}
