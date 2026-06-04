---
name: oh-code
description: Code execution workflow with backup, verification, and publish-safe reporting.
triggers:
  - edit oh-hermes
  - test setup
  - publish repo
  - Arch automation
  - local script change
---

# oh-code

Use this for local code changes.

1. Inspect before editing.
2. Back up or rely on git when touching user configuration.
3. Keep changes scoped.
4. Run the narrowest useful checks.
5. Report changed files, verification, and residual risk.
