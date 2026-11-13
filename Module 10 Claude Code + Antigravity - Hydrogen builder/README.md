# Module 10: Claude Code + Antigravity, Hydrogen builder

**How this differs from Module 6 (Flash builder):** Gemini 4 Hydrogen (high) builds every non-design task, whether Opus can split it into exact mini-tasks or not. Argon is kept for hard tasks and takes over if Hydrogen keeps failing review. Flash scouts (read-only) and is the build fallback when Hydrogen is drained. Hydrogen scored about the same as Argon on one index (secondary source, unverified) and is reported as weaker on terminal and long-horizon tasks.
Not sure which module to use? Pick this one if Hydrogen is in your Antigravity model list. Pick Module 6 (Flash builder) if you do not.

Claude Opus is the boss. It splits your request into tasks, and each task into small mini-tasks when it can write an exact spec for every piece. Builds go out through the Antigravity CLI (`agy`), straight from a script (`scripts/agy-run.sh`) with no helper agent in between, and run at the same time. Launching an Antigravity model costs no Claude usage. Design, reviews and the later fix steps stay on your Claude plan.

## Hydrogen vs Argon vs Flash vs Sonnet 5.5

| | Hydrogen | Argon | Flash | Claude Sonnet 5.5 |
|---|---|---|---|---|
| Artificial Analysis index | 51 (high) | 50 | 31 | 55 |
| Terminal-Bench | 54% | 57.1% | n/a | 64% |
| Price per M tokens (in / out) | $1.50 / $7.50 | not listed here | not listed here | not listed here |
| Role in this module | default builder | hard tasks, safety-switch takeover | scouting, build fallback | design, reviews, fixes (Claude plan) |

Secondary and unverified: these numbers come from third-party benchmark pages and press (Artificial Analysis, Terminal-Bench), not from this module's tests. Only figures that Google or Antigravity published themselves count as primary, and none are claimed here. Treat the table as a reason for the routing, not as proof. The safety switch exists because real quality on your code may differ.

# Part 1: Setup

You only use the Claude desktop app. Claude does the setup for you.

## Step 1. Get your two plans
- **Google AI Pro**: subscribe with the Google account you will use for Antigravity. Your Antigravity builders run on this plan.
- **Claude Pro**: the plan you already use for Claude. Design, reviews and fixes run on it.

## Step 2. Let Claude set it up
1. Put `module-10-files.zip` in your project folder.
2. Open the Claude desktop app. Click **New session** and pick your project folder.
3. Paste this line:
   ```
   Unzip module-10-files.zip in this folder, then read module-10/SETUP.md and follow it.
   ```

Claude unzips the files, asks you one question (may it edit files without asking each time), installs the module, installs `agy` if it is missing (it asks first), checks it and tells you what is left. It will ask your approval for the first one or two commands; that is normal, the approvals list does not exist yet. Signing in to Antigravity with your Google account happens in your browser; Claude starts it and tells you when to finish it. When it finishes, start a new session and choose Opus.

**The installer command (Claude runs it for you, you do not type it).** On Mac, Linux or Git Bash: `bash module-10/install.sh`. On Windows without bash: `powershell -ExecutionPolicy Bypass -File module-10\install.ps1`. Adding `--accept-edits` (Windows: `-AcceptEdits`) answers the edit question with yes, `--no-accept-edits` (`-NoAcceptEdits`) with no. Running it again is safe: it changes nothing the second time.

**What the setup does**
- Copies the 7 agents to `.claude/agents/` and the 5 rule files to `.claude/m10/`.
- Copies `scripts/agy-run.sh` and makes it runnable.
- Copies `CLAUDE.md` and `AGENTS.md`. If you already have your own, it does not overwrite them: it saves the new text as `CLAUDE.module-10.md` and Claude asks whether to put it at the top of your file. An older Module 10 Hydrogen builder copy is backed up and replaced.
- Adds the approvals list to `.claude/settings.json` (merged, your other settings stay). If you say yes to the edit question, it also sets `"defaultMode": "acceptEdits"` there.
- Adds two lines to `.gitignore` (`.claude/agy-quota/` and `.m10/`).
- Starts git and makes a first commit if the folder has none. It never touches your `.env` files.
- Checks that `agy` is installed and offers to install it if not.

