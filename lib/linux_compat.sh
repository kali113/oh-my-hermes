#!/usr/bin/env bash

linux_os_release_value() {
  local key="$1"
  if [[ -f /etc/os-release ]]; then
    awk -F= -v key="$key" '
      $1 == key {
        value = $2
        gsub(/^"/, "", value)
        gsub(/"$/, "", value)
        print value
        exit
      }
    ' /etc/os-release
  fi
}

linux_package_manager() {
  if have pacman; then printf 'pacman\n'
  elif have apt; then printf 'apt\n'
  elif have dnf; then printf 'dnf\n'
  elif have zypper; then printf 'zypper\n'
  elif have nix; then printf 'nix\n'
  elif have apk; then printf 'apk\n'
  else printf 'unknown\n'
  fi
}

linux_user_systemd_status() {
  if ! have systemctl; then
    printf 'missing\n'
  elif systemctl --user is-system-running >/dev/null 2>&1; then
    printf 'ok\n'
  else
    local output
    output="$(systemctl --user is-system-running 2>&1 || true)"
    case "$output" in
      *"Operation not permitted"*|*"Failed to connect"*|*"No medium found"*) printf 'unreachable\n' ;;
      degraded*) printf 'degraded\n' ;;
      *) printf 'available-with-warnings\n' ;;
    esac
  fi
}

linux_command_status() {
  have "$1" && printf 'available' || printf 'missing'
}

linux_runtime_status() {
  local name="$1"
  case "$name" in
    fuse) [[ -e /dev/fuse || -e /usr/bin/fusermount3 || -e /usr/bin/fusermount ]] && printf 'available' || printf 'missing' ;;
    appimage) [[ -e /dev/fuse ]] && printf 'likely-ok' || printf 'needs-fuse-or-extract' ;;
    xdg_portal) have xdg-desktop-portal && printf 'available' || printf 'unknown-or-missing' ;;
    notifications) have notify-send && printf 'available' || printf 'missing' ;;
    browser) have xdg-open && printf 'available' || printf 'missing' ;;
    *) printf 'unknown' ;;
  esac
}

linux_recommendations_json() {
  local first=1 pm session systemd_status
  pm="$(linux_package_manager)"
  session="${XDG_SESSION_TYPE:-unknown}"
  systemd_status="$(linux_user_systemd_status)"
  printf '['
  if [[ "$pm" == "pacman" && ! ( -x /usr/bin/yay || -x /usr/bin/paru ) ]]; then
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '
    oh_json_string "Install yay or paru if you want AUR-backed optional modules."
    first=0
  fi
  if [[ "$session" == "wayland" ]]; then
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '
    oh_json_string "Wayland detected; prefer portal-aware desktop integrations and avoid assuming X11 automation."
    first=0
  fi
  if [[ "$systemd_status" != "ok" && "$systemd_status" != "degraded" ]]; then
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '
    oh_json_string "systemd --user is not fully reachable; timers and services may need a graphical login session."
    first=0
  fi
  if ! have notify-send; then
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '
    oh_json_string "Install libnotify/notify-send for local secretary reminders."
    first=0
  fi
  [[ "$first" == "1" ]] || printf '\n  '
  printf ']'
}

linux_status_json() {
  local distro_id distro_name pkg init systemd_status session desktop shell_name kernel wsl headless
  distro_id="$(linux_os_release_value ID)"
  distro_name="$(linux_os_release_value PRETTY_NAME)"
  pkg="$(linux_package_manager)"
  init="$(ps -p 1 -o comm= 2>/dev/null || printf unknown)"
  systemd_status="$(linux_user_systemd_status)"
  session="${XDG_SESSION_TYPE:-unknown}"
  desktop="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"
  shell_name="$(basename "${SHELL:-unknown}")"
  kernel="$(uname -sr 2>/dev/null || printf unknown)"
  if grep -qi microsoft /proc/version 2>/dev/null; then wsl=1; else wsl=0; fi
  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then headless=1; else headless=0; fi
  printf '{\n'
  printf '  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "system": {\n'
  printf '    "kernel": '; oh_json_string "$kernel"
  printf ',\n    "distro_id": '; oh_json_string "${distro_id:-unknown}"
  printf ',\n    "distro_name": '; oh_json_string "${distro_name:-unknown}"
  printf ',\n    "package_manager": '; oh_json_string "$pkg"
  printf ',\n    "init": '; oh_json_string "$init"
  printf ',\n    "systemd_user": '; oh_json_string "$systemd_status"
  printf ',\n    "wsl": %s,\n    "headless": %s\n  },\n' "$wsl" "$headless"
  printf '  "session": {\n'
  printf '    "type": '; oh_json_string "$session"
  printf ',\n    "desktop": '; oh_json_string "$desktop"
  printf ',\n    "display": '; oh_json_string "${DISPLAY:-}"
  printf ',\n    "wayland_display": '; oh_json_string "${WAYLAND_DISPLAY:-}"
  printf ',\n    "shell": '; oh_json_string "$shell_name"
  printf '\n  },\n'
  printf '  "commands": {\n'
  local first=1 cmd
  for cmd in bash git curl jq python3 node npm uv systemctl notify-send xdg-open hermes; do
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '; oh_json_string "$cmd"; printf ': '; oh_json_string "$(linux_command_status "$cmd")"
    first=0
  done
  printf '\n  },\n'
  printf '  "runtime": {\n'
  printf '    "fuse": '; oh_json_string "$(linux_runtime_status fuse)"
  printf ',\n    "appimage": '; oh_json_string "$(linux_runtime_status appimage)"
  printf ',\n    "xdg_portal": '; oh_json_string "$(linux_runtime_status xdg_portal)"
  printf ',\n    "notifications": '; oh_json_string "$(linux_runtime_status notifications)"
  printf ',\n    "browser": '; oh_json_string "$(linux_runtime_status browser)"
  printf '\n  },\n'
  printf '  "recommendations": '
  linux_recommendations_json
  printf '\n}\n'
}

