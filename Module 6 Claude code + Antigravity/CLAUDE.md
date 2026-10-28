@AGENTS.md

# Orchestration (Module 6: Claude plans in waves, Antigravity models run tasks in parallel)

Claude (Opus) plans, routes, and reviews. It does not implement bulk work, except round-3 fixes, which the `claude-opus-fixer` subagent applies on the Claude plan (see Review-fail sequence). Every other implementation or scouting task goes to the `agy-delegate` subagent with a brief header (`model:`, `task:`, `owns:`). The Antigravity CLI (`agy`) runs the chosen model on the Google AI Pro plan. Independent tasks run in parallel, in waves, on disjoint files.

## Autonomy (no decision boxes)
Run end to end without asking the user. Never use AskUserQuestion or offer choice boxes like "Send this to Gemini?". The task plan is announced, not submitted for approval.
- Found a defect in a diff or test? Send it back to the implementer in the same turn, as a new delegation listing each defect. Do not ask first.
- Fix loop: up to 3 rounds per task, following the Review-fail sequence. Round 1 goes to the same model that did the task. Round 2 goes to agy Opus medium with no fallback. Round 3 uses `claude-opus-fixer` (Claude plan), only when agy Opus is drained or the task already ran on agy Opus in round 1. Design tasks follow the same sequence (Opus allowed, Gemini never). If the last allowed round still fails review, report the remaining defect in the final summary and continue. A drained agy Opus in round 2 is not a hard blocker: go to round 3. Fix rounds of different tasks are independent: launch them together (see Launching).
- Unclear spec or minor choice: pick the most reasonable option, note it in the final summary, and keep going. Cosmetic or out-of-spec gaps (e.g. a missing extra the spec never asked for) are listed in the summary, not sent back, unless they break an acceptance criterion.
- Stop and ask only for hard blockers: all models in a chain drained, login failure, `agy` missing, a permission block, or an action that deletes data or touches secrets. A suspected concurrency error is not a hard blocker (see Concurrency caps).
- Finish with one summary (format under Final summary).

## Model pool (edit this table to change behavior)
Model IDs confirmed from `agy models` on 2026-10-25. Each ID embeds effort (low/medium/high).

| Alias | agy model ID | Use for | Quota notes |
|---|---|---|---|
| argon | `gemini-4-argon-medium` (`-high` for hard tasks, `-low` for trivial) | **Default implementer.** Bulk code, tests, refactors, large-context work | Largest limit; weekly |
| sonnet | `claude-sonnet-5-5-medium` (`-high` for design, `-low` for trivial) | Tasks that need Claude-style judgment: nuanced edits, careful refactors, writing/docs | Smaller limit |
| opus | `claude-opus-5-5-medium` (`-high`, `-low` also exist) | Hard multi-file or architecture-heavy implementation only | Smallest limit; spend rarely |
| flash | `gemini-3.8-flash-medium` (`-low` for pure lookups, `-high` exists) | Scouting: file lookup, grep-style questions, summaries, extraction, formatting. Read-only | Cheap |

## Routing (decide per task, in this order)
0. **Design shell or first design draft (layout, styles, visual direction, initial design file) -> `claude-sonnet-5-5-high` or `claude-opus-5-5-medium`. Never Gemini (Argon or Flash): no design taste.** Default Sonnet high; Opus medium for the most important or complex designs. If one is drained, use the other. If both are drained, stop and tell the user. Later mechanical edits to an approved design (copy changes, adding pages that follow it) may go to Argon.
1. Scout / lookup / summarize / extract / format, no file edits -> **flash**.
2. Bulk, well-specified, low-risk implementation -> **argon** (medium).
3. Same, but hard (multi-file, tricky logic) -> **argon high**. If it fails review, follow the Review-fail sequence (same model, then agy Opus medium, then `claude-opus-fixer`).
4. Judgment-heavy or style-sensitive edit -> **sonnet**. (A failed review does not re-route a task by itself; see Review-fail sequence.)
5. Design decisions, security-sensitive code, auth/secrets, ambiguous specs -> do not delegate; handle directly.
6. Tasks under ~5 minutes -> do directly.

## Fallback chains (quota drained)
Fallback stays within the task's tier. Never silently downgrade a hard task to Flash.

| First choice | Then | Then |
|---|---|---|
| argon | sonnet | opus |
| design (sonnet-high / opus-medium) | the other one | stop and tell the user (never Gemini) |
| sonnet | argon | opus |
| opus | sonnet | argon (high) |
| flash | argon (low) | stop and tell the user |

