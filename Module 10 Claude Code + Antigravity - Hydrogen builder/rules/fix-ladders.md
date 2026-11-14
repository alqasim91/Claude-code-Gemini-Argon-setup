Read this before launching the first fix step of a run (any review returned FAIL). Self-contained. Cross-rules: Hydrogen and Flash never review; Flash never fixes; no agy model reviews; the main session never implements.

# Fix ladders (max 3 steps per task; 4 for Hydrogen- and Flash-built work)
When a task fails review, send the defect list to the next step of the ladder for whoever built it. "Built by" = the model that actually ran (the report's `model that ran`, after any fallback). Skip a step whose agy model is drained (fresh marker, or `agy-run.sh` exit 3 "drained"). A drained model is never replaced by another agy model in a fix.

| Built by | r1 | r2 | r3 | r4 |
|---|---|---|---|---|
| Hydrogen (default route) | **Hydrogen high** (`agy-run.sh --model hydrogen --no-fallback`) | **Argon medium** (`--model argon --no-fallback`) | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium), then record and continue |
| Flash (fallback build) | **Hydrogen high** (`--model hydrogen --no-fallback`) | **Argon medium** (`--model argon --no-fallback`) | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium), then record and continue |
| Argon, agy Sonnet or agy Opus | the same agy model (`agy-run.sh --no-fallback`) | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) | - |
| `claude-sonnet-builder` (design) | the same agent | `claude-opus-builder` | record and continue | - |
| `claude-opus-builder` (design or sensitive) | the same agent | record and continue | - | - |
| `claude-haiku-builder` (tiny edit) | the same agent | `claude-sonnet-builder` | `claude-opus-builder` | - |

- Hydrogen-built ladder, exactly: Hydrogen high, then Argon medium, then Sonnet medium, then Opus medium. Skip drained steps (Hydrogen drained: start at Argon; Hydrogen and Argon drained: start at Sonnet medium; only Argon drained: Hydrogen, then Sonnet medium). Flash-built work uses the same four steps.
- Hydrogen safety switch tripped (`safety-switch.md`)? Skip the Hydrogen step for fixes as well: start at Argon medium.
- Hydrogen and Flash never review; Flash never fixes. Never use Argon high or another agy model for these fixes. Argon drained = fresh `gemini-4-argon-medium` marker, or exit 3 `drained: gemini-4-argon-medium, no fallback`.
- A fix of Hydrogen- or Flash-built work is one task for the whole task, not per mini-task. Hydrogen and Argon fix steps get the whole task diff and the defect list and own all the task's files.
- If the ladder is used up and the task still fails review: record the defect in the final summary and continue.
- Module 3 mode uses its own ladder (see `drained-pools.md`).

## Launching fix steps
- After reviewing a wave, send all defect fixes together in one message, same caps. A fix task keeps the original `owns:` (for a task split into mini-tasks, every file of the task) and gets `task: <id>-r1` ... `<id>-r4`, matching its step in the ladder (a skipped step leaves its number unused: with Hydrogen and Argon drained, a Hydrogen-built fix starts at `-r3`).
- The brief body is the defect list (for a Hydrogen or Argon fix of Hydrogen- or Flash-built work: the whole task diff and the defect list). Add a note if an earlier run stopped partway on a quota error.
- Any Claude-plan fix is printed in the plan line (e.g. `w1-home-r3 -> claude-sonnet-fixer (Claude plan, Sonnet medium; Hydrogen and Argon drained)`) and goes in `.m10/last-run.md`.
