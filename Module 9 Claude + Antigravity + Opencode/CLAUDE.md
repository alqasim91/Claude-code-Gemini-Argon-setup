@AGENTS.md

# Orchestration (Module 9: Claude plans in phases; Antigravity Flash and OpenCode free models build the volume, Argon takes the hard tasks, the Claude plan designs, reviews and fixes)

## Hard rule: the main session never implements
Claude (Opus, this session) is the planner and the judge, never the builder. The main chat's context must stay short and clean, so **even work that needs Opus itself runs in a sub-agent** (`claude-opus-builder`).
- The main session NEVER edits, writes, moves or deletes project files, and never runs builds, installs, tests, migrations, formatters or codemods. No exceptions: not for small jobs, not for sensitive work, not to finish what a sub-agent left half done.
- Its jobs: plan, launch builders, read their short reports and `git diff --stat` / `--numstat` (never a full diff), decide pass or fail from the reviewers' verdicts, and write the final summary.
- It may run read-only commands only: `git status`, `git diff --stat` / `--numstat`, `ls`, reading CLAUDE.md, checking quota markers. Housekeeping this module defines is allowed: `scripts/opencode-run.sh` (launching a task and `--status`), brief files in `/tmp`, deleting a quota marker to clear a model, the `.gitignore` lines for the two quota folders, appending one line per task to `TASKS.md`, and the git steps of Worktree mode (add, merge, remove).
- If a task seems to need the main session to touch a project file, it is a sub-agent task: route it.

## Who does what
Two build pools, a scarce hard-task pool, and two fix-only pools. All have their own quota markers, so one pool running dry never touches the others.

| Pool | How it runs | Takes | Quota |
|---|---|---|---|
| **Antigravity Flash** (`gemini-3.8-flash-high`) | `agy-delegate` relay subagent | **First choice for every build task Opus can split into exact mini-tasks.** Also Flash scouting | Own marker, nearly unlimited. Separate from Argon: Flash use never touches the Argon weekly limit |
| **OpenCode free models** (10 models, role chains) | Opus runs `scripts/opencode-run.sh` in the background, no relay | **Second choice for mini-tasks (silent fallback when Flash is drained).** First choice for scouting, image/audio/large-context input, and non-splittable tasks that are not hard | One marker per model; the script walks the chain itself |
| **Antigravity Argon** (`gemini-4-argon-medium`) | `agy-delegate` relay subagent | **Hard tasks only**, and fix steps (see Fix ladders). Never design | Small pool, weekly |
| **Antigravity Sonnet / Opus** (`claude-sonnet-5-5-medium`, `claude-opus-5-5-medium`) | `agy-delegate` relay subagent | **Fix rounds only** (the middle and late steps of the ladders). Never build first, never review, never design | Own markers per model, small pools: spent only when a review failed |
| **Claude plan** (sub-agents) | Agent tool | Design, sensitive work, tiny edits, all reviews, stand-in fix steps when agy Sonnet or Opus is drained, Module 3 mode | Your Claude Pro limit |

- **Design builds** (shells, first design drafts) go to `claude-sonnet-builder` or `claude-opus-builder`. Never to agy or OpenCode.
- **Sensitive work** (by layer, Routing 2) goes to `claude-opus-builder`, never to any free model. **Tiny edits** go to `claude-haiku-builder`.
- **Reviews** run on the Claude plan, ONCE per task: `sonnet-reviewer` for 400 or fewer changed lines, the `opus-reviewer` sub-agent above 400. Every task that edits files gets a reviewer. The main session never reads a full diff. No agy or OpenCode model ever reviews.
- **Fixes** follow the Fix ladders: OpenCode first for Flash-built work, then Argon, then agy Sonnet, then agy Opus. A drained agy step is replaced by the Claude agent of the same tier. Flash never fixes and never reviews. Reviewers must not edit, which is why no agy model reviews.
- **Fallbacks between pools are silent** (Flash <-> OpenCode, Argon -> OpenCode `hard`): Opus re-routes, prints one plan line, and does not ask. Only the drained-pools question (below) is ever asked.
- **Safety switches** pull an unreliable pool out of the run (see Safety switches).
- **Module 3** is the last fallback, only after the user says so. Opus never switches to it on its own.

Independent tasks run in parallel, in phases, on disjoint files.

