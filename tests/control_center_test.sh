#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$(mktemp -d)"
MOCK_BIN="$STATE/bin"
trap 'rm -rf "$STATE"' EXIT

mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/hermes" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
  "version ") printf 'Hermes Agent 0.0-test\n' ;;
  "desktop --help") printf 'Usage: hermes desktop\n' ;;
  "config check") exit 0 ;;
  "config env-path") printf '%s\n' "$OH_HERMES_STATE/hermes.env" ;;
  *) exit 0 ;;
esac
SH
cat > "$MOCK_BIN/curl" <<'SH'
#!/usr/bin/env bash
exit 7
SH
cat > "$MOCK_BIN/systemctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
  "--user is-system-running") printf 'running\n' ;;
  "--user is-enabled") printf 'disabled\n' ;;
  "--user is-active") printf 'inactive\n'; exit 3 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$MOCK_BIN/hermes" "$MOCK_BIN/curl" "$MOCK_BIN/systemctl"

export OH_HERMES_STATE="$STATE"
export PATH="$MOCK_BIN:$PATH"
printf 'API_SERVER_KEY=test-key\n' > "$STATE/hermes.env"

"$ROOT/bin/oh-hermes" secretary init >/dev/null
"$ROOT/bin/oh-hermes" secretary task add --title "Control center due task" --due 2000-01-01 >/dev/null
"$ROOT/bin/oh-hermes" secretary learn add --title "Control center candidate" --status candidate --body "Review me" >/dev/null

memory_json="$("$ROOT/bin/oh-hermes" memory status --json)"
grep -q '"candidate_lessons": 1' <<< "$memory_json"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$memory_json" >/dev/null
fi

memory_candidates="$("$ROOT/bin/oh-hermes" memory candidates)"
grep -q "Control center candidate" <<< "$memory_candidates"
promote_dry="$("$ROOT/bin/oh-hermes" memory promote-candidates --dry-run)"
grep -q "secretary learn promote" <<< "$promote_dry"
digest="$("$ROOT/bin/oh-hermes" memory digest)"
[[ -f "$digest" ]]

autonomy_json="$("$ROOT/bin/oh-hermes" autonomy status --json)"
grep -q '"guarded-autonomy"' <<< "$autonomy_json"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$autonomy_json" >/dev/null
fi
autonomy_plan="$("$ROOT/bin/oh-hermes" autonomy plan)"
grep -q "Autonomy Plan" <<< "$autonomy_plan"

publish_json="$(OH_HERMES_PUBLISH_READY_FAST=1 "$ROOT/bin/oh-hermes" publish-ready --json)"
grep -q '"checks"' <<< "$publish_json"
grep -q '"tests": "skipped-fast"' <<< "$publish_json"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$publish_json" >/dev/null
fi

center_json="$(OH_HERMES_PUBLISH_READY_FAST=1 "$ROOT/bin/oh-hermes" command-center --json)"
grep -q '"next"' <<< "$center_json"
grep -q '"linux"' <<< "$center_json"
grep -q '"desktop"' <<< "$center_json"
grep -q '"memory"' <<< "$center_json"
grep -q '"autonomy"' <<< "$center_json"
grep -q '"publish"' <<< "$center_json"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$center_json" >/dev/null
fi

overview_json="$(OH_HERMES_PUBLISH_READY_FAST=1 "$ROOT/bin/oh-hermes" agent overview --json)"
grep -q '"linux"' <<< "$overview_json"
grep -q '"desktop"' <<< "$overview_json"
grep -q '"memory"' <<< "$overview_json"
grep -q '"autonomy"' <<< "$overview_json"
grep -q '"publish"' <<< "$overview_json"
grep -q '"recommendations"' <<< "$overview_json"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$overview_json" >/dev/null
fi
