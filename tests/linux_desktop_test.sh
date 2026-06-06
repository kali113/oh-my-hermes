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
case "${1:-}" in
  version) printf 'Hermes Agent 0.0-test\n' ;;
  desktop)
    case "${2:-}" in
      --help) printf 'Usage: hermes desktop [--cwd DIR] [--build-only]\n' ;;
      --build-only) printf 'building desktop\n' ;;
      *) printf 'launching desktop\n' ;;
    esac
    ;;
  *) exit 0 ;;
esac
SH
cat > "$MOCK_BIN/systemctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
  "--user is-system-running") printf 'running\n' ;;
  "--user is-active") printf 'inactive\n'; exit 3 ;;
  *) exit 0 ;;
esac
SH
chmod +x "$MOCK_BIN/hermes" "$MOCK_BIN/systemctl"

export OH_HERMES_STATE="$STATE"
export PATH="$MOCK_BIN:$PATH"

linux_json="$("$ROOT/bin/oh-hermes" linux doctor --json)"
grep -q '"system"' <<< "$linux_json"
grep -q '"commands"' <<< "$linux_json"
grep -q '"hermes": "available"' <<< "$linux_json"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$linux_json" >/dev/null
fi

service_json="$("$ROOT/bin/oh-hermes" linux service-check --json)"
grep -q '"units"' <<< "$service_json"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$service_json" >/dev/null
fi

deps_output="$("$ROOT/bin/oh-hermes" linux deps)"
grep -Eq 'pacman|apt|dnf|zypper|nix|apk|Unknown package manager' <<< "$deps_output"

desktop_json="$("$ROOT/bin/oh-hermes" desktop status --json)"
grep -q '"official_command": 1' <<< "$desktop_json"
grep -q 'Hermes Agent 0.0-test' <<< "$desktop_json"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$desktop_json" >/dev/null
fi

desktop_doctor_json="$("$ROOT/bin/oh-hermes" desktop doctor --json)"
grep -q '"desktop"' <<< "$desktop_doctor_json"
grep -q '"linux"' <<< "$desktop_doctor_json"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$desktop_doctor_json" >/dev/null
fi
