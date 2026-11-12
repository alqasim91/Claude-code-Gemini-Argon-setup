Read this as soon as a script exits 3 or `--status` exits 3, or the user mentions Module 3. Cross-rules: Module 3 is never used without the user saying so; no free model reviews; S = 2 never goes to a free model.

# Quota markers
The free limits are IP-level and unpublished. The script keeps one marker per model in `.claude/opencode-quota/<model-id>` with two lines: `until=<UTC ISO>` and `reason=<matching log line>`, written atomically. A marker is active while now is before `until`. The `until` is the parsed reset time if one was found, else now + 1 hour (unavailable models: 24 hours). The error wording is unverified, so the raw line is saved as `reason=`. A timed-out model gets no marker.
- A model hits its limit: the script marks it and moves to the next model on its own. Opus does nothing. The report's `chain walk:` line shows what happened.
- A model that times out is skipped for that run and the next one is tried. Two timeouts in a row stop the task (exit 1).
- `scripts/opencode-run.sh --status --role <role>` lists markers and "not offered now" models. Exit 0: at least one model is free. Exit 3: the whole chain is drained.
- Delete a marker file to clear it by hand.

# Whole chain drained (exit 3 or `--status` exit 3)
1. Do not launch more tasks of that role. Let running tasks finish and review their results.
2. ASK the user, in words (no decision box): "Free models for <role> are drained (earliest back <time>). Wait (I re-check then) or switch the remaining tasks to Module 3 mode now?"
3. Do nothing on Claude for build work until the user says Module 3. If they say wait, stop. On the next run run `--status` again and ask again if still drained.
Put the question in the user summary under "anything you must decide".

# Module 3 mode (only when the user says Module 3)
Re-route the remaining tasks with the same scores. First match wins:
- Read-only (find, explain, research, summarize) -> `scout`. No review.
- Opus trigger (D = 2, or two or more dimensions = 2, or S = 2 and N >= 1, or A = 2 and C = 2) -> `claude-opus-builder`.
- Easy (A, R, S, V, D all 0, total <= 2, complete spec, a tool can verify it) -> `claude-haiku-builder`.
- Everything else (design, S = 2, docs, copy, logic) -> `claude-sonnet-builder`.
- Tasks already accepted from free models stay as they are. A task that exited 3 may have been partly edited: add to its brief "A previous model may have partly edited the owned files before it stopped. Inspect them first, then finish the task."
- Reviews: `sonnet-reviewer` for haiku and sonnet work up to 400 changed lines. Opus reads the diff itself above 400 lines and for `claude-opus-builder` work.
- Fix ladder: round 1 same agent, round 2 next tier up (haiku -> sonnet -> opus), round 3 `claude-opus-builder`, then record and continue. An opus-builder task stays on opus-builder.
- Concurrency: total 3. Plan lines end with `(Module 3 mode)`. `.m8/last-run.md` lists which tasks ran in Module 3 mode.
- Stay in Module 3 mode for the rest of the session unless the user says to retry the free models.
