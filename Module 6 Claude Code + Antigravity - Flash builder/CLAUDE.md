@AGENTS.md

# Orchestration (Module 6 Flash builder: Claude plans in waves, Flash high builds small exact pieces, Argon builds the rest and fixes Flash's work, the Claude plan designs, reviews and fixes)

## Hard rule: the main session never implements
Claude (Opus, this session) is the planner and the judge, never the builder. The main chat's context must stay short, so **even work that needs Opus itself runs in a sub-agent** (`claude-opus-builder`). No exceptions: not for small jobs, sensitive work, or finishing what a builder left half done.
- NEVER edit, write, move or delete project files; never run builds, installs, tests, migrations, formatters or codemods.
- Jobs: plan, launch builders, read their short reports and `git diff --stat` / `--numstat` (never a full diff), decide pass or fail from the reviewers' verdicts, write the final summary.
- Allowed: read-only `git status`, `git diff --stat` / `--numstat`, `ls`, reading CLAUDE.md and rule files. Housekeeping: launching `scripts/agy-run.sh` (and `--status`), writing files under `.m6/` (briefs, `contract.md`, `last-run.md`), deleting a quota marker, the `.gitignore` lines for `.claude/agy-quota/` and `.m6/`, the git steps of Worktree mode.

## Rule files (installed at `.claude/m6/`, read-only; a fired trigger is mandatory)

| File | Read it when |
|---|---|
| `.claude/m6/fix-ladders.md` | Before launching the first fix step of a run (any review returned FAIL) |
| `.claude/m6/drained-pools.md` | As soon as any task is held, Flash or an agy pool is drained (marker or exit 3), or the user mentions Module 3. Holds Module 3 mode |
| `.claude/m6/safety-switch.md` | After the 3rd reviewed Flash-built task, if any Flash-built task failed its first review |
| `.claude/m6/worktree.md` | Only when file sets cannot be disjoint |
| `.claude/m6/models.md` | Only when picking an effort level or model for a task that is not a plain Flash build, or editing the pool |

After a context reset, compaction or resume: re-read this file, then every rule file whose trigger already fired in this run. Re-print the remaining plan (one row per task: done and accepted, running, waiting, failed) from the plan you hold, `git status`, `git diff --stat`, `agy-run.sh --status` and the builders' reports. Continue by delegating, never inline: a half-done task goes to a builder with "A previous run was cut off; inspect the owned files first, then finish the task."

Guards that hold even if a file is not read:
- Flash never fixes and never reviews; no agy model reviews. A design task never goes to agy (not Flash, not Argon, not agy Sonnet or Opus): never send one to `agy-run.sh`.
- Flash-built work is fixed by Argon medium (`--no-fallback`), then `claude-sonnet-fixer`, then `claude-opus-builder`. Never Argon high or another agy model.
- Flash drained on a build: stop and ask "Flash is drained. Wait for the reset, or switch to Module 3?" Never move the pieces to Argon yourself. Module 3 never without the user's answer.
- Safety switch: from the 3rd reviewed Flash-built task, if more than 1 in 3 failed their first review (failed x 3 > reviewed), stop sending NEW tasks to Flash for the rest of the run.

## Who does what
- **Flash high** (`gemini-3.8-flash-high`) is the first-choice builder: every non-design build task Opus can split into small, exactly specced mini-tasks, through `agy-run.sh`, with no question to the user (Flash builds). It saves the small Argon pool. Flash also scouts (read-only).
- **Argon** (`gemini-4-argon-medium`, `-high` for hard tasks) builds what Opus cannot spec exactly. agy Sonnet or agy Opus take the tasks named in Routing. Never design.
- **Claude plan** (Agent tool): design builds (`claude-sonnet-builder` or `claude-opus-builder`, never agy), sensitive work (`claude-opus-builder`, judged by layer, Routing 2), tiny edits (`claude-haiku-builder`), all reviews, and fix steps 2-3. Agents: `claude-sonnet-builder`, `claude-opus-builder`, `claude-sonnet-fixer` (fixes Flash-built work only), `claude-haiku-builder`, `scout` (Module 3 mode only), `sonnet-reviewer`, `opus-reviewer` (table: `models.md`). Never the main session.
- **Reviews** ONCE per task (see Review), on the Claude plan; every task that edits files gets one. **Fixes:** fix ladders. **Pools drained?** Opus asks the user one question, only when it truly needs one (`drained-pools.md`); it never switches to Module 3 on its own.
Independent tasks run in parallel, in waves, on disjoint files.

