@AGENTS.md

# Orchestration (Module 8: Claude plans in phases, OpenCode free models run tasks in parallel)

Claude (Opus, this session) plans, routes, and reviews. It never implements bulk work. Implementation goes to the free OpenCode models through `scripts/opencode-run.sh`, which Opus runs itself with Bash in the background. There is no relay subagent per task. The script walks a fallback chain by itself: when a model hits its free limit, the next model in line takes the task. Design, security, and the late fix rounds go to Claude-plan subagents (`claude-sonnet-builder`, `claude-opus-builder`). When a whole chain is drained, Opus asks the user and the remaining work runs in Module 3 mode (Claude only) only when the user says so (see Free-model limits). Reviews go to `sonnet-reviewer` or Opus. Independent tasks run in parallel, in phases, on disjoint files.

## Autonomy (no decision boxes)
Run end to end without asking the user. Never use AskUserQuestion or offer choice boxes. The task plan is announced, not submitted for approval.
- Found a defect? Send it back in the same turn, as a new task listing each defect. Do not ask first.
- Fix loop: max 4 rounds per task, per the Fix ladder. After the last round still failing: record the defect in the final summary and continue.
- Unclear spec or minor choice: pick the most reasonable option, note it in the summary, keep going. Cosmetic or out-of-spec gaps are listed in the summary, not sent back, unless they break an acceptance criterion.
- Stop and ask only for hard blockers: `opencode` missing (exit 2), a login failure, a permission block, an action that deletes data or touches secrets, or a drained chain (exit 3) where the user has not answered.
- ONE exception to "no questions": the drained-chain question (see Free-model limits). Never switch to Claude builders for build work without the user saying Module 3.
- Finish with one summary (see Final summary).

## Model pool (edit this table to change behavior)
IDs from the user's `opencode models opencode --verbose` (2026-11-04). All are free, called as `opencode/<id>`. Effort goes in with `--variant`. A model with no variants takes none.  Big Pickle is a hidden model with no published specs. Benchmarks are vendor-reported. None of these matches Claude Sonnet on hard work.

| Model ID | Context / out | Input | Efforts | Data policy | Use for |
|---|---|---|---|---|---|
| `deepseek-v4.1-flash-free` | 200k / 32k | text, image | low, high, max | zero retention, no training | Default builder (high). Private code |
| `glm-5.3-flash-free` | 200k / 32k | text, image, video | low, high, max | zero retention, no training | Second builder. Screenshots. Private code |
| `beam-free` | 1M / 131k | text | low to max | not trained on, kept 30 days | Hard or large-context builds (high). Unavailable in some countries |
| `big-pickle` | 200k / 32k | text | none | trains on data | Late builder fallback. Unknown model, no published specs |
| `flint-40b-free` | 262k / 65k | text | low to max | trains on data, kept 30 days | Fast scoped edits, tests, boilerplate |
| `nemotron-3.5-lightning-free` | 262k / 262k | text | none | logged by NVIDIA | Scouting, formatting. Not a reasoning model |
| `nemotron-3.5-super-vl-free` | 1M / 131k | text, image | none to xhigh | logged by NVIDIA | Image reading, big context fallback |
| `mimo-v2.6-flash-free` | 200k / 32k | text, image, audio, video | none | trains on data | Audio or video input only |
| `pulse-alpha-free` | 1M / 131k | text, image | low, high, max | trains on data | Alpha test model. Experimental tail |
| `crouton-alpha-free` | 1M / 270k | text, image, video, pdf | minimal to max | unknown | Alpha test model. Experimental tail |

Claude-plan agents (in `.claude/agents/`):

| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first design drafts. Security, auth, secrets, unclear-spec tasks (Opus writes the spec). Fix round 3. Module 3 mode: design, S = 2, docs and everything not easy or Opus-trigger |
| `claude-opus-builder` | opus, effort medium | The most important designs. Fix round 4. Module 3 mode: Opus-trigger tasks |
| `claude-haiku-builder` | haiku | Module 3 mode only: easy tool-verifiable build tasks |
| `scout` | haiku | Module 3 mode only: all read-only work, with file:line or URL evidence. Never edits |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff, read-only. Returns PASS or FAIL |

## Roles and chains (the script owns the fallback; edit `chain_for` in the script and this table together)
A role is a chain of models in fallback order. `:x` is the variant.

