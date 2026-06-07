---
name: oh-cortex-worker
description: Delegate planning, research, and review work to the Cortex headless workflow runner via the oh-hermes worker layer.
triggers:
  - cortex worker
  - delegate to cortex
  - cortex plan
  - cortex research
  - cortex review
  - automated workflow
  - headless runner
---

# oh-cortex-worker

Use this when the user wants to delegate a scoped planning, research, or review task to the Cortex headless workflow runner.

## Safety Gates

1. **Cortex starts as planner/researcher/reviewer, not an implementer.** The `implement` mode is disabled by default. Medium/high-risk cards require plan review before implementation.
2. **Always check availability first:** `oh-hermes cortex status --json`. If `available: false`, report the install guide to the user and stop.
3. **Always prefer `--dry-run` first.** Show the command that would run before executing.
4. **Cortex execution is isolated.** Work happens in a git worktree under `~/.oh-hermes/worktrees/` — never in the main working tree.
5. **Results are captured, not auto-applied.** Cortex output goes to `~/.oh-hermes/cortex/runs/<session>/`. A review card is created in Hermes kanban. Nothing is committed or pushed without explicit approval.

## Flow

### 1. Check Status

```bash
oh-hermes cortex status --json
oh-hermes worker list --json
```

If cortex is missing, tell the user:
> Cortex is not installed. Install via `pip install cortex-cli` or follow https://github.com/Mateooo93/cortex-cli.
> Then verify with: `oh-hermes cortex status --json`

### 2. Understand the Card

```bash
oh-hermes kanban show CARD_ID --json
oh-hermes kanban context CARD_ID --json
```

Read the card title, description, status, linked issues, and dependencies.

### 3. Decide Mode

Map the request to a cortex workflow preset:

| Request type | Mode | Cortex preset | Description |
|---|---|---|---|
| "Plan this feature" | `plan` | `plan` | Implementation plan only — no code changes |
| "Research this topic" | `research` | `research` | Investigate repo context, produce findings |
| "Review this change" | `review` | `review` | Review a diff, result, or worker output |
| "Implement this" | — | — | **Disabled by default.** Requires explicit approval and `oh:auto-ok` label. |

### 4. Delegate (Dry Run First)

```bash
oh-hermes worker delegate --to cortex --mode plan --card CARD_ID --dry-run
```

Review the proposed command. If it looks correct, re-run without `--dry-run`:

```bash
oh-hermes worker delegate --to cortex --mode plan --card CARD_ID
```

This creates a worker session and returns a `session_id`.

### 5. Run the Session

```bash
oh-hermes worker run --session SESSION_ID --dry-run
```

Review, then run live:

```bash
oh-hermes worker run --session SESSION_ID
```

Internally this calls:
```bash
cortex workflow run \
  --preset plan \
  --workdir ~/.oh-hermes/worktrees/cortex-CARD_ID-XXXXX \
  --goal "<card context from hermes kanban context CARD_ID>" \
  --output json \
  --save ~/.oh-hermes/cortex/runs/<session>/cortex-workflow.json
```

### 6. Capture Results

After the run completes:
- Read the result from `~/.oh-hermes/cortex/runs/<session>/cortex-workflow.json`
- Summarize findings for the user
- Post a comment to the Hermes kanban card:
  ```bash
  hermes kanban comment CARD_ID --body "## Cortex plan result\n\n<summary>"
  ```
- If the card is linked to a GitHub issue, post a redacted summary:
  ```bash
  oh-hermes github issues sync --dry-run  # review first
  ```

### 7. Review Gate

Create a review card in kanban with the worker output attached. The user (or human worker) reviews before anything is applied:

```bash
hermes kanban create --board default --status todo --title "Review: <plan title>" --body "Review cortex plan output at ~/.oh-hermes/cortex/runs/<session>/cortex-workflow.json"
```

## Mode-Specific Behavior

### plan mode

Cortex reads the kanban card and produces an implementation plan:
- Files to create/modify
- Step-by-step approach
- Estimated complexity
- Risks and dependencies
- Test strategy

Output is a plan document only — no files are modified.

### research mode

Cortex investigates repo context and produces findings:
- Relevant code paths
- Existing patterns
- Dependencies and constraints
- Open questions
- Recommended approach

Output is a research document.

### review mode

Cortex reviews a diff, result, or worker output:
- Correctness assessment
- Style/pattern consistency
- Test coverage gaps
- Security concerns
- Suggested improvements

Output is a review document.

## Boundaries

- **Never enable implement mode** without explicit user instruction and `oh:auto-ok` label on the card.
- **Never run cortex outside a worktree.** The `oh-hermes worker` layer enforces this.
- **Never post unredacted worker output to GitHub.** Use `oh-hermes github issues sync --dry-run` first.
- **Cortex is optional.** If `oh-hermes cortex status --json` returns `available: false`, the core oh-hermes workflow still works — use Hermes natively for planning/research/review.
- **Worker sessions are private.** They live under `~/.oh-hermes/worker-sessions/` and are never synced to GitHub.

## Troubleshooting

| Symptom | Check |
|---|---|
| `available: false` | Run `pip install cortex-cli` or follow the cortex-cli README |
| `workflow_cmd_available: false` | Upgrade cortex to a version with the `workflow` subcommand |
| `mode_disabled` | The mode (e.g. `implement`) is disabled in the worker registry |
| Session not found | Worker sessions are ephemeral; delegate again to create a new one |
| `hermes kanban context` fails | Run `hermes kanban init` first to ensure the kanban database exists |
