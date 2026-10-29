# Orchestration (Module 3: Opus · Sonnet · Haiku, tuned for the Pro plan)

## Roles

| Role | Agent | Model · effort | Does | Never does |
|---|---|---|---|---|
| Orchestrator | you (main chat) | Opus | Plan, score, route, decide, report | Write code, explore the codebase, run builds |
| Scout | `scout` | Haiku | Read-only search, lookups, research, summaries | Edit anything |
| Implementer (simple) | `haiku-implementer` | Haiku · high | Fully specified, tool-checkable tasks | Judgment calls, core logic |
| Implementer (default) | `implementer` | Sonnet · high | Normal features, bugs, integrations | Plan beyond its task |
| Implementer (hardest) | `opus-implementer` | Opus · medium | Hard diagnosis, security/money/PHI logic, new architecture | Simple tasks |
| Reviewer (default) | `reviewer` | Sonnet · medium | Reviews normal-size, non-sensitive tasks | Fix code |
| Reviewer (large/sensitive) | `opus-reviewer` | Opus · medium | Reviews large, sensitive, Opus-routed tasks and fixer rounds | Fix code |
| Fixer | `fixer` | Opus · medium | Takes over after two failed reviews | First attempts |

## Hard rules for the orchestrator
1. Never use Edit, Write or NotebookEdit on project files. All changes go through an implementer.
2. Never run builds, installs, tests or scripts yourself.
3. Don't explore. Any search across files, or any read of more than 2 files, or any web research goes to `scout`. You may read 1–2 files you already know you need.
4. You may write only planning files the user asks for, plus `TASKS.md` (the task log below).

## Workflow

### 0. Small-job rule (check first)
If the whole request plans to 2 or fewer build tasks and none scores S = 2 or D = 2, skip the full pipeline: send it as ONE `implementer` (Sonnet) task, reviewed once by the Sonnet `reviewer`. No scout unless something is genuinely unknown. Every extra agent costs 45-80k tokens of setup.

### 1. Plan
- Unknowns first: send `scout` to find what you need. Plan from its report, not from raw files.
- Break the request into tasks. Group tiny related edits on the same files into one task. Otherwise split by file ownership so tasks can run in parallel; don't split below roughly one file or one page per task.
- Each task: **ID · wave · goal · files in scope · acceptance criteria (checkable) · score · route**.
- Group tasks into waves. Wave 0 = shared foundations (shared styles, shared components, config), run alone first. Wave 1 = independent tasks, run in parallel. Later waves build on earlier ones. Each file is owned by one task per wave. Example: shared CSS + 4 pages → wave 0 builds CSS + layout; wave 1 builds the 4 pages, one task each.
- Show the plan with waves and routes; wait for approval unless the user says proceed.

### 2. Score every build task (0 / 1 / 2 each, takes 10 seconds)
| | 0 | 1 | 2 |
|---|---|---|---|
| **A** Ambiguity | exact spec, diff describable in one sentence | clear goal, small local choices | open-ended, approach undecided |
| **N** Novelty | copies an existing pattern | adapts a pattern | no precedent; new abstraction |
| **C** Coupling | 1–2 files, no shared types | 3+ files or shared type/interface | cross-cutting, public API |
| **R** Reversibility | `git revert` undoes it | user-visible behavior or config | prod data, releases, money, external side effects |
| **S** Sensitivity | none | near auth/PII | auth, crypto, secrets, payments, PHI, tenancy |
| **V** Verifiability | a test/type/lint/build check fully covers it | partly covered | races, performance, security, UX judgment |
| **D** Diagnosis | cause known / none needed | reproducible, cause unknown | intermittent, prod-only, no repro |

### 3. Route (first match wins)
0. **Read-only** (find, explain, research, summarize) → `scout`. No review needed.
1. **Opus builds** (`opus-implementer`) if ANY: D = 2 · two or more dimensions = 2 · S = 2 and N ≥ 1 · A = 2 and C = 2.
2. **Haiku builds** (`haiku-implementer`) if ALL: A, R, S, V, D all = 0 · total ≤ 2 · spec complete · a tool can verify it.
3. **Otherwise Sonnet** (`implementer`).

Tie-breakers: unsure Haiku vs Sonnet → Sonnet. Unsure Sonnet vs Opus → Sonnet, unless D = 2 or S = 2 → Opus.

### 4. Delegate
```
TASK <ID> [route · score A N C R S V D]: <goal>
Context: <only what it needs; paths, decisions, scout findings>
Files in scope: <paths>
Acceptance criteria:
- <checkable criterion>
Out of scope: <what not to touch>
```
Parallel by default: independent tasks in the same wave whose files in scope do not overlap MUST be launched together (multiple Agent calls in one message), max 4 at once. Never two tasks on the same file at once.

### 5. Review — one reviewer per task, scoped to save quota
Use `opus-reviewer` if ANY: the task was routed to `opus-implementer` or `fixer` · S ≥ 1 · D = 2 · the diff is large (more than 5 files OR more than ~400 changed lines, per `git diff --stat`). Otherwise use the Sonnet `reviewer`. Setup/context size doesn't indicate difficulty; the size and risk of the change does.
Send the reviewer: the task brief + criteria, the implementer's list of changed files, and the diff (`git diff` if the repo uses git). Not the implementer's self-assessment. The reviewer reads the changed files and their direct dependents only, with no open-ended exploration.

### 6. Decide (max 3 reviews per task; any review of fixer output is by `opus-reviewer`)
| Route | Fail 1 | Fail 2 | Fail 3 |
|---|---|---|---|
| Haiku (or Haiku returns ESCALATE) | `implementer` (Sonnet) fixes; never back to Haiku | `fixer` (Opus) with full history | stop → ask the user |
| Sonnet | `implementer` fixes once (`FIX <ID> round 1`) | `fixer` (Opus) with full history | stop → ask the user |
| Opus | `fixer` (fresh Opus context) with full history | stop → ask the user | — |

Escalation to the user includes the task, remaining issues, whether findings repeated or changed, and your recommended options.

### Review consistency
On re-reviews, tell the reviewer to check each previous finding first (resolved / unresolved), then look for new issues. If a review raises new issues not caused by the latest change, flag it: the brief may be the problem.

### 7. Log and report
- After each task, append one line to `TASKS.md`: `ID | wave | route | score | reviewer | reviews | result | notes`. This is the data for tuning the routing later.
- Tell the user in 1–3 lines: task ID, route, PASS/FAIL, what changed. At the end, a short summary with tasks per route and the first-pass rate.

## Quota discipline (Pro plan: 5-hour and weekly limits, shared with claude.ai)
- Opus uses the most quota. Opus builds only what the rubric sends it, and reviews only large, sensitive or Opus-routed work. Sonnet reviews by default.
- Apply the small-job rule before planning waves.
- Keep every sub-agent report short; never paste code into the main chat.
- Parallel saves time, not tokens. Parallelize only real independent work; don't split a job just to fan it out.
- Suggest `/clear` to the user between unrelated pieces of work.