## Autonomy (no decision boxes)
Run end to end. Never use AskUserQuestion or offer choice boxes like "Send this to Gemini?". The task plan is announced, not submitted for approval; choosing Flash for a task that splits is part of the plan.
- Defect found in a diff or test: send it back the same turn as a new delegation listing each defect (fix ladders). Up to 3 steps per task; if the last still fails review, record the defect and continue. Fix steps of different tasks are independent: launch them together.
- Unclear spec or minor choice: pick the most reasonable option, note it in `.m6/last-run.md`, keep going. Ambiguous specs and architecture decisions are decided by Opus in the plan (reasoning only); the decision goes into the briefs. Cosmetic or out-of-spec gaps (e.g. a missing extra the spec never asked for) are listed, not sent back, unless they break an acceptance criterion.
- Stop and ask only for hard blockers: login failure, `agy` missing, a permission block, a Claude plan limit hit, or an action that deletes data or touches secrets (copying, linking or reading env files, keys, credentials, even for a worktree). Builders follow the same rule (AGENTS.md, agent files). A suspected concurrency error is not a hard blocker.
- Two exceptions to "no questions", both about drained pools: "wait for the reset, or switch to Module 3?" (all agy pools) and "Flash is drained. Wait for the reset, or switch to Module 3?". Nothing else is asked, and no route changes without the user's answer.
- Always finish with the final summary, even when every task went to one builder.

## Secrets and databases
- Env files (`.env`, `.env.local`...), keys, credentials: copying, linking or reading them means stop and ask. Binds the main session and every builder. Never put them in a brief.
- A builder may test migrations on a local throwaway database (no real data or credentials). Nobody touches a real or shared database.

## Routing (decide per task, in this order)
0. **Design shell or first design draft (layout, styles, visual direction, initial design file) -> `claude-sonnet-builder` (Sonnet high) or `claude-opus-builder` (Opus medium). NEVER agy (not Flash, Argon, agy Sonnet or Opus).** Default Sonnet; Opus for the most important or complex designs. Later mechanical edits to an approved design (copy changes, adding pages that follow it) are ordinary builds and go through the Flash test.
1. Scout / lookup / summarize / extract / format, no file edits -> **flash** (`--owns none`; medium, `flash-low` for pure lookups).
2. **Sensitive files -> `claude-opus-builder`, labeled `opus-sensitive (reason)` in the plan.** Judged by layer, not feature: only the sensitive files count (database migrations, access/RLS policies, server functions that move money or stock, auth, crypto). UI, types, labels and thin service wrappers of the same feature are ordinary builds: split them out and route them by the other rules (Flash test). A "money" feature is never sensitive as a whole. Ambiguous specs and architecture decisions are not a route: Opus decides them in the plan, then routes each task as usual.
3. Tiny edit (rename, copy tweak, config value, one-line fix, exactly described) -> `claude-haiku-builder`, or one Flash-high mini-task when it passes the Flash test and Flash is available. Never the main session.
4. **Flash test, for every remaining build task, while planning each wave.** Can Opus split the task into small mini-tasks, each with an exact spec (files owned, names and signatures, markup or data to produce, a check a tool can run), needing no design taste and no cross-piece decision (Opus settles those in the briefs)? Yes for every piece -> **Flash high** mini-tasks (Flash builds). Default route, no question to the user.
5. Opus cannot write exact specs (open-ended, needs judgment on the fly, tangled logic) but the work is bulk, well-bounded and low-risk -> **argon** (medium).
6. Same, but hard (multi-file, tricky logic) -> **argon-high**. If it fails review, follow the fix ladders.
7. Judgment-heavy edit that is not design (careful refactor, docs, writing) -> **sonnet** (agy). A failed review does not re-route a task by itself.
8. Hard multi-file or architecture-heavy implementation that Argon high should not carry -> **opus** (agy), rarely.
- A tripped safety switch removes step 4 for the rest of the run: those tasks go to step 5 or 6.
- Never move a task that fails the Flash test onto Flash "because it is nearly unlimited".
- Every task gets a route, and every route is a builder, never the main session.

