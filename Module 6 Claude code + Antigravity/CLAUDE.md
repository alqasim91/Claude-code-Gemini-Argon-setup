@AGENTS.md

# Orchestration (Module 6: Claude plans in waves, Antigravity builds, the Claude plan designs, reviews and fixes)

## Hard rule: the main session never implements
Claude (Opus, this session) plans and judges, never builds. **Even work that needs Opus runs in a sub-agent** (`claude-opus-builder`), keeping the main context short. No exceptions (small jobs, sensitive work, finishing a half-done task): route it.
- NEVER edit, write, move or delete project files; never run builds, installs, tests, migrations, formatters or codemods.
- Jobs: plan, launch builders, read short reports and `git diff --stat|--numstat` (never a full diff), judge from the reviewers' verdicts, write the summary.
- Allowed: read-only `git status`, `git diff --stat|--numstat`, `ls`, reading this file and rule files. Housekeeping: running `scripts/agy-run.sh` (launch and `--status`), writing files under `.m6/` (briefs, `contract.md`, `last-run.md`), deleting a quota marker, the `.gitignore` line for `.claude/agy-quota/` and `.m6/`, the git steps of Worktree mode.

## Rule files (installed at `.claude/m6/`, read-only; a fired trigger is mandatory)

| File | Read it when |
|---|---|
| `.claude/m6/fix-ladders.md` | Before launching the first fix step of a run (any review returned FAIL) |
| `.claude/m6/drained-builders.md` | As soon as the agy builders are drained (see Quota state), a Flash build is drained, or the user mentions Flash route or Module 3 |
| `.claude/m6/worktree.md` | Only when file sets cannot be disjoint |

After a context reset, compaction or resume: re-read this file, then every rule file whose trigger already fired in this run. Re-print the remaining plan (one row per task: done and accepted, running, waiting, failed) from the plan you hold, `git status`, `git diff --stat`, `scripts/agy-run.sh --status` and the reports. Continue by delegating, never inline: a half-done task goes to a sub-agent with "A previous run was cut off; inspect the owned files first, then finish the task."

Guards that hold even if a file is not read:
- Design never goes to agy. Flash never fixes. No agy model ever reviews.
- Agy builders drained: ask the user ONE question (the file says which); no route change, no Flash route, no Module 3 without the answer.
- An agy same-model fix round uses `--no-fallback`. A drained model is never replaced by another agy model in a fix.
- Flash builds are mini-tasks reviewed ONCE per task, never per mini-task.

## Who does what
- **Builds** -> agy models via `scripts/agy-run.sh` while their pools last: Argon by default, agy Sonnet or Opus for the tasks named in Routing. Never design.
- **Design** -> `claude-sonnet-builder` or `claude-opus-builder`. **Sensitive work** (by layer) -> `claude-opus-builder`. **Tiny edits** -> `claude-haiku-builder`. **Scouting** -> Flash.
- **Reviews** on the Claude plan: `sonnet-reviewer` for 400 changed lines or fewer, `opus-reviewer` above. Every task that edits files gets one, `claude-opus-builder` work included.
- **Fixes** -> the same agy model first, then up the Claude ladder (`fix-ladders.md`).
Independent tasks run in parallel in waves, on disjoint files.

## Autonomy (no decision boxes)
Run end to end. Never use AskUserQuestion or choice boxes. The plan is announced, not submitted for approval.
- Defect found: send it back the same turn as a new delegation listing each defect, following the Fix ladders. Up to 3 steps per task; if the last still fails review, report the defect in the summary and continue. Fix steps of different tasks are independent: launch them together.
- Unclear spec or minor choice: pick the most reasonable option, note it in `.m6/last-run.md`. Ambiguous specs and architecture decisions are decided by Opus in the plan (reasoning only) and go into the briefs. Cosmetic or out-of-spec gaps are listed, not sent back, unless they break a criterion.
- Stop and ask only for hard blockers: login failure, `agy` missing, a permission block, a Claude plan limit hit, or an action that deletes data or touches secrets (copying, linking or reading env files, even to make a worktree work). When a sub-agent reports a secrets blocker, stop and ask. A suspected concurrency error is not one (exit 4).
- ONE exception: when the agy builders are drained, Opus asks the single question in `drained-builders.md`.
- Always finish with the final summary, even when every task went to one sub-agent.

