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
oh-hermes secretary capture --kind tasks --title "Follow up on X" --body "Context and due date"
oh-hermes secretary worklog "Project name" "Goal for this work session"
oh-hermes secretary brief
oh-hermes secretary --install-timer
oh-hermes secretary status
```

## Integration Boundary

Email, calendar, contacts, chat, and notifications are intentionally opt-in. Add them only after deciding:

- which account/provider to connect
- read-only or write access
- what the agent may do without asking
- what always needs confirmation
- where secrets live outside the repo
