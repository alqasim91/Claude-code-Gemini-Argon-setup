@AGENTS.md

# Orchestration (Module 8: Claude plans in phases, OpenCode free models run tasks in parallel)

Claude (Opus, this session) plans, routes, and reviews. It never implements bulk work. Implementation goes to the free OpenCode models through `scripts/opencode-run.sh`, which Opus runs itself with Bash in the background (no relay subagent). The script walks a fallback chain by itself: a model at its free limit is skipped and the next takes the task. It asks OpenCode which free models are offered now, skips removed ones and tries brand-new `-free` ones last (never with `--private`), so nobody edits the model list by hand. A timed-out model is skipped and the next one tried; two in a row stop the task. Design, security and late fix rounds go to Claude-plan subagents. A drained chain goes to the user; Module 3 mode (Claude only) only when the user says so. Reviews go to `sonnet-reviewer` or Opus. Independent tasks run in parallel, in phases, on disjoint files.

## Rule files (installed at `.claude/m8/`, read-only; a fired trigger is mandatory)

| File | Read it when |
|---|---|
| `.claude/m8/fix-ladders.md` | Before launching the first fix step of a run (any review returned FAIL) |
| `.claude/m8/drained-chain.md` | A script or `--status` exits 3, or the user mentions Module 3 |
| `.claude/m8/worktree.md` | Only when file sets cannot be disjoint |
| `.claude/m8/models.md` | Only when choosing `--start`, judging a data-policy question beyond the Data rule, or editing chains |

After a context reset: re-read this file and every rule file whose trigger already fired in this run.

Guards that hold even if a file is not read:
- Module 3 only after the user says so. Never switch to Claude builders for build work otherwise.
- S = 2 never goes to a free model.
- `--private` on every OpenCode task for S = 1 or a private repo.
- No free model reviews. Design never goes to a free model.

## Autonomy (no decision boxes)
Run end to end. Never use AskUserQuestion or offer choice boxes. The plan is announced, not submitted for approval.
- Found a defect? Send it back the same turn as a new task listing each defect (max 4 rounds, `fix-ladders.md`). After the last round still failing: record the defect and continue.
- Unclear spec or minor choice: pick the most reasonable option, note it in `.m8/last-run.md`. Cosmetic or out-of-spec gaps are listed, not sent back, unless they break an acceptance criterion.
- Stop and ask only for hard blockers: `opencode` missing (exit 2), a login failure, a permission block, an action that deletes data or touches secrets, or a drained chain (exit 3) the user has not answered.
- ONE exception to "no questions": the drained-chain question (`drained-chain.md`). Finish with the final summary.

## Agents and roles
| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first drafts. Security, auth, secrets, unclear-spec tasks (Opus writes the spec). Fix round 3 |
| `claude-opus-builder` | opus, effort medium | The most important designs. Fix round 4 |
| `claude-haiku-builder`, `scout` | haiku | Module 3 mode only (`drained-chain.md`) |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff, read-only. PASS or FAIL |

OpenCode roles (chains: `models.md`): `scout` (read-only), `mech` (easy edits), `build` (default), `hard`, `large` (input over about 150k tokens), `vision` (images), `av` (audio or video).

## Data rule (what may go to which model)
- S = 0 and no personal data: any chain.
- S = 1 (near auth, PII, customer data, business-private code): always `--private`. It keeps only the zero-retention models (`glm-5.3-flash-free`, `deepseek-v4.1-flash-free`); every other free model may train on or log what it receives.
- S = 2 (auth, crypto, secrets, payments, PHI, tenancy): never to a free model; `claude-sonnet-builder`.
- Private code (a client's or employer's): `--private` on every free-model task, `scout` included.
- Never put secrets, keys, or `.env` contents in a brief.

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
**Small job (check first).** 2 or fewer build tasks, none S = 2 or D = 2: ONE `build` task, normal review ladder, no phases, no scout unless something is genuinely unknown.

