Read this before launching the first fix step of a run (any review returned FAIL). Self-contained. Cross-rules: Flash never fixes and never reviews; no agy or OpenCode model reviews; the main session never implements.

# Fix ladders (max 5 steps per task)
When a task fails review, send the defect list to the next step of the ladder for whoever built it. A drained agy Sonnet or Opus step (drained = active marker or `agy-run.sh` exit 3) is replaced silently by the Claude agent of the same tier, so the ladder never gets longer: agy Sonnet -> `claude-sonnet-fixer` (Hydrogen and Flash rows) or `claude-sonnet-builder` (other rows); agy Opus -> `claude-opus-builder`. A drained or tripped Hydrogen, Argon or OpenCode step is skipped.

| Built by | r1 | r2 | r3 | r4 | r5 |
|---|---|---|---|---|---|
| Hydrogen (also a task split across Hydrogen and OpenCode) | **Hydrogen high** (same, a fresh task: whole task diff + defect list) | **Argon medium** | agy Sonnet (medium) | agy Opus (medium) | record and continue |
| OpenCode `build`, `mech` | same model (`--start`) | **Hydrogen high** (cheaper than Argon; skipped when drained or tripped) | **Argon medium** | agy Sonnet | agy Opus |
| Flash (rare last-resort fallback) | **Hydrogen high** | **OpenCode `hard`** (a fresh task, owns all the task's files, `--private` if needed) | **Argon medium** | agy Sonnet | agy Opus |
| Argon | same Argon | agy Sonnet | agy Opus | record and continue | |
| OpenCode `hard` | same model (`--start`) | agy Sonnet | agy Opus | record and continue | |
| OpenCode `large`, `vision`, `av` (agy image/audio ability unverified) | same model (`--start`) | `claude-sonnet-builder` | `claude-opus-builder` | record and continue | |
| `claude-sonnet-builder` (design) | same agent | `claude-opus-builder` | record and continue | | |
| `claude-opus-builder` (design or sensitive) | same agent | record and continue | | | |
| `claude-haiku-builder` (tiny edit) | same agent | `claude-sonnet-builder` | `claude-opus-builder` | | |

- Flash never fixes and never reviews. Never Argon high for fixes. Argon is a ladder step only, never a first build of a non-hard task.
- Hydrogen high is the cheap second step for OpenCode-built work; when it is skipped the row is: same model, Argon medium, agy Sonnet, agy Opus (4 steps).
- agy Sonnet and agy Opus are used only here. They never take a first build, a review, a scout or a design.
- A fix of a split task is one task for the whole task, not per mini-task.
- `--private` tasks keep `--private` in OpenCode fix rounds. A task routed as `opus-sensitive` follows the `claude-opus-builder` row.
- A drained or tripped step is skipped straight to the next. Do not ask the user for that.
- After the last step still failing: record the defect for `.m11/last-run.md` and the user summary, and continue.
- Module 3 mode has its own ladder (in `.claude/m11/drained-pools.md`).

## Fix tasks: brief and launch
- A fix task is named `<id>-r1` ... `<id>-r5`, matching its step in the ladder (a skipped step leaves its number unused). It keeps the original `owns:` (for a split task, every file).
- Its brief body holds the whole task diff and the numbered defect list. For `-r2` and later, add the earlier defects.
- Runs on `agy-run.sh --model hydrogen|argon|sonnet|opus`, on OpenCode (`hard`, or the same role with `--start`), as the ladder says (agy Sonnet and Opus accept only slugs ending in `-r1`..`-r5` with a real `owns:`). Claude steps use the Agent tool with the header (`task:`, `owns:`, optional `worktree:`) and the body.
- `--start <id[:variant]>` makes an OpenCode fix round begin with the model that ran the first time (copy it from the report's `model that ran:` line); the rest of the chain follows if it is limited.
- After reviewing a phase, send all defect fixes together in one message, same caps, `run_in_background: true`. Fix steps of different tasks are independent.
- Print every Claude-plan fix in the plan line and record it in `.m11/last-run.md`.
- After a fix step, review again on the task's whole diff (800-line rule; over 800 moves up to `opus-reviewer`). Tell the reviewer the previous defects.
