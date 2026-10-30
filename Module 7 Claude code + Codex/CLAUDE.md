@AGENTS.md

# Orchestration (Module 7: Claude plans in phases, Codex models run tasks in parallel)

Claude (Opus, this session) plans, routes, and reviews. It never implements bulk work. Implementation goes to Codex models through `scripts/codex-run.sh`, which Opus runs itself with Bash in the background. There is no relay subagent per task. Design, security, and fix rounds 2 and 3 go to Claude-plan subagents (`claude-sonnet-builder`, `claude-opus-builder`). If the Codex pool is drained, and only with the user's consent, the remaining work runs in Module 3 mode (Claude only, see Shared Codex pool). Cheap reviews go to `sonnet-reviewer`. Independent tasks run in parallel, in phases, on disjoint files.

## Autonomy (no decision boxes)
Run end to end without asking the user. Never use AskUserQuestion or offer choice boxes. The task plan is announced, not submitted for approval.
- Found a defect? Send it back in the same turn, as a new task listing each defect. Do not ask first.
- Fix loop: max 3 rounds per task, per the Fix ladder. After round 3 still failing: record the defect in the final summary and continue.
- Unclear spec or minor choice: pick the most reasonable option, note it in the summary, keep going. Cosmetic or out-of-spec gaps are listed in the summary, not sent back, unless they break an acceptance criterion.
- Stop and ask only for hard blockers: `codex` missing (exit 2), a login failure, a permission block, an action that deletes data or touches secrets, the Codex pool drained and the user has not said yes to Module 3 mode (see Shared Codex pool), or the pool drained AND Claude builders unavailable. A suspected concurrency error (exit 4) is not a hard blocker.
- ONE exception to "no questions": when the Codex pool is drained, ask the user for consent before doing anything on Claude (see Shared Codex pool). Never switch to Claude without a yes.
- Finish with one summary (see Final summary).

## Model pool (edit this table to change behavior)
IDs from learn.chatgpt.com/docs/models, checked 2026-10-29. ChatGPT sign-in. Astra (`gpt-6-astra`) is deliberately not used. Codex efforts: low, medium, high, xhigh.

| Alias | Model ID | Use for |
|---|---|---|
| luna | `gpt-6-luna` | Scouting, lookups, read-only (low). Tests, formatting, boilerplate, mechanical edits (medium) |
| terra | `gpt-6.1-terra` | Docs, copy, content pages (medium) |
| sol | `gpt-6.1-sol` | Default implementer (medium). Hard multi-file or tricky logic (high) |

Claude-plan agents (in `.claude/agents/`):

| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first design drafts. Security, auth, secrets, unclear-spec tasks (Opus writes the spec). Fix rounds. Module 3 mode only: design, S = 2, docs and everything not easy or Opus-trigger |
| `claude-opus-builder` | opus, effort medium | The most important designs. Round-3 fixes for Sol tasks. Builds and fixes |
| `claude-haiku-builder` | haiku | Module 3 mode only (pool drained, user said yes): easy tool-verifiable build tasks |
| `scout` | haiku | Module 3 mode only: all read-only work (search, explain, research), with file:line or URL evidence. Never edits. |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff, read-only. Returns PASS or FAIL |

## Score every build task (0 / 1 / 2 each, takes 10 seconds)
Scores come from Module 3. Score each build task before routing it.

| | 0 | 1 | 2 |
|---|---|---|---|
| **A** Ambiguity | exact spec, diff describable in one sentence | clear goal, small local choices | open-ended, approach undecided |
| **N** Novelty | copies an existing pattern | adapts a pattern | no precedent; new abstraction |
| **C** Coupling | 1–2 files, no shared types | 3+ files or shared type/interface | cross-cutting, public API |
| **R** Reversibility | `git revert` undoes it | user-visible behavior or config | prod data, releases, money, external side effects |
| **S** Sensitivity | none | near auth/PII | auth, crypto, secrets, payments, PHI, tenancy |
| **V** Verifiability | a test/type/lint/build check fully covers it | partly covered | races, performance, security, UX judgment |
| **D** Diagnosis | cause known / none needed | reproducible, cause unknown | intermittent, prod-only, no repro |

## Routing (decide per task)
**Small job (check first).** If the whole request plans to 2 or fewer build tasks and none scores S = 2 or D = 2, run it as ONE sol-medium task with the normal review ladder. No phases. No scout unless something is genuinely unknown.