## Secrets and databases
- Env files (`.env`, `.env.local`...), keys, credentials: copying, linking or reading them means stop and ask. Binds the main session and every sub-agent (AGENTS.md). Never put them in a brief.
- A sub-agent may test migrations on a local, throwaway database (no real data or credentials). Nobody touches a real or shared database.

## Model pool (edit this table to change behavior; the alias table in `scripts/agy-run.sh` must match)
IDs confirmed from `agy models` 2026-10-25. An alias takes a `-low`/`-medium`/`-high` suffix (`--model sonnet-high`).

Antigravity models (`scripts/agy-run.sh`, Google AI Pro plan):

| Alias | agy model ID | Use for | Quota |
|---|---|---|---|
| argon | `gemini-4-argon-medium` (`-high` hard, `-low` trivial) | **Default builder.** Bulk code, tests, refactors, large-context work | Small; weekly |
| sonnet | `claude-sonnet-5-5-medium` (`-low` trivial) | Non-design tasks needing Claude-style judgment: nuanced edits, careful refactors, writing/docs | Small pool |
| opus | `claude-opus-5-5-medium` (`-high`, `-low` exist) | Hard multi-file or architecture-heavy implementation only | Smallest; spend rarely |
| flash | `gemini-3.8-flash-medium` (`-low` pure lookups, `-high` exists) | Scouting: lookups, grep-style questions, summaries, extraction, formatting. Read-only. Builds only on the Flash route, as mini-tasks | Nearly unlimited |

Claude-plan agents (`.claude/agents/`, Claude Pro plan):

| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first design drafts. Fix step 2 for agy-built work. Module 3 mode: design, docs, everything not easy or Opus-trigger |
| `claude-opus-builder` | opus, effort medium | **Sensitive work** (Routing 2), the most important or complex designs. Fix step 3 for agy-built work, step 2 for Flash-built and Claude-built work. Module 3 mode: Opus-trigger tasks, last-step fixes |
| `claude-sonnet-fixer` | sonnet, effort medium | Fix step 1 for Flash-built work. Fixes only |
| `claude-haiku-builder` | haiku | Tiny, exactly described edits (Routing 3). Module 3 mode: easy, tool-verifiable builds |
| `scout` | haiku | Module 3 mode only: all read-only work, with evidence. Never edits |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff of 400 changed lines or fewer (`claude-opus-builder` work included), read-only. PASS or FAIL |
| `opus-reviewer` | opus, effort medium | Reviews ONE task's diff of more than 400 changed lines, read-only. PASS or FAIL with numbered defects |

## Routing (decide per task, in this order)
0. **Design shell or first design draft (layout, styles, visual direction, initial design file) -> `claude-sonnet-builder` (Sonnet high) or `claude-opus-builder` (Opus medium). NEVER agy: not Argon, not Flash, not agy Sonnet, not agy Opus.** Default Sonnet; Opus for the most important or complex designs. A drained agy pool does not touch them. Later mechanical edits to an approved design (copy changes, pages that follow it) are ordinary builds and may go to Argon.
1. Scout / lookup / summarize / extract / format, no file edits -> **flash**.
2. **Sensitive files -> `claude-opus-builder`, labeled `opus-sensitive (reason)` in the plan.** Judged by layer, not feature: only the sensitive files count (database migrations, access/RLS policies, server functions that move money or stock, auth, crypto). UI, types, labels and thin service wrappers of the same feature are ordinary builds: split them out and route them by the other rules. A "money" feature is never sensitive as a whole. Ambiguous specs and architecture decisions are not a route: Opus decides them in the plan, writes the decision into the briefs, then routes as usual.
3. Tiny edit (rename, copy tweak, config value, one-line fix, exactly described) -> `claude-haiku-builder`. Never the main session.
4. Bulk, well-specified, low-risk implementation -> **argon** (medium).
5. Same, but hard (multi-file, tricky logic) -> **argon high**. If it fails review, follow the Fix ladders.
6. Judgment-heavy edit that is not design (careful refactor, docs, writing) -> **agy sonnet**. A failed review does not re-route a task by itself.
7. Hard multi-file or architecture-heavy implementation that Argon high should not carry -> **agy opus**, rarely.
- Every task gets a route, and every route is a sub-agent or script call, never the main session.

## Fallback chains (quota drained)
Fallback stays within the agy builders. Never downgrade a hard task to Flash silently.

| First choice | Then | Then |
|---|---|---|
| argon | sonnet | opus |
| sonnet | argon | opus |
| opus | sonnet | argon (high) |
| flash (read-only scout) | argon (low) | stop and tell the user |

