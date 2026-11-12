Read this before launching the first fix step of a run (any review returned FAIL). Cross-rules: Module 3 only after the user says so; S = 2 never goes to a free model; no free model reviews.

# Fix ladder (max 4 rounds per task)
A fix task keeps the original `owns:` and gets task id `<id>-r1` ... `<id>-r4`. Fix rounds of different tasks launch together, within caps. Brief: `.m8/briefs/<id>-rN.md` with the numbered defect list.

| Implementer | Round 1 | Round 2 | Round 3 | Round 4 |
|---|---|---|---|---|
| free model, any role except `hard` | same model (`--start`) | the `hard` role (next free model) | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| `hard` role | same model (`--start`) | `claude-sonnet-builder` | `claude-opus-builder` | record and continue |
| Claude builders | same agent | `claude-opus-builder` | record and continue | |

- `--start <id[:variant]>` copies the `model that ran:` line of the first report; the rest of the chain follows if it is limited.
- Tasks on `vision`, `av` or `large`: round 2 goes to `claude-sonnet-builder` instead of the `hard` role (the hard chain cannot read images or audio, and has smaller context), then round 3 `claude-opus-builder`, then record and continue.
- `--private` tasks keep `--private` in rounds 1 and 2. A task routed by S = 2 follows the "Claude builders" row.
- A drained chain in a fix round skips straight to the next Claude step. Do not ask the user for that.
- After the last round still failing: record the defect in `.m8/last-run.md` and continue. Any Claude-plan fix is stated in the plan line and in `.m8/last-run.md`.