Otherwise route each task with this list. First match wins.
0. **Read-only** (find, explain, research, summarize) -> `scout`. No review. Reports are leads, not facts.
1. **Design shell or first design draft** -> `claude-sonnet-builder` (`claude-opus-builder` for key designs). Never a free model.
2. **S = 2** -> Opus writes the spec, `claude-sonnet-builder` builds. Opus reviews itself.
3. **Hard (the Opus trigger).** ANY of: D = 2 · two or more dimensions = 2 · A = 2 and C = 2 -> `hard`. Opus reviews itself.
4. **Special input.** Needs to read images -> `vision`. Audio or video -> `av`. Input over about 150k tokens -> `large`.
5. **Easy.** ALL of: A, R, S, V, D all = 0 · total <= 2 · spec complete · a tool can verify it -> `mech`.
6. **Otherwise** (docs, copy, logic, standard builds) -> `build`.

Add `--private` to any free-model route when S = 1. Tie-breakers: unsure `mech` vs `build` -> `build`. Unsure `build` vs `hard` -> `build`, unless D = 2 -> `hard`.

**Design NEVER goes to a free model.** Later mechanical edits to an approved design (copy changes, pages that follow it) may go to `mech` or `build`.

## Phases and task plan
If the user's prompt is not already phased, turn it into phases yourself.
1. **Phase 0 = foundation** everything else depends on (design shell, shared styles, schema, types, scaffolding). It runs alone; skip it if there is none.
2. **Each later phase builds on the previous one**: tasks in parallel on disjoint files.
3. **Review a phase completely (diffs, fixes, accepted) before the next.** New tasks found in review go to the next phase.

Before the first launch, print the plan (no approval needed). Before planning and before each phase run `scripts/opencode-run.sh --status --role <role>` for each role in use. Exit 0: a model is free. Exit 3: the chain is drained: do not launch that role; read `drained-chain.md`.

| id | phase | route (reason) | score | owns | after |
|---|---|---|---|---|---|
| p0-shell | 0 | claude-sonnet-builder (design shell) | A1 N1 C1 R0 S0 V1 D0 | `site/styles.css`, `.m8/contract.md` | - |
| p1-home | 1 | build (default) | A1 N1 C1 R0 S0 V1 D0 | `site/index.html` | p0-shell |

- `id`: unique lowercase-kebab slug (the `--task` slug and brief file name). `owns`: exact paths (dirs and globs allowed), or `none` for read-only scouting. `after`: ids needed first.
- State each choice in one line before launching: `p1-home -> build (score A1 N1 C1 R0 S0 V1 D0: default)`.

## Concurrency caps (defaults; all numbers are guesses)
| Limit | Max running at once |
|---|---|
| Free-model tasks total | 3 |
| `hard` or `large` tasks | 1 |

- A task counts from launch until its report returns (fix rounds and scouting too; Claude builder runs do not). Over the caps: launch what fits, launch the rest as slots free.
- Report starts `note: limits hit on N models`: the limit is probably shared; lower the free total by 1 (min 1) for the session and note it in `.m8/last-run.md`.

## File ownership
- Within a phase, every file belongs to exactly one task. No overlaps, including generated and test files.
- Shared files (nav and layout includes, package.json, lockfiles, route index, global config, barrel files) belong to one task or to an **integration task** in the next phase; agents report needs as `needs:` lines.
- Two tasks needing the same file go in different phases (or merge).
- Dependency installs and formatters are tasks: own them, run alone, in their own phase.
- Put the owned list in every brief. Read access is unrestricted. Sets cannot be disjoint: read `.claude/m8/worktree.md`.

## Delegation brief (every task)
Self-contained: goal, owned files, acceptance criteria, constraints. Free models are weaker: give exact file names, function names, signatures and a check command. The run sees only the brief plus AGENTS.md. Save it to `.m8/briefs/<task>.md`.
- **Contract:** the Phase 0 (foundation) task gets `.m8/contract.md` in `owns:`, and its brief says: "When done, write `.m8/contract.md`: every class, id, CSS variable, function name and signature, data shape and the file layout you defined, one per line, grouped by file." Briefs of tasks that depend on shared names say: "Read `.m8/contract.md` first. Use only the names defined there." Never copy the list into briefs. No Phase 0 task: Opus writes it from the plan.
- **Free-model tasks:** the file has the body only. The script adds `task:`/`owns:` and "Read AGENTS.md first".
- **Claude builders and reviewer:** the prompt starts with a header, then the body.
```
task: <slug>
owns: <comma-separated files, or none>
worktree: <path>        (optional)
design                  (optional, bare line, builders only)
```

