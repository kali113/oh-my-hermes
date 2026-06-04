# Personal Agent Layer

`oh-hermes` now has two loops:

1. God mode keeps the Hermes setup healthy and improves the setup itself.
2. Secretary mode keeps a private operating layer for tasks, briefings, decisions, and work logs.

## What Improves With Use

- Memory quality improves when useful preferences, decisions, and task outcomes are captured.
- Skills improve when repeated workflows are turned into skill text and pass guarded evolution.
- Briefings improve as the local inbox, task list, decisions, and work logs become richer.

It does not improve just because time passes. It improves when real workflows create durable, useful state.

## Commands

```bash
oh-hermes secretary init
oh-hermes secretary task add --title "Follow up on X" --due 2026-06-05 --priority high
oh-hermes secretary task list
oh-hermes secretary task done <task-id-prefix>
oh-hermes secretary agenda import ~/calendar.ics
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

`secretary --install-timer` installs both the daily briefing timer and the half-hourly reminder check.

## Integration Boundary

Email, calendar, contacts, chat, and notifications are intentionally opt-in. Add them only after deciding:

- which account/provider to connect
- read-only or write access
- what the agent may do without asking
- what always needs confirmation
- where secrets live outside the repo

The integration policy files live under `~/.oh-hermes/secretary/integrations`. They are private state, not repo content.

Agenda imports are read-only copies under `~/.oh-hermes/secretary/agenda`. Import `.ics`, `.md`, or `.txt` exports there instead of committing calendar data.
