@AGENTS.md

# Orchestration (Module 6 Flash builder: Claude plans in waves, Flash high builds small exact pieces, Argon builds the rest and fixes Flash's work, the Claude plan designs, reviews and fixes)

Claude (Opus, this session) plans, routes, and reads the big diffs. It does not implement bulk work. Who does what:
- **Flash high is the first-choice builder.** Every non-design build task that Opus can split into small, exactly specced mini-tasks goes to Flash (`gemini-3.8-flash-high`) through `agy-delegate`. No question to the user: this is the normal route (see Flash builds). It saves the small Argon pool.
- **Argon builds what Opus cannot spec exactly**, through `agy-delegate`: `gemini-4-argon-medium` by default, `-high` for hard tasks. agy Sonnet or agy Opus take the tasks named in Routing. Never design.
- **Design builds** (shells, first design drafts) go to Claude subagents on the Claude plan: `claude-sonnet-builder` or `claude-opus-builder`. Never to agy, so never to Flash or Argon.
- **Scouting** (read-only) goes to Flash.
- **Reviews** run on the Claude plan, ONCE per task (after all its mini-tasks), picked by changed lines: `sonnet-reviewer` for 400 or fewer, Opus (this session) above 400. No agy model ever reviews.
- **Fixes** follow the Fix ladders. Flash never fixes and never reviews. Flash-built work is fixed by Argon medium first, then Claude Sonnet medium, then Claude Opus medium.
- **Safety switch:** if too many Flash-built tasks fail their first review, Opus stops sending new tasks to Flash for the rest of the run (see Flash safety switch).
- **Pools drained?** Opus asks the user one question, only when it truly needs one (see When the agy pools are drained). It never switches to Module 3 on its own.

Independent tasks run in parallel, in waves, on disjoint files.

## Autonomy (no decision boxes)
Run end to end without asking the user. Never use AskUserQuestion or offer choice boxes like "Send this to Gemini?". The task plan is announced, not submitted for approval. Choosing Flash for a task that splits is part of the plan, not a question.
- Found a defect in a diff or test? Send it back in the same turn, as a new delegation listing each defect, following the Fix ladders. Do not ask first.
- Fix loop: up to 3 steps per task, following the ladder for whoever built it. If the last step still fails review, report the remaining defect in the final summary and continue. Fix steps of different tasks are independent: launch them together (see Launching).
- Unclear spec or minor choice: pick the most reasonable option, note it in the final summary, and keep going. Cosmetic or out-of-spec gaps (e.g. a missing extra the spec never asked for) are listed in the summary, not sent back, unless they break an acceptance criterion.
- Stop and ask only for hard blockers: login failure, `agy` missing, a permission block, a Claude plan limit hit, or an action that deletes data or touches secrets. A suspected concurrency error is not a hard blocker (see Concurrency caps).
- Two exceptions to "no questions", both about drained pools: the question in When the agy pools are drained ("wait for the reset, or switch to Module 3?") and the Flash-drained question ("Flash is drained. Wait for the reset, or switch to Module 3?"). Nothing else is asked, and no route changes without the user's answer.
- Finish with one summary (format under Final summary).

## Model pool (edit this table to change behavior)
Model IDs confirmed from `agy models` on 2026-10-25. Each ID embeds effort (low/medium/high).

Antigravity models (run through `agy-delegate`, on the Google AI Pro plan):

| Alias | agy model ID | Use for | Quota notes |
|---|---|---|---|
| flash (build) | `gemini-3.8-flash-high` | **First-choice builder** for any non-design task Opus can split into small, exactly specced mini-tasks. Always with a real `owns:` list. Never fixes, never reviews | Nearly unlimited |
| flash (scout) | `gemini-3.8-flash-medium` (`-low` for pure lookups) | Scouting: file lookup, grep-style questions, summaries, extraction, formatting. Read-only | Nearly unlimited |
| argon | `gemini-4-argon-medium` (`-high` for hard tasks, `-low` for trivial) | Builds what Opus cannot spec exactly: bulk code, tests, refactors, large-context work. **Fix step 1 for Flash-built work** (medium) | Small pool; weekly |
| sonnet | `claude-sonnet-5-5-medium` (`-low` for trivial) | Non-design tasks that need Claude-style judgment: nuanced edits, careful refactors, writing/docs | Small pool |
| opus | `claude-opus-5-5-medium` (`-high`, `-low` also exist) | Hard multi-file or architecture-heavy implementation only | Smallest pool; spend rarely |