## Launching
Free-model task, one Bash call per task, all calls of a phase in ONE message, each with `run_in_background: true`:
```
scripts/opencode-run.sh --role <role> --task <slug> --owns "<comma list|none>" --brief .m8/briefs/<slug>.md [--private] [--start <id[:variant]>] [--worktree <path>]
```
Wait for the completion notifications; never poll with sleep; never start the next phase early. Never add `--auto` or any flag that bypasses permissions. Not executable: `bash scripts/opencode-run.sh`.

Exit codes:

| Code | Meaning | Opus does |
|---|---|---|
| 0 | Success (`chain walk:` shows skips) | Review |
| 1 | Other error (last 20 log lines), or two timeouts in a row. Unavailable models are skipped for 24 hours, so this is a real failure | Read it. Fix the cause or treat as hard blocker. A model that fails without a limit message is not skipped; send the task to the next fix round |
| 2 | `opencode` not installed or bad arguments | Hard blocker, tell the user |
| 3 | `drained: <role> chain until <time>` (every model limited, or `--private` and no zero-retention model offered) | Let running tasks finish, then `drained-chain.md` |

Claude tasks: Agent tool with `subagent_type` = the agent name, `run_in_background: true`.

## Review ladder
Read the diff of owned files only. Changed lines = added + removed from `git diff --numstat` on owned files, plus lines of new untracked owned files (the script prints it). The reviewer is always at least a grade above the implementer.

| Implementer | Reviewer |
|---|---|
| `scout` | none (read-only) |
| any free model, diff <= 400 changed lines | `sonnet-reviewer` |
| any free model, over 400 lines, or the `hard` role | Opus reviews itself (reads the diff here) |
| Tasks routed by S = 2 or the Opus trigger, and Claude builders (design, security) | Opus reviews itself |

- Never spawn a separate Opus reviewer (23% of the Module 3 cost test bill, no change). If fixes push a task over 400 lines, its review moves up to Opus.
- Give `sonnet-reviewer` the header and the acceptance criteria. It returns PASS or FAIL with a numbered defect list; do not send non-blocking notes back unless they break a criterion.
- Check each report's "possibly from other parallel tasks" list: every path must be owned by another task in the phase. A stray edit to an unowned file is a defect: after the phase (nothing running), revert it only if sure it came from a task, else list it in `.m8/last-run.md`.
- Never accept "done" on a report alone: a free model can report success with no edits, so `changed lines (owned)` must not be 0 for a build task.
- Safety switch: more than 1 in 3 free-built tasks failing first review sends the rest of the run to `claude-sonnet-builder`; note it in `.m8/last-run.md`.

## Final summary
**To the user, at most 8 short plain lines:** what was built and how to open it; what is still open (or "nothing open"); who did the work in one line (e.g. "free models built 5 pieces, Claude designed the styles and did 3 reviews"); anything the user must do or decide (a pending drained-chain question); "Details: .m8/last-run.md". Also print any line the user's prompt explicitly asks for (for example an "Elapsed" line or a files list).

**Detailed record -> `.m8/last-run.md`, overwritten each run:** the table below; fixes by round (call out Claude-plan work); cap changes; worktree use; open items; minor choices; Module 3 mode tasks.

| phase | task | score | route | model that ran | chain walk (limits hit) | reviewer | rounds | result |
|---|---|---|---|---|---|---|---|---|

After each task, append one line to `.m8/TASKS.md`: `ID | phase | route | model that ran | score | reviewer | rounds | result | notes`. This is the data for tuning routing later.

## If everything fails
Only when `opencode` is broken, or the user chose Module 3 and Claude builders cannot take the work: stop and tell the user. Do not do the bulk work yourself.
