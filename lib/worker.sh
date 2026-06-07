#!/usr/bin/env bash

# Worker registry, session model, and delegation for oh-hermes.
# Workers are optional adapters. Cortex is the first supported worker,
# registered through the generic interface so future workers can be added
# without changing the core harness.

OH_WORKER_SESSIONS_DIR="$OH_STATE_DIR/worker-sessions"
OH_WORKER_REGISTRY="$OH_STATE_DIR/worker-registry.json"
mkdir -p "$OH_WORKER_SESSIONS_DIR"

# --- registry helpers --------------------------------------------------

worker_registry_path() {
  printf '%s\n' "$OH_WORKER_REGISTRY"
}

worker_registry_init() {
  if [[ ! -f "$OH_WORKER_REGISTRY" ]]; then
    cat > "$OH_WORKER_REGISTRY" <<'EOF'
{
  "workers": [
    {
      "name": "cortex",
      "type": "external-cli",
      "binary": "cortex",
      "modes": ["plan", "research", "review"],
      "disabled_modes": ["implement"],
      "homepage": "https://github.com/Mateooo93/cortex-cli",
      "install_guide": "Install the latest Linux binary from https://github.com/Mateooo93/cortex-cli/releases or build from source with Go.",
      "available": false,
      "version": null,
      "last_checked": null
    },
    {
      "name": "human",
      "type": "human-in-the-loop",
      "binary": null,
      "modes": ["review", "decision"],
      "disabled_modes": [],
      "homepage": null,
      "install_guide": null,
      "available": true,
      "version": null,
      "last_checked": null
    }
  ]
}
EOF
  fi
}

worker_registry_read() {
  worker_registry_init
  cat "$OH_WORKER_REGISTRY"
}

worker_registry_list_names() {
  python3 - "$OH_WORKER_REGISTRY" <<'PY' 2>/dev/null || true
import json
import sys

data = json.load(open(sys.argv[1]))
for worker in data.get("workers", []):
    print(worker["name"])
PY
}

worker_registry_get() {
  local name="$1"
  python3 - "$OH_WORKER_REGISTRY" "$name" <<'PY' 2>/dev/null || printf 'null'
import json
import sys

data = json.load(open(sys.argv[1]))
target = sys.argv[2]
for worker in data.get("workers", []):
    if worker.get("name") == target:
        print(json.dumps(worker))
        sys.exit(0)
sys.exit(1)
PY
}

worker_registry_set_field() {
  local name="$1" key="$2" value="$3"
  local tmp
  tmp="$(mktemp)"
  python3 - "$OH_WORKER_REGISTRY" "$tmp" "$name" "$key" "$value" <<'PY' 2>/dev/null || true
import json
import sys

registry_path, tmp_path, target, key, raw_value = sys.argv[1:6]
data = json.load(open(registry_path))
value = json.loads(raw_value)
for worker in data.get("workers", []):
    if worker.get("name") == target:
        worker[key] = value
json.dump(data, open(tmp_path, "w"), indent=2)
PY
  if [[ -s "$tmp" ]]; then
    mv "$tmp" "$OH_WORKER_REGISTRY"
  else
    rm -f "$tmp"
  fi
}

# --- detection ---------------------------------------------------------

worker_detect_cortex() {
  local available version
  if have cortex; then
    available="true"
    version="$(cortex --version 2>/dev/null | head -n 1 || printf 'unknown')"
  else
    available="false"
    version=""
  fi
  worker_registry_set_field cortex available "$available"
  if [[ -n "$version" ]]; then
    worker_registry_set_field cortex version "$(oh_json_string "$version")"
  else
    worker_registry_set_field cortex version "null"
  fi
  worker_registry_set_field cortex last_checked "$(oh_json_string "$(date -Is)")"
}

worker_detect_all() {
  worker_registry_init
  worker_detect_cortex
}

# --- sessions ----------------------------------------------------------

worker_session_path() {
  local session_id="$1"
  printf '%s/%s.json' "$OH_WORKER_SESSIONS_DIR" "$session_id"
}

worker_session_create() {
  local worker="$1" mode="$2" card_id="${3:-}"
  local session_id stamp
  stamp="$(ts)"
  session_id="ws-${stamp}-${worker}-$$"
  local spath
  spath="$(worker_session_path "$session_id")"
  python3 - "$spath" "$session_id" "$worker" "$mode" "$card_id" "$stamp" <<'PY'
import json
import sys

spath, session_id, worker, mode, card_id, stamp = sys.argv[1:7]
payload = {
    "session_id": session_id,
    "worker": worker,
    "mode": mode,
    "card_id": card_id,
    "status": "created",
    "created": stamp,
    "started": None,
    "finished": None,
    "exit_code": None,
    "elapsed_seconds": None,
    "worktree": None,
    "result_summary": None,
    "stdout_path": None,
    "stderr_path": None,
}
json.dump(payload, open(spath, "w"), indent=2)
PY
  printf '%s' "$session_id"
}

