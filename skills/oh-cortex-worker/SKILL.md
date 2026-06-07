---
name: oh-cortex-worker
description: Delegate planning, research, and review work to Cortex headless prompts via the oh-hermes worker layer.
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

Use this when the user wants to delegate a scoped planning, research, or review task to Cortex through the oh-hermes worker layer.

## Safety Gates

1. **Cortex starts as planner/researcher/reviewer, not an implementer.** The `implement` mode is disabled by default. Medium/high-risk cards require plan review before implementation.
2. **Always check availability first:** `oh-hermes cortex status --json`. If `available: false`, report the install guide to the user and stop.
3. **Always prefer `--dry-run` first.** Show the command that would run before executing.
4. **Cortex execution is isolated.** Work happens in `CORTEX_WORKTREE_ROOT`, defaulting to `$OH_STATE_DIR/worktrees` (`~/.oh-hermes/worktrees` by default) — never in the main working tree.
5. **Results are captured, not auto-applied.** Cortex output goes to `$OH_STATE_DIR/cortex/runs/<session>` (`~/.oh-hermes/cortex/runs/<session>` by default). A review card is created in Hermes kanban. Nothing is committed or pushed without explicit approval.

## Flow

### 1. Check Status

```bash
oh-hermes cortex status --json
oh-hermes worker list --json
```

If cortex is missing, tell the user:
> Cortex is not installed. Install the latest Linux binary from https://github.com/Mateooo93/cortex-cli/releases or build from source with Go.
> Then verify with: `oh-hermes cortex status --json`

### 2. Understand the Card

```bash
oh-hermes kanban show CARD_ID --json
oh-hermes kanban context CARD_ID --json
```

Read the card title, description, status, linked issues, and dependencies.

### 3. Decide Mode

Map the request to a Cortex mode:

| Request type | Mode | Prompt behavior | Description |
|---|---|---|---|
| "Plan this feature" | `plan` | planning-only prompt | Implementation plan only — no code changes |
| "Research this topic" | `research` | research-only prompt | Investigate repo context, produce findings |
| "Review this change" | `review` | review-only prompt | Review a diff, result, or worker output |
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

Internally this calls the current Cortex headless CLI:
```bash
cortex \
  --workdir "$CORTEX_WORKTREE_ROOT/cortex-CARD_ID-XXXXX" \
  -p "<mode-specific prompt built from hermes kanban context CARD_ID>"
```

### 6. Capture Results

After the run completes:
- Read the result from `$OH_STATE_DIR/cortex/runs/<session>/cortex-result.json`
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
hermes kanban create --board default --status todo --title "Review: <plan title>" --body "Review cortex plan output at $OH_STATE_DIR/cortex/runs/<session>/cortex-result.json"
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
| `available: false` | Install the latest Linux binary or build from source with Go |
| `headless_cmd_available: false` | Upgrade cortex to a version with the `-p` headless prompt flag |
| `mode_disabled` | The mode (e.g. `implement`) is disabled in the worker registry |
| Session not found | Worker sessions live in `OH_WORKER_SESSIONS_DIR`, defaulting to `$OH_STATE_DIR/worker-sessions`; delegate again to create one |
| `hermes kanban context` fails | Run `hermes kanban init` first to ensure the kanban database exists |
