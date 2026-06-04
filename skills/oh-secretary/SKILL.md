---
name: oh-secretary
description: Personal secretary workflow for briefings, reminders, task capture, decisions, and private coordination.
triggers:
  - secretary
  - briefing
  - reminder
  - schedule
  - task capture
  - personal assistant
---

# oh-secretary

Use this when the user wants personal-agent behavior: briefings, task tracking, reminders, decisions, follow-ups, and coordination.

1. Start with the private secretary state under `~/.oh-hermes/secretary`.
2. Use `oh-hermes secretary task add|list|done|due` for tasks instead of unstructured notes.
3. Use `oh-hermes secretary reminders` for due reminders and `oh-hermes secretary brief` for a daily operating summary.
4. Use `oh-hermes secretary agenda import|feed|list|today` for read-only local calendar or agenda files.
5. Capture durable preferences and decisions with `oh-hermes secretary capture` only when they are not better represented as tasks.
6. Check `oh-hermes secretary integrations status` before using email, calendar, notifications, or external task systems.
7. Ask before sending messages, changing calendar/email data, spending money, or publishing anything.
8. Keep private account data out of the publishable repo.
9. When a workflow repeats, turn it into a checklist or skill proposal so god-mode can improve it later.