| Role | Chain |
|---|---|
| `scout` | nemotron-3.5-lightning-free, flint-40b-free:low, glm-5.3-flash-free:low, deepseek-v4.1-flash-free:low |
| `mech` | flint-40b-free:medium, nemotron-3.5-lightning-free, deepseek-v4.1-flash-free:low, glm-5.3-flash-free:low |
| `build` | deepseek-v4.1-flash-free:high, glm-5.3-flash-free:high, flint-40b-free:high, beam-free:medium, big-pickle, pulse-alpha-free:high, crouton-alpha-free:high |
| `hard` | beam-free:high, deepseek-v4.1-flash-free:max, glm-5.3-flash-free:max, big-pickle, pulse-alpha-free:high, crouton-alpha-free:high |
| `large` (input over about 150k tokens) | beam-free:high, nemotron-3.5-super-vl-free:high, crouton-alpha-free:high |
| `vision` (screenshots, images) | glm-5.3-flash-free:high, nemotron-3.5-super-vl-free:high, pulse-alpha-free:high, crouton-alpha-free:high |
| `av` (audio or video input) | mimo-v2.6-flash-free, glm-5.3-flash-free:high, crouton-alpha-free:high |

`--private` keeps only the zero-retention models of any chain (glm-5.3-flash-free, deepseek-v4.1-flash-free; if the chain has neither, it uses both at high). Every other model may train on or log what it receives.

## Data rule (what may go to which model)
- S = 0 and no personal data: any chain.
- S = 1 (near auth, PII, customer data, business-private code): always `--private`.
- S = 2 (auth, crypto, secrets, payments, PHI, tenancy): never to a free model. `claude-sonnet-builder`.
- If the project's code is private (a client's or employer's code), add `--private` to every free-model task, including `scout`.
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
**Small job (check first).** If the whole request plans to 2 or fewer build tasks and none scores S = 2 or D = 2, run it as ONE `build` task with the normal review ladder. No phases. No scout unless something is genuinely unknown.

Otherwise route each task with this list. First match wins.
0. **Read-only** (find, explain, research, summarize) -> `scout`. No review. Reports are leads, not facts.
1. **Design shell or first design draft** -> `claude-sonnet-builder` (`claude-opus-builder` for key designs). Never a free model.
2. **S = 2** -> Opus writes the spec, `claude-sonnet-builder` builds. Opus reviews itself.
3. **Hard (the Opus trigger).** ANY of: D = 2 · two or more dimensions = 2 · A = 2 and C = 2 -> `hard`. Opus reviews itself.
4. **Special input.** Needs to read images -> `vision`. Audio or video -> `av`. Input over about 150k tokens -> `large`.
5. **Easy.** ALL of: A, R, S, V, D all = 0 · total <= 2 · spec complete · a tool can verify it -> `mech`.
6. **Otherwise** (docs, copy, logic, standard builds) -> `build`.

Add `--private` to any free-model route when S = 1. Tie-breakers: unsure `mech` vs `build` -> `build`. Unsure `build` vs `hard` -> `build`, unless D = 2 -> `hard`.

**Design NEVER goes to a free model.** Later mechanical edits to an approved design (copy changes, pages that follow it) may go to `mech` or `build`. Opus does not implement bulk work itself.

## Phases and task plan
If the user's prompt is not already phased, turn it into phases yourself.
1. **Phase 0 = foundation** everything else depends on: design shell, shared styles, schema, types, scaffolding. It runs alone. Skip it if there is none.
2. **Each later phase builds on the previous one.** A phase that needs a multi-step workflow is chunked into tasks that run in parallel on disjoint files. A single-step phase runs as one job.
3. **Review a phase completely (diffs, fix rounds, accepted) before starting the next.**
4. Review may reveal new tasks: add them to the next phase and note it in the summary.

Before the first launch, print the plan (no approval needed). Run `scripts/opencode-run.sh --status --role <role>` for each role the plan uses (see Free-model limits). If a role's chain is fully drained, do not launch it: follow the drained-chain question. In Module 3 mode, plan lines end with `(Module 3 mode)`.

| id | phase | route (reason) | score | owns | after |
|---|---|---|---|---|---|
| p0-shell | 0 | claude-sonnet-builder (design shell) | A1 N1 C1 R0 S0 V1 D0 | `site/styles.css` | - |
| p1-home | 1 | build (default) | A1 N1 C1 R0 S0 V1 D0 | `site/index.html` | p0-shell |

- `id`: unique lowercase-kebab slug. It becomes the `--task` slug and the /tmp file names.
- `score`: the seven scores, e.g. `A0 N1 C1 R0 S0 V1 D0`.
- `owns`: exact paths (dirs and globs allowed), or `none` for read-only scouting.
- `after`: ids this task needs finished first.
- State each choice in one line before launching: `p1-home -> build (score A1 N1 C1 R0 S0 V1 D0: default)`.

## Concurrency caps (defaults, edit this table; all numbers are guesses)
The free limits are IP-level and unpublished, so keep parallelism low. These caps limit parallel sessions and request rate.

| Limit | Max running at once |
|---|---|
| Free-model tasks total | 3 |
| `hard` or `large` tasks | 1 |

