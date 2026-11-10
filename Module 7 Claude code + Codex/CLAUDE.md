@AGENTS.md

# Orchestration (Module 7: Claude plans in phases, Codex models run tasks in parallel)

Claude (Opus, this session) plans, routes and reviews. It never implements bulk work. Codex models implement through `scripts/codex-run.sh`, which Opus runs itself with Bash in the background. No relay subagent. Design, security, and fix rounds 2 and 3 go to Claude-plan subagents; cheap reviews to `sonnet-reviewer`.

## Run folder `.m7/` (git-ignored)
`briefs/<task>.md`, `logs/` (script scratch), `contract.md`, `TASKS.md`, `last-run.md`.

## Rule files (at `.claude/m7/`; a fired trigger is mandatory)

| File | Read it when |
|---|---|
| `.claude/m7/codex-limits.md` | Any exit 3 or 5 (run or `--status`), or the user mentions Module 3 |
| `.claude/m7/fix-ladders.md` | Before the first fix round of a run (a review returned FAIL) |
| `.claude/m7/models.md` | Before the first Claude builder or `scout` launch of a run |
| `.claude/m7/worktree.md` | Only when file sets cannot be disjoint |

After a context reset or resume: re-read this file and every rule file whose trigger fired; rebuild the plan from `.m7/TASKS.md` and `git status`.

Guards that hold even if a file is not read:
- Codex 5-hour limit (exit 3): Opus stops and tells the user. No question, no Claude builders.
- Codex weekly limit (exit 5): Opus asks the ONE question (wait or Module 3) and does nothing on Claude until the user answers.
- Never switch to Claude builders without the user saying Module 3.
- Design never goes to a Codex model. S = 2 stays on Claude.
- Never add a flag that bypasses the sandbox or approvals.

## Autonomy (no decision boxes)
Run end to end. Never use AskUserQuestion or choice boxes. The plan is announced, not approved.
- Defect found? Send it back the same turn as a new task listing defects. Max 3 rounds (`fix-ladders.md`); still failing after round 3: record the defect, continue.
- Unclear spec or minor choice: pick the most reasonable option, note it in `.m7/last-run.md`. Cosmetic or out-of-spec gaps are listed, not sent back, unless they break an acceptance criterion.
- Stop and ask only for hard blockers: `codex` missing (exit 2), a login failure, a permission block, an action that deletes data or touches secrets, the weekly limit hit and the user has not answered, or a limit hit AND the user chose Module 3 mode but Claude builders are unavailable. Exit 4 is not a hard blocker.
- The only question allowed is the weekly-limit one; the 5-hour limit is a stop-and-tell.

## Model pool (edit this table to change behavior)
IDs from learn.chatgpt.com/docs/models, checked 2026-10-29, ChatGPT sign-in. Astra (`gpt-6-astra`) is deliberately not used. Efforts: low, medium, high, xhigh.

| Alias | Model ID | Use for |
|---|---|---|
| luna | `gpt-6-luna` | Scouting, lookups, read-only (low). Tests, formatting, boilerplate, mechanical edits (medium) |
| terra | `gpt-6.1-terra` | Docs, copy, content pages (medium) |
| sol | `gpt-6.1-sol` | Default implementer (medium). Hard multi-file or tricky logic (high) |

Claude-plan agents: `claude-sonnet-builder`, `claude-opus-builder`, `claude-haiku-builder` and `scout` (Module 3 mode only), `sonnet-reviewer`. Who takes what: `.claude/m7/models.md`.

## Score every build task (0 / 1 / 2 each)

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
**Small job (check first).** If the whole request plans to 2 or fewer build tasks and none scores S = 2 or D = 2: ONE sol-medium task, normal review ladder, no phases, no scout unless something is genuinely unknown.

