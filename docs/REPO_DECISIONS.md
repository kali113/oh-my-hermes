# Repo Decisions

Default modules:

- `gbrain`: durable brain, skills, and MCP server.
- `hermes-workspace`: visual cockpit and swarm control plane.
- `anysearch`: portable current-search skill.

Guarded modules:

- `memos`: real Hermes memory-provider plugin, enabled only after health checks.
- `self-evolution`: lab workflow for improving skills with dry-run, cost caps, and review.

Applied on this workstation:

- `memos`: installed and active as the Hermes memory provider.
- `self-evolution`: installed as a private lab dependency; no optimizer output is auto-applied.
- `systemd/user`: Workspace, dashboard, and weekly auto-improvement report units are installed locally.

Optional UI modules:

- `hermes-web-ui`: not vendored; Business Source License.
- `clawpanel`: not vendored; AGPL-3.0 and OpenClaw-centered.
- `aionui`, `hermes-desktop`, `cc-switch`: useful for some workflows, not default.

Reference-only sources:

- Awesome lists and Orange Book are linked for learning and playbooks, not copied.
