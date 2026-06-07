#!/usr/bin/env bash

# Codebase intake scanner for oh-hermes.
# Scans tracked files for TODO/FIXME, docs plans, test gaps, and publish
# readiness items. Creates local candidates first; only creates GitHub
# issues when --apply is explicitly passed.

# --- scanners ----------------------------------------------------------

codebase_scan_todos() {
  local root="${1:-$OH_ROOT}"
  need rg
  rg -n --no-heading \
    --glob '!.git/' \
    --glob '!vendor/' \
    --glob '!node_modules/' \
    --glob '!*.pyc' \
    --glob '!*.min.*' \
    -e 'TODO' -e 'FIXME' -e 'HACK' -e 'XXX' -e 'WORKAROUND' \
    "$root" 2>/dev/null | head -n 200 || true
}

codebase_scan_doc_plans() {
  local root="${1:-$OH_ROOT}"
  need rg
  rg -n --no-heading \
    --glob '!.git/' \
    --glob '!vendor/' \
    --glob '!node_modules/' \
    -e 'PLAN:' -e 'PROPOSAL:' -e 'RFC:' -e 'DESIGN:' \
    "$root" 2>/dev/null | head -n 100 || true
}

codebase_scan_test_gaps() {
  local root="${1:-$OH_ROOT}"
  local src_count test_count

  src_count="$(find "$root" -name '*.sh' -not -path '*/.git/*' -not -path '*/vendor/*' -not -path '*/tests/*' 2>/dev/null | wc -l)"
  test_count="$(find "$root/tests" -name '*.sh' 2>/dev/null | wc -l)"

  printf 'source_files=%s test_files=%s ratio=%s\n' "$src_count" "$test_count" "$(python3 -c "print(round($test_count / max($src_count, 1), 2))" 2>/dev/null || printf '0')"
}

codebase_scan_publish_items() {
  local root="${1:-$OH_ROOT}"
  printf '# Publish Readiness Items\n\n'
  if [[ -d "$root/.git" ]]; then
    local dirty
    dirty="$(git -C "$root" status --short 2>/dev/null | wc -l)"
    printf 'dirty_tracked_files=%s\n' "$dirty"
  fi

  local missing=0
  for file in README.md .gitignore .env.EXAMPLE; do
    [[ -f "$root/$file" ]] || { printf 'missing_file=%s\n' "$file"; missing=1; }
  done
  [[ "$missing" == "0" ]] && printf 'required_files_present=true\n' || printf 'required_files_present=false\n'
}

# --- intake ------------------------------------------------------------

codebase_intake_json() {
  local dry=0 apply=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      --apply) apply=1; shift ;;
      *) shift ;;
    esac
  done

  local generated root
  generated="$(date -Is)"
  root="$OH_ROOT"

  local todo_count doc_plan_count test_ratio
  todo_count="$(codebase_scan_todos "$root" | wc -l)"
  doc_plan_count="$(codebase_scan_doc_plans "$root" | wc -l)"
  test_ratio="$(codebase_scan_test_gaps "$root" | grep -oP 'ratio=\K[0-9.]+' || printf '0')"

  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "root": '; oh_json_string "$root"
  printf ',\n  "dry_run": %s' "$dry"
  printf ',\n  "apply": %s' "$apply"
  printf ',\n  "findings": {\n'
  printf '    "todos_fixmes": %s,\n' "$todo_count"
  printf '    "doc_plans": %s,\n' "$doc_plan_count"
  printf '    "test_ratio": %s,\n' "$test_ratio"
  printf '    "publish_items": '
  oh_json_string "$(codebase_scan_publish_items "$root" | head -c 1000)"
  printf '\n  }'
  printf ',\n  "candidates": []'
  printf ',\n  "message": '
  if [[ "$apply" == "1" ]]; then
    oh_json_string "Codebase intake with --apply is not yet implemented. Review candidates with oh-hermes kanban cards --json first."
  else
    oh_json_string "Codebase scan completed. Review findings, then use --apply to create kanban cards from candidates."
  fi
  printf '\n}\n'
}

codebase_scan_json() {
  local generated root
  generated="$(date -Is)"
  root="$OH_ROOT"

  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "root": '; oh_json_string "$root"
  printf ',\n  "todos": ['
  local first=1 line
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '; oh_json_string "$line"
    first=0
  done < <(codebase_scan_todos "$root")
  [[ "$first" == "1" ]] || printf '\n  '
  printf '],\n'
  printf '  "doc_plans": ['
  first=1
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '; oh_json_string "$line"
    first=0
  done < <(codebase_scan_doc_plans "$root")
  [[ "$first" == "1" ]] || printf '\n  '
  printf '],\n'
  printf '  "test_gaps": '; oh_json_string "$(codebase_scan_test_gaps "$root")"
  printf ',\n  "publish_items": '; oh_json_string "$(codebase_scan_publish_items "$root" | head -c 1000)"
  printf '\n}\n'
}

# --- command dispatch --------------------------------------------------

codebase_cmd() {
  local sub="${1:-scan}"
  shift || true
  case "$sub" in
    scan) codebase_scan_json "$@" ;;
    intake) codebase_intake_json "$@" ;;
    *) die "Unknown codebase command: $sub" ;;
  esac
}