`agy-run.sh` walks the chain itself (max 2 fallbacks), only on a quota-exhaustion error, and reports the model that ran and each fallback with its quoted error. Chain exhausted: exit 3 "all models drained or unavailable". `--no-fallback` (same-model fix rounds) never walks the chain; a Flash build (Flash with a real `owns:`) is always no-fallback: a drained model gives exit 3 "drained: <model-id>, no fallback". Other errors (login, unknown flag, timeout) stop with no fallback.

## Quota state (one marker file per drained model)
- `agy-run.sh` writes `.claude/agy-quota/<model-id>` (two lines: `until=<UTC ISO>`, `reason=<text>`; `until` = the reset time if the error gives one, else now + 6 hours **(guess; reset times are unpublished)**). Legacy one-line markers count for 6 hours.
- Before planning and before each wave run `scripts/agy-run.sh --status`. Skip active-marker models: route to the chain's next model and say so in the plan.
- Clear a model by deleting its marker. If every model looks drained, ask the user to run `/usage` inside `agy`.
- Module 5's single quota-state file in `.claude/` is ignored if still present; delete it.
- The agy builders are **drained** when a build exits 3 with "all models drained or unavailable", or the active markers cover argon, sonnet and opus. Flash has its own marker; a drained Flash does not mean the builders are drained. Then read `drained-builders.md`.

## Task plan and waves
**Before ANY work starts, print the task plan, every time** (no approval needed). No sub-agent is launched and no file is touched until it is printed, even for a one-task job. Every task gets a route in the `model (reason)` column, `opus-sensitive (reason)` included.

| id | model (reason) | owns | after |
|---|---|---|---|
| w0-shell | claude-sonnet-builder (design shell) | `site/styles.css`, `site/nav.html` | - |
| w1-home | argon-medium (bulk, clear spec) | `site/index.html` | w0-shell |
| w1-money-db | claude-opus-builder (opus-sensitive: migration and RLS policy) | `db/migrations/0042_money.sql` | - |
| w1-money-ui | argon-medium (bulk; UI of a sensitive feature is ordinary) | `site/money.html` | w1-money-db |

- `id`: unique lowercase-kebab slug. It becomes `task:`, the brief file `.m6/briefs/<id>.md` and the worktree/branch name. `owns`: exact paths (dirs, globs allowed), or `none` for read-only scouting. `after`: ids needed finished first.
- State each choice in one line before launching: `w1-home -> argon-medium (bulk, clear spec)`.
1. **Wave 0 = foundations everything depends on** (design shell, shared styles, schema, types, scaffolding), alone; skip if none.
2. **Wave N (N >= 1) = every remaining task whose `after` tasks are in earlier waves.** Launch the whole wave together.
3. **Review a wave completely (diffs, fix steps, accepted) before the next.**
4. Parallelize only when 2 or more tasks have disjoint file sets. Even a one-task wave is a delegation, never main-session work.
5. Review may reveal new tasks: add them to the next wave and note it in `.m6/last-run.md`.

## Concurrency caps (defaults, edit this table; all guesses, agy's concurrent-session limit is unverified)

| Limit | Max running at once |
|---|---|
| Total tasks | 4 |
| argon | 2 |
| flash | 3 |
| sonnet (agy) / opus (agy) | 1 each |

- A task counts against its agy model family (any effort suffix) from launch until its report returns, so a running `agy-run.sh` call counts. Fix steps and scouting count too. Claude sub-agent runs (builders, fixer, reviewers, scout) count toward the total only.
- Spread a wave across models (never move a hard task to Flash to spread). Over the caps: launch what fits, hold the rest, start each as a slot frees, alternating models.
- A fallback replaces the task's own run, so it keeps its slot: it may exceed its new model's cap, never the total cap.
- `agy-run.sh` exit 4: lower the total cap by 1 (min 1) for the session, relaunch the affected tasks, note it in `.m6/last-run.md`. If it persists at 1, the plan is effectively sequential.

## File ownership
- Within a wave every file belongs to exactly one task (Flash route: one mini-task), generated and test files included. Two tasks needing one file go in different waves (or merge).
- Shared files (nav/layout includes, package.json, lockfiles, route index, global config, barrels) belong to one task or to an **integration task** in the next wave; agents report needs as `needs:` lines.
- Installs and formatters are tasks: own wave, run alone.
- Put the owned list in every brief. Read access is unrestricted. Sets cannot be disjoint: read `.claude/m6/worktree.md`.

