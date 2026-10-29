@AGENTS.md

# Orchestration (Module 7: Claude plans in phases, Codex models run tasks in parallel)

Claude (Opus, this session) plans, routes, and reviews. It never implements bulk work. Implementation goes to Codex models through `scripts/codex-run.sh`, which Opus runs itself with Bash in the background. There is no relay subagent per task. Design, security, and fix rounds 2 and 3 go to Claude-plan subagents (`claude-sonnet-builder`, `claude-opus-builder`). Cheap reviews go to `sonnet-reviewer`. Independent tasks run in parallel, in phases, on disjoint files.

## Autonomy (no decision boxes)
Run end to end without asking the user. Never use AskUserQuestion or offer choice boxes. The task plan is announced, not submitted for approval.
- Found a defect? Send it back in the same turn, as a new task listing each defect. Do not ask first.
- Fix loop: max 3 rounds per task, per the Fix ladder. After round 3 still failing: record the defect in the final summary and continue.
- Unclear spec or minor choice: pick the most reasonable option, note it in the summary, keep going. Cosmetic or out-of-spec gaps are listed in the summary, not sent back, unless they break an acceptance criterion.
- Stop and ask only for hard blockers: `codex` missing (exit 2), a login failure, a permission block, an action that deletes data or touches secrets, or Codex chain drained AND Claude builders unavailable. A suspected concurrency error (exit 4) is not a hard blocker.
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
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first design drafts. Security, auth, secrets, unclear-spec tasks (Opus writes the spec). Fix rounds. Fallback when Codex is drained |
| `claude-opus-builder` | opus, effort medium | The most important designs. Round-3 fixes for Sol tasks. Builds and fixes |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff, read-only. Returns PASS or FAIL |

## Routing (decide per task)
| Task type | Goes to |
|---|---|
| Small job (whole request is ~1 file or under ~5 minutes) | One sol-medium run. No phases. Normal review ladder |
| Design shell or first design draft | `claude-sonnet-builder` (`claude-opus-builder` for key designs) |
| Scouting, lookups, read-only | luna-low |
| Tests, formatting, boilerplate, mechanical edits | luna-medium |
| Docs, copy, content pages | terra-medium |
| Standard implementation (default) | sol-medium |
| Hard: multi-file or tricky logic | sol-high |
| Security, auth, secrets, unclear spec | Opus writes the spec, `claude-sonnet-builder` builds |

**Design NEVER goes to a Codex model.** Later mechanical edits to an approved design (copy changes, pages that follow it) may go to sol or luna. Opus does not implement bulk work itself.

## Phases and task plan
If the user's prompt is not already phased, turn it into phases yourself.
1. **Phase 0 = foundation** everything else depends on: design shell, shared styles, schema, types, scaffolding. It runs alone. Skip it if there is none.
2. **Each later phase builds on the previous one.** A phase that needs a multi-step workflow is chunked into tasks that run in parallel on disjoint files. A single-step phase runs as one job.
3. **Review a phase completely (diffs, fix rounds, accepted) before starting the next.**
4. Review may reveal new tasks: add them to the next phase and note it in the summary.

Before the first launch, print the plan (no approval needed). Also list fresh quota markers first (see Quota fallback).

| id | phase | model (reason) | owns | after |
|---|---|---|---|---|
| p0-shell | 0 | claude-sonnet-builder (design shell) | `site/styles.css` | - |
| p1-home | 1 | sol-medium (standard, clear spec) | `site/index.html` | p0-shell |

- `id`: unique lowercase-kebab slug. It becomes the `--task` slug, the /tmp file names, and the worktree/branch name.
- `owns`: exact paths (dirs and globs allowed), or `none` for read-only scouting.
- `after`: ids this task needs finished first.
- State each choice in one line before launching: `p1-home -> sol-medium (standard, clear spec)`.

## Concurrency caps (defaults, edit this table; all numbers are guesses)

| Limit | Max running at once |
|---|---|
| Total | 3 |
| sol | 2 |
| terra | 2 |
| luna | 3 |