Claude-plan agents (in `.claude/agents/`, on the Claude Pro plan, never relays):

| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first design drafts. Fix step 2 for agy-built work (Argon, agy Sonnet, agy Opus). Module 3 mode: design, docs, and everything not easy or Opus-trigger |
| `claude-opus-builder` | opus, effort medium | The most important or complex designs. Fix step 3 for agy-built and Flash-built work, step 2 for Claude-built design work. Module 3 mode: Opus-trigger tasks and last-step fixes |
| `claude-sonnet-fixer` | sonnet, effort medium | Fix step 2 for Flash-built work (step 1 when Argon is drained). Fixes only |
| `claude-haiku-builder` | haiku | Module 3 mode only: easy, tool-verifiable build tasks |
| `scout` | haiku | Module 3 mode only: all read-only work, with file:line or URL evidence. Never edits |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff of 400 changed lines or fewer, read-only. Returns PASS or FAIL |

## Routing (decide per task, in this order)
0. **Design shell or first design draft (layout, styles, visual direction, initial design file) -> `claude-sonnet-builder` (Sonnet high) or `claude-opus-builder` (Opus medium). NEVER agy: not Flash, not Argon, not agy Sonnet, not agy Opus.** Default Sonnet; Opus for the most important or complex designs. These run on the Claude plan, so a drained agy pool does not touch them. Later mechanical edits to an approved design (copy changes, adding pages that follow it) are ordinary builds and go through the Flash test below.
1. Scout / lookup / summarize / extract / format, no file edits -> **flash** (medium).
2. Security-sensitive code, auth/secrets, ambiguous specs, architecture decisions -> do not delegate; handle directly.
3. Tasks under ~5 minutes -> do directly.
4. **Flash test, for every remaining build task, while planning each wave or phase.** Can Opus split the task into small, specific mini-tasks, and write an exact spec for each one? An exact spec has: the files the mini-task owns, names and signatures, the markup or data to produce, and a check a tool can run. It also needs no design taste and no cross-piece decision (Opus settles those in the briefs). If yes for every piece -> **Flash high** mini-tasks (see Flash builds). This is the default route and needs no question to the user.
5. Opus cannot write exact specs (open-ended, needs judgment on the fly, tangled logic) but the work is bulk, well-bounded and low-risk -> **argon** (medium).
6. Same, but hard (multi-file, tricky logic) -> **argon high**. If it fails review, follow the Fix ladders.
7. Judgment-heavy edit that is not design (careful refactor, docs, writing) -> **agy sonnet**. (A failed review does not re-route a task by itself; see Fix ladders.)
8. Hard multi-file or architecture-heavy implementation that Argon high should not carry -> **agy opus**, rarely.
- A tripped Flash safety switch removes step 4 for the rest of the run: those tasks go to step 5 or 6 instead.
- Never move a task that fails the Flash test onto Flash "because it is nearly unlimited".

## Fallback chains (quota drained)
Fallback stays within the agy builders. Never silently downgrade a hard task to Flash.

| First choice | Then | Then |
|---|---|---|
| argon | sonnet | opus |
| sonnet | argon | opus |
| opus | sonnet | argon (high) |
| flash (read-only scout) | argon (low) | stop and tell the user |
| flash (build) | no chain: stop and ask | - |

`agy-delegate` walks the chain itself (max 2 fallbacks), only when an error looks like quota exhaustion, and reports which model actually ran. When a builder chain is exhausted it reports "all models drained or unavailable": that counts toward the drained pools (see Quota state). No-fallback mode (a brief with `fallback: none`, used for same-model fix rounds and for Argon fixing Flash work, and always for Flash builds) never walks the chain: a drained model returns "drained: <model-id>, no fallback". A design brief is refused by the delegate. Other errors (login, unknown flag, timeout, suspected concurrency limit) stop the run with no fallback.

## Quota state (one marker file per drained model)
- `agy-delegate` writes `.claude/agy-quota/<model-id>` when a model looks drained. Content: UTC ISO time. Written atomically (temp file in the same dir, then `mv`), so parallel tasks never corrupt each other's state.
- Before planning, list fresh markers: `find .claude/agy-quota -type f ! -name '.tmp.*' -mmin -360`. Skip models with a marker under 6 hours old **(guess; reset times are unpublished)**. Route to the chain's next model instead and say so in the plan.
- To clear a model, delete its marker. If every model looks drained, ask the user to run `/usage` inside `agy`.
- Module 5's single quota-state file in `.claude/` is ignored if still present; delete it.
- The **agy pools** (Argon, agy Sonnet, agy Opus) are **drained** when every builder chain is exhausted: a build comes back "all models drained or unavailable", or the fresh markers cover argon, sonnet and opus. Flash has its own markers (`gemini-3.8-flash-high` for builds, `gemini-3.8-flash-medium` for scouting); a drained Flash does not mean the agy pools are drained, and the other way round.
- **Argon drained** (for fix routing) means a fresh marker on `gemini-4-argon-medium`, or the delegate returned "drained: gemini-4-argon-medium, no fallback".

