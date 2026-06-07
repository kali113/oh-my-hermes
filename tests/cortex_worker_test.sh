#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$(mktemp -d)"
export OH_HERMES_STATE="$STATE"
trap 'rm -rf "$STATE"' EXIT

OH="$ROOT/bin/oh-hermes"
pass=0
fail=0

check_pass() {
  pass=$((pass + 1))
  printf '\033[1;32mPASS\033[0m %s\n' "$1"
}

check_fail() {
  fail=$((fail + 1))
  printf '\033[1;31mFAIL\033[0m %s\n' "$1"
}

# Validate JSON (stderr discarded to avoid [dry-run] messages mixing in)
assert_json() {
  local label="$1" json="$2"
  if printf '%s' "$json" | python3 -m json.tool >/dev/null 2>&1; then
    check_pass "$label"
  else
    check_fail "$label (invalid JSON)"
  fi
}

# Check that JSON contains a key (recursively in string form)
assert_contains() {
  local label="$1" json="$2" key="$3"
  if printf '%s' "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); s=json.dumps(d); assert '$key' in s" 2>/dev/null; then
    check_pass "$label"
  else
    check_fail "$label (missing '$key')"
  fi
}

assert_true() {
  local label="$1" json="$2" path="$3"
  local val
  val="$(printf '%s' "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d$path)" 2>/dev/null || true)"
  if [[ "$val" == "True" || "$val" == "true" ]]; then
    check_pass "$label"
  else
    check_fail "$label (expected true, got '$val')"
  fi
}

assert_false() {
  local label="$1" json="$2" path="$3"
  local val
  val="$(printf '%s' "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d$path)" 2>/dev/null || true)"
  if [[ "$val" == "False" || "$val" == "false" || "$val" == "0" ]]; then
    check_pass "$label"
  else
    check_fail "$label (expected false/0, got '$val')"
  fi
}

# Helper: run oh-hermes, capture stdout only (stderr goes to terminal)
oh_stdout() {
  "$OH" "$@" 2>/dev/null || true
}

printf '\n# Cortex worker tests\n\n'

# 1. cortex status --json (cortex is missing in this env)
out="$(oh_stdout cortex status --json)"
assert_json "cortex status --json is valid JSON" "$out"
assert_false "cortex available is false" "$out" "['available']"
assert_contains "cortex status includes install_guide" "$out" "install_guide"

# 2. cortex install-check --json
out="$(oh_stdout cortex install-check --json)"
assert_json "cortex install-check --json is valid JSON" "$out"
assert_false "cortex install-check available is false" "$out" "['available']"

# 3. worker list --json
out="$(oh_stdout worker list --json)"
assert_json "worker list --json is valid JSON" "$out"
assert_contains "worker list includes cortex" "$out" "cortex"
assert_contains "worker list includes human" "$out" "human"

# 4. worker status --json
out="$(oh_stdout worker status --json)"
assert_json "worker status --json is valid JSON" "$out"

# 5. worker delegate --to cortex --mode plan --dry-run
out="$(oh_stdout worker delegate --to cortex --mode plan --card test-1 --dry-run)"
assert_json "worker delegate --dry-run is valid JSON" "$out"
assert_contains "worker delegate dry_run reports reason" "$out" "reason"
assert_contains "worker delegate dry_run has would_create_session" "$out" "would_create_session"

# 6. worker delegate --to cortex --mode implement --dry-run (disabled mode)
out="$(oh_stdout worker delegate --to cortex --mode implement --card test-1 --dry-run)"
assert_json "worker delegate disabled mode is valid JSON" "$out"
assert_contains "worker delegate disabled mode reports mode_disabled" "$out" "mode_disabled"

# 7. worker delegate --to unknown-worker --mode plan --dry-run
out="$(oh_stdout worker delegate --to no-such-worker --mode plan --dry-run)"
assert_json "worker delegate unknown worker is valid JSON" "$out"
assert_contains "worker delegate unknown worker reports worker_not_found" "$out" "worker_not_found"

# 8. kanban status --json
out="$(oh_stdout kanban status --json)"
assert_json "kanban status --json is valid JSON" "$out"
assert_contains "kanban status has statuses" "$out" "statuses"

# 9. kanban boards --json
out="$(oh_stdout kanban boards --json)"
assert_json "kanban boards --json is valid JSON" "$out"
assert_contains "kanban boards has boards array" "$out" "boards"

# 10. github labels ensure --dry-run
out="$(oh_stdout github labels ensure --dry-run)"
assert_json "github labels ensure --dry-run is valid JSON" "$out"
assert_contains "github labels has dry_run" "$out" "dry_run"
assert_contains "github labels has labels" "$out" "labels"

# 11. codebase scan --json
out="$(oh_stdout codebase scan --json)"
assert_json "codebase scan --json is valid JSON" "$out"
assert_contains "codebase scan has todos" "$out" "todos"
assert_contains "codebase scan has doc_plans" "$out" "doc_plans"

# 12. codebase intake --dry-run
out="$(oh_stdout codebase intake --dry-run)"
assert_json "codebase intake --dry-run is valid JSON" "$out"

# 13. usage/help
out="$("$OH" --help 2>&1 || true)"
if echo "$out" | grep -q "worker"; then
  check_pass "usage includes worker commands"
else
  check_fail "usage includes worker commands"
fi
if echo "$out" | grep -q "cortex"; then
  check_pass "usage includes cortex commands"
else
  check_fail "usage includes cortex commands"
fi
if echo "$out" | grep -q "kanban"; then
  check_pass "usage includes kanban commands"
else
  check_fail "usage includes kanban commands"
fi
if echo "$out" | grep -q "github"; then
  check_pass "usage includes github commands"
else
  check_fail "usage includes github commands"
fi
if echo "$out" | grep -q "codebase"; then
  check_pass "usage includes codebase commands"
else
  check_fail "usage includes codebase commands"
fi

# 14. module list includes cortex
out="$("$OH" modules list 2>&1 || true)"
if echo "$out" | grep -q "cortex"; then
  check_pass "module list includes cortex"
else
  check_fail "module list includes cortex"
fi

# 15. module status json includes cortex
out="$(oh_stdout modules json)"
assert_json "modules json is valid JSON" "$out"
assert_contains "modules json includes cortex" "$out" "cortex"

# 16. worker run --dry-run with bogus session (expects die message on stderr)
out="$("$OH" worker run --session no-such-session --dry-run 2>&1 || true)"
if echo "$out" | grep -qi "not found\|Session"; then
  check_pass "worker run with bogus session reports error"
else
  check_fail "worker run with bogus session reports error (got: '$out')"
fi

# summary
printf '\n'
if [[ "$fail" == "0" ]]; then
  printf '\033[1;32mAll %d tests passed\033[0m\n' "$pass"
else
  printf '\033[1;31m%d passed, %d failed\033[0m\n' "$pass" "$fail"
  exit 1
fi
