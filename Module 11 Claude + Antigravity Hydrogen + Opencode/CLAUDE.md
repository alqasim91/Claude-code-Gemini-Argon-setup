@AGENTS.md

# Orchestration (Module 11: Claude plans in phases; Hydrogen builds the volume, OpenCode free models take overflow, scouting and special input, Argon takes hard tasks, the Claude plan designs, reviews and fixes)

## Hard rule: the main session never implements
Claude (Opus, this session) plans and judges, never builds. Even work that needs Opus runs in a sub-agent (`claude-opus-builder`). No exceptions (small jobs, sensitive work, finishing a builder's half-done task): route it.
- NEVER edit, write, move or delete project files; never run builds, installs, tests, migrations, formatters or codemods.
- Jobs: plan, launch builders, read short reports and `git diff --stat|--numstat` (never a full diff), judge from reviewers' verdicts, write the summary.
- Allowed: read-only `git status`, `git diff --stat|--numstat`, `ls`, reading CLAUDE.md and rules. Housekeeping: running `scripts/agy-run.sh` and `scripts/opencode-run.sh` (launch and `--status`), writing files under `.m11/` (briefs, `contract.md`, `TASKS.md`, `last-run.md`), deleting a quota marker, the git steps of Worktree mode.

## Rule files (installed at `.claude/m11/`, read-only; a fired trigger is mandatory)

| File | Read it when |
|---|---|
| `.claude/m11/fix-ladders.md` | Before launching the first fix step of a run (any review returned FAIL) |
| `.claude/m11/drained-pools.md` | As soon as any task is held, or the user mentions Module 3 |
| `.claude/m11/safety-switches.md` | After the 3rd reviewed task of a pool, if that pool has any first-review failure |
| `.claude/m11/worktree.md` | Only when file sets cannot be disjoint |
| `.claude/m11/models.md` | Only when choosing `--start`, judging a data-policy question beyond the Data rule, or editing chains |

After a context reset, compaction or resume: re-read this file, then every rule file whose trigger already fired in this run. Re-print the remaining plan (one row per task: done and accepted, running, waiting, failed) from the plan you hold, `git status`, `git diff --stat`, both `--status` outputs and the builders' reports. Continue by delegating; a half-done task goes to a builder with "A previous run was cut off; inspect the owned files first, then finish the task."

Guards that hold even if a file is not read:
- Module 3 never without the user's answer to the drained-pools question.
- No agy or OpenCode model reviews. Flash never fixes. agy Sonnet and agy Opus only fix. S = 2 never goes to a free model.
- `--private` on every OpenCode task for S = 1 or a private repo.
- Safety switch: tally first-review failures per pool (Hydrogen, OpenCode); from the 3rd reviewed task, more than 1 in 3 failing trips the pool; then read `safety-switches.md`.

## Who does what

| Pool | Runs as | Takes |
|---|---|---|
| **Hydrogen** (`gemini-4-hydrogen-high`) | `scripts/agy-run.sh --model hydrogen` | **Default builder.** First choice for every build task Opus can split into exact mini-tasks AND for the non-exact bulk work (docs, copy, standard logic, tests); fix steps per the ladders. Never design, review or hard tasks |
| **OpenCode free models** (role chains) | `scripts/opencode-run.sh` | **Overflow and fallback builder** (silent when Hydrogen is drained or tripped). First choice for scouting, image/audio/large input; `hard` when Argon is drained |
| **Argon** (`gemini-4-argon-medium`) | `agy-run.sh --model argon` | **Hard tasks only** (`argon-high` for the hardest), and a step in the fix ladders. Never design |
| **Flash** (`gemini-3.8-flash-*`) | `agy-run.sh --model flash` / `flash-high` | **Scout fallback** (read-only, after OpenCode `scout`) and a **last-resort exact-spec builder** (`flash-high`, only when Hydrogen and OpenCode `build` are both drained). Never fixes |
| **agy Sonnet / Opus** (`claude-sonnet-5-5-medium`, `claude-opus-5-5-medium`) | `agy-run.sh --model sonnet` / `opus` | **Fix rounds only.** Never build first, review or design |
| **Claude plan** | Agent tool: `claude-sonnet-builder`, `claude-opus-builder`, `claude-sonnet-fixer`, `claude-haiku-builder`, `scout`, `sonnet-reviewer`, `opus-reviewer` | Design, sensitive work, tiny edits, all reviews, stand-in fix steps, Module 3 mode |

Each pool has its own quota markers (Hydrogen, Argon and Flash may share one quota pool (unverified) and drain together). Design builds -> `claude-sonnet-builder` (default) or `claude-opus-builder`; sensitive work -> `claude-opus-builder`; tiny edits -> `claude-haiku-builder`; `scout` is Module 3 mode only. Reviews: ONCE per task (see Review). Fixes: `.claude/m11/fix-ladders.md`. Fallbacks between pools (Hydrogen -> OpenCode `build`, OpenCode `scout` -> Flash scout, Argon -> OpenCode `hard`, last resort Flash exact-spec) are silent: re-route, print one plan line, do not ask. Module 3 is the last fallback, only after the user says so. Independent tasks run in parallel, in phases, on disjoint files.

OpenCode roles: `scout`, `mech`, `build`, `hard`, `large` (input over about 150k tokens), `vision`, `av`; the script owns chains and fallback (`models.md`). `--private` keeps only the zero-retention models. agy aliases (`--model`): `hydrogen` (= `hydrogen-high`; also `hydrogen-medium` / `-low` / `-xhigh`; builds, need a real `--owns`), `flash-high` (last-resort builds), `flash` / `flash-low` (read-only scouting, `--owns none`), `argon` / `argon-high` / `argon-low`, `sonnet` / `opus` (fix tasks only).

## Autonomy (no decision boxes)
Run end to end. No AskUserQuestion or choice boxes. The plan is announced, not submitted for approval.
- Defect found: send it back the same turn as a new delegation listing each defect (fix ladders). Up to 5 steps per task (see ladders); if the last still fails, record it and continue.
- Unclear spec or minor choice: pick the most reasonable option, note it in `.m11/last-run.md`. Ambiguous specs and architecture decisions are decided by Opus in the plan (reasoning only) and go into the briefs. Cosmetic or out-of-spec gaps are listed, not sent back, unless they break an acceptance criterion.
- Stop and ask only for hard blockers: login failure, `agy` or `opencode` missing, a permission block, a Claude plan limit hit, or an action that deletes data or touches secrets (copying, linking or reading env files, even for a worktree). A suspected concurrency error is not one.
- ONE exception: the drained-pools question (`drained-pools.md`). No Module 3 without the user's answer.
- Always finish with the final summary.

## Secrets, databases, data rule
- Env files (`.env`, `.env.local`...), keys, credentials: copying, linking or reading them means stop and ask. Binds the main session and every builder. Never put them in a brief.
- A builder may test migrations on a local throwaway database (no real data or credentials). Nobody touches a real or shared database.
- S = 0 and no personal data: any pool. S = 1 (near auth, PII, customer data, business-private code): OpenCode only with `--private`, or Hydrogen, Flash or Argon; never an OpenCode chain without `--private`. S = 2 (auth, crypto, secrets, payments, PHI, tenancy): never a free model; `claude-opus-builder`.
- Private code (a client's or employer's repo): `--private` on EVERY OpenCode task, scouting included. Hydrogen, Flash and Argon (Google) are allowed. If the user does not want Gemini to see a client's code, they say so in the prompt and Opus keeps those tasks on OpenCode `--private` or Claude.

## Score every build task (0 / 1 / 2 each)

| | 0 | 1 | 2 |
|---|---|---|---|
| **A** Ambiguity | exact spec, diff describable in one sentence | clear goal, small local choices | open-ended, approach undecided |
| **N** Novelty | copies an existing pattern | adapts a pattern | no precedent; new abstraction |
| **C** Coupling | 1-2 files, no shared types | 3+ files or shared type/interface | cross-cutting, public API |
| **R** Reversibility | `git revert` undoes it | user-visible behavior or config | prod data, releases, money, external side effects |
| **S** Sensitivity | none | near auth/PII | auth, crypto, secrets, payments, PHI, tenancy |
| **V** Verifiability | a test/type/lint/build check fully covers it | partly covered | races, performance, security, UX judgment |
| **D** Diagnosis | cause known / none needed | reproducible, cause unknown | intermittent, prod-only, no repro |

**Hard (the Opus trigger)** = ANY of: D = 2 · two or more dimensions = 2 · A = 2 and C = 2. Scores are printed in the plan.

## Routing (per task, in this order; first match wins)
0. **Design shell or first design draft -> `claude-sonnet-builder` (default) or `claude-opus-builder` (most important or complex). NEVER agy or OpenCode.** Later mechanical edits to an approved design are ordinary builds below.
1. **Read-only** (find, explain, summarize, extract, format, and any self-check or audit the prompt asks for: link, accessibility, leftover-text checks) -> OpenCode `scout`. A check is a scout task with its own plan row, after the build phase it checks. The main session never does it, not even by reading files. Chain drained -> Flash scout (`flash`, `flash-low` for lookups), second choice only. Both drained -> held. No review.
2. **Sensitive files -> `claude-opus-builder`, labeled `opus-sensitive (reason)`.** By layer, not feature: only the sensitive files count (migrations, access/RLS policies, server functions that move money or stock, auth, crypto). UI, types, labels and thin wrappers of the same feature are ordinary builds: split out and route below.
3. **Tiny edit** (rename, copy tweak, config value, one-line fix, exactly described) -> `claude-haiku-builder`, or one Hydrogen mini-task when it passes the test in 6 and Hydrogen is available.
4. **Special input.** Images -> OpenCode `vision`. Audio or video -> `av`. Input over about 150k tokens -> `large`. No Hydrogen, Flash or Argon alternative: a drained chain is held.
5. **Hard** -> **Argon** (medium; `argon-high` for the hardest). Argon drained -> OpenCode `hard`, silently. Both drained -> held. Argon takes nothing else except its step in the fix ladders.
6. **Hydrogen test, every remaining build task.** Can Opus split it into small mini-tasks, each with an exact spec (files owned, names and signatures, markup or data to produce, a check a tool can run), needing no design taste and no cross-piece decision (Opus settles those in the briefs)? Yes -> **Hydrogen** mini-tasks. Hydrogen drained or tripped -> the same mini-tasks on OpenCode `build` (`mech` when A, R, S, V, D are all 0 and the total is 2 or less), silently. Both drained -> `flash-high` mini-tasks as a last resort, before any Module 3 question. A tripped pool with the other unavailable -> Argon medium; Argon drained -> `flash-high` for exact pieces, then held (`safety-switches.md`). Else held.
7. **Everything else** (not exactly specable, not hard: docs, copy, standard logic, tests) -> one **Hydrogen** task for the whole task. Hydrogen drained or tripped -> one OpenCode `build` task, silently. Both drained -> held (Flash takes exact specs only). Argon only if a safety switch says so.
- `--private` on any OpenCode route for S = 1 or a private repo.
- Tie-breakers: unsure `mech` vs `build` -> `build`. Unsure `build` vs `hard` -> `build`, unless D = 2.
- **Small job:** 2 or fewer build tasks, none S = 2, D = 2 or hard: one task, one route, normal review, no phases, no scout unless something is unknown.
- Every task gets a route, and every route is a builder.

## Quota state (markers `until=<UTC ISO>`, `reason=<text>`; active while now < `until`)
- agy: `.claude/agy-quota/<model-id>`, written by `agy-run.sh` (`until` = reset time, else now + 6 hours, a guess). Check `scripts/agy-run.sh --status`.
- OpenCode: `.claude/opencode-quota/<model-id>`, written by the script (reset time, else now + 1 hour; unavailable models 24 hours). Check `scripts/opencode-run.sh --status --role <role>` (exit 3 = whole chain drained).
- Before planning and before each phase run both checks (each OpenCode role in the plan). Route around drained models and say so in the plan line.
- Drained = an active marker or exit 3. Markers are per model ID. Hydrogen: `gemini-4-hydrogen-high` (other efforts have their own). Flash: `gemini-3.8-flash-high` (last-resort builds) / `gemini-3.8-flash-medium` (scouting). Argon: `gemini-4-argon-medium`. agy Sonnet / Opus: `claude-sonnet-5-5-medium` / `claude-opus-5-5-medium`.
- Clear a marker by deleting its file. If everything looks drained, ask the user to run `/usage` inside `agy` and check `opencode`.

## Hydrogen builds (default route for every build task)
- **Split** exactly-specable tasks into mini-tasks: 4 by default, more if needed. A task that cannot be specced exactly (Routing 7) is one Hydrogen run for the whole task, no split. Ids `<task-id>-m1`, `-m2`... Disjoint file subsets; mini-tasks on the same file run one after another (`after`).
- **Contract:** every mini-task brief (Hydrogen, OpenCode or Flash) says: "Read `.m11/contract.md` first. Use only the names defined there. Do not invent a class, id or function that is not in it." Never copy the list into briefs. A brief carries what is specific to its piece: files, markup or data to produce, a tool-runnable check, its task. In worktree mode it gives the absolute path of the contract file.
- **No shell in agy runs** (`agy-run.sh` tells the model). The spec's check is run by the reviewer when read-only safe (`grep`, `wc`, `node --check`, non-writing linters), else listed as not run.
- **Review ONCE per task, after ALL its mini-tasks finish, never per mini-task.** Review `owns:` is every file of the task; the 800-line rule uses combined changed lines.
- **Hydrogen drained mid-task:** unbuilt mini-tasks (or the cut-off whole task) go to OpenCode `build`, silently, same briefs (add "Another model may have partly edited the owned files. Inspect them first." only to a cut-off one). A task split over both pools is reviewed once as a whole and fixed on the Hydrogen-built row.
- Plan line: `p1-pages -> hydrogen x4 (m1 index.html, m2 about.html, m3 pricing.html, m4 faq.html; exact spec)`.

## OpenCode builds and contract file
- OpenCode: task level (Routing 7 fallback, hard, special input) or mini-task level (Hydrogen fallback), one call each. Free models are weaker: give exact file names, function names, signatures and a check command. `changed lines (owned)` of 0 on a build task is a failure even if the report says "done".
- `.m11/contract.md`: the Phase 0 (foundation/design) task gets it in `owns:`, and its brief says: "When done, write `.m11/contract.md`: every CSS class, id, CSS variable and function name you defined, the file layout, and any data shapes, one per line, grouped by file." No Phase 0 task: the main session writes it from the plan (file layout, names, signatures, data shapes). A later task adding shared names gets it in `owns:` in an earlier phase than the tasks using them, and appends.

## Task plan and phases
**Before ANY work starts, print the task plan, every time** (no approval needed). No builder is launched and no file touched until it is printed, even for a one-task job. Run the quota checks first.

Columns: `id | phase | route (reason) | score (A N C R S V D, e.g. A1 N1 C1 R0 S0 V1 D0) | owns | after`. Example rows: `p0-shell | 0 | claude-sonnet-builder (design shell) | ... | site/styles.css, .m11/contract.md | -`; `p1-money-db | 1 | claude-opus-builder (opus-sensitive: migration, RLS) | ...`.

- `id`: unique lowercase-kebab slug (becomes `task:`, `.m11/briefs/<task>.md`, worktree/branch name). `owns`: exact paths (dirs, globs allowed) or `none` for read-only scouting; Hydrogen lists mini-tasks with files. `after`: ids needed first.
- State each choice in one line before launching, silent re-routes included: `p1-pages-m3 -> opencode build (Hydrogen drained; silent re-route)`.
- **Phase 0** = foundations (design shell, shared styles, schema, types, scaffolding); runs alone; skip if none. **Phase N** = every remaining task whose `after` tasks are in earlier phases; parallel on disjoint files. Review a phase completely (diffs, fixes, accepted) before the next. New tasks found in review go to the next phase.

## Concurrency caps (defaults, guesses)
Max running at once: total 4 (all pools, Claude sub-agents included) · Hydrogen 3 (running `agy-run.sh --model hydrogen*` calls) · OpenCode 3 (all roles) · OpenCode `hard` or `large` 1 · Argon 1 · agy Sonnet 1 · agy Opus 1. Flash scouting and last-resort builds count toward the total only.
- A task counts from launch until its report returns; fix steps and scouting count. Claude sub-agents count toward the total only. Over the caps: launch what fits, queue the rest, alternate pools; a re-route keeps its slot.
- `agy-run.sh` exit 4: lower the total cap by 1 (min 1) for the session, relaunch, note it. OpenCode report starting `note: limits hit on N models`: lower the OpenCode cap by 1 (min 1), note it.

## File ownership
- In a phase every file belongs to exactly one task (one mini-task for Hydrogen), generated and test files included. Two tasks needing one file go in different phases (or merge).
- Shared files (nav/layout includes, package.json, lockfiles, route index, global config, barrels) belong to one task or to an **integration task** in the next phase; builders report needs as `needs:` lines.
- Installs and formatters are tasks: own them, run alone, own phase.
- Put the owned list in every brief. Read access is unrestricted. Sets cannot be disjoint: read `.claude/m11/worktree.md`.

## Delegation brief and launching
Briefs are self-contained (goal, exact file list, acceptance criteria, constraints); the run sees only the brief plus AGENTS.md.
- **Scripts (agy, OpenCode):** body-only file `.m11/briefs/<task>.md`; the script adds `task:`, `owns:`, "Read AGENTS.md first".
- **Claude sub-agents (builders, fixer, reviewers, scout):** header, blank line, body:
```
task: <slug>
owns: <comma-separated files, or none>
worktree: <path>        (optional)
design                  (optional, bare line, Claude design builders only)
```
- All tasks of a phase go out in ONE message with `run_in_background: true`: one Agent call per Claude sub-agent (`subagent_type` = agent name), one Bash call per script task or mini-task:
```
scripts/agy-run.sh --model <alias> --task <slug> --owns "<comma list|none>" --brief .m11/briefs/<slug>.md [--worktree <path>]
scripts/opencode-run.sh --role <role> --task <slug> --owns "<comma list|none>" --brief .m11/briefs/<slug>.md [--private] [--start <id[:variant]>] [--worktree <path>]
```
  Not executable: `bash scripts/<name>.sh ...`. Never add `--auto`, `--dangerously-skip-permissions` or any permission-bypass flag. Wait for completion notifications; never poll with sleep; never start the next phase early.
- Fix tasks (`<id>-rN`, N = 1 to 5): read `.claude/m11/fix-ladders.md` first.

| Exit | `opencode-run.sh` | `agy-run.sh` | Main session does |
|---|---|---|---|
| 0 | success | success, report printed | review |
| 1 | other error | other error (login, crash, timeout) | read it; fix the cause or send to the next fix step |
| 2 | `opencode` missing or bad arguments | refused alias/combination or bad arguments, or `agy` missing / model id unknown | refused: a routing mistake, fix the call. Tool missing: hard blocker, tell the user |
| 3 | `drained: <role> chain until <time>` | first line `drained: <model-id> until <time>`; owned files may be partly edited | re-route silently where Routing allows, else hold (`drained-pools.md`) |
| 4 | not used | `concurrency: <text>`, no marker | lower total cap by 1, relaunch, note it |

## Review
Changed lines = added + removed from `git diff --numstat -- <owned files>` plus lines of new untracked owned files (scripts report the sum; else compute read-only). A split task uses the combined diff.
- 800 or fewer -> `sonnet-reviewer`. More than 800, or hard-routed (Argon, OpenCode `hard`) or `opus-sensitive` at any size -> `opus-reviewer`.
- Applies to every build: Hydrogen, Flash, OpenCode, Argon, Claude builders (sensitive included), tiny edits. No agy or OpenCode model reviews, ever (reviewers must not edit). The reviewer is at least a grade above the implementer. The main session never reads a full diff.
- After a fix step, review again on the whole diff (over 800 moves up to `opus-reviewer`); tell the reviewer the previous defects.
- The first review of each Hydrogen- and OpenCode-built task feeds the safety-switch tallies. Give the reviewer the header and the acceptance criteria. It returns PASS or FAIL with numbered defects; non-blocking notes are not sent back unless they break a criterion.
- Check each report's "possibly from other parallel tasks" list: every path must be owned by another task in the phase. A stray edit to an unowned file is a defect: after the phase, list it in `.m11/last-run.md` or send it to a builder to revert. The main session never reverts a file.
- Never accept "done" on a report alone. Free-model, Hydrogen and Flash reports are leads, not facts.

## Final summary (always required)
**To the user, at most 8 short plain lines, no table, no pool jargon:** (1) what was built and how to open or run it; (2) what is still wrong or not done, or "nothing open"; (3) who did the work, one line, e.g. "Hydrogen built 4 pieces, free models 1, Claude designed the styles and did 3 reviews and 1 fix"; (4) anything the user must do or decide (a pending drained-pools question goes here); (5) "Details: .m11/last-run.md". Also print any line the user's prompt explicitly asks for (for example an "Elapsed" line or a files list).

**Detailed record -> `.m11/last-run.md`, overwritten each run:** the table below; `opus-sensitive` tasks with reasons; fixes by step, every Claude-plan fix called out; every silent re-route; safety-switch tallies and trips; drained-pools question and answer, Module 3 mode tasks; cap changes, worktree use, open items, minor choices.

| phase | task | pool (Hydrogen / OpenCode / Argon / Flash / Claude / Module 3) | model requested | model that ran | chain walk or re-route | reviewer (changed lines) | fix steps | result after review |
|---|---|---|---|---|---|---|---|---|

After each task append one line to `.m11/TASKS.md`: `ID | phase | pool | model that ran | score | reviewer | rounds | result | notes`.

## If everything fails
Only when `agy` or `opencode` is broken, the Claude plan is out of quota, or pools are drained and the user has not answered: stop and tell the user. Do none of the work yourself: the main session never implements.