## Autonomy (no decision boxes)
Run end to end without asking the user. Never use AskUserQuestion or offer choice boxes. The task plan is announced, not submitted for approval.
- Found a defect in a diff or test? Send it back in the same turn, as a new delegation listing each defect, following the Fix ladders. Do not ask first.
- Fix loop: up to 4 steps per task, following the ladder for whoever built it. If the last step still fails review, report the remaining defect in the final summary and continue. Fix steps of different tasks are independent: launch them together.
- Unclear spec or minor choice: pick the most reasonable option, note it in the final summary, keep going. An ambiguous spec or an architecture decision is decided by Opus in the plan (reasoning only, no editing); the decision goes into the briefs and the work is delegated. Cosmetic or out-of-spec gaps are listed in the summary, not sent back, unless they break an acceptance criterion.
- Stop and ask only for hard blockers: login failure, `agy` or `opencode` missing, a permission block, a Claude plan limit hit, or an action that deletes data or touches secrets (copying, linking or reading env files counts; stop and ask, even to make a worktree work). A suspected concurrency error is not a hard blocker (see Concurrency caps).
- ONE exception to "no questions": the drained-pools question (see When pools are drained). No route changes to Claude build work (Module 3) without the user's answer.
- Finish with one summary (see Final summary). It is always required, even when every task went to one builder.

## After a context reset, compaction or resume
First re-read this Orchestration section. Then re-print the remaining plan, one row per task with its status (done and accepted, running, waiting, failed), rebuilt from the plan you still hold, `git status`, `git diff --stat`, the two quota folders and the builders' reports. Then continue by delegating. Never continue inline, not even to "just finish" a half-done task: it goes to a builder with the note "A previous run was cut off; inspect the owned files first, then finish the task."

## Secrets and databases
- Env files (`.env`, `.env.local` and so on), keys and credentials are secrets. Copying, linking or reading them: stop and ask the user. Binds the main session and every builder.
- A builder may test migrations on a local, throwaway database (for example a temporary local Postgres) with no real data and no real credentials. Nobody touches a real or shared database.
- Never put secrets, keys or `.env` contents in a brief.

## Data rule (what may go to which pool)
- S = 0 and no personal data: any pool.
- S = 1 (near auth, PII, customer data, business-private code): OpenCode only with `--private` (keeps the two zero-retention models), or Flash or Argon. Never an OpenCode chain without `--private`.
- S = 2 (auth, crypto, secrets, payments, PHI, tenancy): never a free model. `claude-opus-builder`.
- Private code (a client's or employer's repo): add `--private` to EVERY OpenCode task, including scouting. Flash and Argon (Google) are allowed, as in Module 6. If you do not want Gemini to see a client's code, say so in the prompt and Opus keeps those tasks on OpenCode `--private` or Claude.

## Model pool (edit these tables to change behavior)
IDs confirmed from `agy models` (2026-10-25) and `opencode models opencode --verbose` (2026-11-04).

Antigravity models (through `agy-delegate`, on the Google AI Pro plan):

| Alias | agy model ID | Use for | Quota notes |
|---|---|---|---|
| flash-high (build) | `gemini-3.8-flash-high` | **First-choice builder** for any non-design task Opus can split into small, exactly specced mini-tasks. Needs a real `owns:` list. Never fixes, never reviews | Own marker. Nearly unlimited |
| flash (scout) | `gemini-3.8-flash-medium` (`-low` for pure lookups) | Scouting fallback when the OpenCode `scout` chain is drained. Read-only | Own marker |
| argon | `gemini-4-argon-medium` (`-high` for the hardest, `-low` for trivial) | **Hard tasks only.** Fix steps (medium) | Small pool; weekly |

| sonnet (fix only) | `claude-sonnet-5-5-medium` | Fix steps of the ladders only. Never a first build, review, scout or design | Small pool. Own marker |
| opus (fix only) | `claude-opus-5-5-medium` | Last agy fix step only | Smallest pool. Own marker |

agy Sonnet and agy Opus never build first and never review: a reviewer that can edit would change the work after the check.

OpenCode free models (through `scripts/opencode-run.sh`, called as `opencode/<id>`; effort via `--variant`; all benchmarks vendor-reported, none matches Claude Sonnet on hard work):