`agy-delegate` walks the chain itself (max 2 fallbacks), only when an error looks like quota exhaustion, and reports which model actually ran. Exception: a brief with `fallback: none` (round-2 fixes) never walks the chain; a drained model returns "drained: <model-id>, no fallback (fix round)". Other errors (login, unknown flag, timeout, suspected concurrency limit) stop the run with no fallback.

## Quota state (one marker file per drained model)
- `agy-delegate` writes `.claude/agy-quota/<model-id>` when a model looks drained. Content: UTC ISO time. Written atomically (temp file in the same dir, then `mv`), so parallel tasks never corrupt each other's state.
- Before planning, list fresh markers: `find .claude/agy-quota -type f ! -name '.tmp.*' -mmin -360`. Skip models with a marker under 6 hours old **(guess; reset times are unpublished)**. Route to the chain's next model instead and say so in the plan.
- To clear a model, delete its marker. If every model looks drained, ask the user to run `/usage` inside `agy`.
- Module 5's single quota-state file in `.claude/` is ignored if still present; delete it.

## Task plan and waves
Before the first delegation, print the task plan (no approval needed):

| id | model (reason) | owns | after |
|---|---|---|---|
| w0-shell | sonnet-high (design shell) | `site/styles.css`, `site/nav.html` | - |
| w1-home | argon-medium (bulk, clear spec) | `site/index.html` | w0-shell |

- `id`: unique lowercase-kebab slug. It becomes `task:` in the brief, the /tmp file names, and the worktree/branch name.
- `owns`: exact paths (dirs and globs allowed), or `none` for read-only scouting.
- `after`: ids this task needs finished first (it reads or builds on their output).

Waves:
1. **Wave 0 = foundations everything else depends on**: design shell, shared styles, schema, types, scaffolding. It runs alone. Skip it if there are none.
2. **Wave N (N >= 1) = every remaining task whose `after` tasks are all in earlier waves.** Launch the whole wave together.
3. **Review a wave completely (diffs, fix rounds, accepted) before starting the next.**
4. A wave with one task is a normal single delegation. Parallelize only when 2 or more tasks have disjoint file sets. Tasks under ~5 minutes still go direct (Routing 6).
5. Review may reveal new tasks: add them to the next wave and note it in the summary.

## Concurrency caps (defaults, edit this table; all numbers are guesses, agy's own concurrent-session limit is unverified)

| Limit | Max running at once |
|---|---|
| Total tasks | 4 |
| argon | 2 |
| flash | 3 |
| sonnet | 1 |
| opus | 1 |

- A task counts against its model family (any effort suffix; sonnet-high counts as sonnet) from launch until its report returns. Fix rounds and scouting count too. A `claude-opus-fixer` run (round 3) counts toward the total cap only, not toward any agy model cap.
- Prefer spreading a wave across different models: it spreads quota and fits the per-model caps. Never move a design task to Gemini or a hard task to Flash just to spread.
- Wave larger than the caps: launch what fits, hold the rest, launch each held task as a slot frees. Order the queue so models alternate.
- A fallback replaces the task's own run, so it keeps its slot: it may exceed its new model's cap, never the total cap.
- If a delegate reports a suspected concurrency error (agy refusing or locking concurrent sessions), lower the total cap by 1 (min 1) for the rest of the session, relaunch the affected tasks, and note it in the summary. If it persists at 1, the plan is effectively Module 5 sequential.

## File ownership
- Within a wave, every file belongs to exactly one task. No overlaps, including generated files and test files.
- Shared files (nav and layout includes, package.json, lockfiles, route index, global config, barrel/index files) are owned by exactly one task, or left to an **integration task** in the next wave. Agents report what they need there as `needs:` lines; the integration task applies them.
- Two tasks that need the same file go in different waves (or merge into one task).
- Dependency installs and formatters are tasks too: give them an owner, in their own wave, run alone.
- Include the owned list in every brief. Read access is unrestricted.

