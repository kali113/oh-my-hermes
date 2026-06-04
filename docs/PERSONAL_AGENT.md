# Personal Agent Layer

`oh-hermes` now has two loops:

1. God mode keeps the Hermes setup healthy and improves the setup itself.
2. Secretary mode keeps a private operating layer for tasks, worker actions, briefings, decisions, and work logs.

## What Improves With Use

- Memory quality improves when useful preferences, decisions, and task outcomes are captured.
- Skills improve when repeated workflows are turned into skill text and pass guarded evolution.
- Briefings improve as the local inbox, task list, decisions, and work logs become richer.
- Worker quality improves when proposed actions are approved, rejected, or completed with useful notes.

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
oh-hermes secretary action reject <action-id-prefix>
oh-hermes secretary action done <action-id-prefix>
oh-hermes secretary action plan
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
oh-hermes secretary --install-timer
oh-hermes secretary status
oh-hermes agent status
oh-hermes agent report
oh-hermes agent context-pack
oh-hermes publish-check
```

`secretary --install-timer` installs the daily briefing timer, half-hourly reminder check, hourly read-only agenda feed sync, and daily routine runner.
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