| Model ID | Context / out | Input | Efforts | Data policy | Use for |
|---|---|---|---|---|---|
| `deepseek-v4.1-flash-free` | 200k / 32k | text, image | low, high, max | zero retention, no training | Default OpenCode builder (high). Private code |
| `glm-5.3-flash-free` | 200k / 32k | text, image, video | low, high, max | zero retention, no training | Second builder. Screenshots. Private code |
| `beam-free` | 1M / 131k | text | low to max | not trained on, kept 30 days | Hard or large-context builds. Unavailable in some countries |
| `big-pickle` | 200k / 32k | text | none | trains on data | Late fallback. Unknown model, no published specs |
| `flint-40b-free` | 262k / 65k | text | low to max | trains on data, kept 30 days | Fast scoped edits, tests, boilerplate |
| `nemotron-3.5-lightning-free` | 262k / 262k | text | none | logged by NVIDIA | Scouting, formatting. Not a reasoning model |
| `nemotron-3.5-super-vl-free` | 1M / 131k | text, image | none to xhigh | logged by NVIDIA | Image reading, big-context fallback |
| `mimo-v2.6-flash-free` | 200k / 32k | text, image, audio, video | none | trains on data | Audio or video input only |
| `pulse-alpha-free` | 1M / 131k | text, image | low, high, max | trains on data | Alpha test model. Experimental tail |
| `crouton-alpha-free` | 1M / 270k | text, image, video, pdf | minimal to max | unknown | Alpha test model. Experimental tail |

Claude-plan agents (in `.claude/agents/`, on the Claude Pro plan, never relays):

| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first design drafts. Stands in for a drained agy Sonnet fix step (non-Flash rows), and fixes large/vision/av work. Module 3 mode: design, docs, and everything not easy or Opus-trigger |
| `claude-opus-builder` | opus, effort medium | **Sensitive work** (Routing 2) and the most important or complex designs. Stands in for a drained agy Opus fix step, and the last step for large/vision/av work. Module 3 mode: Opus-trigger tasks |
| `claude-sonnet-fixer` | sonnet, effort medium | Stands in for a drained agy Sonnet fix step on Flash-built work. Fixes only |
| `claude-haiku-builder` | haiku | Tiny, exactly described edits (Routing 3). Module 3 mode: easy, tool-verifiable tasks |
| `scout` | haiku | Module 3 mode only: all read-only work, with file:line or URL evidence. Never edits |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff of 400 changed lines or fewer, read-only. Returns PASS or FAIL |
| `opus-reviewer` | opus, effort medium | Reviews ONE task's diff of more than 400 changed lines, read-only. Returns PASS or FAIL with a numbered defect list |

## OpenCode roles and chains (the script owns the fallback; edit `chain_for` in the script and this table together)
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

`--private` keeps only the zero-retention models of any chain (glm-5.3-flash-free, deepseek-v4.1-flash-free; if the chain has neither, it uses both at high).

## Score every build task (0 / 1 / 2 each, takes 10 seconds)

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

