Read this after the 3rd reviewed task of a pool, if that pool has any first-review failure. Self-contained. Cross-rules: scouting is unaffected; no agy or OpenCode model reviews; S = 2 never goes to a free model.

# Safety switches (per run, per pool)
Opus keeps one tally per pool: Flash-built tasks and OpenCode-built tasks reviewed, and how many failed their FIRST review (re-reviews do not change it). A task counts for the pool that built most of its files (tie: OpenCode).
- From the 3rd reviewed task of a pool on, after each first review: if MORE than 1 in 3 of that pool's tasks failed their first review (failed x 3 > reviewed), the pool is **tripped** for the rest of the run.
- A tripped pool gets no NEW tasks. Tasks already building finish and are reviewed as usual. Opus prints "Safety switch tripped: <pool>, <failed> of <reviewed> failed their first review" in the plan and records it in `.m9/last-run.md`.
- **Flash tripped:** Routing 6 goes to OpenCode `build` directly. **OpenCode tripped:** Routing 6 goes to Flash; Routing 7 (not splittable) goes to Argon medium, because free models proved unreliable in this run. **Both tripped:** the rest of the non-design builds go to Argon medium; Argon drained -> held, ask the drained-pools question (`.claude/m9/drained-pools.md`).
- Scouting is not affected. The tallies and switches reset on the next run.
