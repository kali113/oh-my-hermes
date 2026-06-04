#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/bin/oh-hermes" test
"$ROOT/bin/oh-hermes" install --dry-run --no-modules

