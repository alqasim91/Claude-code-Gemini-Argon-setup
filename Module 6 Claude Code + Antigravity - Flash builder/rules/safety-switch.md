Read this after the 3rd reviewed Flash-built task of a run, if any Flash-built task failed its first review. Self-contained.

# Flash safety switch (per run)
Opus keeps a tally of Flash-built tasks and whether each passed or failed its FIRST review (re-reviews after a fix do not change the tally).
- From the 3rd reviewed Flash-built task on, after each first review: if MORE than 1 in 3 of the Flash-built tasks reviewed so far failed their first review (failed x 3 > reviewed), the switch trips. Count only tasks reviewed so far, not tasks still running or planned.
- Once tripped, Opus stops routing NEW tasks to Flash for the rest of the run. Tasks already building on Flash finish and are reviewed as usual. New tasks that passed the Flash test now go to Argon (Routing steps 5 and 6).
- Opus says so in a plan line ("Flash safety switch tripped: <failed> of <reviewed> Flash-built tasks failed their first review; new tasks go to Argon") and in `.m6/last-run.md`, with the tally.
- Flash scouting is not affected. If Argon is drained when the switch has tripped, treat tasks that cannot go to Argon as in `drained-pools.md`, with the question ("wait for the reset, or switch to Module 3?").
- The tally and the switch reset on the next run.