`agy` should list these six models (the full list also has `-low`, `-medium`, `-high` and, for Hydrogen, `-xhigh` variants): `gemini-4-hydrogen-high` (default builder), `gemini-4-argon-medium`, `gemini-3.8-flash-high`, `gemini-3.8-flash-medium`, `claude-sonnet-5-5-medium`, `claude-opus-5-5-medium`. Claude checks this and tells you in plain words if one is missing.

## Step 3. Try it
Start a new session in the project folder, choose Opus, and paste a prompt from `module-10/test-prompt.md` (**Prompt A**, the Driftwood site, or **Prompt B**, the Orbit Catch game), unchanged. Watch for: a task plan table first, the design shell built by `claude-sonnet-builder` or `claude-opus-builder` (never by `agy`), page and script tasks built by Hydrogen high (split into mini-tasks where Opus can spec them exactly) and launched together, ONE Sonnet review per task (after all its mini-tasks), and a short final message. The main chat itself edits no project files and reads no full diff.

## Approvals
The installer adds an allow-list to `.claude/settings.json`: the runner script, read-only git commands and the `.m10/` run folder. So a run does not stop to ask for each launch. It also blocks reading `.env` files. The installer also asks one question: may Claude edit files in this folder without asking each time? Yes sets `"defaultMode": "acceptEdits"` in that file (`--accept-edits` on Mac or `-AcceptEdits` on Windows answers yes up front); no leaves every edit asking as usual. Never add `--dangerously-skip-permissions`.

# Part 2: How it works

**The main chat stays clean on purpose.** Opus is the head chef who never touches a pan: it only plans and judges, and every line of code gets cooked in a sub-agent.

## The cast
| Who | Role |
|---|---|
| **Opus** (your Claude session) | The boss. Only plans and judges: launches sub-agents, reads their short reports, and never edits files, runs builds or reads a full diff. |
| **Hydrogen high** (`gemini-4-hydrogen-high`, alias `hydrogen`) | The default builder for every non-design task: exact mini-tasks or bulk work. Also fix step 1 for its own work. `-medium`, `-low`, `-xhigh` are selectable. Never reviews. |
| **Argon** (`gemini-4-argon-medium`) | Hard tasks (medium; high for the hardest), terminal-heavy or long-horizon work, and every new build once the Hydrogen safety switch trips. Fix step 2 for Hydrogen- and Flash-built work. Small pool. |
| **Sonnet / Opus via agy** | Specialists for non-design builds. Sonnet for careful edits and docs. Opus for hard multi-file work. Small pools. |
| **Flash** (`gemini-3.8-flash-*`) | Scout (medium, `-low` for lookups): read-only lookups, summaries, checks. Also the build fallback (`gemini-3.8-flash-high`) for exact mini-tasks when Hydrogen is drained. Never fixes or reviews. |
| **`scripts/agy-run.sh`** | The runner script. Sends one task or mini-task to one Antigravity model, follows the fallback chain, and reports what changed. It refuses design. |
| **`claude-sonnet-builder`** | Design shells and first drafts (Sonnet high). Fix step 2 for work Argon, agy Sonnet or agy Opus built. |
| **`claude-opus-builder`** | Sensitive work (migrations, access policies, money and stock functions, auth, crypto) and the most important designs (Opus medium). Last fix step: step 3 for agy-built work, step 4 for Hydrogen- and Flash-built work. |
| **`claude-sonnet-fixer`** | Fix step 3 for Hydrogen- and Flash-built work (Sonnet medium), earlier if Hydrogen or Argon is drained. Fixes only. |
| **`sonnet-reviewer`** | Reads one task's diff of 400 changed lines or fewer. Returns PASS or FAIL. |
| **`opus-reviewer`** | Reads one task's diff of more than 400 changed lines (Opus medium). Returns PASS or FAIL. |
| **`claude-haiku-builder`** | Tiny, exactly described edits. In Module 3 mode: easy builds. |
| **`scout`** | Module 3 mode only: all read-only work. |

