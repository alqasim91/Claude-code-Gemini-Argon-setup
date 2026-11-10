Read this before launching the first fix step of a run (any review returned FAIL). Self-contained. Cross-rules: Flash never fixes and never reviews; no agy or OpenCode model reviews; the main session never implements.

# Fix ladders (max 4 steps per task)
When a task fails review, send the defect list to the next step of the ladder for whoever built it. A drained agy step (Argon excepted; drained = active marker or `agy-run.sh` exit 3) is replaced by the Claude agent of the same tier, so the ladder never gets longer: agy Sonnet -> `claude-sonnet-fixer` (Flash row) or `claude-sonnet-builder` (other rows); agy Opus -> `claude-opus-builder`. A drained Argon step or OpenCode step is skipped.

| Built by | r1 | r2 | r3 | r4 |
|---|---|---|---|---|
| Flash (also a task split across Flash and OpenCode) | **OpenCode `hard` role** (a fresh task: whole task diff + defect list, owns all the task's files, `--private` if needed) | **Argon medium** | agy Sonnet (medium) | agy Opus (medium) |
| OpenCode `build`, `mech` | same model (`--start`) | **Argon medium** | agy Sonnet | agy Opus |
| Argon | same Argon | agy Sonnet | agy Opus | record and continue |
| OpenCode `hard` | same model (`--start`) | agy Sonnet | agy Opus | record and continue |
| OpenCode `large`, `vision`, `av` (agy image/audio ability unverified) | same model (`--start`) | `claude-sonnet-builder` | `claude-opus-builder` | record and continue |
| `claude-sonnet-builder` (design) | same agent | `claude-opus-builder` | record and continue | |
| `claude-opus-builder` (design or sensitive) | same agent | record and continue | | |
| `claude-haiku-builder` (tiny edit) | same agent | `claude-sonnet-builder` | `claude-opus-builder` | |

- Flash never fixes and never reviews; its first fix goes to OpenCode. Never Argon high for fixes.
- agy Sonnet and agy Opus are used only here. They never take a first build, a review, a scout or a design.
- A fix of a split task is one task for the whole task, not per mini-task.
- `--private` tasks keep `--private` in OpenCode fix rounds. A task routed as `opus-sensitive` follows the `claude-opus-builder` row.
- A drained OpenCode chain in a fix round skips straight to the next step. Do not ask the user for that.
- After the last step still failing: record the defect for `.m9/last-run.md` and the user summary, and continue.
- Module 3 mode has its own ladder (in `.claude/m9/drained-pools.md`).

## Fix tasks: brief and launch
- A fix task is named `<id>-r1` ... `<id>-r4`, matching its step in the ladder (a skipped step leaves its number unused). It keeps the original `owns:` (for a split task, every file).
- Its brief body holds the whole task diff and the numbered defect list. For `-r2` and later, add the earlier defects.
- Runs on OpenCode `hard` (a Flash-built task's first fix), or on `agy-run.sh --model argon|sonnet|opus` as the ladder says (agy Sonnet and Opus accept only slugs ending in `-r1`..`-r4` with a real `owns:`). Claude steps use the Agent tool with the header (`task:`, `owns:`, optional `worktree:`) and the body.
- `--start <id[:variant]>` makes an OpenCode fix round begin with the model that ran the first time (copy it from the report's `model that ran:` line); the rest of the chain follows if it is limited.
- After reviewing a phase, send all defect fixes together in one message, same caps, `run_in_background: true`. Fix steps of different tasks are independent.
- Print every Claude-plan fix in the plan line and record it in `.m9/last-run.md`.
- After a fix step, review again on the task's whole diff (800-line rule; over 800 moves up to `opus-reviewer`). Tell the reviewer the previous defects.
