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
if [[ "${1:-}" == "--user" && "${2:-}" == "is-active" && "${3:-}" == "--quiet" ]]; then
  case "${4:-}" in
    oh-hermes-workspace.service|oh-hermes-dashboard.service|oh-hermes-memos.service) exit 0 ;;
  esac
fi
exit 1
SH
chmod +x "$MOCK_BIN/hermes" "$MOCK_BIN/curl" "$MOCK_BIN/systemctl"

export OH_HERMES_STATE="$STATE"
export PATH="$MOCK_BIN:$PATH"
printf 'API_SERVER_KEY=test-key\n' > "$STATE/hermes.env"

health="$("$ROOT/bin/oh-hermes" agent json)"
grep -q '"workspace": "running-unreachable"' <<< "$health"
grep -q '"dashboard": "running-unreachable"' <<< "$health"
grep -q '"memos": "running-unreachable"' <<< "$health"
grep -q '"api": "unknown-unreachable"' <<< "$health"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$health" >/dev/null
fi

cat > "$MOCK_BIN/systemctl" <<'SH'
#!/usr/bin/env bash
printf 'Failed to connect to user scope bus via local transport: Operation not permitted\n' >&2
exit 1
SH
chmod +x "$MOCK_BIN/systemctl"

health="$("$ROOT/bin/oh-hermes" agent json)"
grep -q '"workspace": "unknown-unreachable"' <<< "$health"
grep -q '"dashboard": "unknown-unreachable"' <<< "$health"
grep -q '"memos": "unknown-unreachable"' <<< "$health"
grep -q '"api": "unknown-unreachable"' <<< "$health"
