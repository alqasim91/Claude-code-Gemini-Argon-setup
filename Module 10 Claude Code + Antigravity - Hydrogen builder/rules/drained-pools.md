Read this as soon as any task is held, Hydrogen, Argon, Flash or agy Sonnet is drained (marker or `agy-run.sh` exit 3), or the user mentions Module 3. Self-contained. Cross-rules: Module 3 never without the user's answer; the main session never implements.

# When a build's whole chain is drained
Applies when every model in a task's chain is drained (fresh markers, or the matching exit 3 results, or a build returned `drained: all models drained or unavailable (tried: ...)`). The chains: **bulk build** (no `--exact`): Hydrogen (`gemini-4-hydrogen-high`), Argon (`gemini-4-argon-medium`), agy Sonnet (`claude-sonnet-5-5-medium`). **Exact mini-task** (`--exact`): Hydrogen, Flash high (`gemini-3.8-flash-high`), Argon. Markers are per model ID; Hydrogen, Argon and Flash may share one quota pool (unverified), so they may drain together.
- **Only part of a chain drained: no question.** Hydrogen drained: exact mini-tasks go to Flash high, then Argon medium; bulk tasks to Argon medium, then agy Sonnet (the script walks this itself; plan lines say so). Hydrogen and Flash drained: exact mini-tasks go to Argon medium. Argon drained: Hydrogen keeps building; hard tasks follow the chain (argon -> sonnet -> opus). Flash scouts follow `flash -> argon-low`; if both are drained, stop and tell the user.
1. A build's whole chain drained: stop launching builds on those models. Let running tasks finish and review them. Design tasks, `claude-opus-builder` sensitive work and Claude-plan fix steps keep running as planned. Tasks routed to agy Sonnet or agy Opus (Routing 6, 7) may still run while those pools have quota.
2. Every other non-design build task is held. Do not start a wave that depends on them. When everything that can run has run and been reviewed, stop and ask the user ONE question, in words (no decision box), then wait:
   "Antigravity is drained for <only the models that were in the chain of the held tasks, e.g. Hydrogen, Argon and Sonnet for bulk builds, or Hydrogen, Flash and Argon for exact mini-tasks> (marker times: <times>). Wait for the reset, or switch to Module 3?"
   Name Flash only if Flash was in the chain of a held task. Never say Flash is drained when it was not.
3. Do nothing on the held tasks (no Claude builds either) until the user answers. Reset times are unpublished: a marker past its `until` time counts as cleared (the default `until` is a 6-hour guess).
   - Wait -> stop. On the next run, re-check the markers (`scripts/agy-run.sh --status`); if still drained, ask again.
   - Module 3 -> Module 3 mode for the held tasks (see below).
   - An answer given in the original prompt ("wait", "use Module 3") counts as the user's answer.
4. If the safety switch tripped (no Hydrogen) AND Argon is drained, all remaining non-design builds are held: ask the question in step 2.

# Module 3 mode (only after the user answered "switch to Module 3")
Claude-only building with Claude builder subagents. No agy at all for the remaining tasks, including Hydrogen and Flash. Tasks already built and accepted on Hydrogen, Flash or Argon stay as they are. Score every remaining build task 0 / 1 / 2 on each dimension (takes 10 seconds):

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
- Reviews: the usual 400-line rule (`sonnet-reviewer` up to 400 changed lines, `opus-reviewer` above).
- Fix ladder: round 1 the same agent, round 2 the next tier up (haiku -> `claude-sonnet-builder` -> `claude-opus-builder`), round 3 `claude-opus-builder`, then record and continue. An opus-builder task stays on opus-builder.
- Concurrency: total 4, no per-model caps. Plan lines end with `(Module 3 mode)`. `.m10/last-run.md` lists which tasks ran in Module 3 mode.
- Stay in Module 3 mode for the rest of the session unless the user says to retry agy.