Everything in the Claude rows runs on your Claude plan. No Antigravity model ever reviews.

## A build in 5 beats
```
 1 PLAN        Opus prints a task table first, before any work: id, model, owned files, after
      |
 2 WAVE 0      design shell alone, built by Claude (Sonnet high or Opus medium)
      |
 3 WAVE 1+     tasks run in parallel on Hydrogen high (mini-tasks when Opus can spec
               them exactly, bulk otherwise), Argon for hard ones. One owner per file
      |
 4 SCOUTS      Flash checks links, leftovers, accessibility
      |
 5 REVIEW      once per task, after all its mini-tasks: Sonnet reviews small diffs,
               an Opus reviewer reads big ones; defects go back for fixing
```
- **One owner per file.** Two tasks never touch the same file in a wave. Mini-tasks on the same file run one after another.
- **Hydrogen first.** Every non-design build goes to Hydrogen high, with no question to you. While planning, Opus also checks: can I write an exact spec for each small piece? Yes (4 mini-tasks by default, more if needed) means mini-tasks, which can fall back to Flash if Hydrogen is drained. No means one bulk Hydrogen task. Hard tasks go to Argon.
- **Waves.** Each wave is reviewed fully before the next one starts.
- **Sensitive files go to `claude-opus-builder`** (Opus medium, on your Claude plan): database migrations, access policies, functions that move money or stock, auth and crypto. It is judged by layer: the screens, types and labels of the same feature are ordinary builds.
- **Tiny edits go to `claude-haiku-builder` (or Hydrogen, when the edit can be specced exactly).** Opus itself never edits, not even a one-liner. Unclear specs and architecture choices: Opus decides them in the plan, then delegates.
- **Design never goes to Antigravity** (not Hydrogen, Argon or Flash). Shells and first design drafts always go to a Claude builder.

## Who reviews
Opus counts the changed lines of the task (added plus removed, plus new files). A task built from mini-tasks is reviewed ONCE, after all its mini-tasks finish, on the combined diff, never per mini-task.

| Changed lines | Reviewer |
|---|---|
| 400 or fewer | `sonnet-reviewer` |
| More than 400 | `opus-reviewer` (Opus medium) |

Same rule for every builder, `claude-opus-builder` included. The main chat never reads the full diff, only the verdict. No Antigravity model ever reviews. If a fix pushes a task over 400, the next review moves up to `opus-reviewer`.

## When a review fails
Up to 3 steps (4 for Hydrogen- and Flash-built work). Who fixes depends on who built it (the model that actually ran).

| Built by | Step 1 | Step 2 | Step 3 | Step 4 |
|---|---|---|---|---|
| Hydrogen | Hydrogen high (`gemini-4-hydrogen-high`) | Argon medium (`gemini-4-argon-medium`) | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium) |
| Flash (fallback build) | Hydrogen high | Argon medium | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium) |
| Argon, agy Sonnet or agy Opus | the same model | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) | - |
| `claude-sonnet-builder` (design) | the same agent | `claude-opus-builder` | record and continue | - |
| `claude-opus-builder` (design or sensitive) | the same agent | record and continue | - | - |
| `claude-haiku-builder` (tiny edit) | the same agent | `claude-sonnet-builder` | `claude-opus-builder` | - |

- A drained step is skipped (Hydrogen drained: start at Argon; Hydrogen and Argon drained: start at Sonnet medium). A drained Argon-, Sonnet- or Opus-built model skips straight to the Claude steps. Argon high is never used for fixes.
- Flash never fixes and never reviews. Hydrogen and Argon fix steps get the whole task's diff and the defect list, and fix the whole task.
- Still failing after the last step? It goes in the final summary and the build keeps going.

## The Hydrogen safety switch
Opus keeps score. From the 3rd reviewed Hydrogen-built task on, if more than 1 in 3 failed their first review, Opus stops sending new tasks (and fix steps) to Hydrogen for the rest of that run. Those tasks go to Argon medium instead, and Opus says so in the plan and the final summary.