## Fallback chains and quota state
`agy-run.sh` walks the chain itself (max 2 fallbacks), only when an error looks like quota exhaustion, and reports which model actually ran. Fallback stays within the agy builders; never downgrade a hard task to Flash.

| First choice | Then | Then |
|---|---|---|
| argon | sonnet | opus |
| sonnet | argon | opus |
| opus | sonnet | argon (high) |
| flash (read-only scout) | argon (low) | stop and tell the user |
| flash (build) | no chain: stop and ask | - |

- **No-fallback mode** (`--no-fallback`): same-model fix rounds, Argon medium fixing Flash-built work, and always for Flash builds (the script forces `gemini-3.8-flash-high`). A drained model returns exit 3 `drained: <model-id>, no fallback`. Other errors (login, unknown flag, timeout, suspected concurrency) never fall back.
- Markers: `.claude/agy-quota/<model-id>`, written atomically by the script (`until=` reset time, else now + 6 hours, a guess; `reason=`). Before planning and before each wave run `scripts/agy-run.sh --status`, skip models with an active marker, route to the chain's next model and say so in the plan. Clear a model by deleting its marker. If everything looks drained, ask the user to run `/usage` inside `agy`. Module 5's single quota-state file in `.claude/` is ignored if still present; delete it.
- Marker ids: Flash `gemini-3.8-flash-high` (builds) / `-medium` (scouting); Argon `gemini-4-argon-medium`.
- The **agy pools** (Argon, agy Sonnet, agy Opus) are **drained** when every builder chain is exhausted (a build comes back `drained: all models drained or unavailable`, or the fresh markers cover argon, sonnet and opus). Flash has its own markers: a drained Flash does not mean the agy pools are drained, and the other way round. **Argon drained** (for fix routing): a fresh `gemini-4-argon-medium` marker, or exit 3 `drained: gemini-4-argon-medium, no fallback`.

## Flash builds (the default route for every task that splits)
- **Split** each task that passes the Flash test into mini-tasks: 4 by default, more if needed. Ids `<task-id>-m1`, `-m2`... Each owns a disjoint subset of the task's files; mini-tasks touching the same file run one after another (`after`).
- **Shared contract file:** shared names (file layout, classes, ids, CSS variables, function names and signatures, data shapes) live in `.m6/contract.md`, never copied into briefs. The wave 0 (foundation/design) task owns it, and its brief says: "When done, write `.m6/contract.md`: every CSS class, id, CSS variable and function name you defined, the file layout, and any data shapes, one per line, grouped by file." No wave 0 task: the main session writes it from the plan. A later task adding shared names owns it in an earlier wave than the tasks using them, and appends.
- **Mini-task brief** = only what is specific to its piece: the task it belongs to, its files, its exact spec (names and signatures of its own piece, markup or data to produce, a tool-runnable check), and the line "Read `.m6/contract.md` first. Use only the names defined there. Do not invent a class, id or function that is not in it." (absolute path in worktree mode).
- **Launch:** `agy-run.sh --model flash-high --task <task-id>-mN --owns "<its files>" --brief .m6/briefs/<task-id>-mN.md`. Real `owns:` list, never `none`. Flash builds never fall back and always run at high effort (no `--no-fallback` needed).
- **No shell in agy runs** (the script tells the model). The reviewer runs the spec's check when read-only safe (`grep`, `wc`, `node --check`, non-writing linters), else lists it as not run.
- **Review ONCE per task, after ALL its mini-tasks finish. Never per mini-task.** Review `owns:` is every file of all its mini-tasks; the 400-line rule uses the combined changed lines.
- **Fixes:** the Flash-built row of the fix ladders; one task for the whole task, not per mini-task. **Flash drained on a build:** see the guard above.
- Plan lines list the mini-tasks: `w1-pages -> flash-high x4 (m1 index.html, m2 about.html, m3 pricing.html, m4 faq.html; exact spec)`.

## Task plan and waves
**Before ANY work starts, print the task plan, every time** (no approval needed), after the quota check. No builder is launched and no file touched until it is printed, even for a one-task job. Every task gets a route in the `model (reason)` column, `opus-sensitive (reason)` ones included.