worker_session_update() {
  local session_id="$1" key="$2" value="$3"
  local spath tmp
  spath="$(worker_session_path "$session_id")"
  [[ -f "$spath" ]] || return 1
  tmp="$(mktemp)"
  python3 - "$spath" "$tmp" "$key" "$value" <<'PY' 2>/dev/null
import json
import sys

spath, tmp, key, raw_value = sys.argv[1:5]
data = json.load(open(spath))
data[key] = json.loads(raw_value)
json.dump(data, open(tmp, "w"), indent=2)
PY
  if [[ -s "$tmp" ]]; then
    mv "$tmp" "$spath"
  else
    rm -f "$tmp"
    return 1
  fi
}

worker_session_read() {
  local session_id="$1"
  local spath
  spath="$(worker_session_path "$session_id")"
  if [[ -f "$spath" ]]; then
    cat "$spath"
  else
    printf 'null'
  fi
}

worker_session_list() {
  local spath
  for spath in "$OH_WORKER_SESSIONS_DIR"/*.json; do
    [[ -f "$spath" ]] || continue
    cat "$spath"
    printf '\n'
  done
}

# --- delegation --------------------------------------------------------

worker_delegate() {
  local card_id="" worker="" mode="" dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --card) card_id="${2:-}"; [[ -n "$card_id" ]] || die "--card requires a value"; shift 2 ;;
      --to) worker="${2:-}"; [[ -n "$worker" ]] || die "--to requires a worker name"; shift 2 ;;
      --mode) mode="${2:-}"; [[ -n "$mode" ]] || die "--mode requires a value"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) die "Unknown delegate option: $1" ;;
    esac
  done

  [[ -n "$worker" ]] || die "--to WORKER is required"
  [[ -n "$mode" ]] || die "--mode MODE is required"

  worker_detect_all

  # Dry-run check comes first — report what would happen regardless of availability
  if [[ "$dry" == "1" ]]; then
    local wjson_dry available_dry disabled_dry reason_dry
    wjson_dry="$(worker_registry_get "$worker")"
    available_dry="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(str(d.get('available',False)).lower())" "$wjson_dry" 2>/dev/null || printf 'false')"
    disabled_dry="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); modes=d.get('disabled_modes',[]); print(str('$mode' in modes).lower())" "$wjson_dry" 2>/dev/null || printf 'false')"

    if [[ "$wjson_dry" == "null" ]]; then
      reason_dry="worker_not_found"
    elif [[ "$disabled_dry" == "true" ]]; then
      reason_dry="mode_disabled"
    elif [[ "$available_dry" != "true" ]]; then
      reason_dry="worker_unavailable"
    else
      reason_dry="dry_run"
    fi

    printf '{\n'
    printf '  "delegated": false'
    printf ',\n  "reason": '; oh_json_string "$reason_dry"
    printf ',\n  "worker": '; oh_json_string "$worker"
    printf ',\n  "mode": '; oh_json_string "$mode"
    printf ',\n  "card_id": '; oh_json_string "$card_id"
    printf ',\n  "would_create_session": %s' "$([[ "$reason_dry" == "dry_run" ]] && printf 'true' || printf 'false')"
    printf '\n}\n'
    return 0
  fi

  local wjson available
  wjson="$(worker_registry_get "$worker")"
  if [[ "$wjson" == "null" ]]; then
    printf '{\n  "delegated": false,\n  "reason": "worker_not_found",\n  "worker": '
    oh_json_string "$worker"
    printf '\n}\n'
    return 1
  fi
  available="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(str(d.get('available',False)).lower())" "$wjson" 2>/dev/null || printf 'false')"

  if [[ "$available" != "true" ]]; then
    local guide
    guide="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('install_guide','see docs'))" "$wjson" 2>/dev/null || printf 'see docs')"
    printf '{\n'
    printf '  "delegated": false'
    printf ',\n  "reason": "worker_unavailable"'
    printf ',\n  "worker": '; oh_json_string "$worker"
    printf ',\n  "install_guide": '; oh_json_string "$guide"
    printf '\n}\n'
    return 1
  fi

  local disabled
  disabled="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); modes=d.get('disabled_modes',[]); print(str('$mode' in modes).lower())" "$wjson" 2>/dev/null || printf 'false')"

  if [[ "$disabled" == "true" ]]; then
    printf '{\n'
    printf '  "delegated": false'
    printf ',\n  "reason": "mode_disabled"'
    printf ',\n  "worker": '; oh_json_string "$worker"
    printf ',\n  "mode": '; oh_json_string "$mode"
    printf '\n}\n'
    return 1
  fi

  local session_id
  session_id="$(worker_session_create "$worker" "$mode" "$card_id")"
  printf '{\n  "delegated": true,\n  "session_id": '
  oh_json_string "$session_id"
  printf ',\n  "worker": '
  oh_json_string "$worker"
  printf ',\n  "mode": '
  oh_json_string "$mode"
  if [[ -n "$card_id" ]]; then
    printf ',\n  "card_id": '
    oh_json_string "$card_id"
  fi
  printf '\n}\n'
}

# --- status / list -----------------------------------------------------

worker_status_json() {
  worker_detect_all
  printf '{\n'
  printf '  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "sessions_dir": '; oh_json_string "$OH_WORKER_SESSIONS_DIR"
  printf ',\n  "workers": '
  python3 -c "
import json
data = json.load(open('$OH_WORKER_REGISTRY'))
print(json.dumps(data.get('workers', []), indent=4))
" 2>/dev/null || printf '[]'
  printf ',\n  "recent_sessions": '
  local first=1
  printf '['
  while IFS= read -r sess; do
    [[ -n "$sess" ]] || continue
    [[ "$first" == "1" ]] || printf ','
    printf '\n    %s' "$sess"
    first=0
  done < <(worker_recent_session_files | while read -r f; do cat "$f"; done)
  [[ "$first" == "1" ]] || printf '\n  '
  printf ']\n'
  printf '}\n'
}

worker_list_json() {
  worker_detect_all
  printf '{\n'
  printf '  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "workers": '
  python3 -c "
import json
data = json.load(open('$OH_WORKER_REGISTRY'))
print(json.dumps(data.get('workers', []), indent=4))
" 2>/dev/null || printf '[]'
  printf '\n}\n'
}

worker_run() {
  local session_id="" dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session) session_id="${2:-}"; [[ -n "$session_id" ]] || die "--session requires a value"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) die "Unknown run option: $1" ;;
    esac
  done

  [[ -n "$session_id" ]] || die "--session SESSION_ID is required"

  local spath sess worker mode card_id
  spath="$(worker_session_path "$session_id")"
  [[ -f "$spath" ]] || die "Session not found: $session_id"

  sess="$(cat "$spath")"
  worker="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['worker'])" "$sess" 2>/dev/null)"
  mode="$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['mode'])" "$sess" 2>/dev/null)"
  card_id="$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('card_id',''))" "$sess" 2>/dev/null)"

  if [[ "$dry" == "1" ]]; then
    printf '{\n  "run": false,\n  "reason": "dry_run",\n  "session_id": '
    oh_json_string "$session_id"
    printf ',\n  "worker": '
    oh_json_string "$worker"
    printf ',\n  "mode": '
    oh_json_string "$mode"
    printf '\n}\n'
    return 0
  fi

  case "$worker" in
    cortex)
      local args=(--mode "$mode" --json)
      [[ -n "$card_id" ]] && args+=(--card "$card_id")
      cortex_workflow_run "${args[@]}"
      ;;
    *)
      die "Live worker execution is not implemented for worker: $worker"
      ;;
  esac
}

worker_recent_session_files() {
  find "$OH_WORKER_SESSIONS_DIR" -name '*.json' -type f -print0 2>/dev/null |
    while IFS= read -r -d '' file; do
      local mtime
      mtime="$(stat -c '%Y' "$file" 2>/dev/null || stat -f '%m' "$file" 2>/dev/null || printf '0')"
      printf '%s %s\n' "$mtime" "$file"
    done |
    sort -rn |
    head -n 10 |
    cut -d' ' -f2-
}

# --- command dispatch --------------------------------------------------

worker_cmd() {
  local sub="${1:-status}"
  shift || true
  case "$sub" in
    status) worker_status_json "$@" ;;
    list) worker_list_json "$@" ;;
    delegate) worker_delegate "$@" ;;
    run) worker_run "$@" ;;
    *) die "Unknown worker command: $sub" ;;
  esac
}
