#!/usr/bin/env bash

install_anysearch() {
  need curl
  need unzip
  local dest tmp
  dest="$HOME/.hermes/skills/anysearch"
  tmp="$(mktemp -d)"
  if [[ -d "$dest/scripts" ]]; then
    info "AnySearch skill already installed at $dest"
    return 0
  fi
  info "Installing AnySearch skill to $dest"
  run mkdir -p "$(dirname "$dest")"
  if [[ "$OH_DRY_RUN" == "1" ]]; then
    printf '[dry-run] download anysearch-ai/anysearch-skill archive\n'
    return 0
  fi
  curl -fsSL -o "$tmp/anysearch.zip" https://github.com/anysearch-ai/anysearch-skill/archive/refs/heads/main.zip
  unzip -q "$tmp/anysearch.zip" -d "$tmp"
  rm -rf "$dest"
  mv "$tmp"/anysearch-skill-main "$dest"
  if have python3; then
    printf 'Runtime: Python\nCommand: python3 %s/scripts/anysearch_cli.py\n' "$dest" > "$dest/runtime.conf"
  elif have node; then
    printf 'Runtime: Node.js\nCommand: node %s/scripts/anysearch_cli.js\n' "$dest" > "$dest/runtime.conf"
  else
    printf 'Runtime: Bash\nCommand: bash %s/scripts/anysearch_cli.sh\n' "$dest" > "$dest/runtime.conf"
  fi
  rm -rf "$tmp"
}

status_anysearch() {
  if [[ -f "$HOME/.hermes/skills/anysearch/SKILL.md" ]]; then
    printf 'installed\n'
  else
    printf 'missing\n'
  fi
}