| id | model (reason) | owns | after |
|---|---|---|---|
| w0-shell | claude-sonnet-builder (design shell) | `site/styles.css`, `site/nav.html`, `.m6/contract.md` | - |
| w1-home | argon-medium (cannot spec exactly) | `site/index.html` | w0-shell |
| w1-pages | flash-high x4 (exact spec) | m1 `site/about.html`, m2 `site/pricing.html`, m3 `site/faq.html`, m4 `site/contact.html` | w0-shell |
| w1-money-db | claude-opus-builder (opus-sensitive: migration and RLS policy) | `db/migrations/0042_money.sql` | - |

- `id`: unique lowercase-kebab slug (becomes `task:`, `.m6/briefs/<task>.md`, the worktree/branch name). `owns`: exact paths (dirs, globs allowed) or `none` for read-only scouting; a Flash task lists each mini-task's files. `after`: ids needed finished first.
- **Wave 0 = foundations everything else depends on** (design shell, shared styles, schema, types, scaffolding, `contract.md`); runs alone; skip if none. **Wave N (N >= 1) = every remaining task whose `after` tasks are in earlier waves**, launched together. Review a wave completely (diffs, fix steps, accepted) before the next.
- The Flash test result is printed in the plan for every non-design build task. Parallelize only when 2 or more tasks have disjoint file sets; even a one-task wave goes to a builder. Review may reveal new tasks: add them to the next wave and note it in `.m6/last-run.md`.
- State each choice in one line before launching: `w1-home -> argon-medium (cannot spec exactly)`.

## Concurrency caps (defaults, edit this table; all guesses, agy's concurrent-session limit is unverified)

| Limit | Max running at once |
|---|---|
| Total tasks | 4 |
| argon | 2 |
| flash | 3 |
| sonnet (agy) | 1 |
| opus (agy) | 1 |

- A task counts against its agy model family (any effort suffix; Flash scouts and Flash builds both count against flash) from launch until its report returns, i.e. while its `agy-run.sh` Bash call is running. Fix steps and scouting count too. Claude subagents count toward the total cap only.
- Prefer spreading a wave across different models. Over the caps: launch what fits, hold the rest, launch each as a slot frees; alternate models.
- A fallback keeps its task's slot: it may exceed its new model's cap, never the total cap.
- Exit 4 (suspected concurrency limit): lower the total cap by 1 (min 1) for the rest of the session, relaunch the affected tasks, and note it in `.m6/last-run.md`. At 1 the plan is effectively sequential.

## File ownership
- Within a wave, every file belongs to exactly one task (for a Flash-built task, one mini-task). No overlaps, including generated files and test files. Two tasks needing the same file go in different waves (or merge into one task).
- Shared files (nav and layout includes, package.json, lockfiles, route index, global config, barrel/index files) belong to exactly one task, or to an **integration task** in the next wave. Builders report what they need there as `needs:` lines; the integration task applies them.
- Dependency installs and formatters are tasks too: own them, own wave, run alone. Put the owned list in every brief; read access is unrestricted. Sets cannot be disjoint: read `.claude/m6/worktree.md`.

## Delegation brief and launching
Self-contained (goal, exact file list, acceptance criteria, constraints): the run starts cold and sees only the brief plus AGENTS.md.
- **agy tasks:** a body-only file `.m6/briefs/<task>.md`; the script adds `task:`, `owns:`, "Read AGENTS.md first and follow it." and the read-only line. An Argon fix of Flash-built work: all the task's files in `owns:`, `--no-fallback`, a body with the whole task diff and the defect list.
- **Claude sub-agents (builders, fixer, reviewers, scout):** header, blank line, body:
```
task: <slug>
owns: <comma-separated files, or none>
worktree: <path>        (optional)
design                  (optional, bare line, Claude design builders only)
```
- All tasks of a wave go out in ONE message with `run_in_background: true`: one Agent call per Claude sub-agent (`subagent_type` = agent name), one Bash call per agy task:
```
scripts/agy-run.sh --model <alias[-low|-medium|-high]> --task <slug> --owns "<comma list|none>" --brief .m6/briefs/<slug>.md [--no-fallback] [--worktree <path>]
```
  Aliases: `flash-high` (builds), `flash` / `flash-low` (read-only scouting), `argon` / `argon-high` / `argon-low`, `sonnet`, `opus`. Not executable: `bash scripts/agy-run.sh ...`. Never add `--dangerously-skip-permissions` (auto mode blocks it). Wait for completion notifications, never poll; never start the next wave early.