## Flash builds (the default route for every task that splits)
Flash high is small and fast but nearly unlimited, so it only gets small pieces that Opus can spec exactly.
- **Split** each task that passes the Flash test into mini-tasks: 4 by default, more if needed. Ids are `<task-id>-m1`, `-m2`, and so on. Each mini-task owns a disjoint subset of its task's files. Mini-tasks that must touch the same file run one after another (`after`), never in parallel.
- **Shared contract:** Opus writes the shared contract (file layout, names, signatures, ids and classes, data shapes) into every mini-task brief so the pieces fit. Each brief also says which task it belongs to.
- **Brief header:** `model: flash-high`, `task: <task-id>-mN`, a real `owns:` list (never `none`), no `fallback:` line needed (Flash builds never fall back). Flash builds always run at high effort.
- **Review ONCE per task, after ALL its mini-tasks finish. Never per mini-task.** Review the combined diff of the whole task: `owns:` is every file of all its mini-tasks. The 400-line rule applies to the combined changed lines (see Review).
- **Fixes follow the Flash-built row of the Fix ladders:** Argon medium, then Sonnet medium, then Opus medium. A fix is one task for the whole task (not per mini-task), owning all the task's files. Flash never fixes or reviews.
- **Flash drained on a build** (fresh `gemini-3.8-flash-high` marker, or the delegate returns "drained"): stop and ask the user "Flash is drained. Wait for the reset, or switch to Module 3?" Do not move the pieces to Argon on your own.
- Plan lines for Flash tasks list the mini-tasks: `w1-pages -> flash-high x4 (m1 index.html, m2 about.html, m3 pricing.html, m4 faq.html; exact spec)`.

## Flash safety switch (per run)
Opus keeps a tally of Flash-built tasks and whether each passed or failed its FIRST review (re-reviews after a fix do not change the tally).
- From the 3rd reviewed Flash-built task on, after each first review: if MORE than 1 in 3 of the Flash-built tasks reviewed so far failed their first review (failed x 3 > reviewed), the switch trips. Count only tasks reviewed so far, not tasks still running or planned.
- Once tripped, Opus stops routing NEW tasks to Flash for the rest of the run. Tasks already building on Flash finish and are reviewed as usual. New tasks that passed the Flash test now go to Argon (Routing steps 5 and 6).
- Opus says so in a plan line ("Flash safety switch tripped: <failed> of <reviewed> Flash-built tasks failed their first review; new tasks go to Argon") and in the final summary, with the tally.
- Flash scouting is not affected. If Argon is drained when the switch has tripped, treat tasks that cannot go to Argon as in When the agy pools are drained, with the question ("wait for the reset, or switch to Module 3?").
- The tally and the switch reset on the next run.

## When the agy pools are drained
Applies when Argon, agy Sonnet and agy Opus are all drained (see Quota state). Flash does not stop: it is the normal builder.
1. Stop launching agy builds on Argon, agy Sonnet and agy Opus. Let running tasks finish and review them. Design tasks, Flash builds and Claude-plan fix steps do not need those pools, so they keep running as planned.
2. **Flash keeps building what can be split.** Tasks that pass the Flash test continue on Flash high as usual (unless the safety switch tripped or Flash itself is drained, see below).
3. **Tasks that cannot be split** (they fail the Flash test, so they would have gone to Argon, agy Sonnet or agy Opus) are held. Do not start a wave that depends on them. When everything that can run has run and been reviewed, stop and ask the user ONE question, in words (no decision box), then wait:
   "Antigravity is drained for Argon, Sonnet and Opus (marker times: <times>). Some remaining tasks cannot be split into exact Flash mini-tasks. Wait for the reset, or switch to Module 3?"
