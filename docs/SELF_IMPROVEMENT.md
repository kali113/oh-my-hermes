# Self-Improvement Loop

`oh-hermes` uses a guarded self-improvement loop:

1. `oh-hermes auto-improve` records private diagnostics under `~/.oh-hermes/reports`.
2. `oh-hermes self-review` asks Hermes for a bounded self-review and records the result.
3. `oh-hermes evolve-skill <skill> --run` uses `hermes-agent-self-evolution` to generate proposal artifacts.
4. Only reviewed, low-risk repo changes are applied.

## God Mode

`oh-hermes god-mode --once` runs the whole loop unattended:

- backs up Hermes config
- reapplies core Hermes defaults
- refreshes default modules
- starts Workspace/dashboard services
- checks Workspace, dashboard, MemOS, and Hermes API health
- writes redacted private diagnostics
- runs bounded Hermes self-review
- evolves each local `oh-*` skill
- applies an evolved skill only when metrics improve, the file differs, and `oh-hermes test` passes
- commits passing repo changes locally when `OH_HERMES_GOD_COMMIT=1`

The timer installed by `oh-hermes god-mode --install-timer` runs hourly with randomized delay.

## Current Run

- Skill: `oh-auto-improve`
- Optimizer path: DSPy MIPROv2 fallback through `hermes-agent-self-evolution`
- Model path: OpenRouter via Hermes `.env`
- Token cap: `HERMES_EVOLUTION_MAX_TOKENS`, default `4096`
- Latest validated proposal: `/home/arch/.oh-hermes/vendor/hermes-agent-self-evolution/output/oh-auto-improve/20260603_223753/`
- Result: constraints passed; holdout score improved from `0.552` to `0.585`
- Applied to repo: no, because the emitted `evolved_skill.md` was identical to the baseline skill text.

## Guardrails

- Private reports are redacted before being written.
- Self-review and evolution commands are timeout-bound.
- Self-evolution output remains a proposal until reviewed.
- API keys and API server tokens must never be committed.
