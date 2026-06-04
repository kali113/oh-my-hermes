#!/usr/bin/env bash

gbrain_search_mode_prompt() {
  if ! is_tty; then
    warn "Non-interactive GBrain setup: leaving search mode unchanged"
    return 0
  fi
  cat <<'EOF'

GBrain search mode controls retrieval payload and downstream model cost.

Per-query cost @ 10K queries/mo:

                  Haiku 4.5     Sonnet 4.6    Opus 4.7
  conservative    $40/mo        $120/mo       $200/mo
  balanced        $100/mo       $300/mo       $500/mo
  tokenmax        $200/mo       $600/mo       $1,000/mo

Recommended for this Hermes setup: balanced.
EOF
  printf 'Choose search mode [balanced]: '
  local mode
  IFS= read -r mode
  mode="${mode:-balanced}"
  case "$mode" in
    conservative|balanced|tokenmax) run gbrain config set search.mode "$mode" ;;
    *) warn "Invalid mode '$mode'; keeping existing GBrain default" ;;
  esac
}

install_gbrain() {
  need bun
  need hermes
  if ! have gbrain; then
    info "Installing GBrain via Bun"
    run bun install -g github:garrytan/gbrain
  else
    info "GBrain already installed"
  fi

  if [[ ! -f "$HOME/.gbrain/config.json" ]]; then
    info "Initializing GBrain"
    if [[ -n "${ZEROENTROPY_API_KEY:-}" || -n "${OPENAI_API_KEY:-}" ]]; then
      run gbrain init --pglite
      gbrain_search_mode_prompt
    else
      warn "No ZEROENTROPY_API_KEY or OPENAI_API_KEY in environment; initializing GBrain without embeddings"
      run gbrain init --pglite --no-embedding
    fi
  fi

  if ! hermes mcp list 2>/dev/null | grep -q 'gbrain'; then
    info "Adding GBrain MCP server to Hermes"
    if [[ "$OH_DRY_RUN" == "1" ]]; then
      run hermes mcp add gbrain --command gbrain --args serve
    else
      printf 'Y\n' | hermes mcp add gbrain --command gbrain --args serve
    fi
  else
    info "Hermes MCP already has gbrain"
  fi
}

status_gbrain() {
  if have gbrain; then
    printf 'installed'
    if hermes mcp list 2>/dev/null | grep -q 'gbrain'; then
      printf ', mcp configured\n'
    else
      printf ', mcp missing\n'
    fi
  else
    printf 'missing\n'
  fi
}