- A task counts against its Codex model family (any effort) from launch until its report returns. Fix rounds and scouting count too.
- Claude builder and fixer runs count toward the total only.
- Phase larger than the caps: launch what fits, hold the rest, launch each as a slot frees. Alternate models in the queue.
- A fallback replaces the task's own run, so it keeps its slot: it may exceed its new model's cap, never the total.
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
scripts/codex-run.sh --model <alias[-effort]|full-id> --task <slug> --owns "<comma list|none>" --brief /tmp/brief-<slug>.md [--worktree <path>] [--no-fallback]
```
Aliases: luna, terra, sol, with optional `-low|-medium|-high|-xhigh` (default medium). A full model id works too (`--effort` sets effort). Wait for the completion notifications. Never poll with sleep. Never start the next phase early. Never add a flag that bypasses the sandbox or approvals.

Exit codes:

| Code | Meaning | Opus does |
|---|---|---|
| 0 | Success, report printed | Review |
| 1 | Other error (last 20 log lines shown) | Read it. Fix the cause or treat as hard blocker |
| 2 | `codex` not installed or bad arguments | Hard blocker, tell the user |
| 3 | `drained: <chain>` (quota) | Claude builder for the task, or next fix-ladder step |
| 4 | Suspected concurrency limit | Lower the total cap by 1, relaunch |

Claude tasks: Agent tool with `subagent_type: claude-sonnet-builder`, `claude-opus-builder`, or `sonnet-reviewer`, `run_in_background: true`.

## Review ladder
Read the diff of owned files only. Changed lines = added + removed from `git diff --numstat` on owned files, plus the line count of new untracked owned files (the script prints it).

| Implementer | Reviewer |
|---|---|
| luna or terra | `sonnet-reviewer` |
| sol medium, diff <= 400 changed lines | `sonnet-reviewer` |
| sol medium over 400 lines, or sol high | Opus reviews itself (reads the diff in this session) |
| Claude builders (design, security) | Opus reviews itself |

- Never spawn a separate Opus reviewer. In the Module 3 cost test, fresh Opus reviewers were 23% of the bill and changed nothing.
- If fixes push a task over 400 lines, its review moves up to Opus.
- Give `sonnet-reviewer` the header (`task:`, `owns:`) and the acceptance criteria. It returns PASS or FAIL with a numbered defect list. Non-blocking notes are listed apart; do not send them back unless they break a criterion.
- Check each report's "possibly from other parallel tasks" list: every path must be owned by another task in the phase. A stray edit to a file nobody owns is a defect: after the phase (nothing running), revert it only if sure it came from a task, otherwise list it in the summary.
- Never accept "done" on a report alone. Luna scouting reports are leads, not facts: verify anything you act on.

## Fix ladder (max 3 rounds per task)
A fix task keeps the original `owns:` and gets task id `<id>-r1`, `<id>-r2`, `<id>-r3`. Fix rounds of different tasks launch together, within caps. Fix rounds of Codex models use `--no-fallback`. Round 1 uses the model that actually ran (after any fallback).

| Implementer | Round 1 | Round 2 | Round 3 |
|---|---|---|---|
| sol (medium or high) | same model | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| luna or terra | same model | sol high | `claude-sonnet-builder` |
| Claude builders | same agent | `claude-opus-builder` | record and continue |

After round 3 still failing: record the defect in the final summary and continue. A drained Codex model in a fix round (exit 3) is not a blocker: take the next round's agent. Any Claude-plan fix or fallback is stated in the plan line and the final summary.

## Quota fallback and markers
When a Codex model looks drained, `scripts/codex-run.sh` walks the chain (max 2 fallbacks) and reports what ran.

| First choice | Then | Then | Then |
|---|---|---|---|
| luna | terra | sol | Claude |
| terra | sol | Claude | - |
| sol | Claude | - | - |

"Claude" = the script exits 3 and prints `drained: <chain>`. Opus then spawns `claude-sonnet-builder` for that task and says so in the plan line and the summary. Never downgrade a hard (sol-high) task to luna or terra. Fix rounds never fall back (`--no-fallback`).

- The script writes `.claude/codex-quota/<model-id>` (UTC ISO time), atomically (temp file in the same dir, then `mv`).
- Before planning, list fresh markers: `find .claude/codex-quota -type f ! -name '.tmp.*' -mmin -360`. Skip models with a marker under 6 hours old **(guess)** and route to the chain's next step, saying so in the plan.
- Clear a model by deleting its marker.
- ChatGPT plan limits may be shared across all Codex models (unverified). Then every Codex model drains together and the work goes to Claude.

## Final summary
One summary: what was built; the table below; fixes by round (call out Claude-plan work); cap changes; worktree use; open items; minor choices made.

| phase | task | model requested | model that ran | fallbacks | reviewer | rounds | result |
|---|---|---|---|---|---|---|---|

## If everything fails
Only when every Codex model is drained or `codex` is broken AND Claude builders cannot take the work: stop and tell the user. Do not do the bulk work yourself.