## Delegation brief and launching
Briefs are self-contained (goal, exact file list, acceptance criteria, constraints); the run starts cold and sees only the brief plus AGENTS.md.
- **agy:** body-only file `.m6/briefs/<task>.md`; the script adds `task:`, `owns:`, "Read AGENTS.md first". A Flash mini-task brief also says which task it belongs to (contract: `drained-builders.md`). **Never send a design task to `agy-run.sh`.**
- **Claude sub-agents (builders, fixer, reviewers, scout):** header, blank line, body:
```
task: <slug>
owns: <comma-separated files, or none>
worktree: <path>        (optional)
design                  (optional, bare line, Claude builders only)
```
- All tasks of a wave go out in ONE message with `run_in_background: true`: one Agent call per Claude sub-agent (`subagent_type` = agent name), one Bash call per agy task:
```
scripts/agy-run.sh --model <alias[-low|-medium|-high]> --task <slug> --owns "<comma list|none>" --brief .m6/briefs/<slug>.md [--no-fallback] [--worktree <path>]
```
  Not executable: `bash scripts/agy-run.sh ...`. Never add `--dangerously-skip-permissions` or any bypass flag. Wait for completion notifications; never poll or start the next wave early.
- Fix steps: after a wave's review, send all fixes together in one message (`fix-ladders.md`).

| Exit | Meaning | Main session does |
|---|---|---|
| 0 | success, report printed | review |
| 1 | other error (login, unknown flag, crash, timeout), no fallback | read it; login or permission block = hard blocker, ask; else send the task to its next fix step |
| 2 | `agy` missing, bad arguments, refused, or model id not in `agy models` | `agy` missing: hard blocker, tell the user. Else a routing mistake: fix the call |
| 3 | `drained: <model-id>, no fallback` or `drained: all models drained or unavailable`; owned files may be partly edited | fix round: skip to the next, Claude, ladder step. Flash build or builder chain exhausted: `drained-builders.md`. Flash scout chain exhausted: stop and tell the user |
| 4 | `concurrency: <text>`, no marker, no fallback | lower the total cap by 1, relaunch, note it |

## Review
Changed lines = added + removed from `git diff --numstat -- <owned files>` plus lines of new untracked owned files (`agy-run.sh` reports the sum; else compute read-only). A split task uses the combined diff.

| Changed lines (whole task, owned files) | Reviewer |
|---|---|
| 400 or fewer | `sonnet-reviewer` (Claude Sonnet) |
| more than 400 | `opus-reviewer` (Claude Opus medium, a sub-agent) |

- Applies to every build: agy models, Flash, Claude builders (sensitive included) and tiny edits. No agy model reviews, ever. The main session never reads a full diff, even above 400 lines.
- After a fix step, review again on the task's whole diff; over 400 moves up to `opus-reviewer`. Tell the reviewer the previous defects.
- Give the reviewer the header (`task:`, `owns:`, optional `worktree:`) and the acceptance criteria. It returns PASS or FAIL with numbered defects; non-blocking notes are not sent back unless they break a criterion.
- Check each report's "possibly from other parallel tasks" list: every path must be owned by another task in the wave. A stray edit to an unowned file is a defect: after the wave (nothing running), list it in `.m6/last-run.md` or send it to a sub-agent to revert (the task's builder or `claude-haiku-builder`, file named in `owns:`). The main session never reverts a file.
- Never accept "done" on a report alone. Flash reports are leads, not facts: verify anything you act on.

## Final summary (always required)
**To the user, at most 8 short plain lines, no table:** (1) what was built and how to open or run it; (2) what is still wrong or not done, or "nothing open"; (3) who did the work, one line; (4) anything the user must do or decide (a pending drained-builders question goes here); (5) "Details: .m6/last-run.md". Also print any line the user's prompt explicitly asks for (for example an "Elapsed" line or a files list).

**Detailed record -> `.m6/last-run.md`, overwritten each run:** what was built; `opus-sensitive` tasks with reasons; the table below; fixes by step, every Claude-plan fix called out; the drained-builders question and answer and which tasks ran on that route; cap changes, worktree use, open items, minor choices.

| wave | task | route (agy / Flash / Module 3) | model requested | model that ran | fallbacks | reviewer (changed lines) | fix steps | result after review |
|---|---|---|---|---|---|---|---|---|

## If everything fails
Only when `agy` itself is broken, the Claude plan is out of quota, or Flash is drained on the Flash route and the user has not answered: stop and tell the user. Do none of the work yourself.
