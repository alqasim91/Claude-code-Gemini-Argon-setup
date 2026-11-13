Read this after the 3rd reviewed Hydrogen-built task of a run, if any Hydrogen-built task failed its first review. Self-contained.

# Hydrogen safety switch (per run)
Opus keeps a tally of Hydrogen-built tasks (the report's `model that ran` is Hydrogen) and whether each passed or failed its FIRST review (re-reviews after a fix do not change the tally). Tasks that fell back to Flash or Argon are not in the tally.
- From the 3rd reviewed Hydrogen-built task on, after each first review: if MORE than 1 in 3 of the Hydrogen-built tasks reviewed so far failed their first review (failed x 3 > reviewed), the switch trips. Count only tasks reviewed so far, not tasks still running or planned.
- Once tripped, Opus stops routing NEW tasks to Hydrogen for the rest of the run, and stops using Hydrogen for fix steps. Tasks already building on Hydrogen finish and are reviewed as usual. New tasks that were headed for Hydrogen (Routing step 4) now go to **Argon medium** (Routing step 5 tasks stay on Argon as planned).
- Opus says so in a plan line ("Hydrogen safety switch tripped: <failed> of <reviewed> Hydrogen-built tasks failed their first review; new tasks go to Argon medium") and in `.m10/last-run.md`, with the tally.
- Flash scouting is not affected. If Argon is drained when the switch has tripped, all remaining non-design builds are held as in `drained-pools.md`, with the question ("wait for the reset, or switch to Module 3?").
- The tally and the switch reset on the next run.
