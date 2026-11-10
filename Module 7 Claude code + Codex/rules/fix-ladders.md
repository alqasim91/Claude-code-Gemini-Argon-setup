Read this before launching the first fix round of a run (any review returned FAIL). Self-contained. Cross-rules: the Codex 5-hour limit is a stop-and-tell; the weekly limit is the one question; never switch to Claude builders without the user saying Module 3; never bypass the sandbox.

# Fix ladder (max 3 rounds per task)
A fix task keeps the original `owns:` and gets task id `<id>-r1`, `<id>-r2`, `<id>-r3`. Fix rounds of different tasks launch together, within caps. Round 1 uses the same model as the original run.

| Implementer | Round 1 | Round 2 | Round 3 |
|---|---|---|---|
| sol (medium or high) | same model | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| luna or terra | same model | sol high | `claude-sonnet-builder` |
| Claude builders | same agent | `claude-opus-builder` | record and continue |

- A task routed to `claude-sonnet-builder` by S = 2 follows the "Claude builders" row.
- After round 3 still failing: record the defect in `.m7/last-run.md` and the user summary, and continue.
- If a Codex fix round exits 3 it waits like any other task (5-hour rule); if it exits 5 it follows the weekly rule (both in `.claude/m7/codex-limits.md`). It is not retried on another Codex model: only if the user chose Module 3 does it run on the Module 3 mode ladder at that round number.
- Any Claude-plan fix is stated in the plan line and recorded in `.m7/last-run.md`.
