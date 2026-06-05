#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$(mktemp -d)"
OUT="$STATE/out"
trap 'rm -rf "$STATE"' EXIT

export OH_HERMES_STATE="$STATE"
snapshot="$("$ROOT/bin/oh-hermes" publish-snapshot --skip-check --out-dir "$OUT")"
archive="$(tail -n 2 <<< "$snapshot" | sed -n '1p')"
manifest="$(tail -n 1 <<< "$snapshot")"

[[ -f "$archive" ]]
[[ -f "$manifest" ]]
grep -q "Publish Snapshot" "$manifest"
grep -q "Redaction check: \`passed\`" "$manifest"
contents="$STATE/archive-contents.txt"
tar -tzf "$archive" > "$contents"
grep -q '/README.md$' "$contents"
! grep -q '/.git/' "$contents"
! grep -q '/reports/' "$contents"
! grep -q '/backups/' "$contents"
