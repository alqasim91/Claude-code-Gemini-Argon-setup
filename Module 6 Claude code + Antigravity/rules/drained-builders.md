Read this as soon as the agy builders are drained (a build exits 3 "all models drained or unavailable", or active markers cover argon, sonnet and opus), a Flash build is drained, or the user mentions Flash route or Module 3. Self-contained. Cross-rules: no route change, Flash route or Module 3 without the user's answer to the question below; Flash never fixes or reviews; no agy model reviews; the main session never implements.

# When agy builders are drained
Applies when Argon, agy Sonnet and agy Opus are all drained. Opus stops here and asks. It never switches to Flash or to Module 3 on its own.
1. Stop launching agy builds. Let running tasks finish and review them. Design tasks and Claude-plan fix steps do not need agy, so they keep running as planned. Do not start the next wave.
2. Analyze the remaining non-design build tasks. For each, ask: can it be split into small mini-tasks (4 by default, more if needed) that Flash can build reliably? A mini-task is reliable for Flash when it is one file or one clear piece, has an exact spec (names, signatures, markup or data to produce), has a check a tool can run, and needs no design taste or cross-piece decision (Opus makes those in the briefs). If even one remaining task fails this test, the answer is no for the whole set.
3. Stop and ask the user ONE question, in words (no decision box), then wait:
   - Everything splits: "Antigravity is drained for Argon, Sonnet and Opus (marker times: <times>). The remaining tasks can be split into small mini-tasks that Flash can build. a) switch to Flash, or b) switch to Module 3?"
   - Something does not split: "Antigravity is drained for Argon, Sonnet and Opus (marker times: <times>). Some remaining tasks are too big or too risky for Flash mini-tasks. Wait for the reset, or switch to Module 3?"
4. Do nothing on Flash builds or Claude builds for the remaining tasks until the user answers. Reset times are unpublished: a marker past its `until` time counts as cleared (a legacy one-line marker counts as active for 6 hours **(guess)**).
   - a) -> Flash route. b) -> Module 3 mode. Wait -> stop. On the next run, re-check `scripts/agy-run.sh --status`; if the builders are still drained, ask again.
   - An answer given in the original prompt ("use Flash", "use Module 3") counts as the user's answer.

# Flash route (only after the user answered a)
Flash is nearly unlimited, but small and fast, so it only gets small pieces.
- **Split every remaining task** into mini-tasks (4 by default, more if needed). Ids are `<task-id>-m1`, `-m2`... Each owns a disjoint subset of its task's files. Mini-tasks that must touch the same file run one after another (`after`), never in parallel.
- **Contract:** Opus writes the shared contract (file layout, names, signatures, ids, classes) to `.m6/contract.md`, once, before launching the mini-tasks (the wave-0 task gets it in `owns:` and writes it; with no wave-0 task the main session writes it from the plan). Every mini-task brief says: "Read `.m6/contract.md` first. Use only the names defined there. Do not invent a class, id or function that is not in it." Never copy the list into briefs. In worktree mode the brief gives the absolute path of the contract file. A brief also says which task the mini-task belongs to.
- Flash builds all mini-tasks: `agy-run.sh --model flash` with a real `--owns` list. It is always no-fallback. Flash drained on a build (exit 3): stop and ask "Flash is drained. Wait for the reset, or switch to Module 3?"
- **Review ONCE per task, after ALL its mini-tasks finish. Never per mini-task.** Review the combined diff of the whole task: `owns:` is every file of all its mini-tasks. The 400-line rule applies to the combined changed lines.
- **Fixes follow the Flash row** (`.claude/m6/fix-ladders.md`): Flash never fixes or reviews. A fix is one task for the whole task, owning all the task's files.
- Design still goes to the Claude builders. Flash scouting continues. Work already accepted from agy stays as it is.
- Plan lines end with `(Flash route)`. Stay on the Flash route for the rest of the session unless the user says to retry agy builders.

# Module 3 mode (only after the user answered b)
Claude-only building with Claude builder sub-agents. No agy at all for the remaining tasks, including Flash. Score every remaining build task 0 / 1 / 2 on each dimension (takes 10 seconds):

| | 0 | 1 | 2 |
|---|---|---|---|
| **A** Ambiguity | exact spec, diff describable in one sentence | clear goal, small local choices | open-ended, approach undecided |
| **N** Novelty | copies an existing pattern | adapts a pattern | no precedent; new abstraction |
| **C** Coupling | 1-2 files, no shared types | 3+ files or shared type/interface | cross-cutting, public API |
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
- Reviews: the usual 400-line rule (`sonnet-reviewer` up to 400 changed lines, `opus-reviewer` above).
- Fix ladder: round 1 the same agent, round 2 the next tier up (haiku -> `claude-sonnet-builder` -> `claude-opus-builder`), round 3 `claude-opus-builder`, then record and continue. An opus-builder task stays on opus-builder.
- Concurrency: total 4, no per-model caps. Plan lines end with `(Module 3 mode)`. The final record lists which tasks ran in Module 3 mode.
- Stay in Module 3 mode for the rest of the session unless the user says to retry agy.
