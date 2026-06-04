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