Otherwise first match wins:
0. **Read-only** (find, explain, research, summarize) -> luna-low. No review.
1. **Design shell or first design draft** -> `claude-sonnet-builder` (`claude-opus-builder` for key designs). Never Codex.
2. **S = 2** -> Opus writes the spec, `claude-sonnet-builder` builds, Opus reviews itself.
3. **Hard (the Opus trigger).** ANY of: D = 2 · two or more dimensions = 2 · S = 2 and N >= 1 (see 2) · A = 2 and C = 2 -> sol-high. Opus reviews itself.
4. **Easy.** ALL of: A, R, S, V, D all = 0 · total <= 2 · spec complete · a tool can verify it -> luna-medium.
5. **Docs, copy, content pages** (prose, not logic) -> terra-medium.
6. **Otherwise** -> sol-medium.

Tie-breakers: unsure luna vs sol -> sol. Unsure sol-medium vs sol-high -> sol-medium, unless D = 2 -> sol-high.

**Design NEVER goes to a Codex model.** Later mechanical edits to an approved design (copy changes, pages that follow it) may go to sol or luna.

## Phases and task plan
Phase the work yourself if the prompt is unphased.
1. **Phase 0 = foundation** everything else depends on: design shell, shared styles, schema, types, scaffolding. It runs alone. Skip it if there is none.
2. **Each later phase builds on the previous one.** A multi-step phase is chunked into parallel tasks on disjoint files; a single-step phase is one job.
3. **Review a phase completely (diffs, fix rounds, accepted) before the next.**
4. New tasks found in review go in the next phase; note it in `.m7/last-run.md`.
5. **Contract.** The foundation task writes `.m7/contract.md` (shared names: classes, ids, functions, signatures). Briefs of tasks that depend on shared names say "Read `.m7/contract.md` first. Use only the names defined there."

Before the first launch, print the plan (no approval needed). Run `scripts/codex-run.sh --status` first (and before every phase). If a limit is active, print no plan and launch nothing: follow `codex-limits.md`.

Plan columns: `id | phase | model (reason) | score | owns | after`, e.g. `p1-home | 1 | sol-medium (default) | A1 N1 C1 R0 S0 V1 D0 | site/index.html | p0-shell`.

- `id`: unique lowercase-kebab slug (the `--task` slug, log names, worktree/branch name). `score`: the seven scores. `owns`: exact paths (dirs and globs allowed), or `none` for read-only scouting. `after`: ids needed first.
- State each choice in one line before launching: `p1-home -> sol-medium (score ...: default)`.

## Concurrency caps (guesses; edit this table)
They limit parallel sessions, not quota (one shared pool, two limits).

| Limit | Max running at once |
|---|---|
| Total | 3 |
| sol | 2 |
| terra | 2 |
| luna | 3 |

- A task counts against its Codex model family (any effort) from launch until its report returns, fix rounds and scouting included. Claude builder runs count toward the total only.
- Phase over the caps: launch what fits, hold the rest, launch as slots free. Alternate models.
- Exit 4: lower the total by 1 (min 1) for the session, relaunch the affected tasks, note it in `.m7/last-run.md`. Module 3 mode caps: `codex-limits.md`.

## File ownership
- Within a phase, every file belongs to exactly one task, generated and test files included.
- Shared files (nav/layout includes, package.json, lockfiles, route index, global config, barrel files) are owned by one task, or left to an **integration task** in the next phase. Agents report needs as `needs:` lines; the integration task applies them.
- Two tasks that need the same file go in different phases (or merge into one task).
- Dependency installs and formatters are tasks too: own them, run alone, in their own phase. Put the owned list in every brief. Reading is unrestricted.
- Worktree mode (optional, default off) is for file sets that cannot be disjoint: `.claude/m7/worktree.md`.

## Delegation brief (every task)
Self-contained (goal, owned files, acceptance criteria, constraints): the run starts cold and sees only the brief plus AGENTS.md. Save it to `.m7/briefs/<task>.md`.
- **Codex tasks:** the file has the body only. The script adds `task:`/`owns:` and "Read AGENTS.md first".
- **Claude builders and reviewer:** the prompt starts with a header, then the body.
```
task: <slug>
owns: <comma-separated files, or none>
worktree: <path>        (optional)
design                  (optional, bare line, builders only)
```