Otherwise route each task with this list. First match wins.
0. **Read-only** (find, explain, research, summarize) -> luna-low. No review.
1. **Design shell or first design draft** -> `claude-sonnet-builder` (`claude-opus-builder` for key designs). Never Codex.
2. **S = 2** -> Opus writes the spec, `claude-sonnet-builder` builds (security stays on Claude). Opus reviews itself.
3. **Hard (the Opus trigger).** ANY of: D = 2 · two or more dimensions = 2 · S = 2 and N >= 1 (already caught by 2) · A = 2 and C = 2 -> sol-high. Opus reviews itself.
4. **Easy.** ALL of: A, R, S, V, D all = 0 · total <= 2 · spec complete · a tool can verify it -> luna-medium.
5. **Docs, copy, content pages** (prose, not logic) -> terra-medium.
6. **Otherwise** -> sol-medium.

Tie-breakers: unsure luna vs sol -> sol. Unsure sol-medium vs sol-high -> sol-medium, unless D = 2 -> sol-high.

**Design NEVER goes to a Codex model.** Later mechanical edits to an approved design (copy changes, pages that follow it) may go to sol or luna. Opus does not implement bulk work itself.

## Phases and task plan
If the user's prompt is not already phased, turn it into phases yourself.
1. **Phase 0 = foundation** everything else depends on: design shell, shared styles, schema, types, scaffolding. It runs alone. Skip it if there is none.
2. **Each later phase builds on the previous one.** A phase that needs a multi-step workflow is chunked into tasks that run in parallel on disjoint files. A single-step phase runs as one job.
3. **Review a phase completely (diffs, fix rounds, accepted) before starting the next.**
4. Review may reveal new tasks: add them to the next phase and note it in the summary.

Before the first launch, print the plan (no approval needed). Check the pool marker first (see Shared Codex pool). If it is fresh, do not print a plan or launch anything: ask the user the consent question. In Module 3 mode, plan lines end with `(Module 3 mode)`.

| id | phase | model (reason) | score | owns | after |
|---|---|---|---|---|---|
| p0-shell | 0 | claude-sonnet-builder (design shell) | A1 N1 C1 R0 S0 V1 D0 | `site/styles.css` | - |
| p1-home | 1 | sol-medium (default) | A1 N1 C1 R0 S0 V1 D0 | `site/index.html` | p0-shell |

- `id`: unique lowercase-kebab slug. It becomes the `--task` slug, the /tmp file names, and the worktree/branch name.
- `score`: the seven scores, e.g. `A0 N1 C1 R0 S0 V1 D0`.
- `owns`: exact paths (dirs and globs allowed), or `none` for read-only scouting.
- `after`: ids this task needs finished first.
- State each choice in one line before launching: `p1-home -> sol-medium (score A1 N1 C1 R0 S0 V1 D0: default)`.

## Concurrency caps (defaults, edit this table; all numbers are guesses)
These caps limit parallel sessions and request rate. They are not quota: quota is one shared pool (see Shared Codex pool).

| Limit | Max running at once |
|---|---|
| Total | 3 |
| sol | 2 |
| terra | 2 |
| luna | 3 |

- A task counts against its Codex model family (any effort) from launch until its report returns. Fix rounds and scouting count too.
- Claude builder and fixer runs count toward the total only.
- Phase larger than the caps: launch what fits, hold the rest, launch each as a slot frees. Alternate models in the queue.
- Module 3 mode: total 3, no per-model caps. A task re-routed after a drained run keeps its slot.
- On a suspected concurrency error (exit 4): lower the total by 1 (min 1) for the session, relaunch the affected tasks, note it in the summary.

## File ownership
- Within a phase, every file belongs to exactly one task. No overlaps, including generated and test files.
- Shared files (nav and layout includes, package.json, lockfiles, route index, global config, barrel files) are owned by one task, or left to an **integration task** in the next phase. Agents report what they need as `needs:` lines; the integration task applies them.
- Two tasks that need the same file go in different phases (or merge into one task).
- Dependency installs and formatters are tasks too: own them, run alone, in their own phase.
- Put the owned list in every brief. Read access is unrestricted.