linux_status_human() {
  local distro_name distro_id
  distro_name="$(linux_os_release_value PRETTY_NAME)"
  distro_id="$(linux_os_release_value ID)"
  printf '# oh-hermes Linux Status\n\n'
  printf -- '- Generated: `%s`\n' "$(date -Is)"
  printf -- '- Distro: `%s` (`%s`)\n' "${distro_name:-unknown}" "${distro_id:-unknown}"
  printf -- '- Package manager: `%s`\n' "$(linux_package_manager)"
  printf -- '- Session: `%s` / `%s`\n' "${XDG_SESSION_TYPE:-unknown}" "${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"
  printf -- '- systemd --user: `%s`\n' "$(linux_user_systemd_status)"
  printf -- '- Headless: `%s`\n' "$([[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]] && printf yes || printf no)"
  printf '\n## Commands\n\n'
  local cmd
  for cmd in bash git curl jq python3 node npm uv systemctl notify-send xdg-open hermes; do
    printf -- '- `%s`: `%s`\n' "$cmd" "$(linux_command_status "$cmd")"
  done
  printf '\n## Runtime\n\n'
  printf -- '- FUSE: `%s`\n' "$(linux_runtime_status fuse)"
  printf -- '- AppImage: `%s`\n' "$(linux_runtime_status appimage)"
  printf -- '- XDG portal: `%s`\n' "$(linux_runtime_status xdg_portal)"
  printf -- '- Notifications: `%s`\n' "$(linux_runtime_status notifications)"
}

linux_deps() {
  local distro_id pkg
  distro_id="$(linux_os_release_value ID)"
  pkg="$(linux_package_manager)"
  printf '# oh-hermes Linux Dependency Plan\n\n'
  printf 'These commands are printed for review; `oh-hermes linux deps` does not install packages.\n\n'
  case "$pkg:$distro_id" in
    pacman:*)
      printf '```bash\nsudo pacman -S --needed bash git curl jq python nodejs npm base-devel xdg-utils libnotify fuse2 fuse3\n```\n'
      ;;
    apt:*)
      printf '```bash\nsudo apt update\nsudo apt install -y bash git curl jq python3 nodejs npm build-essential xdg-utils libnotify-bin fuse3\n```\n'
      ;;
    dnf:*)
      printf '```bash\nsudo dnf install -y bash git curl jq python3 nodejs npm @development-tools xdg-utils libnotify fuse fuse3\n```\n'
      ;;
    zypper:*)
      printf '```bash\nsudo zypper install bash git curl jq python3 nodejs npm -t pattern devel_basis xdg-utils libnotify-tools fuse3\n```\n'
      ;;
    nix:*)
      printf '```bash\nnix profile install nixpkgs#bash nixpkgs#git nixpkgs#curl nixpkgs#jq nixpkgs#python3 nixpkgs#nodejs nixpkgs#xdg-utils nixpkgs#libnotify\n```\n'
      ;;
    apk:*)
      printf '```bash\nsudo apk add bash git curl jq python3 nodejs npm build-base xdg-utils libnotify fuse3\n```\n'
      ;;
    *)
      printf 'Unknown package manager. Required tools: bash git curl jq python3 node npm xdg-open notify-send systemctl when available.\n'
      ;;
  esac
}

linux_service_check_json() {
  local first=1 unit state
  printf '{\n  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "systemd_user": '; oh_json_string "$(linux_user_systemd_status)"
  printf ',\n  "units": ['
  if have systemctl; then
    for unit in "$OH_ROOT"/systemd/user/oh-hermes-*.service "$OH_ROOT"/systemd/user/oh-hermes-*.timer; do
      [[ -f "$unit" ]] || continue
      state="$(systemctl --user is-active "$(basename "$unit")" 2>/dev/null || true)"
      state="$(printf '%s\n' "${state:-inactive}" | head -n 1)"
      [[ "$first" == "1" ]] || printf ','
      printf '\n    {"name": '; oh_json_string "$(basename "$unit")"
      printf ', "active": '; oh_json_string "$state"
      printf '}'
      first=0
    done
  fi
  printf '\n  ]\n}\n'
}

linux_service_check() {
  if [[ "${1:-}" == "--json" ]]; then
    linux_service_check_json
    return 0
  fi
  printf '# oh-hermes Linux Service Check\n\n'
  printf -- '- systemd --user: `%s`\n\n' "$(linux_user_systemd_status)"
  if have systemctl; then
    systemctl --user list-timers 'oh-hermes*' --no-pager 2>&1 || true
    printf '\n'
    systemctl --user is-active oh-hermes-memos.service oh-hermes-workspace.service oh-hermes-dashboard.service 2>&1 || true
  else
    printf 'systemctl missing\n'
  fi
}

linux_cmd() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    status|doctor)
      if [[ "${1:-}" == "--json" ]]; then linux_status_json; else linux_status_human; fi
      ;;
    deps) linux_deps "$@" ;;
    service-check) linux_service_check "$@" ;;
    *) die "Unknown linux command: $sub" ;;
  esac
}