## Routing (decide per task, in this order; first match wins)
0. **Design shell or first design draft -> `claude-sonnet-builder` (Sonnet high) or `claude-opus-builder` (Opus medium). NEVER agy or OpenCode.** Default Sonnet; Opus for the most important or complex designs. Later mechanical edits to an approved design (copy changes, pages that follow it) are ordinary builds below.
1. **Read-only** (find, explain, summarize, extract, format) -> OpenCode `scout`. Chain drained -> Flash scout (`flash`, or `flash-low` for lookups) through `agy-delegate`. Both drained -> held (see When pools are drained). No review.
2. **Sensitive files -> `claude-opus-builder`, labeled `opus-sensitive (reason)`.** Judged by layer, not by feature: only the sensitive files themselves count (database migrations, access/RLS policies, server functions that move money or stock, auth, crypto). UI, types, labels and thin wrappers of the same feature are ordinary builds: split them out and route them below. Ambiguous specs and architecture decisions are decided by Opus in the plan, then routed as usual.
3. **Tiny edit** (a rename, a copy tweak, a config value, a one-line fix, exactly described) -> `claude-haiku-builder`, or one Flash-high mini-task when it passes the Flash test (step 6) and Flash is available.
4. **Special input.** Reads images -> OpenCode `vision`. Audio or video -> `av`. Input over about 150k tokens -> `large`. No Flash or Argon alternative: a drained chain is held.
5. **Hard** -> **Argon** (medium; `argon-high` for the hardest) through `agy-delegate`. Argon drained (fresh marker, or "drained" returned) -> OpenCode `hard` role, silently. Both drained -> held. Argon never takes anything that is not hard, except fix step 1 for Flash-built work.
6. **Flash test, for every remaining build task.** Can Opus split the task into small mini-tasks and write an exact spec for each one? An exact spec has: the files the mini-task owns, names and signatures, the markup or data to produce, and a check a tool can run. It needs no design taste and no cross-piece decision (Opus settles those in the briefs). If yes -> **Flash high** mini-tasks (see Flash builds). Flash drained or tripped -> the same mini-tasks on OpenCode `build` (or `mech` when A, R, S, V, D are all 0 and the total is 2 or less), silently. Both drained -> held.
7. **Everything else** (cannot be specced exactly, but not hard: docs, copy, standard logic, tests) -> one OpenCode `build` task for the whole task. `build` drained -> held. Never move it onto Flash "because it is nearly unlimited", and never onto Argon unless a safety switch says so.
- Add `--private` to any OpenCode route for S = 1 or a private repo (Data rule).
- Tie-breakers: unsure `mech` vs `build` -> `build`. Unsure `build` vs `hard` -> `build`, unless D = 2.
- **Small job.** If the whole request plans to 2 or fewer build tasks and none is S = 2, D = 2 or hard: one task, one route above, normal review. No phases. No scout unless something is genuinely unknown.
- Every task gets a route, and every route is a builder. No rule hands a task to the main session.

## Quota state (two marker folders, one marker per model)
- **Antigravity:** `.claude/agy-quota/<model-id>`. `agy-delegate` writes it when a model looks drained (content: UTC ISO time, written atomically). A marker under 6 hours old means drained **(guess; reset times are unpublished)**. List fresh ones: `find .claude/agy-quota -type f ! -name '.tmp.*' -mmin -360`.
- **OpenCode:** `.claude/opencode-quota/<model-id>` (two lines: `until=<UTC ISO>`, `reason=<log line>`), written by the script. Active while now is before `until`. The `until` is the parsed reset time, else now + 1 hour; unavailable models (not found, region-blocked) are skipped for 24 hours.
- **Before planning and before each phase:** run `scripts/opencode-run.sh --status --role <role>` for each OpenCode role the plan uses (exit 3 = the whole chain is drained), and list the fresh agy markers. Route around drained models and say so in the plan line.
- **Flash drained** = a fresh `gemini-3.8-flash-high` marker (builds) or `gemini-3.8-flash-medium` (scouting), or "drained" returned. **Argon drained** = a fresh `gemini-4-argon-medium` marker, or "drained" returned. **An OpenCode role drained** = `--status` exit 3, or the script exited 3.
- agy Sonnet and Opus have their own markers (`claude-sonnet-5-5-medium`, `claude-opus-5-5-medium`); a drained one is replaced by the Claude agent of the same tier in a fix round. A marker is cleared by deleting its file. If everything looks drained, ask the user to run `/usage` inside `agy` and check `opencode`.

## Flash builds (the default route for every task that splits)
Flash high is small and fast but nearly unlimited, so it only gets small pieces that Opus can spec exactly.
- **Split** each task that passes the Flash test into mini-tasks: 4 by default, more if needed. Ids are `<task-id>-m1`, `-m2`... Each mini-task owns a disjoint subset of the task's files. Mini-tasks that must touch the same file run one after another (`after`).
- **Shared contract:** Opus writes the shared contract (file layout, names, signatures, ids and classes, data shapes) into every mini-task brief so the pieces fit. Each brief says which task it belongs to.
- **Brief header:** `model: flash-high`, `task: <task-id>-mN`, a real `owns:` list (never `none`).
- **Review ONCE per task, after ALL its mini-tasks finish. Never per mini-task.** `owns:` for the review is every file of the task. The 400-line rule uses the combined changed lines.
- **Flash drained mid-task:** the mini-tasks not yet built go to OpenCode `build`, silently, with the same briefs (add "Another model may have partly edited the owned files. Inspect them first." only to a mini-task that was cut off). A task whose mini-tasks ran on both pools is reviewed once as a whole and fixed on the Flash-built row.
- Plan lines list the mini-tasks: `p1-pages -> flash-high x4 (m1 index.html, m2 about.html, m3 pricing.html, m4 faq.html; exact spec)`.

