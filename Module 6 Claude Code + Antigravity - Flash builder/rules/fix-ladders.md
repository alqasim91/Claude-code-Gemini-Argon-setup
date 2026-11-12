Read this before launching the first fix step of a run (any review returned FAIL). Self-contained. Cross-rules: Flash never fixes and never reviews; no agy model reviews; the main session never implements.

# Fix ladders (max 3 steps per task)
When a task fails review, send the defect list to the next step of the ladder for whoever built it. If the first step's agy model is drained (fresh marker, or `agy-run.sh` exit 3 "drained"), skip straight to the next, Claude, step. A drained model is never replaced by another agy model in a fix.

| Built by | r1 | r2 | r3 |
|---|---|---|---|
| Argon, agy Sonnet or agy Opus | the same agy model (`agy-run.sh --no-fallback`) | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| Flash (default route) | **Argon medium** (`agy-run.sh --model argon --no-fallback`; gets the whole task diff and the defect list, owns all the task's files) | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium), then record and continue |
| `claude-sonnet-builder` (design) | the same agent | `claude-opus-builder` | record and continue |
| `claude-opus-builder` (design or sensitive) | the same agent | record and continue | - |
| `claude-haiku-builder` (tiny edit) | the same agent | `claude-sonnet-builder` | `claude-opus-builder` |

- Flash never fixes and never reviews. Its work goes straight to the Flash row.
- Flash-built ladder, exactly: Argon medium, then Sonnet medium, then Opus medium. Argon drained (fresh `gemini-4-argon-medium` marker, or exit 3 `drained: gemini-4-argon-medium, no fallback`)? Skip r1 and start at Sonnet medium. Never use Argon high or another agy model for these fixes.
- A fix of Flash-built work is one task for the whole task, not per mini-task.
- If the ladder is used up and the task still fails review: record the defect in the final summary and continue.
- Module 3 mode uses its own ladder (see `drained-pools.md`).

## Launching fix steps
- After reviewing a wave, send all defect fixes together in one message, same caps. A fix task keeps the original `owns:` (for a task split into mini-tasks, every file of the task) and gets `task: <id>-r1`, `<id>-r2` or `<id>-r3`, matching its step in the ladder (a skipped step leaves its number unused: with Argon drained, a Flash-built fix starts at `-r2`).
- The brief body is the defect list (for an Argon fix of Flash work: the whole task diff and the defect list). Add a note if an earlier run stopped partway on a quota error.
- Any Claude-plan fix is printed in the plan line (e.g. `w1-home-r2 -> claude-sonnet-builder (Claude plan, Sonnet high; Argon drained)` or `w1-pages-r2 -> claude-sonnet-fixer (Claude plan, Sonnet medium; Argon drained)`) and goes in `.m6/last-run.md`.
