#!/usr/bin/env bash

# Hermes native kanban wrapper for oh-hermes.
# Uses `hermes kanban` as the source of truth. Does not create a parallel
# kanban database. All display/formatting lives here; core state lives in
# Hermes kanban.db.

# --- low-level helpers -------------------------------------------------

kanban_require() {
  need hermes
  hermes kanban init >/dev/null 2>&1 || true
}

kanban_default_board() {
  # `hermes kanban boards` output format (stdout):
  #     SLUG                      NAME                          COUNTS
  # ●   default                   Default                       (empty)
  # Current board: default
  hermes kanban boards 2>/dev/null \
    | grep '●' \
    | awk '{print $2}' \
    | head -n 1 || true
}

# --- status ------------------------------------------------------------

kanban_status_json() {
  kanban_require
  local board generated
  board="$(kanban_default_board)"
  generated="$(date -Is)"

  # `hermes kanban stats` output format:
  # By status:
  #   triage    0
  #   todo      0
  #   scheduled  0
  #   ready     0
  #   running   0
  #   blocked   0
  #   done      0
  # hermes kanban stats writes preamble to stdout; strip everything before "By status:"
  local stats_raw
  stats_raw="$(hermes kanban stats ${board:+--board "$board"} 2>/dev/null | sed -n '/^By status:/,$p' || true)"

  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "board": '; oh_json_string "${board:-default}"
  printf ',\n  "statuses": {\n'

  local key value first=1
  while IFS= read -r line; do
    # Match lines like "  triage    0" or "  scheduled  0"
    if [[ "$line" =~ ^[[:space:]]+([a-z_]+)[[:space:]]+([0-9]+) ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
      [[ "$first" == "1" ]] || printf ',\n'
      printf '    '; oh_json_string "$key"; printf ': %s' "$value"
      first=0
    fi
  done <<< "$stats_raw"

  [[ "$first" == "1" ]] || printf '\n  '
  printf '}\n'
  printf '}\n'
}

# --- boards ------------------------------------------------------------

kanban_boards_json() {
  kanban_require
  local generated
  generated="$(date -Is)"
  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "boards": ['
  local first=1 line slug name
  while IFS= read -r line; do
    # Match board lines: "●   default                   Default                       (empty)"
    # or without bullet: "    default                   Default                       (empty)"
    # Only match board lines like "●   default                   Default                       (empty)"
    # Skip header/preamble lines
    if [[ "$line" =~ ^[[:space:]]*(●[[:space:]]+)?([a-zA-Z0-9_-]+)[[:space:]]+([A-Za-z0-9_][A-Za-z0-9_ -]*)[[:space:]] ]]; then
      slug="${BASH_REMATCH[2]}"
      name="${BASH_REMATCH[3]}"
      name="${name%"${name##*[![:space:]]}"}"  # trim trailing whitespace
      # Skip header row labels
      [[ "$slug" == "SLUG" ]] && continue
      [[ "$slug" == "Current" ]] && continue
      [[ "$first" == "1" ]] || printf ','
      printf '\n    {'
      printf '"slug": '; oh_json_string "$slug"
      printf ', "name": '; oh_json_string "${name:-$slug}"
      printf '}'
      first=0
    fi
  done < <(hermes kanban boards 2>/dev/null || true)
  [[ "$first" == "1" ]] || printf '\n  '
  printf ']\n'
  printf '}\n'
}

# --- cards -------------------------------------------------------------

kanban_cards_json() {
  kanban_require
  local board="" status_filter=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --board) board="${2:-}"; shift 2 ;;
      --status) status_filter="${2:-}"; shift 2 ;;
      *) shift ;;
    esac
  done
  board="${board:-$(kanban_default_board)}"

  local generated
  generated="$(date -Is)"

  local args=(kanban list --json)
  [[ -n "$board" ]] && args+=(--board "$board")
  [[ -n "$status_filter" ]] && args+=(--status "$status_filter")

  # hermes kanban list --json may not exist; fall back to plain list
  local raw
  raw="$("${args[@]}" 2>/dev/null || hermes kanban list ${board:+--board "$board"} 2>/dev/null || true)"

  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "board": '; oh_json_string "${board:-default}"
  printf ',\n  "cards": '
  # If the output starts with '[', treat it as JSON
  if [[ "$raw" =~ ^[[:space:]]*\[ ]]; then
    printf '%s\n' "$raw"
  else
    # Parse plain-text list format: UUID STATUS ASSIGNEE TITLE
    printf '['
    local first=1 id status assignee title rest
    while IFS= read -r line; do
      [[ "$line" =~ ^[0-9a-f-]{20,} ]] || continue
      id="$(awk '{print $1}' <<< "$line")"
      status="$(awk '{print $2}' <<< "$line")"
      assignee="$(awk '{print $3}' <<< "$line")"
      rest="$(awk '{for(i=4;i<=NF;i++) printf "%s ", $i; print ""}' <<< "$line" | sed 's/ *$//')"
      [[ "$first" == "1" ]] || printf ','
      printf '\n    {'
      printf '"id": '; oh_json_string "$id"
      printf ', "status": '; oh_json_string "$status"
      printf ', "assignee": '; oh_json_string "${assignee:-unassigned}"
      printf ', "title": '; oh_json_string "${rest:-}"
      printf '}'
      first=0
    done <<< "$raw"
    [[ "$first" == "1" ]] || printf '\n  '
    printf ']'
  fi
  printf '\n}\n'
}

# --- show card ---------------------------------------------------------

kanban_show_json() {
  local card_id="${1:-}"
  [[ -n "$card_id" ]] || die "kanban show requires CARD_ID"

  kanban_require

  local raw generated
  generated="$(date -Is)"
  raw="$(hermes kanban show "$card_id" 2>/dev/null || true)"

  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "card_id": '; oh_json_string "$card_id"
  printf ',\n  "raw": '
  oh_json_string "$raw"
  printf '\n}\n'
}

# --- context -----------------------------------------------------------

kanban_context_json() {
  local card_id="${1:-}"
  [[ -n "$card_id" ]] || die "kanban context requires CARD_ID"

  kanban_require

  local raw generated
  generated="$(date -Is)"
  raw="$(hermes kanban context "$card_id" 2>/dev/null || true)"

  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "card_id": '; oh_json_string "$card_id"
  printf ',\n  "context": '
  oh_json_string "$raw"
  printf '\n}\n'
}

# --- sync-github -------------------------------------------------------

kanban_sync_github_json() {
  local dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      *) shift ;;
    esac
  done

  kanban_require
  local generated board
  generated="$(date -Is)"
  board="$(kanban_default_board)"

  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "board": '; oh_json_string "${board:-default}"
  printf ',\n  "dry_run": %s' "$dry"
  printf ',\n  "synced": false'
  printf ',\n  "message": '
  oh_json_string "kanban sync-github is a planned feature; use oh-hermes github issues sync for intake"
  printf '\n}\n'
}

# --- command dispatch --------------------------------------------------

kanban_cmd() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    status) kanban_status_json "$@" ;;
    boards) kanban_boards_json "$@" ;;
    cards) kanban_cards_json "$@" ;;
    show) kanban_show_json "$@" ;;
    context) kanban_context_json "$@" ;;
    sync-github) kanban_sync_github_json "$@" ;;
    *) die "Unknown kanban command: $sub" ;;
  esac
}