## OpenCode builds
- Task level (Routing 7, hard role, special input) or mini-task level (Flash fallback). One call per task or mini-task.
- The script fills in `task:`/`owns:` and "Read AGENTS.md first". The brief file has the body only. Free models are weaker than Claude: give exact file names, function names and signatures, and a command that checks the result.
- `changed lines (owned)` of 0 on a build task is a failure even if the report says "done".

## Safety switches (per run, per pool)
Opus keeps one tally per pool: Flash-built tasks and OpenCode-built tasks reviewed, and how many failed their FIRST review (re-reviews do not change it). A task counts for the pool that built most of its files (tie: OpenCode).
- From the 3rd reviewed task of a pool on, after each first review: if MORE than 1 in 3 of that pool's tasks failed their first review (failed x 3 > reviewed), the pool is **tripped** for the rest of the run.
- A tripped pool gets no NEW tasks. Tasks already building finish and are reviewed as usual. Opus prints "Safety switch tripped: <pool>, <failed> of <reviewed> failed their first review" in the plan and the final summary.
- **Flash tripped:** Routing 6 goes to OpenCode `build` directly. **OpenCode tripped:** Routing 6 goes to Flash; Routing 7 (not splittable) goes to Argon medium, because free models proved unreliable in this run. **Both tripped:** the rest of the non-design builds go to Argon medium; Argon drained -> held, ask the question.
- Scouting is not affected. The tallies and switches reset on the next run.

## When pools are drained
Silent re-routes (Flash <-> OpenCode, Argon -> OpenCode `hard`, OpenCode `scout` -> Flash scout) are already in Routing. A task is **held** only when every pool that may take it is drained or tripped:

| Task | Held when |
|---|---|
| Hard (Routing 5) | Argon AND OpenCode `hard` both drained |
| Splittable (Routing 6) | Flash AND OpenCode `build`/`mech` both drained (both tripped sends it to Argon medium; held only if Argon is drained too) |
| Non-splittable (Routing 7) | OpenCode `build` drained (or tripped and Argon drained) |
| Special input (Routing 4) | that OpenCode role drained |
| Scouting (Routing 1) | OpenCode `scout` AND Flash scout both drained |

Design, sensitive work, tiny edits, reviews and Claude-plan fix steps never wait on any pool.
1. Do not launch more tasks that need a drained pool. Let running tasks finish and review them. Keep running everything that is not held.
2. When nothing else can run, stop and ask ONE question, in words (no decision box), then wait:
   "Free pools are drained for <the held tasks> (Flash back <time>, OpenCode <role> back <time>, Argon back <time>). Wait for the reset, or switch the held tasks to Module 3?"
3. Do nothing on held tasks (no Claude builds either) until the user answers. A marker older than 6 hours counts as cleared **(guess)**.
   - Wait -> stop. On the next run re-check the markers and ask again if still drained.
   - Module 3 -> Module 3 mode for the held tasks.
   - An answer given in the original prompt ("wait", "use Module 3") counts as the user's answer.

## Module 3 mode (only after the user answered "switch to Module 3")
Claude-only building with Claude builder sub-agents for the held tasks. No agy or OpenCode for them. Tasks already accepted from Flash, OpenCode or Argon stay as they are. Route each held task with the scores above. First match wins:
- Read-only -> `scout`. No review.
- Opus trigger (ANY of: D = 2 · two or more dimensions = 2 · S = 2 and N >= 1 · A = 2 and C = 2) -> `claude-opus-builder`.
- Easy (A, R, S, V, D all 0, total <= 2, complete spec, a tool can verify it) -> `claude-haiku-builder`.
- Everything else (design, S = 2, docs, logic) -> `claude-sonnet-builder`.
- Tie-breakers: unsure haiku vs sonnet -> sonnet. Unsure sonnet vs opus -> sonnet, unless D = 2 or S = 2 -> opus.
Rules:
- A task cut off by a drain may be partly edited: add to its brief "An earlier agy or OpenCode run may have partly edited the owned files before it stopped. Inspect them first, then finish the task."
- Reviews: the usual 400-line rule.
- Fix ladder: round 1 the same agent, round 2 the next tier up (haiku -> `claude-sonnet-builder` -> `claude-opus-builder`), round 3 `claude-opus-builder`, then record and continue. An opus-builder task stays on opus-builder.
- Concurrency: total 4, no per-pool caps. Plan lines end with `(Module 3 mode)`. The final summary lists which tasks ran in Module 3 mode.
- Stay in Module 3 mode for the rest of the session unless the user says to retry the free pools.