4. Do nothing on those held tasks (no Claude builds either) until the user answers. Reset times are unpublished: a marker older than 6 hours counts as cleared **(guess)**.
   - Wait -> stop. On the next run, re-check the markers; if the pools are still drained, ask again.
   - Module 3 -> Module 3 mode for the held tasks (see below).
   - An answer given in the original prompt ("wait", "use Module 3") counts as the user's answer.
5. **Flash drained while building:** stop and ask "Flash is drained. Wait for the reset, or switch to Module 3?" (same answers as above).
6. If the safety switch tripped AND the agy pools are drained, all remaining non-design builds are held: ask the question in step 3.

## Module 3 mode (only after the user answered "switch to Module 3")
Claude-only building with Claude builder subagents. No agy at all for the remaining tasks, including Flash. Tasks already built and accepted on Flash or Argon stay as they are. Score every remaining build task 0 / 1 / 2 on each dimension (takes 10 seconds):

| | 0 | 1 | 2 |
|---|---|---|---|
| **A** Ambiguity | exact spec, diff describable in one sentence | clear goal, small local choices | open-ended, approach undecided |
| **N** Novelty | copies an existing pattern | adapts a pattern | no precedent; new abstraction |
| **C** Coupling | 1–2 files, no shared types | 3+ files or shared type/interface | cross-cutting, public API |
| **R** Reversibility | `git revert` undoes it | user-visible behavior or config | prod data, releases, money, external side effects |
| **S** Sensitivity | none | near auth/PII | auth, crypto, secrets, payments, PHI, tenancy |
| **V** Verifiability | a test/type/lint/build check fully covers it | partly covered | races, performance, security, UX judgment |
| **D** Diagnosis | cause known / none needed | reproducible, cause unknown | intermittent, prod-only, no repro |

Route each remaining task. First match wins:
- Read-only (find, explain, research, summarize) -> `scout`. No review.
- Opus trigger (ANY of: D = 2 · two or more dimensions = 2 · S = 2 and N >= 1 · A = 2 and C = 2) -> `claude-opus-builder`.
- Easy (A, R, S, V, D all 0, total <= 2, complete spec, a tool can verify it) -> `claude-haiku-builder`.
- Everything else (design, S = 2, docs, logic) -> `claude-sonnet-builder`.
- Tie-breakers: unsure haiku vs sonnet -> sonnet. Unsure sonnet vs opus -> sonnet, unless D = 2 or S = 2 -> opus.

Rules:
- Tasks already accepted from agy stay as they are. A task cut off by a drain may be partly edited: add to its brief "An agy run may have partly edited the owned files before it stopped. Inspect them first, then finish the task."
- Reviews: the usual 400-line rule (`sonnet-reviewer` up to 400 changed lines, Opus above).
- Fix ladder: round 1 the same agent, round 2 the next tier up (haiku -> `claude-sonnet-builder` -> `claude-opus-builder`), round 3 `claude-opus-builder`, then record and continue. An opus-builder task stays on opus-builder.
- Concurrency: total 4, no per-model caps. Plan lines end with `(Module 3 mode)`. The final summary lists which tasks ran in Module 3 mode.
- Stay in Module 3 mode for the rest of the session unless the user says to retry agy.

## Task plan and waves
Before the first delegation, print the task plan (no approval needed):

| id | model (reason) | owns | after |
|---|---|---|---|
| w0-shell | claude-sonnet-builder (design shell) | `site/styles.css`, `site/nav.html` | - |
| w1-home | argon-medium (cannot spec exactly) | `site/index.html` | w0-shell |
| w1-pages | flash-high x4 (exact spec) | m1 `site/about.html`, m2 `site/pricing.html`, m3 `site/faq.html`, m4 `site/contact.html` | w0-shell |

- `id`: unique lowercase-kebab slug. It becomes `task:` in the brief, the /tmp file names, and the worktree/branch name.
- `owns`: exact paths (dirs and globs allowed), or `none` for read-only scouting. For a Flash task, list the mini-tasks with the files each one owns.
- `after`: ids this task needs finished first (it reads or builds on their output).

Waves:
1. **Wave 0 = foundations everything else depends on**: design shell, shared styles, schema, types, scaffolding. It runs alone. Skip it if there are none.
2. **Wave N (N >= 1) = every remaining task whose `after` tasks are all in earlier waves.** Launch the whole wave together.
3. **Review a wave completely (diffs, fix steps, accepted) before starting the next.**
4. A wave with one task is a normal single delegation. The Flash test (Routing step 4) is applied to every non-design build task while planning each wave or phase, and the result is printed in the plan. Parallelize only when 2 or more tasks have disjoint file sets. Tasks under ~5 minutes still go direct (Routing 7).
5. Review may reveal new tasks: add them to the next wave and note it in the summary.

