Read this as soon as any task is held, or the user mentions Module 3. Self-contained. Cross-rules: Module 3 is never used without the user's answer to the question below; no agy or OpenCode model reviews; the main session never implements.

# When pools are drained
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
3. Do nothing on held tasks (no Claude builds either) until the user answers. A marker past its `until` time counts as cleared; a legacy one-line agy marker counts as active for 6 hours **(guess)**.
   - Wait -> stop. On the next run re-check the markers and ask again if still drained.
   - Module 3 -> Module 3 mode for the held tasks.
   - An answer given in the original prompt ("wait", "use Module 3") counts as the user's answer.
Put the question in the user summary under "anything you must decide", and in `.m9/last-run.md` with the answer.

# Module 3 mode (only after the user answered "switch to Module 3")
Claude-only building with Claude builder sub-agents for the held tasks. No agy or OpenCode for them. Tasks already accepted from Flash, OpenCode or Argon stay as they are. Route each held task with the scores in CLAUDE.md. First match wins:
- Read-only -> `scout`. No review.
- Opus trigger (ANY of: D = 2 · two or more dimensions = 2 · S = 2 and N >= 1 · A = 2 and C = 2) -> `claude-opus-builder`.
- Easy (A, R, S, V, D all 0, total <= 2, complete spec, a tool can verify it) -> `claude-haiku-builder`.
- Everything else (design, S = 2, docs, logic) -> `claude-sonnet-builder`.
- Tie-breakers: unsure haiku vs sonnet -> sonnet. Unsure sonnet vs opus -> sonnet, unless D = 2 or S = 2 -> opus.
Rules:
- A task cut off by a drain may be partly edited: add to its brief "An earlier agy or OpenCode run may have partly edited the owned files before it stopped. Inspect them first, then finish the task."
- Reviews: the usual 800-line rule (and `opus-reviewer` for hard-routed work).
- Fix ladder: round 1 the same agent, round 2 the next tier up (haiku -> `claude-sonnet-builder` -> `claude-opus-builder`), round 3 `claude-opus-builder`, then record and continue. An opus-builder task stays on opus-builder.
- Concurrency: total 4, no per-pool caps. Plan lines end with `(Module 3 mode)`. `.m9/last-run.md` lists which tasks ran in Module 3 mode.
- Stay in Module 3 mode for the rest of the session unless the user says to retry the free pools.