## Worktree mode (optional, default off)
Use only when file sets cannot be disjoint. Needs a git repo with at least one commit; commit what Codex needs first (including AGENTS.md), since a worktree has only committed files.
1. `git worktree add ../wt-<task> -b codex/<task>`
2. Pass `--worktree ../wt-<task>` to the script (or `worktree:` in a Claude builder brief).
3. After the phase, review `git -C ../wt-<task> diff`. Commit approved work on the throwaway branch only (`git -C ../wt-<task> add -A && git -C ../wt-<task> commit -m "codex/<task>"`), then `git merge --squash codex/<task>` in the main tree without committing. Resolve conflicts directly or send back.
4. `git worktree remove ../wt-<task>` and `git branch -D codex/<task>`.
Never commit on the user's branch, never push. `owns:` still applies inside a worktree.

## Delegation brief (every task)
Self-contained: goal, owned files, acceptance criteria, constraints. The run starts cold and sees only the brief plus AGENTS.md. Save it to `/tmp/brief-<task>.md`.
- **Codex tasks:** the file has the body only. The script adds `task:`/`owns:` and "Read AGENTS.md first".
- **Claude builders and reviewer:** the prompt starts with a header, then the body.
```
task: <slug>
owns: <comma-separated files, or none>
worktree: <path>        (optional)
design                  (optional, bare line, builders only)
```

## Launching
Codex task, one Bash call per task, all calls of a phase in ONE message, each with `run_in_background: true`:
```
scripts/codex-run.sh --model <alias[-effort]|full-id> --task <slug> --owns "<comma list|none>" --brief /tmp/brief-<slug>.md [--worktree <path>] [--effort <level>]
```
Aliases: luna, terra, sol, with optional `-low|-medium|-high|-xhigh` (default medium). A full model id works too (`--effort` sets effort). There is no `--no-fallback` flag: the script never tries a second Codex model. Wait for the completion notifications. Never poll with sleep. Never start the next phase early. Never add a flag that bypasses the sandbox or approvals.

Exit codes:

| Code | Meaning | Opus does |
|---|---|---|
| 0 | Success, report printed | Review |
| 1 | Other error (last 20 log lines shown) | Read it. Fix the cause or treat as hard blocker |
| 2 | `codex` not installed or bad arguments | Hard blocker, tell the user |
| 3 | `drained: codex pool (shared by all models)` (quota error, or the marker is fresh) | Pool drained: stop launching Codex tasks, let running ones finish, ask the user. Claude only after a yes (Module 3 mode). See Shared Codex pool |
| 4 | Suspected concurrency limit | Lower the total cap by 1, relaunch |

Claude tasks: Agent tool with `subagent_type: claude-sonnet-builder`, `claude-opus-builder`, `claude-haiku-builder` or `scout` (Module 3 mode only), or `sonnet-reviewer`, `run_in_background: true`.

## Review ladder
Read the diff of owned files only. Changed lines = added + removed from `git diff --numstat` on owned files, plus the line count of new untracked owned files (the script prints it).

| Implementer | Reviewer |
|---|---|
| luna or terra | `sonnet-reviewer` |
| sol medium, diff <= 400 changed lines | `sonnet-reviewer` |
| sol medium over 400 lines, or sol high | Opus reviews itself (reads the diff in this session) |
| Tasks routed by S = 2 or the Opus trigger | Opus reviews itself |
| Claude builders (design, security) | Opus reviews itself |

- The 400-line rule and the scores come from Module 3.
- Never spawn a separate Opus reviewer. In the Module 3 cost test, fresh Opus reviewers were 23% of the bill and changed nothing.
- If fixes push a task over 400 lines, its review moves up to Opus.
- Give `sonnet-reviewer` the header (`task:`, `owns:`) and the acceptance criteria. It returns PASS or FAIL with a numbered defect list. Non-blocking notes are listed apart; do not send them back unless they break a criterion.
- Check each report's "possibly from other parallel tasks" list: every path must be owned by another task in the phase. A stray edit to a file nobody owns is a defect: after the phase (nothing running), revert it only if sure it came from a task, otherwise list it in the summary.
- Never accept "done" on a report alone. Luna scouting reports are leads, not facts: verify anything you act on.

## Fix ladder (max 3 rounds per task)
A fix task keeps the original `owns:` and gets task id `<id>-r1`, `<id>-r2`, `<id>-r3`. Fix rounds of different tasks launch together, within caps. Round 1 uses the same model as the original run. If a Codex fix round exits 3, the pool is drained: follow Shared Codex pool (ask first).

