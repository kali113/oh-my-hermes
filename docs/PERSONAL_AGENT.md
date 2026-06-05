# Personal Agent Layer

`oh-hermes` now has two loops:

1. God mode keeps the Hermes setup healthy and improves the setup itself.
2. Secretary mode keeps a private operating layer for tasks, worker actions, worker sessions, reusable lessons, briefings, decisions, and work logs.

## What Improves With Use

- Memory quality improves when useful preferences, decisions, and task outcomes are captured.
- Skills improve when repeated workflows are turned into skill text and pass guarded evolution.
- Briefings improve as the local inbox, task list, decisions, and work logs become richer.
- Worker quality improves when proposed actions are approved, rejected, or completed with useful notes.
- Future context improves when noisy candidate lessons are archived and durable lessons are promoted.

It does not improve just because time passes. It improves when real workflows create durable, useful state.

## Commands

```bash
oh-hermes secretary init
oh-hermes secretary inbox import ~/note.md
oh-hermes secretary inbox list
oh-hermes secretary inbox triage --id note --to task --due 2026-06-05
oh-hermes secretary inbox triage --id note --to action
oh-hermes secretary decision add --title "Use local-first reminders"
oh-hermes secretary action add --title "Draft follow-up" --type message --risk medium --requires-approval 1
oh-hermes secretary action list
oh-hermes secretary action approve <action-id-prefix>
oh-hermes secretary action start <action-id-prefix>
oh-hermes secretary action reject <action-id-prefix>
oh-hermes secretary action done <action-id-prefix>
oh-hermes secretary action plan
oh-hermes secretary session list
oh-hermes secretary session show <session-id-prefix>
oh-hermes secretary learn add --title "Prefer local-first workflows" --body "Keep private state outside the repo."
oh-hermes secretary learn list
oh-hermes secretary learn show <lesson-id-prefix>
oh-hermes secretary learn promote <lesson-id-prefix>
oh-hermes secretary learn archive <lesson-id-prefix>
oh-hermes secretary learn review
oh-hermes secretary sweep
oh-hermes secretary audit
oh-hermes secretary routine add --name "Morning review" --schedule daily
oh-hermes secretary routine run daily
oh-hermes secretary task add --title "Follow up on X" --due 2026-06-05 --priority high
oh-hermes secretary task list
oh-hermes secretary task done <task-id-prefix>
oh-hermes secretary agenda import ~/calendar.ics
oh-hermes secretary agenda feed add --name local-calendar --source ~/calendar.ics
oh-hermes secretary agenda feed sync
oh-hermes secretary agenda list
oh-hermes secretary agenda today
oh-hermes secretary notify status
oh-hermes secretary notify enable-local
oh-hermes secretary notify test --send
oh-hermes secretary reminders
oh-hermes secretary integrations init
oh-hermes secretary integrations status
oh-hermes secretary integrations plan
oh-hermes secretary capture --kind tasks --title "Follow up on X" --body "Context and due date"
oh-hermes secretary worklog "Project name" "Goal for this work session"
oh-hermes secretary brief
oh-hermes secretary focus
oh-hermes secretary focus --json
oh-hermes secretary next
oh-hermes secretary next --json
oh-hermes secretary --install-timer
oh-hermes secretary status
oh-hermes agent status
oh-hermes agent json
oh-hermes agent overview
oh-hermes agent overview --json
oh-hermes agent report
oh-hermes agent context-pack
oh-hermes publish-check
oh-hermes publish-snapshot --out-dir /tmp/oh-hermes-publish
```

`agent json` is the machine-readable personal-agent status surface. Health values use `ok` for verified HTTP success, `running-unreachable` when the backing user service is active but the HTTP probe cannot reach it, and `unknown-unreachable` when the current execution environment blocks local probing.

`agent overview --json` is the one-call control-plane payload for autonomous workers. It includes status, modules, the selected next item, and the current focus queue.

`secretary --install-timer` installs the daily briefing, focus queue, worker action plan, learning review, maintenance sweep, and state audit timer, half-hourly reminder check, hourly read-only agenda feed sync, and daily routine runner.
`secretary init` seeds a default daily review routine if none exists.

## Integration Boundary

Email, calendar, contacts, chat, and notifications are intentionally opt-in. Add them only after deciding:

- which account/provider to connect
- read-only or write access
- what the agent may do without asking
- what always needs confirmation
- where secrets live outside the repo

The integration policy files live under `~/.oh-hermes/secretary/integrations`. They are private state, not repo content.

Agenda imports and feed definitions are read-only private state under `~/.oh-hermes/secretary/agenda`. Import `.ics`, `.md`, or `.txt` exports there instead of committing calendar data.

Inbox imports are private intake items under `~/.oh-hermes/secretary/inbox`. Triage moves them to `inbox/triaged` and creates a task, worker action, decision, or worklog.

## Worker Action Queue

Worker actions are the approval boundary for autonomous work. They live under `~/.oh-hermes/secretary/actions` and carry status, type, risk, project, and approval metadata.

- `proposed`: captured work that should not be treated as done.
- `approved`: work the operator has allowed the agent to perform or continue.
- `rejected`: work that should not be performed.
- `done`: completed work with a status-log note.

Use `--requires-approval 1` for messages, account changes, external writes, purchases, destructive operations, and any task where leaking or changing private data would matter.

## Worker Sessions

Starting an approved action creates a worker session under `~/.oh-hermes/secretary/sessions` and moves the action to `in_progress`. A session captures the proposed work, operating rules, active lessons, and a place for work notes.

- `action start`: create a focused active session from an approved action.
- `session list`: show active worker sessions.
- `session show`: inspect the context for a work session.
- `action done` or `action reject`: closes active sessions for that action and creates a candidate lesson.

This separates planning from execution: actions decide what may be done, sessions hold the working context while it is being done.

## Focus Queue

Focus queues live in `~/.oh-hermes/secretary/briefings/focus-YYYY-MM-DD.md`. They compress active sessions, due tasks, approved actions, proposed actions needing approval, inbox items, and candidate lessons into one priority lane for the day.

Use `oh-hermes secretary focus` when you want the personal agent to decide what deserves attention before starting a work session.

Use `oh-hermes secretary next` or `oh-hermes secretary next --json` when an agent needs exactly one top priority item plus the recommended safe command.

## Learning Loop

Reusable lessons live under `~/.oh-hermes/secretary/learning`. Completing a task or closing a worker action automatically creates a candidate lesson. Daily learning reviews collect active lessons, candidate lessons, recent completed tasks, and closed actions.

- `candidate`: useful-looking but not trusted enough for future context.
- `active`: promoted lesson that appears in daily briefings and context packs.
- `archived`: noisy, stale, or one-off lesson.

This is how usage makes the setup better over time: outcomes become reviewable learning candidates, and only promoted lessons become durable guidance.

## Maintenance Sweeps

Maintenance sweeps live under `~/.oh-hermes/secretary/sweeps`. They surface stale open tasks, stalled worker actions, stale active sessions, candidate lessons waiting for review, and missing integration setup.

Use `oh-hermes secretary sweep` when the agent feels cluttered or when you want a compact cleanup checklist. The daily secretary timer creates one automatically.

## State Audits

State audits live under `~/.oh-hermes/secretary/audits`. They check for malformed statuses, invalid risk or confidence metadata, missing action-session links, active sessions pointing at closed actions, and missing base secretary files.

Use `oh-hermes secretary audit --strict` in scripts when consistency problems should fail the run. The daily timer uses non-strict mode so it records issues without breaking the rest of the secretary loop.
