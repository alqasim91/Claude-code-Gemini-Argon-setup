Read this on any `codex-run.sh` exit 3 or 5, any `--status` exit 3 or 5, or when the user mentions Module 3. Self-contained. Cross-rules: 5-hour limit = Opus stops and tells the user; weekly limit = the one question; never switch to Claude builders without the user saying Module 3; design never goes to a Codex model; S = 2 stays on Claude.

# Codex limits and Module 3 mode
The Codex plan has TWO limits: a 5-hour limit and a weekly limit. Both are shared by all Codex models (luna, terra, sol), one pool. There is no Codex-to-Codex fallback: if one model hits a limit, all do.

- The script keeps one marker per limit in `.claude/codex-quota/`: `5h` and `weekly`. Each has two lines: `until=<UTC ISO>` and `reason=<first matching log line>`. It writes them atomically (temp file in the same dir, then `mv`) when a run hits a limit. A marker is active while now is before `until`. Weekly wins if both are active. If an old single `.claude/codex-quota/codex` file exists, delete it: it is ignored.
- The script classifies a hit as weekly if the log mentions week, weekly, 7 days or 7-day, or (when the text does not say 5-hour) a parsed reset time is more than 5 hours away. Otherwise 5h. `until` is the parsed reset time if one was found, else now + 5 hours (5h) or now + 24 hours (weekly, re-checked daily). The exact error wording is unverified, so the raw line is printed in the report.
- Before planning and before every phase, run `scripts/codex-run.sh --status`. Exit 0 means no limit is active. Exit 3 means the 5-hour limit is active, exit 5 the weekly limit. It prints the until time and the time remaining.
- A run that hits a limit (or starts while a marker is active) tries no other Codex model, prints `drained: codex 5h limit until <time>` (exit 3) or `drained: codex weekly limit until <time>` (exit 5), and still prints its report.

**5-hour limit (exit 3, or `--status` exit 3):**
1. Stop launching Codex tasks. Let tasks already running finish and review their results.
2. Then STOP and tell the user: "Codex 5-hour limit hit. Codex is back at <until, local time if possible, else UTC>. Re-run me after that and I continue from the next task."
3. Do NOT ask about Module 3 and do NOT use Claude builders for build work. Exception: if the user says "use Module 3" (now or in the original prompt), switch to Module 3 mode.
4. When resumed after the until time, run `--status` again and continue from the task plan (`.m7/TASKS.md` shows what is done). With a limit active before planning, print no plan and launch nothing.

**Weekly limit (exit 5, or `--status` exit 5):**
1. Stop launching Codex tasks. Let tasks already running finish and review their results.
2. ASK the user, in words (no decision box): "Codex weekly limit hit (until <time>). Wait (I re-check Codex in 24 hours) or switch the remaining tasks to Module 3 mode now?"
3. Do nothing on Claude until the user says Module 3. Never fall back to Claude without it, including hard (sol-high) tasks and fix rounds.
4. If they say wait: stop. On the next run after the until time, run `--status`; if the weekly limit is still active, ask again.

**Module 3 mode (only when the user says Module 3).** Re-route the remaining tasks with the same scores. First match wins:
- Read-only (find, explain, research, summarize) -> `scout`. No review.
- Opus trigger (D = 2, or two or more dimensions = 2, or S = 2 and N >= 1, or A = 2 and C = 2) -> `claude-opus-builder`.
- Easy (A, R, S, V, D all 0, total <= 2, complete spec, a tool can verify it) -> `claude-haiku-builder`.
- Everything else (design, S = 2, docs, copy, logic) -> `claude-sonnet-builder`.
- Tasks already accepted from Codex stay as they are. A task that exited 3 or 5 may have been partly edited: add to its brief "A Codex run may have partly edited the owned files before it stopped. Inspect them first, then finish the task."
- Reviews: `sonnet-reviewer` for haiku and sonnet work up to 400 changed lines. Opus reads the diff itself above 400 lines and for `claude-opus-builder` work.
- Fix ladder: round 1 same agent, round 2 next tier up (haiku -> sonnet -> opus), round 3 `claude-opus-builder`, then record and continue. An opus-builder task stays on opus-builder.
- Concurrency: total 3, no per-model caps. A task re-routed after a limit hit keeps its slot.
- Plan lines end with `(Module 3 mode)`. `.m7/last-run.md` lists which tasks ran in Module 3 mode.
- Stay in Module 3 mode for the rest of the session unless the user says to retry Codex.
