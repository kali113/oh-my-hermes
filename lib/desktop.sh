#!/usr/bin/env bash

desktop_latest_log() {
  local dir
  for dir in "$HOME/.hermes" "$OH_LOG_DIR"; do
    [[ -d "$dir" ]] || continue
    find "$dir" -type f \( -name '*desktop*.log' -o -name '*gui*.log' \) 2>/dev/null
  done | sort | tail -n 1
  return 0
}

desktop_status_json() {
  local hermes_available desktop_available version latest_log cwd
  cwd="$OH_ROOT"
  if have hermes; then hermes_available=1; else hermes_available=0; fi
  if have hermes && hermes desktop --help >/dev/null 2>&1; then desktop_available=1; else desktop_available=0; fi
  version="$(hermes version 2>/dev/null | head -n 1 || true)"
  latest_log="$(desktop_latest_log)"
  printf '{\n'
  printf '  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "official_command": %s,\n' "$desktop_available"
  printf '  "hermes_available": %s,\n' "$hermes_available"
  printf '  "hermes_version": '; oh_json_string "${version:-unknown}"
  printf ',\n  "default_cwd": '; oh_json_string "$cwd"
  printf ',\n  "latest_log": '; oh_json_string "$latest_log"
  printf ',\n  "legacy_source_enabled": %s,\n' "${OH_HERMES_DESKTOP_LEGACY_SOURCE:-0}"
  printf '  "source": '; oh_json_string "https://hermes-agent.nousresearch.com/docs/user-guide/desktop"
  printf '\n}\n'
}

desktop_status() {
  if [[ "${1:-}" == "--json" ]]; then
    desktop_status_json
    return 0
  fi
  printf '# oh-hermes Desktop Status\n\n'
  printf -- '- Generated: `%s`\n' "$(date -Is)"
  if have hermes; then
    printf -- '- Hermes: `%s`\n' "$(hermes version 2>/dev/null | head -n 1 || printf available)"
  else
    printf -- '- Hermes: `missing`\n'
  fi
  if have hermes && hermes desktop --help >/dev/null 2>&1; then
    printf -- '- Official desktop command: `available`\n'
    printf -- '- Launch: `oh-hermes desktop launch`\n'
    printf -- '- Build current OS app: `oh-hermes desktop build`\n'
  else
    printf -- '- Official desktop command: `missing`\n'
    printf -- '- Fix: `hermes update`, then rerun `oh-hermes desktop doctor`\n'
  fi
  printf -- '- Legacy third-party source: `%s`\n' "$([[ "${OH_HERMES_DESKTOP_LEGACY_SOURCE:-0}" == "1" ]] && printf enabled || printf disabled)"
  local latest_log
  latest_log="$(desktop_latest_log)"
  [[ -n "$latest_log" ]] && printf -- '- Latest desktop/gui log: `%s`\n' "$latest_log"
  return 0
}

desktop_doctor_json() {
  printf '{\n'
  printf '  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "desktop": '; desktop_status_json
  printf ',\n  "linux": '; linux_status_json
  printf ',\n  "notes": [\n'
  printf '    '; oh_json_string "Hermes Desktop is first-party; oh-hermes wraps hermes desktop instead of vendoring a fork."
  printf ',\n    '; oh_json_string "Linux desktop control through upstream computer-use is not assumed; this wrapper verifies app/runtime compatibility."
  printf '\n  ]\n}\n'
}

desktop_doctor() {
  if [[ "${1:-}" == "--json" ]]; then
    desktop_doctor_json
    return 0
  fi
  printf '# oh-hermes Desktop Doctor\n\n'
  desktop_status
  printf '\n## Linux Runtime\n\n'
  linux_status_human
  printf '\n## Notes\n\n'
  printf -- '- Hermes Desktop uses the same Hermes config, API keys, sessions, skills, and memory.\n'
  printf -- '- Official command path is preferred: `hermes desktop`.\n'
  printf -- '- Legacy `fathah/hermes-desktop` source remains opt-in with `OH_HERMES_DESKTOP_LEGACY_SOURCE=1`.\n'
}

desktop_launch() {
  need hermes
  local cwd="$OH_ROOT"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cwd) cwd="${2:-}"; [[ -n "$cwd" ]] || die "--cwd needs a value"; shift 2 ;;
      *) die "Unknown desktop launch option: $1" ;;
    esac
  done
  hermes desktop --cwd "$cwd"
}

desktop_build() {
  need hermes
  local cwd="$OH_ROOT"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cwd) cwd="${2:-}"; [[ -n "$cwd" ]] || die "--cwd needs a value"; shift 2 ;;
      *) die "Unknown desktop build option: $1" ;;
    esac
  done
  hermes desktop --build-only --cwd "$cwd"
}

desktop_cmd() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    status) desktop_status "$@" ;;
    doctor) desktop_doctor "$@" ;;
    launch) desktop_launch "$@" ;;
    build) desktop_build "$@" ;;
    *) die "Unknown desktop command: $sub" ;;
  esac
}