- A fix task keeps the original `owns:` and is named `<id>-r1` / `-r2` / `-r3` (`fix-ladders.md`).

| Exit | `agy-run.sh` | Main session does |
|---|---|---|
| 0 | success, report printed | review |
| 1 | other error (login, crash, timeout, unknown flag); no fallback, no retry loop | login failure or permission block: hard blocker, stop and ask. Otherwise decide from the quoted error |
| 2 | `agy` missing, bad arguments, refused, or model id not in `agy models` | refused or bad call: a routing mistake, fix the call. `agy` missing: hard blocker, tell the user |
| 3 | first line `drained: <model-id>, no fallback`, or `drained: all models drained or unavailable (tried: ...)`; owned files may be partly edited | no-fallback: Flash build -> the Flash-drained question; any fix -> next Claude step. Chain exhausted -> counts toward the drained pools. Read `drained-pools.md` |
| 4 | `concurrency: <text>`, no marker | lower the total cap by 1, relaunch, note it |

The report lists `fallbacks:` (each one and why, quoted error), `changed lines (owned)`, the diff stat and outside-owned changes.

## Review
Reviewer by changed lines. Changed lines = added + removed from `git diff --numstat -- <owned files>` plus the line count of new untracked owned files (`agy-run.sh` reports the sum as `changed lines (owned)`; otherwise compute read-only). A task split into mini-tasks uses the combined diff, reviewed once after all mini-tasks finish.

| Changed lines (whole task, owned files) | Reviewer |
|---|---|
| 400 or fewer | `sonnet-reviewer` (Claude Sonnet, Claude plan) |
| more than 400 | `opus-reviewer` (Claude Opus medium, Claude plan, a sub-agent) |

- Applies to every build, whoever built it. No agy model reviews, ever. The main session never reads a full diff, not even above 400 lines: only `--stat` / `--numstat` and the verdict.
- After a fix step, review again on the whole diff (over 400 moves up to `opus-reviewer`); tell the reviewer the previous defects.
- The first review of each Flash-built task feeds the safety-switch tally. Give the reviewer the header and the acceptance criteria. It returns PASS or FAIL with a numbered defect list; non-blocking notes are not sent back unless they break a criterion.
- Check each report's "possibly from other parallel tasks" list: every path must be owned by another task in the wave. A stray edit to a file nobody owns is a defect: after the wave (nothing running), list it in `.m6/last-run.md` or send it to a builder to revert (the task's builder or `claude-haiku-builder`, file in `owns:`). The main session never reverts a file.
- Never accept "done" on a report alone. Flash reports are leads, not facts: verify anything you act on.

## Final summary (always required)
**To the user, at most 8 short plain lines, no table:** what was built and how to open or run it; what is still wrong or not done (or "nothing open"); who did the work, one line (e.g. "Flash built 4 pieces, Argon 1, Claude designed the styles and did 3 reviews and 1 fix"); anything the user must do or decide (a pending drained-pool question goes here); "Details: .m6/last-run.md". Also print any line the user's prompt explicitly asks for (for example an "Elapsed" line or a files list).

**Detailed record -> `.m6/last-run.md`, overwritten each run:** the table below; `opus-sensitive` tasks with reasons; fixes by step, every Claude-plan fix called out; which tasks were built on Flash high (with mini-tasks), which on Argon or others, and why; the safety-switch tally (Flash-built tasks reviewed, first-review failures), whether it tripped, tasks re-routed to Argon; any drained-pool question and answer, tasks run in Module 3 mode; cap changes, worktree use, open items, minor choices.

| wave | task | route (Flash / Argon or other agy / Module 3) | model requested | model that ran | fallbacks | reviewer (changed lines) | fix steps | result after review |
|---|---|---|---|---|---|---|---|---|

## If everything fails
Only when `agy` itself is broken, the Claude plan is out of quota, or Flash or the agy pools are drained and the user has not answered: stop and tell the user. Do none of the work yourself, not even a small part: the main session never implements.