## Launching
Codex task: one Bash call per task, all of a phase in ONE message, each `run_in_background: true`:
```
scripts/codex-run.sh --model <alias[-effort]|full-id> --task <slug> --owns "<comma list|none>" --brief .m7/briefs/<slug>.md [--worktree <path>] [--effort <level>]
```
Aliases: luna, terra, sol, optional `-low|-medium|-high|-xhigh` (default medium). A full model id works too (`--effort` sets effort). There is no `--no-fallback` flag: the script never tries a second Codex model. Wait for completion notifications; never poll with sleep or start the next phase early.

| Code | Meaning | Opus does |
|---|---|---|
| 0 | Success | Review |
| 1 | Other error (last 20 log lines) | Fix the cause or treat as hard blocker |
| 2 | `codex` not installed or bad arguments | Hard blocker, tell the user |
| 3 | `drained: codex 5h limit until <time>` | Let running tasks finish, then STOP and tell the user (`codex-limits.md`) |
| 4 | Suspected concurrency limit | Lower total cap, relaunch (see caps) |
| 5 | `drained: codex weekly limit until <time>` | Let running tasks finish, then ASK the user (`codex-limits.md`) |

Claude tasks: Agent tool with `subagent_type` as named above, `run_in_background: true`.

## Review ladder
Read the diff of owned files only. Changed lines = added + removed from `git diff --numstat` on owned files, plus the line count of new untracked owned files (the script prints it).

| Implementer | Reviewer |
|---|---|
| luna or terra | `sonnet-reviewer` |
| sol medium, diff <= 400 changed lines | `sonnet-reviewer` |
| sol medium over 400 lines, or sol high | Opus reviews itself (reads the diff in this session) |
| Tasks routed by S = 2 or the Opus trigger | Opus reviews itself |
| Claude builders (design, security) | Opus reviews itself |

- Never spawn a separate Opus reviewer (23% of the Module 3 test bill, no gain). If fixes push a task over 400 lines, its review moves up to Opus.
- Give `sonnet-reviewer` the header (`task:`, `owns:`) and the acceptance criteria. It returns PASS or FAIL with a numbered defect list; do not send back its non-blocking notes unless they break a criterion.
- Each report's "possibly from other parallel tasks" paths must be owned by another task in the phase. A stray edit to a file nobody owns is a defect: after the phase (nothing running) revert it only if sure it came from a task, else list it in `.m7/last-run.md`.
- Never accept "done" on a report alone. Luna scouting reports are leads: verify what you act on.

## Fix ladder
Max 3 rounds, ids `<id>-r1` to `<id>-r3`, same `owns:`. Round 1 same model, then up the ladder. Table and details: `.claude/m7/fix-ladders.md` (mandatory before the first fix round).

## Final summary
**To the user, at most 8 short plain lines:** what was built and how to open it; what is still open; who did the work, one line; anything the user must decide (a weekly-limit question or 5-hour stop goes here); "Details: .m7/last-run.md". Also print any line the user's prompt explicitly asks for (for example "Elapsed" or a files list).

**Detailed record -> `.m7/last-run.md`, overwritten each run:** the table below; fixes by round (call out Claude-plan work); cap changes; worktree use; open items; minor choices; tasks that ran in Module 3 mode.

| phase | task | score | model requested | model that ran | limit hit (5h/weekly) -> what happened | reviewer | rounds | result |
|---|---|---|---|---|---|---|---|---|

Limit column: none, waited for the 5h reset, or ran in Module 3 mode on the user's say-so.

After each task, append one line to `.m7/TASKS.md`: `ID | phase | route | score | reviewer | rounds | result | notes` (data for tuning routing).

## If everything fails
Only when `codex` is broken, or a limit is hit and the user chose Module 3 but Claude builders cannot take the work: stop and tell the user. Do not do the bulk work yourself.