## Concurrency caps (defaults, edit this table; all numbers are guesses, agy's own concurrent-session limit is unverified)

| Limit | Max running at once |
|---|---|
| Total tasks | 4 |
| argon | 2 |
| flash | 3 |
| sonnet (agy) | 1 |
| opus (agy) | 1 |

- A task counts against its agy model family (any effort suffix; Flash scouts and Flash builds both count against flash) from launch until its report returns. Fix steps and scouting count too. Runs of Claude subagents (builders, fixer, reviewer, scout) count toward the total cap only, never toward an agy model cap.
- Prefer spreading a wave across different models: it spreads quota and fits the per-model caps. Never move a task that fails the Flash test onto Flash just to spread.
- Wave larger than the caps: launch what fits, hold the rest, launch each held task as a slot frees. Order the queue so models alternate.
- A fallback replaces the task's own run, so it keeps its slot: it may exceed its new model's cap, never the total cap.
- If a delegate reports a suspected concurrency error (agy refusing or locking concurrent sessions), lower the total cap by 1 (min 1) for the rest of the session, relaunch the affected tasks, and note it in the summary. If it persists at 1, the plan is effectively sequential.

## File ownership
- Within a wave, every file belongs to exactly one task (for a Flash-built task, one mini-task). No overlaps, including generated files and test files.
- Shared files (nav and layout includes, package.json, lockfiles, route index, global config, barrel/index files) are owned by exactly one task, or left to an **integration task** in the next wave. Agents report what they need there as `needs:` lines; the integration task applies them.
- Two tasks that need the same file go in different waves (or merge into one task).
- Dependency installs and formatters are tasks too: give them an owner, in their own wave, run alone.
- Include the owned list in every brief. Read access is unrestricted.

## Worktree mode (optional, default off)
Use only when file sets cannot be disjoint. Requires a git repo with at least one commit; commit the files the builders need first (including AGENTS.md), since a worktree has only committed files (untracked files such as `node_modules` and `.env` are absent).
Per task, Opus:
1. `git worktree add ../wt-<task> -b agy/<task>`
2. Brief gets `worktree: ../wt-<task>`; `agy-delegate` runs `agy` with that directory as working directory, and Claude builders work only inside it.
3. After the wave, review `git -C ../wt-<task> diff`. Commit approved work on the throwaway branch only (`git -C ../wt-<task> add -A && git -C ../wt-<task> commit -m "agy/<task>"`), then bring it into the main tree without committing there: `git merge --squash agy/<task>`. Conflicts: resolve directly or send back.
4. `git worktree remove ../wt-<task>` and `git branch -D agy/<task>`.
Never commit on the user's branch, never push. The `owns:` list still applies inside a worktree (keeps merges clean).

## Delegation brief (every task)
Self-contained: goal, exact file list, acceptance criteria, constraints. The run starts cold and sees only the brief plus AGENTS.md. First lines are a header:

```
model: <alias or ID>    (agy-delegate only)
task: <slug>
owns: <comma-separated file list, or none>
worktree: <path>        (optional)
design                  (optional, bare line, Claude builders only; agy-delegate refuses it)
fallback: none          (optional, agy-delegate only: same-model fix rounds)
```
Then a blank line, then the body. Claude subagents get the same header without `model:` and `fallback:`. A Flash mini-task brief also says which task it belongs to, and carries the shared contract. An Argon fix of Flash-built work gets `model: argon`, `fallback: none`, all the task's files in `owns:`, and a body with the whole task diff and the defect list.

## Launching
- All `agy-delegate` and Claude-subagent calls of a wave go in ONE message: one Agent tool call per task, each with `run_in_background: true`. Then wait for all to finish. Do not poll, and do not start the next wave early.
- `agy` itself runs with `run_in_background` inside the subagent (Claude Code foreground calls die after 10 minutes), `--mode accept-edits`, `--print-timeout 0`. Never `--dangerously-skip-permissions` (auto mode blocks it).
- Claude subagents: Agent tool with `subagent_type: claude-sonnet-builder`, `claude-opus-builder`, `claude-sonnet-fixer`, `claude-haiku-builder`, `scout` or `sonnet-reviewer`.
- State the choice in the plan, one line per task, before launching: `w1-home -> argon-medium (cannot spec exactly)`.
- Fix steps: after reviewing a wave, send all defect fixes together in one message, same caps. A fix task keeps the original `owns:` (for a task split into mini-tasks, every file of the task) and gets `task: <id>-r1`, `<id>-r2` or `<id>-r3`, matching its step in the ladder (a skipped step leaves its number unused: with Argon drained, a Flash-built fix starts at `-r2`). The brief body is the defect list; add a note if an earlier run stopped partway on a quota error. Any Claude-plan fix is printed in the plan line (e.g. `w1-home-r2 -> claude-sonnet-builder (Claude plan, Sonnet high; Argon drained)` or `w1-pages-r2 -> claude-sonnet-fixer (Claude plan, Sonnet medium; Argon drained)`) and in the final summary.