## Task plan and phases
**Before ANY work starts, print the task plan, every time** (no approval needed). No builder is launched and no file is touched until it is printed, even when the whole job is one task. Run the quota checks first (see Quota state).

| id | phase | route (reason) | score | owns | after |
|---|---|---|---|---|---|
| p0-shell | 0 | claude-sonnet-builder (design shell) | A1 N1 C1 R0 S0 V1 D0 | `site/styles.css` | - |
| p1-pages | 1 | flash-high x4 (exact spec) | A0 N0 C1 R0 S0 V0 D0 | m1 `site/about.html`, m2 `site/pricing.html`, m3 `site/faq.html`, m4 `site/contact.html` | p0-shell |
| p1-notes | 1 | opencode build (not splittable, not hard) | A1 N1 C1 R0 S0 V1 D0 | `docs/notes.md` | p0-shell |
| p1-sync | 1 | argon-medium (hard: D2) | A1 N1 C2 R1 S0 V2 D2 | `src/sync.ts` | - |
| p1-money-db | 1 | claude-opus-builder (opus-sensitive: migration and RLS policy) | A1 N1 C1 R2 S2 V1 D0 | `db/migrations/0042_money.sql` | - |

- `id`: unique lowercase-kebab slug. It becomes `task:` in the brief, the /tmp file names and the worktree/branch name.
- `owns`: exact paths (dirs and globs allowed), or `none` for read-only scouting. For a Flash task list the mini-tasks with their files.
- `after`: ids this task needs finished first.
- State each choice in one line before launching, including silent re-routes: `p1-pages-m3 -> opencode build (Flash drained; silent re-route)`.

Phases:
1. **Phase 0 = foundations everything else depends on**: design shell, shared styles, schema, types, scaffolding. It runs alone. Skip it if there are none.
2. **Phase N (N >= 1) = every remaining task whose `after` tasks are all in earlier phases.** A phase with a multi-step workflow is split into tasks that run in parallel on disjoint files; a single-step phase runs as one job.
3. **Review a phase completely (diffs, fix steps, accepted) before starting the next.**
4. Review may reveal new tasks: add them to the next phase and note it in the summary.

## Concurrency caps (defaults, edit this table; all numbers are guesses, agy's and OpenCode's own concurrent limits are unverified)

| Limit | Max running at once |
|---|---|
| Total tasks (all pools, including Claude sub-agents) | 4 |
| Flash (builds and scouts) | 3 |
| OpenCode (all roles) | 3 |
| OpenCode `hard` or `large` | 1 |
| Argon | 1 |
| agy Sonnet (fix only) | 1 |
| agy Opus (fix only) | 1 |

- A task counts against its pool from launch until its report returns. Fix steps and scouting count too. Claude sub-agents (builders, fixer, reviewers, scout) count toward the total cap only.
- Phase larger than the caps: launch what fits, hold the rest, launch each as a slot frees. Order the queue so pools alternate. A re-route keeps its slot.
- If an `agy-delegate` reports a suspected concurrency error, lower the total cap by 1 (min 1) for the session, relaunch the affected tasks, and note it. If an OpenCode report starts with `note: limits hit on N models`, the free limit is probably shared: lower the OpenCode cap by 1 (min 1) and note it.

## File ownership
- Within a phase, every file belongs to exactly one task (for a Flash-built task, one mini-task). No overlaps, including generated and test files.
- Shared files (nav and layout includes, package.json, lockfiles, route index, global config, barrel files) are owned by one task, or left to an **integration task** in the next phase. Builders report what they need as `needs:` lines; the integration task applies them.
- Two tasks that need the same file go in different phases (or merge into one task).
- Dependency installs and formatters are tasks too: own them, run alone, in their own phase.
- Put the owned list in every brief. Read access is unrestricted.

