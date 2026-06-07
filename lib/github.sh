#!/usr/bin/env bash

# GitHub bridge for oh-hermes.
# Uses `gh` CLI because auth is already verified by the user.
# Defaults to --dry-run for all mutating operations.
# Never syncs private secretary state to GitHub.

OH_GITHUB_LABELS=(
  "oh:type/feature"
  "oh:type/bug"
  "oh:type/plan"
  "oh:type/research"
  "oh:type/review"
  "oh:type/docs"
  "oh:status/triage"
  "oh:status/spec"
  "oh:status/ready"
  "oh:status/running"
  "oh:status/blocked"
  "oh:status/done"
  "oh:worker/hermes"
  "oh:worker/cortex"
  "oh:worker/human"
  "oh:risk/low"
  "oh:risk/medium"
  "oh:risk/high"
  "oh:auto-ok"
  "oh:needs-human-review"
)

github_require() {
  need gh
  if ! gh auth status >/dev/null 2>&1; then
    die "gh is not authenticated. Run: gh auth login"
  fi
}

github_repo() {
  gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || true
}

# --- labels ------------------------------------------------------------

github_labels_list_json() {
  github_require
  local repo
  repo="$(github_repo)"
  [[ -n "$repo" ]] || die "Could not determine GitHub repo"

  printf '{\n'
  printf '  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "repo": '; oh_json_string "$repo"
  printf ',\n  "labels": ['
  local first=1 label
  while IFS= read -r label; do
    [[ -n "$label" ]] || continue
    [[ "$first" == "1" ]] || printf ','
    printf '\n    '; oh_json_string "$label"
    first=0
  done < <(gh label list --repo "$repo" --json name -q '.[].name' 2>/dev/null || true)
  [[ "$first" == "1" ]] || printf '\n  '
  printf ']\n'
  printf '}\n'
}

github_labels_ensure() {
  local dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      *) shift ;;
    esac
  done

  github_require
  local repo existing created=0 skipped=0 errors=0
  repo="$(github_repo)"
  [[ -n "$repo" ]] || die "Could not determine GitHub repo"

  existing="$(gh label list --repo "$repo" --json name -q '.[].name' 2>/dev/null || true)"

  printf '{\n'
  printf '  "generated": '; oh_json_string "$(date -Is)"
  printf ',\n  "repo": '; oh_json_string "$repo"
  printf ',\n  "dry_run": %s' "$dry"
  printf ',\n  "labels": ['

  local first=1 label_name color description
  for label_spec in "${OH_GITHUB_LABELS[@]}"; do
    label_name="$label_spec"

    # Derive color and description from label name
    case "$label_name" in
      oh:type/*)     color="0052CC"; description="Work type: ${label_name#oh:type/}" ;;
      oh:status/*)   color="006B75"; description="Workflow status: ${label_name#oh:status/}" ;;
      oh:worker/*)   color="8250DF"; description="Assigned worker: ${label_name#oh:worker/}" ;;
      oh:risk/*)     color="BF2600"; description="Risk level: ${label_name#oh:risk/}" ;;
      oh:auto-ok)    color="36B37E"; description="Safe for automated application" ;;
      oh:needs-human-review) color="FF8C00"; description="Requires human review before merge" ;;
      *)             color="999999"; description="" ;;
    esac

    local action
    if echo "$existing" | grep -Fqx "$label_name"; then
      action="exists"
      skipped=$((skipped + 1))
    else
      action="create"
      created=$((created + 1))
      if [[ "$dry" != "1" ]]; then
        gh label create "$label_name" --repo "$repo" --color "$color" ${description:+--description "$description"} 2>/dev/null || {
          action="error"
          errors=$((errors + 1))
        }
      else
        printf '[dry-run] gh label create %s --color %s\n' "$label_name" "$color" >&2
      fi
    fi

    [[ "$first" == "1" ]] || printf ','
    printf '\n    {'
    printf '"name": '; oh_json_string "$label_name"
    printf ', "action": '; oh_json_string "$action"
    printf ', "color": '; oh_json_string "$color"
    printf '}'
    first=0
  done

  printf '\n  ]'
  printf ',\n  "summary": {'
  printf '"created": %s, "skipped": %s, "errors": %s' "$created" "$skipped" "$errors"
  printf '}\n'
  printf '}\n'
}

# --- issues ------------------------------------------------------------

github_issues_import() {
  local dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      *) shift ;;
    esac
  done

  github_require
  local repo generated
  repo="$(github_repo)"
  generated="$(date -Is)"

  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "repo": '; oh_json_string "$repo"
  printf ',\n  "dry_run": %s' "$dry"
  printf ',\n  "imported": []'
  printf ',\n  "message": '
  oh_json_string "github issues import runs via kanban intake. Use oh-hermes kanban cards --json to review candidates, then oh-hermes github issues sync to push selected cards."
  printf '\n}\n'
}

github_issues_sync() {
  local dry=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry=1; shift ;;
      *) shift ;;
    esac
  done

  github_require
  local repo generated
  repo="$(github_repo)"
  generated="$(date -Is)"

  printf '{\n'
  printf '  "generated": '; oh_json_string "$generated"
  printf ',\n  "repo": '; oh_json_string "$repo"
  printf ',\n  "dry_run": %s' "$dry"
  printf ',\n  "synced": []'
  printf ',\n  "message": '
  oh_json_string "github issues sync bridges kanban cards to GitHub issues. Cards in 'ready' status with oh:auto-ok label are candidates for automated issue creation. Medium/high-risk cards require human review."
  printf '\n}\n'
}

# --- comment posting (redacted) ----------------------------------------

github_post_worker_summary() {
  local issue_number="$1" summary="$2" dry="${3:-1}"
  github_require
  local repo
  repo="$(github_repo)"

  if [[ "$dry" == "1" ]]; then
    printf '[dry-run] gh issue comment %s --repo %s --body ...\n' "$issue_number" "$repo"
    return 0
  fi

  gh issue comment "$issue_number" --repo "$repo" --body "$summary" 2>/dev/null || {
    warn "Failed to post comment to issue #$issue_number"
    return 1
  }
}

# --- command dispatch --------------------------------------------------

github_cmd() {
  local sub="${1:-labels}"
  shift || true
  case "$sub" in
    labels)
      local sub2="${1:-list}"
      shift || true
      case "$sub2" in
        list) github_labels_list_json "$@" ;;
        ensure) github_labels_ensure "$@" ;;
        *) die "Unknown github labels command: $sub2" ;;
      esac
      ;;
    issues)
      local sub2="${1:-import}"
      shift || true
      case "$sub2" in
        import) github_issues_import "$@" ;;
        sync) github_issues_sync "$@" ;;
        *) die "Unknown github issues command: $sub2" ;;
      esac
      ;;
    *) die "Unknown github command: $sub" ;;
  esac
}
