Read this as soon as any task is held, Flash or an agy pool is drained (marker or `agy-run.sh` exit 3), or the user mentions Module 3. Self-contained. Cross-rules: Module 3 never without the user's answer; the main session never implements.

# When the agy pools are drained
Applies when Argon, agy Sonnet and agy Opus are all drained (every builder chain exhausted: a build returned `drained: all models drained or unavailable`, or the fresh markers cover argon, sonnet and opus). Flash does not stop: it is the normal builder. Flash has its own markers (`gemini-3.8-flash-high` for builds, `gemini-3.8-flash-medium` for scouting); a drained Flash does not mean the agy pools are drained, and the other way round.
1. Stop launching agy builds on Argon, agy Sonnet and agy Opus. Let running tasks finish and review them. Design tasks, Flash builds and Claude-plan fix steps do not need those pools, so they keep running as planned.
2. **Flash keeps building what can be split.** Tasks that pass the Flash test continue on Flash high as usual (unless the safety switch tripped or Flash itself is drained, see below).
3. **Tasks that cannot be split** (they fail the Flash test, so they would have gone to Argon, agy Sonnet or agy Opus) are held. Do not start a wave that depends on them. When everything that can run has run and been reviewed, stop and ask the user ONE question, in words (no decision box), then wait:
   "Antigravity is drained for Argon, Sonnet and Opus (marker times: <times>). Some remaining tasks cannot be split into exact Flash mini-tasks. Wait for the reset, or switch to Module 3?"
4. Do nothing on those held tasks (no Claude builds either) until the user answers. Reset times are unpublished: a marker past its `until` time counts as cleared (the default `until` is a 6-hour guess).
   - Wait -> stop. On the next run, re-check the markers (`scripts/agy-run.sh --status`); if the pools are still drained, ask again.
   - Module 3 -> Module 3 mode for the held tasks (see below).
   - An answer given in the original prompt ("wait", "use Module 3") counts as the user's answer.
5. **Flash drained while building** (fresh `gemini-3.8-flash-high` marker, or exit 3 `drained: gemini-3.8-flash-high, no fallback`): stop and ask "Flash is drained. Wait for the reset, or switch to Module 3?" (same answers as above). Do not move the pieces to Argon on your own.
6. If the safety switch tripped AND the agy pools are drained, all remaining non-design builds are held: ask the question in step 3.
A read-only Flash scout whose chain ends (`flash -> argon-low`, both drained): stop and tell the user.

# Module 3 mode (only after the user answered "switch to Module 3")
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
- Reviews: the usual 400-line rule (`sonnet-reviewer` up to 400 changed lines, `opus-reviewer` above).
- Fix ladder: round 1 the same agent, round 2 the next tier up (haiku -> `claude-sonnet-builder` -> `claude-opus-builder`), round 3 `claude-opus-builder`, then record and continue. An opus-builder task stays on opus-builder.
- Concurrency: total 4, no per-model caps. Plan lines end with `(Module 3 mode)`. `.m6/last-run.md` lists which tasks ran in Module 3 mode.
- Stay in Module 3 mode for the rest of the session unless the user says to retry agy.