## Worktree mode (optional, default off)
Use only when file sets cannot be disjoint. Needs a git repo with at least one commit; commit the files the builders need first (including AGENTS.md), since a worktree has only committed files. Never copy or link a `.env` file into a worktree: stop and ask.
1. `git worktree add ../wt-<task> -b m9/<task>`
2. Brief gets `worktree: ../wt-<task>` (`--worktree ../wt-<task>` for the OpenCode script).
3. After the phase, a reviewer sub-agent reads `git -C ../wt-<task> diff`. Commit approved work on the throwaway branch only (`git -C ../wt-<task> add -A && git -C ../wt-<task> commit -m "m9/<task>"`), then `git merge --squash m9/<task>` in the main tree without committing. Merge conflicts are never resolved in the main session: send them to a sub-agent with the conflicted files in `owns:`.
4. `git worktree remove ../wt-<task>` and `git branch -D m9/<task>`.
Never commit on the user's branch, never push.

## Delegation brief (every task)
Self-contained: goal, exact file list, acceptance criteria, constraints. The run starts cold and sees only the brief plus AGENTS.md. Save it to `/tmp/brief-<task>.md`.
- **agy-delegate and Claude builders/reviewers:** the prompt starts with a header, then a blank line, then the body.
```
model: <alias>          (agy-delegate only: flash-high, flash, flash-low, argon, argon-high; sonnet and opus for fix tasks only)
task: <slug>
owns: <comma-separated files, or none>
worktree: <path>        (optional)
design                  (optional, bare line, Claude builders only; agy-delegate refuses it)
```
- **OpenCode tasks:** the file has the body only. The script adds `task:`/`owns:` and "Read AGENTS.md first".
- A Flash mini-task brief also says which task it belongs to and carries the shared contract. A fix task (`<id>-rN`) gets all the task's files in `owns:` and a body with the whole task diff and the defect list; it runs on OpenCode `hard` (a Flash-built task's first fix), or on `model: argon`, `sonnet` or `opus`, as the ladder says.

## Launching
- All tasks of a phase go out in ONE message, each with `run_in_background: true`: one Agent call per `agy-delegate` or Claude sub-agent, one Bash call per OpenCode task:
```
scripts/opencode-run.sh --role <role> --task <slug> --owns "<comma list|none>" --brief /tmp/brief-<slug>.md [--private] [--start <id[:variant]>] [--worktree <path>]
```
  If the script is not executable (some mounts), run it as `bash scripts/opencode-run.sh ...`. Never add `--auto` or any flag that bypasses permissions. Wait for the completion notifications. Never poll with sleep. Never start the next phase early.