## Review
Reviewer by changed lines. Changed lines = added + removed from `git diff --numstat -- <owned files>` plus the line count of new untracked owned files (`agy-delegate` reports the sum; otherwise compute it yourself). For a task split into mini-tasks, use the combined diff of the whole task. Review once per task, after all its mini-tasks have finished, never per mini-task.

| Changed lines (whole task, owned files) | Reviewer |
|---|---|
| 400 or fewer | `sonnet-reviewer` (Claude Sonnet, Claude plan) |
| more than 400 | Opus reads the diff itself, in this session |

- The rule applies to every build: Flash, Argon, agy Sonnet, agy Opus, and Claude builders alike. No agy model reviews, ever. Never spawn a separate Opus reviewer: Opus reads big diffs itself.
- After a fix step, review again with the same rule on the task's whole diff. If fixes push a task over 400 lines, its review moves up to Opus.
- The first review of each Flash-built task feeds the Flash safety switch tally. Give `sonnet-reviewer` the header (`task:`, `owns:`, optional `worktree:`) and the acceptance criteria. It returns PASS or FAIL with a numbered defect list. Non-blocking notes are listed apart; do not send them back unless they break a criterion. On a re-review, tell it the previous defects.
- Check each report's "possibly from other parallel tasks" list: every path must be owned by another task in the wave. A stray edit to a file nobody owns is a defect: after the wave (nothing running), revert it directly only if you are sure it came from a task, otherwise leave it and list it in the summary.
- Never accept "done" on the report alone. Flash reports are leads, not facts: verify anything you act on.

## Fix ladders (max 3 steps per task)
When a task fails review, send the defect list to the next step of the ladder for whoever built it. If the first step's agy model is drained (fresh marker, or the delegate returns "drained"), skip straight to the next, Claude, step. A drained model is never replaced by another agy model in a fix.

| Built by | r1 | r2 | r3 |
|---|---|---|---|
| Argon, agy Sonnet or agy Opus | the same agy model (`agy-delegate`, `fallback: none`) | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| Flash (default route) | **Argon medium** (`gemini-4-argon-medium` through `agy-delegate`, `fallback: none`; gets the whole task diff and the defect list, owns all the task's files) | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium), then record and continue |
| `claude-sonnet-builder` (design) | the same agent | `claude-opus-builder` | record and continue |
| `claude-opus-builder` (design) | the same agent | record and continue | - |

- Flash never fixes and never reviews. Its work goes straight to the Flash row.
- Flash-built ladder, exactly: Argon medium, then Sonnet medium, then Opus medium. Argon drained (fresh `gemini-4-argon-medium` marker, or "drained" returned)? Skip r1 and start at Sonnet medium. Never use Argon high or another agy model for these fixes.
- A fix of Flash-built work is one task for the whole task, not per mini-task.
- If the ladder is used up and the task still fails review: record the defect in the final summary and continue.
- Module 3 mode uses its own ladder (see Module 3 mode).

## Final summary
One summary: what was built; a per-wave table; fixes sent and their outcome by step, with every Claude-plan fix called out; which tasks were built on Flash high (with their mini-tasks) and which on Argon or others, and why; the Flash safety switch tally (Flash-built tasks reviewed, first-review failures) and whether it tripped, and which tasks were re-routed to Argon because of it; any drained-pool question and the user's answer (wait or Module 3 mode), and which tasks ran on that route; cap changes, worktree use, open items, minor choices made.

| wave | task | route (Flash / Argon or other agy / Module 3) | model requested | model that ran | fallbacks | reviewer (changed lines) | fix steps | result after review |
|---|---|---|---|---|---|---|---|---|

## If everything fails
Only when `agy` itself is broken, or the Claude plan is out of quota, or Flash or the agy pools are drained and the user has not answered: stop and tell the user. Do not do the bulk work yourself.
