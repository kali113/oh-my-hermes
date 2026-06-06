#!/usr/bin/env bash

publish_check() {
  local failed=0 tracked_private dirty
  info "Running publish-readiness checks"

  redact_check "$OH_ROOT" || failed=1
  "$OH_ROOT/bin/oh-hermes" test || failed=1

  info "Verifying systemd user units"
  systemd-analyze verify --user "$OH_ROOT"/systemd/user/*.service "$OH_ROOT"/systemd/user/*.timer || failed=1

  info "Checking git worktree"
  dirty="$(git -C "$OH_ROOT" status --short)"
  if [[ -n "$dirty" ]]; then
    printf '%s\n' "$dirty"
    failed=1
  fi

  info "Checking tracked private/generated paths"
  tracked_private="$(git -C "$OH_ROOT" ls-files | awk '
    /^\.env\.EXAMPLE$/ { next }
    /(^|\/)\.env($|\.)/ ||
    /(^|\/)(vendor|runtime|backups|reports|node_modules)\// ||
    /(^|\/)(auth|token|secret|credentials)\.(json|yaml|yml|env)$/ ||
    /^.*\.log$/ {
      print
    }
  ')"
  if [[ -n "$tracked_private" ]]; then
    printf '%s\n' "$tracked_private"
    failed=1
  fi

  info "Checking required publish docs"
  for file in README.md docs/PERSONAL_AGENT.md docs/SELF_IMPROVEMENT.md docs/REPO_DECISIONS.md .env.EXAMPLE .gitignore; do
    if [[ ! -f "$OH_ROOT/$file" ]]; then
      printf 'missing %s\n' "$file"
      failed=1
    fi
  done

  if [[ "$failed" == "0" ]]; then
    info "Publish check passed"
  else
    die "Publish check failed"
  fi
}

publish_ready_shell_syntax_status() {
  local file
  while IFS= read -r file; do
    bash -n "$file" >/dev/null 2>&1 || { printf 'failed:%s\n' "$file"; return 0; }
  done < <(find "$OH_ROOT" -type f \( -name '*.sh' -o -path "$OH_ROOT/bin/oh-hermes" \) -not -path '*/vendor/*')
  printf 'ok\n'
}

publish_ready_tests_status() {
  if [[ "${OH_HERMES_PUBLISH_READY_FAST:-0}" == "1" ]]; then
    printf 'skipped-fast\n'
  elif [[ "${OH_HERMES_PUBLISH_READY_CHECKING_TESTS:-0}" == "1" ]]; then
    printf 'skipped-nested\n'
  elif OH_HERMES_PUBLISH_READY_CHECKING_TESTS=1 "$OH_ROOT/bin/oh-hermes" test >/dev/null 2>&1; then
    printf 'ok\n'
  else
    printf 'failed\n'
  fi
}

publish_ready_redaction_status() {
  redact_check "$OH_ROOT" >/dev/null 2>&1 && printf 'ok\n' || printf 'failed\n'
}

publish_ready_systemd_status() {
  if ! have systemd-analyze; then
    printf 'missing\n'
  elif systemd-analyze verify --user "$OH_ROOT"/systemd/user/*.service "$OH_ROOT"/systemd/user/*.timer >/dev/null 2>&1; then
    printf 'ok\n'
  else
    local output
    output="$(systemd-analyze verify --user "$OH_ROOT"/systemd/user/*.service "$OH_ROOT"/systemd/user/*.timer 2>&1 || true)"
    case "$output" in
      *"Operation not permitted"*|*"Failed to turn off SO_PASSRIGHTS"*) printf 'environment-unreachable\n' ;;
      *) printf 'failed\n' ;;
    esac
  fi
}

publish_ready_dirty_count() {
  if [[ -d "$OH_ROOT/.git" ]]; then
    git -C "$OH_ROOT" status --short 2>/dev/null | wc -l | tr -d ' '
  else
    printf '0'
  fi
}

publish_ready_remote_status() {
  if [[ ! -d "$OH_ROOT/.git" ]]; then
    printf 'not-a-git-repo\n'
  elif git -C "$OH_ROOT" remote get-url origin >/dev/null 2>&1; then
    printf 'configured\n'
  else
    printf 'missing\n'
  fi
}

publish_ready_private_paths() {
  if [[ ! -d "$OH_ROOT/.git" ]]; then
    return 0
  fi
  git -C "$OH_ROOT" ls-files | awk '
    /^\.env\.EXAMPLE$/ { next }
    /(^|\/)\.env($|\.)/ ||
    /(^|\/)(vendor|runtime|backups|reports|node_modules)\// ||
    /(^|\/)(auth|token|secret|credentials)\.(json|yaml|yml|env)$/ ||
    /^.*\.log$/ {
      print
    }
  '
}

publish_ready_docs_status() {
  local file missing=0
  for file in README.md docs/PERSONAL_AGENT.md docs/SELF_IMPROVEMENT.md docs/REPO_DECISIONS.md .env.EXAMPLE .gitignore; do
    [[ -f "$OH_ROOT/$file" ]] || missing=1
  done
  [[ "$missing" == "0" ]] && printf 'ok\n' || printf 'missing\n'
}

publish_ready_json() {
  local redaction syntax tests systemd dirty remote private_count docs status
  redaction="$(publish_ready_redaction_status)"
  syntax="$(publish_ready_shell_syntax_status)"
  tests="$(publish_ready_tests_status)"
  systemd="$(publish_ready_systemd_status)"
  dirty="$(publish_ready_dirty_count)"
  remote="$(publish_ready_remote_status)"
  private_count="$(publish_ready_private_paths | wc -l | tr -d ' ')"
  docs="$(publish_ready_docs_status)"
  status="ready"
  [[ "$redaction" == "ok" ]] || status="not_ready"
  [[ "$syntax" == "ok" ]] || status="not_ready"
  case "$tests" in ok|skipped-fast|skipped-nested) ;; *) status="not_ready" ;; esac
  case "$systemd" in ok|environment-unreachable|missing) ;; *) status="not_ready" ;; esac
  [[ "${dirty:-0}" == "0" ]] || status="not_ready"
  [[ "${private_count:-0}" == "0" ]] || status="not_ready"
  [[ "$docs" == "ok" ]] || status="not_ready"
  printf '{\n'
  printf '  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "status": '; oh_json_string "$status"
  printf ',\n  "checks": {\n'
  printf '    "redaction": '; oh_json_string "$redaction"
  printf ',\n    "shell_syntax": '; oh_json_string "$syntax"
  printf ',\n    "tests": '; oh_json_string "$tests"
  printf ',\n    "systemd_user_units": '; oh_json_string "$systemd"
  printf ',\n    "git_dirty_files": %s,\n' "${dirty:-0}"
  printf '    "tracked_private_paths": %s,\n' "${private_count:-0}"
  printf '    "required_docs": '; oh_json_string "$docs"
  printf ',\n    "origin_remote": '; oh_json_string "$remote"
  printf '\n  },\n'
  printf '  "next_command": '
  if [[ "$status" == "ready" ]]; then
    oh_json_string "oh-hermes publish-check"
  elif [[ "${dirty:-0}" != "0" ]]; then
    oh_json_string "git -C $OH_ROOT status --short"
  else
    oh_json_string "oh-hermes test"
  fi
  printf '\n}\n'
}

publish_ready() {
  if [[ "${1:-}" == "--json" ]]; then
    publish_ready_json
    return 0
  fi
  local payload status
  payload="$(publish_ready_json)"
  status="$(awk -F'"' '/"status":/ {print $4; exit}' <<< "$payload")"
  printf '# oh-hermes Publish Ready\n\n'
  printf '```json\n%s\n```\n' "$payload"
  [[ "$status" == "ready" ]]
}

publish_snapshot() {
  local out_dir="" skip_check=0 archive manifest revision tracked_count
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --out-dir) out_dir="${2:-}"; [[ -n "$out_dir" ]] || die "--out-dir needs a value"; shift 2 ;;
      --skip-check) skip_check=1; shift ;;
      *) die "Unknown publish-snapshot option: $1" ;;
    esac
  done

  need git
  [[ -d "$OH_ROOT/.git" ]] || die "publish-snapshot requires a git checkout"
  if [[ "$skip_check" != "1" ]]; then
    publish_check
  else
    redact_check "$OH_ROOT"
  fi

  revision="$(git -C "$OH_ROOT" rev-parse --short=12 HEAD)"
  tracked_count="$(git -C "$OH_ROOT" ls-files | wc -l)"
  [[ -n "$out_dir" ]] || out_dir="$OH_STATE_DIR/publish"
  mkdir -p "$out_dir"
  archive="$out_dir/oh-hermes-$revision.tar.gz"
  manifest="$out_dir/oh-hermes-$revision.MANIFEST.md"

  git -C "$OH_ROOT" archive --format=tar.gz --prefix="oh-hermes-$revision/" -o "$archive" HEAD
  {
    printf '# oh-hermes Publish Snapshot\n\n'
    printf -- '- Generated: `%s`\n' "$(date -Is)"
    printf -- '- Revision: `%s`\n' "$revision"
    printf -- '- Archive: `%s`\n' "$archive"
    printf -- '- Tracked files: `%s`\n\n' "$tracked_count"
    printf '## Contents\n\n'
    printf 'This archive is produced from `git archive HEAD`; private runtime state under `~/.oh-hermes`, vendored checkouts, logs, reports, and secrets are not included unless they are tracked by git.\n\n'
    printf '## Verification\n\n'
    if [[ "$skip_check" == "1" ]]; then
      printf -- '- Full publish check: `skipped by --skip-check`\n'
      printf -- '- Redaction check: `passed`\n'
    else
      printf -- '- Full publish check: `passed`\n'
    fi
  } > "$manifest"
  printf '%s\n' "$archive"
  printf '%s\n' "$manifest"
}