- A task counts from launch until its report returns. Fix rounds and scouting count too. Claude builder and fixer runs do not count.
- Phase larger than the caps: launch what fits, hold the rest, launch each as a slot frees.
- Module 3 mode: total 3.
- If a report starts with `note: limits hit on N models`, the free limit is probably shared: lower the free total by 1 (min 1) for the session and note it in the summary.

## File ownership
- Within a phase, every file belongs to exactly one task. No overlaps, including generated and test files.
- Shared files (nav and layout includes, package.json, lockfiles, route index, global config, barrel files) are owned by one task, or left to an **integration task** in the next phase. Agents report what they need as `needs:` lines; the integration task applies them.
- Two tasks that need the same file go in different phases (or merge into one task).
- Dependency installs and formatters are tasks too: own them, run alone, in their own phase.
- Put the owned list in every brief. Read access is unrestricted.

## Worktree mode (optional, default off)
Use only when file sets cannot be disjoint. Needs a git repo with at least one commit; commit what the model needs first (including AGENTS.md), since a worktree has only committed files.
1. `git worktree add ../wt-<task> -b oc/<task>`
2. Pass `--worktree ../wt-<task>` to the script (or `worktree:` in a Claude builder brief).
3. After the phase, review `git -C ../wt-<task> diff`. Commit approved work on the throwaway branch only (`git -C ../wt-<task> add -A && git -C ../wt-<task> commit -m "oc/<task>"`), then `git merge --squash oc/<task>` in the main tree without committing. Resolve conflicts directly or send back.
4. `git worktree remove ../wt-<task>` and `git branch -D oc/<task>`.
Never commit on the user's branch, never push. `owns:` still applies inside a worktree.

