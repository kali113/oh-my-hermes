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
