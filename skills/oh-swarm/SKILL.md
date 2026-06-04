---
name: oh-swarm
description: Multi-agent task decomposition for Hermes Workspace or Hermes workers.
triggers:
  - workspace
  - dashboard
  - multi-agent
  - swarm
  - service orchestration
---

# oh-swarm

Use this for long tasks that benefit from parallel lanes.

1. Split into 2-6 tasks with machine-checkable exit criteria.
2. Assign one role per worker.
3. Require proof-bearing checkpoints.
4. Keep irreversible external actions behind a human review gate.
5. Summarize blockers and next actions in the inbox/report surface.