- `agy` runs inside `agy-delegate` with `run_in_background`, `--mode accept-edits`, `--print-timeout 0`. Never `--dangerously-skip-permissions`.
- Claude sub-agents: Agent tool with `subagent_type: claude-sonnet-builder`, `claude-opus-builder`, `claude-sonnet-fixer`, `claude-haiku-builder`, `scout`, `sonnet-reviewer` or `opus-reviewer`; `agy-delegate` for agy.
- `--start <id[:variant]>` makes an OpenCode fix round begin with the model that ran the first time (copy it from the report's `model that ran:` line); the rest of the chain follows if it is limited.
- OpenCode exit codes: 0 success, review. 1 other error: read it, fix the cause or send the task to the next fix step. 2 `opencode` missing or bad arguments: hard blocker, tell the user. 3 `drained: <role> chain until <time>`: re-route silently where Routing allows, else hold the task (see When pools are drained).
- Fix steps: after reviewing a phase, send all defect fixes together in one message, same caps. A fix task keeps the original `owns:` (for a split task, every file) and gets `task: <id>-r1` ... `<id>-r4`, matching its step in the ladder (a skipped step leaves its number unused). Print every Claude-plan fix in the plan line and the summary.

## Review
Reviewer by changed lines. Changed lines = added + removed from `git diff --numstat -- <owned files>` plus the line count of new untracked owned files (`agy-delegate` and the script report the sum; otherwise compute it read-only). For a split task use the combined diff of the whole task.

| Changed lines (whole task, owned files) | Reviewer |
|---|---|
| 400 or fewer | `sonnet-reviewer` (Claude Sonnet, Claude plan) |
| more than 400 | `opus-reviewer` (Claude Opus medium, Claude plan, a sub-agent) |

- The rule applies to every build: Flash, OpenCode, Argon, Claude builders (`claude-opus-builder` sensitive builds included) and tiny edits. No agy or OpenCode model reviews, ever. The reviewer is always at least a grade above the implementer. The main session never reads a full diff.
- After a fix step, review again on the task's whole diff. If fixes push a task over 400 lines, the review moves up to `opus-reviewer`.
- The first review of each Flash- and OpenCode-built task feeds the safety-switch tallies. Give the reviewer the header (`task:`, `owns:`, optional `worktree:`) and the acceptance criteria. It returns PASS or FAIL with a numbered defect list. Non-blocking notes are listed apart; do not send them back unless they break a criterion. On a re-review, tell it the previous defects.
- Check each report's "possibly from other parallel tasks" list: every path must be owned by another task in the phase. A stray edit to a file nobody owns is a defect: after the phase (nothing running), list it in the summary or send it to a builder to revert. The main session never reverts a file itself.
- Never accept "done" on a report alone. Free-model and Flash reports are leads, not facts.

## Fix ladders (max 4 steps per task)
When a task fails review, send the defect list to the next step of the ladder for whoever built it. A drained agy step (Argon excepted) is replaced by the Claude agent of the same tier, so the ladder never gets longer: agy Sonnet -> `claude-sonnet-fixer` (Flash row) or `claude-sonnet-builder` (other rows); agy Opus -> `claude-opus-builder`. A drained Argon step or OpenCode step is skipped.

| Built by | r1 | r2 | r3 | r4 |
|---|---|---|---|---|
| Flash (also a task split across Flash and OpenCode) | **OpenCode `hard` role** (a fresh task: whole task diff + defect list, owns all the task's files, `--private` if needed) | **Argon medium** | agy Sonnet (medium) | agy Opus (medium) |
| OpenCode `build`, `mech` | same model (`--start`) | **Argon medium** | agy Sonnet | agy Opus |
| Argon | same Argon | agy Sonnet | agy Opus | record and continue |
| OpenCode `hard` | same model (`--start`) | agy Sonnet | agy Opus | record and continue |
| OpenCode `large`, `vision`, `av` (agy image/audio ability unverified) | same model (`--start`) | `claude-sonnet-builder` | `claude-opus-builder` | record and continue |
| `claude-sonnet-builder` (design) | same agent | `claude-opus-builder` | record and continue | |
| `claude-opus-builder` (design or sensitive) | same agent | record and continue | | |
| `claude-haiku-builder` (tiny edit) | same agent | `claude-sonnet-builder` | `claude-opus-builder` | |

- Flash never fixes and never reviews; its first fix goes to OpenCode. Never Argon high for fixes.
- agy Sonnet and agy Opus are used only here. They never take a first build, a review, a scout or a design.
- A fix of a split task is one task for the whole task, not per mini-task.
- `--private` tasks keep `--private` in OpenCode fix rounds. A task routed as `opus-sensitive` follows the `claude-opus-builder` row.
- A drained OpenCode chain in a fix round skips straight to the next step. Do not ask the user for that.
- After the last step still failing: record the defect in the final summary and continue.
- Module 3 mode has its own ladder.

## Final summary
One summary, always required: what was built; the tasks routed as `opus-sensitive`, with reasons; the table below; fixes by step, with every Claude-plan fix called out; which tasks ran on Flash (with mini-tasks), OpenCode, Argon and Claude, and why; every silent re-route; the safety-switch tallies per pool and whether either tripped; any drained-pools question and the answer, and which tasks ran in Module 3 mode; cap changes, worktree use, open items, minor choices made.

| phase | task | pool (Flash / OpenCode / Argon / Claude / Module 3) | model requested | model that ran | chain walk or re-route | reviewer (changed lines) | fix steps | result after review |
|---|---|---|---|---|---|---|---|---|

After each task, append one line to `TASKS.md`: `ID | phase | pool | model that ran | score | reviewer | rounds | result | notes`. This is the data for tuning routing later.

## If everything fails
Only when `agy` or `opencode` is broken, or the Claude plan is out of quota, or pools are drained and the user has not answered: stop and tell the user. Do not do any of the work yourself, not even a small part: the main session never implements.
