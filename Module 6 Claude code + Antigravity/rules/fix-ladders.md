Read this before launching the first fix step of a run (any review returned FAIL). Self-contained. Cross-rules: Flash never fixes or reviews; no agy model reviews; the main session never implements.

# Fix ladders (max 3 steps per task)
When a task fails review, send the defect list to the next step of the ladder for whoever built it. If the first step's agy model is drained (active marker in `scripts/agy-run.sh --status`, or exit 3), skip straight to the next, Claude, step. A drained model is never replaced by another agy model in a fix.

| Built by | r1 | r2 | r3 |
|---|---|---|---|
| Argon, agy Sonnet or agy Opus | the same agy model (`agy-run.sh --no-fallback`) | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| Flash (Flash route) | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium) | record and continue |
| `claude-sonnet-builder` (design) | the same agent | `claude-opus-builder` | record and continue |
| `claude-opus-builder` (design or sensitive) | the same agent | record and continue | - |
| `claude-haiku-builder` (tiny edit) | the same agent | `claude-sonnet-builder` | `claude-opus-builder` |

- Flash never fixes and never reviews. Its work goes straight to the Flash row. A Flash fix is one task for the whole task (not per mini-task), owning all the task's files.
- If the ladder is used up and the task still fails review: record the defect in the final summary and continue.
- Module 3 mode uses its own ladder (`.claude/m6/drained-builders.md`).

## Fix tasks: brief and launch
- After reviewing a wave, send all defect fixes together in one message, same caps, `run_in_background: true`. Fix steps of different tasks are independent.
- A fix task keeps the original `owns:` and gets `task: <id>-r1`, `<id>-r2` or `<id>-r3`, matching its step in the ladder (a skipped step leaves its number unused). The brief body is the defect list; add a note if an earlier run stopped partway on a quota error.
- agy step: body-only brief `.m6/briefs/<id>-rN.md`, `scripts/agy-run.sh --model <same alias and effort> --no-fallback ...`. Claude steps: the Agent tool with the header and the body.
- Print every Claude-plan fix in the plan line (e.g. `w1-home-r2 -> claude-sonnet-builder (Claude plan, Sonnet high; Argon drained)`) and record it in `.m6/last-run.md`.
- After a fix step, review again on the task's whole diff (400-line rule; over 400 moves up to `opus-reviewer`). Tell the reviewer the previous defects.