## When quota runs out
- A drained model gets a marker file in `.claude/agy-quota/` with a reset time. If agy gives none, the script uses 6 hours from now (a guess). Opus skips it until then. Check with `scripts/agy-run.sh --status`. Delete a marker to clear it.
- A drained Hydrogen build moves on by itself in the script: exact mini-tasks go Flash high, then Argon medium; bulk tasks go Argon medium, then agy Sonnet. A fix task never falls back: the script forces `--no-fallback` for any task whose slug ends in `-r1` to `-r9`, so Flash or any other model never serves a fix. Argon builds go Sonnet, then Opus.
- **Quota facts are unconfirmed.** Hydrogen, Argon and Flash may share one quota pool (unverified), so draining one may drain the others. The 6-hour reset in the markers is a guess. Markers are per model ID.
- **Every model in the chain drained?** Bulk builds use the chain Hydrogen, Argon, agy Sonnet; exact mini-tasks use Hydrogen, Flash high, Argon. Everything that can still run (design, sensitive work, reviews, Claude fixes) runs; builds whose whole chain is drained are held, and Opus asks you ONE question naming only the models that were actually in that chain, for example **"Antigravity is drained for Hydrogen, Argon and Sonnet. Wait for the reset, or switch to Module 3?"** It never switches on its own.
- **Only part of a chain drained?** No question: the chain above covers it and the report says which model ran.
- **Module 3 mode.** Claude builds the rest, with no Antigravity. Opus scores each task, then picks `claude-haiku-builder` (easy), `claude-sonnet-builder` (normal and design) or `claude-opus-builder` (hardest). Read-only work goes to `scout`. Reviews use the same 400-line rule.

# Part 3: Good to know

- **No relay.** Antigravity models are launched by `scripts/agy-run.sh`. The main chat only reads its short report.
- **Run folder.** `.m10/` holds the briefs, the logs, the shared contract (`contract.md`) and the detailed table of the last run (`last-run.md`). It is git-ignored and safe to delete between runs.
- **Shared contract.** The names every builder must agree on (classes, ids, functions) live in `.m10/contract.md`. Each brief points to it instead of repeating the list.
- **The final message is short.** A few plain lines. Details are in `.m10/last-run.md`.
- **Rule files.** Rarely needed rules live in `.claude/m10/`. Opus reads them only when needed, which keeps every message cheaper.
- **agy runs have no shell.** Headless `agy` (`--mode accept-edits`) edits files but denies shell commands, so the models can't run tests. The reviewer runs the safe, read-only checks.
- **Parallel runs drain quota faster.** Several models spend your Google quota at once. Prefer fewer, bigger tasks.
- **Default caps (editable guesses):** 4 tasks total (hydrogen 3, argon 1, flash 2, agy sonnet 1, agy opus 1). The per-pool numbers are guesses, agy's concurrent-session limit is unverified. Claude subagent runs count toward the total only. Edit the caps table in `CLAUDE.md`.
- **Hydrogen high does the bulk of the building** and Argon's small pool is kept for hard tasks and for taking over if Hydrogen keeps failing review.
- **Design, sensitive builds, reviews and the Sonnet and Opus fix steps use your Claude plan**, not Google quota. Watch your Claude usage too.
- **Review every diff.** File ownership is enforced by instructions, not the filesystem. Fallbacks can switch models mid-task.
- **Unverified:** whether starting `agy` from Claude opens the browser sign-in page (if not, Claude asks you to sign in in the Antigravity app), whether `agy` allows concurrent sessions, the real quota error text, whether the `effort` setting in the Claude agent files is honored, and whether the script flow works on Windows (the script is a bash script, so it likely needs Git Bash). The script was tested against a stand-in `agy`, not the real tool.
- **After a context reset** the main chat re-reads `CLAUDE.md`, re-prints the plan with each task's status, and keeps delegating. It never carries on inline.
- **Secrets stay out.** Copying, linking or reading `.env` files, keys or credentials makes Claude stop and ask, and sub-agents follow the same rule. Sub-agents may test migrations only on a local throwaway database.
- **A summary always arrives**, even when all the work went to one sub-agent.