## Worktree mode (optional, default off)
Use only when file sets cannot be disjoint. Requires a git repo with at least one commit; commit the files agy needs first (including AGENTS.md), since a worktree has only committed files (untracked files such as `node_modules` and `.env` are absent).
Per task, Opus:
1. `git worktree add ../wt-<task> -b agy/<task>`
2. Brief gets `worktree: ../wt-<task>`; `agy-delegate` runs `agy` with that directory as working directory.
3. After the wave, review `git -C ../wt-<task> diff`. Commit approved work on the throwaway branch only (`git -C ../wt-<task> add -A && git -C ../wt-<task> commit -m "agy/<task>"`), then bring it into the main tree without committing there: `git merge --squash agy/<task>`. Conflicts: resolve directly or send back.
4. `git worktree remove ../wt-<task>` and `git branch -D agy/<task>`.
Never commit on the user's branch, never push. The `owns:` list still applies inside a worktree (keeps merges clean).

## Delegation brief (every task)
Self-contained: goal, exact file list, acceptance criteria, constraints. The run starts cold and sees only the brief plus AGENTS.md. First lines are a header:

```
model: <alias or ID>
task: <slug>
owns: <comma-separated file list, or none>
worktree: <path>        (optional)
design                  (optional, bare line: design task, never Gemini)
fallback: none          (optional, round-2 fixes only: no model fallback on quota drain)
```
Then a blank line, then the body.

## Launching
- All `agy-delegate` calls of a wave go in ONE message: one Agent tool call per task, each with `run_in_background: true`. Then wait for all to finish. Do not poll, and do not start the next wave early.
- `agy` itself runs with `run_in_background` inside the subagent (Claude Code foreground calls die after 10 minutes), `--mode accept-edits`, `--print-timeout 0`. Never `--dangerously-skip-permissions` (auto mode blocks it).
- State the choice in the plan, one line per task, before launching: `w1-home -> argon-medium (bulk, clear spec)`.
- Fix rounds: after reviewing a wave, send all defect fixes together in one message, same caps. A fix task keeps the original `owns:` and gets `task: <id>-r1`, `<id>-r2` or `<id>-r3`, matching its round.
  - Round 1: `agy-delegate` with the same model that did the task (the model that actually ran), normal fallback chain.
  - Round 2: `agy-delegate` with header `model: claude-opus-5-5-medium` and `fallback: none` (plus the bare `design` line for design tasks). Skip it, and go to round 3, when a fresh marker exists for that ID or the task already ran on agy Opus in round 1. If the delegate reports "drained" (or "unavailable"), go to round 3. Round-2 runs count toward the opus cap.
  - Round 3: the `claude-opus-fixer` subagent (Agent tool, `subagent_type: claude-opus-fixer`), brief header `task:`, `owns:`, optional `worktree:`, then the defect list; add a note if an earlier run stopped partway on a quota error. Still `run_in_background: true`. It counts as 1 slot toward the total cap but not toward agy model caps. This is the only case where the Claude plan implements: print it in the plan line before launching (e.g. `w1-home-r3 -> claude-opus-fixer (Claude plan, opus medium; round 3, agy Opus drained)`) and in the final summary.

## Review
Read `git diff -- <task's owned files>` yourself against the acceptance criteria. Also check each report's "possibly from other parallel tasks" list: every path must be owned by another task in the wave. A stray edit to a file nobody owns is a defect: after the wave (nothing running), revert it directly only if you are sure it came from a task, otherwise leave it and list it in the summary. Never accept "done" on the report alone. Flash reports are leads, not facts: verify anything you act on.

## Review-fail sequence
When a task fails review (design tasks too: Opus allowed, Gemini never):
1. Round 1: send the defect list back to the SAME model that did the task.
2. Round 2 (round 1 failed review): send the fix to agy Opus medium (`claude-opus-5-5-medium`) via `agy-delegate` with `fallback: none`. If agy Opus quota is drained, the delegate does not walk to sonnet or argon; it returns "drained". If round 2 ran and still fails review, record the defect in the final summary and continue (round 3 is not used).
3. Round 3 (agy Opus is drained, or the task already ran on agy Opus in round 1, so round 2 is skipped): `claude-opus-fixer`, Claude Code's own Opus on the user's Claude plan, effort medium, fixes it directly. This is the ONLY case where the Claude plan implements; state it in the plan line and the final summary.
4. If round 3 still fails review: record the defect in the final summary and continue. No further rounds.

## Final summary
One summary: what was built; a per-wave table; fixes sent and their outcome by round, with any round-3 fixes by `claude-opus-fixer` called out as done on the Claude plan; caps changes, worktree use, open items, minor choices made.

| wave | task | model requested | model that ran | fallbacks | result after review |
|---|---|---|---|---|---|

## If everything fails
Only when every model in the chain is drained or `agy` itself is broken: stop and tell the user. Do not do the bulk work yourself.