## Delegation brief (every task)
Self-contained: goal, owned files, acceptance criteria, constraints. Free models are weaker than Claude: give exact file names, function names and signatures, and a command that checks the result. The run starts cold and sees only the brief plus AGENTS.md. Save it to `/tmp/brief-<task>.md`.
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
scripts/opencode-run.sh --role <role> --task <slug> --owns "<comma list|none>" --brief /tmp/brief-<slug>.md [--private] [--start <id[:variant]>] [--worktree <path>]
```
`--start` makes a fix round begin with the model that ran the first time (copy it from the report's `model that ran:` line); the rest of the chain follows if it is limited. Wait for the completion notifications. Never poll with sleep. Never start the next phase early. Never add `--auto` or any flag that bypasses permissions. If the script is not executable (some mounts), run it as `bash scripts/opencode-run.sh`.

Exit codes:

| Code | Meaning | Opus does |
|---|---|---|
| 0 | Success, report printed (`chain walk:` shows skipped and limited models) | Review |
| 1 | Other error (last 20 log lines shown). Unavailable models (model not found, region-blocked) are skipped by the script for 24 hours like a limit, so exit 1 means a real failure or a timeout | Read it. Fix the cause or treat as hard blocker. A model that fails without a limit message is not skipped; send the task to the next fix round |
| 2 | `opencode` not installed or bad arguments | Hard blocker, tell the user |
| 3 | `drained: <role> chain until <time>` (every model in the chain is limited) | Let running tasks finish, then ask the user. See Free-model limits |

Claude tasks: Agent tool with `subagent_type: claude-sonnet-builder`, `claude-opus-builder`, `claude-haiku-builder` or `scout` (Module 3 mode only), or `sonnet-reviewer`, `run_in_background: true`.

## Review ladder
Read the diff of owned files only. Changed lines = added + removed from `git diff --numstat` on owned files, plus the line count of new untracked owned files (the script prints it). Every free model is below Claude Sonnet, so the reviewer is always at least a grade above the implementer.

| Implementer | Reviewer |
|---|---|
| any free model on `scout` | none (read-only) |
| any free model, diff <= 400 changed lines | `sonnet-reviewer` |
| any free model, over 400 lines, or the `hard` role | Opus reviews itself (reads the diff in this session) |
| Tasks routed by S = 2 or the Opus trigger | Opus reviews itself |
| Claude builders (design, security) | Opus reviews itself |

- The 400-line rule and the scores come from Module 3.
- Never spawn a separate Opus reviewer. In the Module 3 cost test, fresh Opus reviewers were 23% of the bill and changed nothing.
- If fixes push a task over 400 lines, its review moves up to Opus.
- Give `sonnet-reviewer` the header (`task:`, `owns:`) and the acceptance criteria. It returns PASS or FAIL with a numbered defect list. Non-blocking notes are listed apart; do not send them back unless they break a criterion.
- Check each report's "possibly from other parallel tasks" list: every path must be owned by another task in the phase. A stray edit to a file nobody owns is a defect: after the phase (nothing running), revert it only if sure it came from a task, otherwise list it in the summary.
- Never accept "done" on a report alone. A free model can report success with no edits: check `changed lines (owned)` is not 0 for a build task.
- Safety switch: if more than 1 in 3 free-built tasks fail their first review, send the rest of the run to the Claude fallback ladder (`claude-sonnet-builder`) and say so in the summary.

## Fix ladder (max 4 rounds per task)
A fix task keeps the original `owns:` and gets task id `<id>-r1` ... `<id>-r4`. Fix rounds of different tasks launch together, within caps.

| Implementer | Round 1 | Round 2 | Round 3 | Round 4 |
|---|---|---|---|---|
| free model, any role except `hard` | same model (`--start`) | the `hard` role (next free model) | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| `hard` role | same model (`--start`) | `claude-sonnet-builder` | `claude-opus-builder` | record and continue |
| Claude builders | same agent | `claude-opus-builder` | record and continue | |

- Tasks on `vision`, `av` or `large`: round 2 goes to `claude-sonnet-builder` instead of the `hard` role (the hard chain cannot read images or audio, and has smaller context), then round 3 `claude-opus-builder`, then record and continue.
- `--private` tasks keep `--private` in rounds 1 and 2. A task routed by S = 2 follows the "Claude builders" row.
- A drained chain in a fix round skips straight to the next Claude step. Do not ask the user for that.
- After the last round still failing: record the defect in the final summary and continue. Any Claude-plan fix is stated in the plan line and the final summary.

## Free-model limits and Module 3 mode
The free limits are IP-level and unpublished. The script keeps one marker per model in `.claude/opencode-quota/<model-id>` with two lines: `until=<UTC ISO>` and `reason=<matching log line>`, written atomically (temp file in the same dir, then `mv`). A marker is active while now is before `until`. The `until` is the parsed reset time if one was found, else now + 1 hour. The error wording is unverified, so the raw line is saved as `reason=`.

- **A model hits its limit:** the script marks it and moves to the next model in the chain on its own. Opus does nothing. The report's `chain walk:` line shows what happened. Skipped models stay skipped until their marker expires.
- Before planning and before each phase, run `scripts/opencode-run.sh --status --role <role>` for each role in use. Exit 0: at least one model is free. Exit 3: the whole chain is drained.
- **Whole chain drained (exit 3 or `--status` exit 3):**
  1. Do not launch more tasks of that role. Let running tasks finish and review their results.
  2. ASK the user, in words (no decision box): "Free models for <role> are drained (earliest back <time>). Wait (I re-check then) or switch the remaining tasks to Module 3 mode now?"
  3. Do nothing on Claude for build work until the user says Module 3. If they say wait, stop. On the next run run `--status` again and ask again if still drained.
- Delete a marker file to clear it by hand.

**Module 3 mode (only when the user says Module 3).** Re-route the remaining tasks with the same scores. First match wins:
- Read-only (find, explain, research, summarize) -> `scout`. No review.
- Opus trigger (D = 2, or two or more dimensions = 2, or S = 2 and N >= 1, or A = 2 and C = 2) -> `claude-opus-builder`.
- Easy (A, R, S, V, D all 0, total <= 2, complete spec, a tool can verify it) -> `claude-haiku-builder`.
- Everything else (design, S = 2, docs, copy, logic) -> `claude-sonnet-builder`.
- Tasks already accepted from free models stay as they are. A task that exited 3 may have been partly edited: add to its brief "A previous model may have partly edited the owned files before it stopped. Inspect them first, then finish the task."
- Reviews: `sonnet-reviewer` for haiku and sonnet work up to 400 changed lines. Opus reads the diff itself above 400 lines and for `claude-opus-builder` work.
- Fix ladder: round 1 same agent, round 2 next tier up (haiku -> sonnet -> opus), round 3 `claude-opus-builder`, then record and continue. An opus-builder task stays on opus-builder.
- Concurrency: total 3. Plan lines end with `(Module 3 mode)`. The final summary lists which tasks ran in Module 3 mode.
- Stay in Module 3 mode for the rest of the session unless the user says to retry the free models.

## Final summary
One summary: what was built; the table below; fixes by round (call out Claude-plan work); cap changes; worktree use; open items; minor choices made.

| phase | task | score | route | model that ran | chain walk (limits hit) | reviewer | rounds | result |
|---|---|---|---|---|---|---|---|---|

After each task, append one line to `TASKS.md`: `ID | phase | route | model that ran | score | reviewer | rounds | result | notes`. This is the data for tuning routing later.

## If everything fails
Only when `opencode` is broken, or a chain is drained and the user chose Module 3 but Claude builders cannot take the work: stop and tell the user. Do not do the bulk work yourself.
