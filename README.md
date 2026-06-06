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
- Official Hermes Desktop launcher/status integration through `hermes desktop`.
- Linux compatibility doctor for Arch-first use plus best-effort Debian, Fedora, openSUSE, NixOS, Alpine, WSL, Wayland, X11, and headless detection.
- Command-center JSON that aggregates health, modules, Desktop, Linux compatibility, secretary focus, memory, autonomy, and publish readiness.
- GBrain as the default durable brain layer.
- AnySearch as the default current-search skill.
- Optional MemOS and Hermes self-evolution lab modules.
- Durable `systemd --user` MemOS viewer service for local memory inspection.
- Personal secretary/worker layer for private tasks, briefings, decisions, and work logs.
- Worker action queue for proposed, approved, rejected, and completed personal-agent work.
- Worker session files that turn approved actions into focused in-progress work contexts.
- Usage-learning loop for reusable lessons from completed tasks and action outcomes.
- Maintenance sweeps for stale tasks, stalled actions, active sessions, lessons, and integration gaps.
- State audits for malformed tasks, actions, sessions, lessons, routines, and broken action-session links.
- Default daily review routine with a scheduled routine runner.
- Weekly `systemd --user` auto-improvement reports.
- Redaction checks before publishing.

## Useful Commands

```bash
oh-hermes doctor
oh-hermes command-center
oh-hermes command-center --json
oh-hermes linux doctor
oh-hermes linux doctor --json
oh-hermes linux deps
oh-hermes linux service-check --json
oh-hermes desktop status
oh-hermes desktop status --json
oh-hermes desktop doctor
oh-hermes desktop launch
oh-hermes desktop build
oh-hermes memory status --json
oh-hermes memory digest
oh-hermes memory candidates
oh-hermes memory promote-candidates --dry-run
oh-hermes autonomy status --json
oh-hermes autonomy plan
oh-hermes autonomy run --dry-run
oh-hermes agent status
oh-hermes agent json
oh-hermes agent overview
oh-hermes agent overview --json
oh-hermes modules json
oh-hermes agent report
oh-hermes agent context-pack
oh-hermes publish-check
oh-hermes publish-ready --json
oh-hermes publish-snapshot --out-dir /tmp/oh-hermes-publish
oh-hermes auto-improve
oh-hermes self-review
oh-hermes evolve-skill oh-auto-improve --dry-run
oh-hermes god-mode --once
oh-hermes god-mode --install-timer
oh-hermes secretary task add --title "Follow up" --due 2026-06-05
oh-hermes secretary inbox import ~/note.md
oh-hermes secretary inbox triage --id note --to task --due 2026-06-05
oh-hermes secretary action add --title "Draft follow-up" --risk medium --requires-approval 1
oh-hermes secretary action approve <action-id-prefix>
oh-hermes secretary action start <action-id-prefix>
oh-hermes secretary session list
oh-hermes secretary action done <action-id-prefix>
oh-hermes secretary action plan
oh-hermes secretary learn add --title "Prefer local-first workflows"
oh-hermes secretary learn list
oh-hermes secretary learn review
oh-hermes secretary learn promote <lesson-id-prefix>
oh-hermes secretary sweep
oh-hermes secretary audit
oh-hermes secretary routine add --name "Morning review" --schedule daily
oh-hermes secretary routine run daily
oh-hermes secretary task list
oh-hermes secretary agenda import ~/calendar.ics
oh-hermes secretary agenda feed add --name local-calendar --source ~/calendar.ics
oh-hermes secretary agenda feed sync
oh-hermes secretary agenda today
oh-hermes secretary notify enable-local
oh-hermes secretary reminders
oh-hermes secretary integrations status
oh-hermes secretary brief
oh-hermes secretary focus
oh-hermes secretary focus --json
oh-hermes secretary next
oh-hermes secretary next --json
oh-hermes secretary --install-timer
oh-hermes auto-improve --install-timer
oh-hermes ui --background
```

`self-review` asks Hermes to critique this setup and stores the answer under `~/.oh-hermes/reports`.
`evolve-skill` wraps `hermes-agent-self-evolution`; default mode is validation-only. Use `--run` only when you want to spend model calls generating a reviewed proposal artifact.
`god-mode` runs the unattended cycle: backups, service repair, durable service setup, diagnostics, self-review, skill evolution, safe auto-apply, redaction checks, and local commits.
`command-center --json` is the widest machine-readable control-plane view: next item, Linux compatibility, Desktop status, memory, autonomy, publish readiness, and recommendations.
`linux doctor --json` is the Linux portability gate. It detects distro, package manager, session type, desktop environment, user systemd reachability, command dependencies, AppImage/FUSE risk, notifications, browser helpers, and runtime recommendations.
`desktop` wraps first-party Hermes Desktop through `hermes desktop`; third-party desktop sources remain opt-in only.
`memory` summarizes durable learning state and keeps bulk lesson promotion review-first.
`autonomy` exposes guarded dry-run automation plans. Use `god-mode` for the full existing unattended cycle.
`publish-ready --json` reports release gate signals during active development; `publish-check` remains the strict clean-tree publish gate.
`agent status` is the quick command-center view for health, timers, services, tasks, git state, and latest reports.
`agent json` emits the same core command-center signal as parseable JSON for dashboards, scripts, and worker pipelines.
`agent overview --json` aggregates agent status, module inventory, Linux compatibility, Desktop status, memory, autonomy, publish readiness, secretary next item, and focus queue in one control-plane payload.
`modules json` emits module tier, role, upstream source, and current install status for dashboards and setup audits.
Health values use `ok` for verified HTTP success, `running-unreachable` when the backing user service is active but HTTP cannot be reached, and `unknown-unreachable` when local probing is blocked by the execution environment.
`agent context-pack` writes a redacted private summary for future sessions under `~/.oh-hermes/reports`.
`secretary` manages your private personal-agent layer under `~/.oh-hermes/secretary`: inbox, tasks, worker actions, worker sessions, reusable lessons, decisions, work logs, daily briefings, focus queues, next-item selection, daily worker action plans, learning reviews, maintenance sweeps, and state audits.
`publish-check` is the release gate before pushing a redacted public repo.
`publish-snapshot` creates a `git archive HEAD` tarball plus a manifest after the publish gate passes.
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
