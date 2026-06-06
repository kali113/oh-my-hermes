#!/usr/bin/env bash

command_center_recommendations_json() {
  local next_section id title status due priority risk project action command reason dirty first=1
  IFS=$'\034' read -r next_section id title status due priority risk project action command reason < <(secretary_next_pick)
  dirty="$(publish_ready_dirty_count)"
  printf '['
  if [[ "$next_section" != "none" ]]; then
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '
    oh_json_string "Work the secretary next item before starting speculative setup changes."
    first=0
  fi
  if [[ "$dirty" != "0" ]]; then
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '
    oh_json_string "Review tracked repo changes before publishing."
    first=0
  fi
  if ! have hermes || ! hermes desktop --help >/dev/null 2>&1; then
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '
    oh_json_string "Run hermes update if the official desktop command is missing."
    first=0
  fi
  if ! have notify-send; then
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '
    oh_json_string "Install notify-send to enable local secretary reminders."
    first=0
  fi
  [[ "$first" == "1" ]] || printf '\n  '
  printf ']'
}

command_center_json() {
  printf '{\n'
  printf '  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "next": '; secretary_next_json
  printf ',\n  "linux": '; linux_status_json
  printf ',\n  "desktop": '; desktop_status_json
  printf ',\n  "memory": '; memory_status_json
  printf ',\n  "autonomy": '; autonomy_status_json
  printf ',\n  "publish": '; OH_HERMES_PUBLISH_READY_FAST="${OH_HERMES_PUBLISH_READY_FAST:-1}" publish_ready_json
  printf ',\n  "recommendations": '
  command_center_recommendations_json
  printf '\n}\n'
}

command_center() {
  if [[ "${1:-}" == "--json" ]]; then
    command_center_json
    return 0
  fi
  local section id title status due priority risk project action command reason publish_payload publish_status linux_pm desktop_available
  IFS=$'\034' read -r section id title status due priority risk project action command reason < <(secretary_next_pick)
  publish_payload="$(OH_HERMES_PUBLISH_READY_FAST=1 publish_ready_json)"
  publish_status="$(awk -F'"' '/"status":/ && !seen {print $4; seen=1}' <<< "$publish_payload")"
  linux_pm="$(linux_package_manager)"
  if have hermes && hermes desktop --help >/dev/null 2>&1; then desktop_available=available; else desktop_available=missing; fi
  printf '# oh-hermes Command Center\n\n'
  printf -- '- Generated: `%s`\n' "$(date -Is)"
  printf -- '- Linux package manager: `%s`\n' "$linux_pm"
  printf -- '- Desktop: `%s`\n' "$desktop_available"
  printf -- '- Publish readiness: `%s`\n\n' "$publish_status"
  printf '## Next Item\n\n'
  printf -- '- Section: `%s`\n' "$section"
  [[ -n "$title" ]] && printf -- '- Title: `%s`\n' "$title"
  printf -- '- Command: `%s`\n' "$command"
  printf -- '- Reason: %s\n\n' "$reason"
  printf '## Recommended Checks\n\n'
  printf -- '- `oh-hermes linux doctor --json`\n'
  printf -- '- `oh-hermes desktop doctor --json`\n'
  printf -- '- `oh-hermes memory status --json`\n'
  printf -- '- `oh-hermes autonomy status --json`\n'
  printf -- '- `oh-hermes publish-ready --json`\n'
}