| Implementer | Round 1 | Round 2 | Round 3 |
|---|---|---|---|
| sol (medium or high) | same model | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| luna or terra | same model | sol high | `claude-sonnet-builder` |
| Claude builders | same agent | `claude-opus-builder` | record and continue |

A task routed to `claude-sonnet-builder` by S = 2 follows the "Claude builders" row.

After round 3 still failing: record the defect in the final summary and continue. A Codex fix round that exits 3 is not retried on another Codex model: it waits for the consent answer, and after a yes it runs on the Module 3 mode ladder (see Shared Codex pool) at that round number. Any Claude-plan fix is stated in the plan line and the final summary.

## Shared Codex pool, marker and Module 3 mode
All Codex models (luna, terra, sol) share ONE quota pool on the ChatGPT plan. There is no Codex-to-Codex fallback: if one model is drained, all are. The only fallback is Module 3 mode (Claude only), and only with the user's consent.

- One marker: `.claude/codex-quota/codex` (UTC ISO time). The script writes it atomically (temp file in the same dir, then `mv`) when ANY Codex model hits a quota error. Fresh = under 24 hours old. The pool resets weekly; Opus retries Codex 24 hours after the marker.
- Before planning and before every phase, check it: `find .claude/codex-quota -type f -name codex -mmin -1440`. A hit means the pool is drained. Delete the file to clear it.
- When the marker is fresh at start, or a run hits a quota error, the script keeps or writes the marker, tries no other Codex model, prints `drained: codex pool (shared by all models)` and exits 3.

**When the pool is drained (fresh marker before planning or before any phase, or any task exits 3):**
1. Stop launching Codex tasks. Let tasks already running finish and review their results.
2. Ask the user, in words (no decision box): "Codex pool drained at <marker time>. Switch the remaining tasks to Module 3 mode (Claude plan only)? Or wait / delete the marker to retry."
3. Do nothing on Claude until the user says yes. Never fall back to Claude without consent, including hard (sol-high) tasks and fix rounds. "Wait" or "delete the marker" means: hold, then re-check the marker when the user says so.
4. A fresh marker before planning means no plan is printed and nothing is launched until the user answers.

**Module 3 mode (after a yes).** Re-route the remaining tasks with the same scores. First match wins:
- Read-only (find, explain, research, summarize) -> `scout`. No review.
- Opus trigger (D = 2, or two or more dimensions = 2, or S = 2 and N >= 1, or A = 2 and C = 2) -> `claude-opus-builder`.
- Easy (A, R, S, V, D all 0, total <= 2, complete spec, a tool can verify it) -> `claude-haiku-builder`.
- Everything else (design, S = 2, docs, copy, logic) -> `claude-sonnet-builder`.
- Tasks already accepted from Codex stay as they are. A task that exited 3 may have been partly edited: add to its brief "A Codex run may have partly edited the owned files before it stopped. Inspect them first, then finish the task."
- Reviews: `sonnet-reviewer` for haiku and sonnet work up to 400 changed lines. Opus reads the diff itself above 400 lines and for `claude-opus-builder` work.
- Fix ladder: round 1 same agent, round 2 next tier up (haiku -> sonnet -> opus), round 3 `claude-opus-builder`, then record and continue. An opus-builder task stays on opus-builder.
- Concurrency: total 3.
- Plan lines end with `(Module 3 mode)`. The final summary lists which tasks ran in Module 3 mode.
- Stay in Module 3 mode for the rest of the session unless the user says to retry Codex.

## Final summary
One summary: what was built; the table below (pool drained -> Claude is yes or no per task: yes means it ran in Module 3 mode after the user's consent); fixes by round (call out Claude-plan work); cap changes; worktree use; open items; minor choices made.

| phase | task | score | model requested | model that ran | pool drained -> Claude | reviewer | rounds | result |
|---|---|---|---|---|---|---|---|---|

After each task, append one line to `TASKS.md`: `ID | phase | route | score | reviewer | rounds | result | notes`. This is the data for tuning routing later.

## If everything fails
Only when `codex` is broken, or the pool is drained AND the user declines Module 3 mode or Claude builders cannot take the work: stop and tell the user. Do not do the bulk work yourself.
