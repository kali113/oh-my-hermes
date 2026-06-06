#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$(mktemp -d)"
trap 'rm -rf "$STATE"' EXIT

export OH_HERMES_STATE="$STATE"

modules_json="$("$ROOT/bin/oh-hermes" modules json)"
grep -q '"modules"' <<< "$modules_json"
grep -q '"name": "anysearch"' <<< "$modules_json"
grep -q '"name": "workspace"' <<< "$modules_json"
grep -q '"name": "hermes-desktop"' <<< "$modules_json"
grep -q '"tier": "default"' <<< "$modules_json"
grep -q '"source": "https://github.com/outsourc-e/hermes-workspace"' <<< "$modules_json"
grep -q '"source": "https://hermes-agent.nousresearch.com/docs/user-guide/desktop"' <<< "$modules_json"
if command -v python3 >/dev/null 2>&1; then
  python3 -m json.tool <<< "$modules_json" >/dev/null
fi
