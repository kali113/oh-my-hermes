# oh-hermes

Arch-first companion setup for `NousResearch/hermes-agent`.

`oh-hermes` does not fork Hermes. It backs up your local Hermes home, applies a small set of reversible quality-of-life defaults, installs selected companion modules, and keeps publishable files separate from secrets and private state.

## Quick Start

```bash
cd /home/arch/oh-hermes
./bin/oh-hermes status
./bin/oh-hermes backup
./bin/oh-hermes install
```

## What It Adds

- Hermes-native profile distribution files.
- YOLO/autonomous local defaults with PII redaction enabled.
- Interactive Bash integration so `hermes update` runs `oh-hermes update --system`.
- OpenAI-compatible provider setup helper.
- Local Hermes API server key generation and Workspace token wiring.
- Hermes Workspace as the default visual cockpit.
- GBrain as the default durable brain layer.
- AnySearch as the default current-search skill.
- Optional MemOS and Hermes self-evolution lab modules.
- Durable `systemd --user` MemOS viewer service for local memory inspection.
- Personal secretary/worker layer for private tasks, briefings, decisions, and work logs.
- Weekly `systemd --user` auto-improvement reports.
- Redaction checks before publishing.

## Useful Commands

```bash
oh-hermes doctor
oh-hermes auto-improve
oh-hermes self-review
oh-hermes evolve-skill oh-auto-improve --dry-run
oh-hermes god-mode --once
oh-hermes god-mode --install-timer
oh-hermes secretary brief
oh-hermes secretary --install-timer
oh-hermes auto-improve --install-timer
oh-hermes ui --background
```

`self-review` asks Hermes to critique this setup and stores the answer under `~/.oh-hermes/reports`.
`evolve-skill` wraps `hermes-agent-self-evolution`; default mode is validation-only. Use `--run` only when you want to spend model calls generating a reviewed proposal artifact.
`god-mode` runs the unattended cycle: backups, service repair, durable service setup, diagnostics, self-review, skill evolution, safe auto-apply, redaction checks, and local commits.
`secretary` manages your private personal-agent layer under `~/.oh-hermes/secretary`: inbox, tasks, decisions, work logs, and daily briefings.
See `docs/SELF_IMPROVEMENT.md` for the latest guarded evolution result.
See `docs/PERSONAL_AGENT.md` for the secretary/worker operating model.

## Local Services

After `oh-hermes ui --background` or `oh-hermes god-mode --install-timer`:

- Workspace: `http://127.0.0.1:3000`
- Hermes dashboard: `http://127.0.0.1:9119`
- Hermes API server: `http://127.0.0.1:8642`
- MemOS viewer: `http://127.0.0.1:18800`

```bash
oh-hermes ui --status
oh-hermes ui --remove-service
```

## Publish Rule

Never commit `~/.hermes/.env`, raw `config.yaml` dumps, sessions, logs, memories, Discord tokens, API keys, public IP inventory, or private brain data.
