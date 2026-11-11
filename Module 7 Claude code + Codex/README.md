# Module 7: Claude plans, Codex models build in parallel

Claude Opus is the boss. It splits your request into phases and tasks, and runs them on OpenAI Codex models through the Codex CLI (`codex exec`), signed in with your ChatGPT plan. Independent tasks run at the same time. Claude does design, security, fixes and reviews.

What changed from Module 6: `agy` is replaced by Codex. There is no relay subagent per task any more. Opus runs `scripts/codex-run.sh` itself in the background. In Module 6 each relay subagent paid about 50k tokens just to start, so removing it is the main cost saving.

# Part 1: Setup

Short on time? Skip to Step 4 (Install the files): Claude Code can do most of this for you.

Do the steps in order. Each step shows **Mac** (Terminal) and **Windows** (PowerShell).

## Step 1. Get a ChatGPT plan that includes Codex
Use the ChatGPT account you will sign in with. Your Codex models run on this plan.

## Step 2. Install the Codex CLI
**Mac**
```bash
npm i -g @openai/codex
# or: brew install codex
codex --version
```
**Windows (PowerShell)**
```powershell
npm i -g @openai/codex
codex --version
```
You should see a version number. Command not found? Close the terminal, open a new one, try again. The script `codex-run.sh` is a bash script: on Windows run Claude Code from Git Bash or WSL.

## Step 3. Log in with ChatGPT
```
codex login
```
Choose **Sign in with ChatGPT** and finish in the browser. Then check the flags this module uses:
```
codex exec --help
```
Look for `-m` (model), `-c` (config override), `--sandbox` and `-o` (output file). The flags come from third-party docs. If a name differs, edit the variables at the top of `scripts/codex-run.sh`.

## Step 4. Install the files (one command)

**Easiest: let Claude Code set it up**

1. Put `module-7-files.zip` in your project folder.
2. Open the Claude desktop app. Click **New session** and pick your project folder.
3. Paste this line:
   ```
   Unzip module-7-files.zip in this folder, then read module-7/SETUP.md and follow it.
   ```

Claude Code unzips the files, asks you one question (may it edit files without asking each time), installs the module, checks the outside tools and tells you what is left. It will ask your approval for the first one or two commands; that is normal, the approvals list does not exist yet. Signing in to `codex` stays with you, because it opens a browser. When it finishes, start a new session and choose Opus.

**Or run the installer yourself**

Unzip `module-7-files.zip` **inside your project folder** (it creates a `module-7` folder). Open a terminal in the project folder. Run one command.

**Mac**
```bash
bash module-7/install.sh
```
**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -File module-7\install.ps1
```
It prints one line per step. Running it again is safe: it changes nothing the second time. The runner script is a bash script: on Windows run Claude Code from Git Bash or WSL.

The installer asks one question: may Claude edit files in this folder without asking each time? Answer `y` for runs you can leave alone, or `n` to approve each edit yourself. To answer yes up front, add `--accept-edits` to the Mac command or `-AcceptEdits` to the Windows command. You can change it later in `.claude/settings.json`.

**What it does**
- Copies the 5 agents to `.claude/agents/` and the 4 rule files to `.claude/m7/`.
- Copies `scripts/codex-run.sh` and makes it runnable.
- Copies `CLAUDE.md` and `AGENTS.md`. If you already have your own, it does not overwrite them: it saves the new text as `CLAUDE.module-7.md` and tells you to paste it in. An older Module 7 copy is backed up and replaced.
- Adds the approvals list to `.claude/settings.json` (merged, your other settings stay).
- Asks the one edit question described above and, only if you say yes, sets `"defaultMode": "acceptEdits"` in that file.
- Adds two lines to `.gitignore` (`.claude/codex-quota/` and `.m7/`).
- Starts git and makes a first commit if the folder has none. It never touches your `.env` files.
- Checks that `codex` is installed and tells you how to get it if not.

<details>
<summary>Manual install (only if you prefer to copy by hand)</summary>

**Mac**
```bash
mkdir -p .claude/agents .claude/m7 .claude/codex-quota scripts
cp module-7/CLAUDE.md module-7/AGENTS.md .
cp module-7/agents/*.md .claude/agents/
cp module-7/rules/*.md .claude/m7/
cp module-7/scripts/codex-run.sh scripts/
chmod +x scripts/codex-run.sh
cp module-7/settings.json .claude/settings.json
printf '.claude/codex-quota/\n.m7/\n' >> .gitignore
git init && git add -A && git commit -m "start"
```
**Windows (PowerShell)**
```powershell
New-Item -ItemType Directory -Force .claude\agents, .claude\m7, .claude\codex-quota, scripts | Out-Null
Copy-Item module-7\CLAUDE.md, module-7\AGENTS.md .
Copy-Item module-7\agents\*.md .claude\agents\
Copy-Item module-7\rules\*.md .claude\m7\
Copy-Item module-7\scripts\codex-run.sh scripts\
Copy-Item module-7\settings.json .claude\settings.json
Add-Content .gitignore ".claude/codex-quota/", ".m7/"
```
Already have a `CLAUDE.md`, `AGENTS.md` or `.claude/settings.json`? Do not overwrite them: paste the new text into your file. Not using git yet? The review step reads `git diff`, so run `git init && git add -A && git commit -m "start"` once.
Want Claude to edit files here without asking each time? Add `"defaultMode": "acceptEdits"` inside `"permissions"` in `.claude/settings.json`.
</details>

**Check it worked:** `ls -la .claude/agents .claude/m7 scripts`. You should see:
- 5 agents: `claude-sonnet-builder`, `claude-opus-builder`, `claude-haiku-builder`, `sonnet-reviewer`, `scout`.
- 4 files in `.claude/m7/`: `codex-limits.md`, `fix-ladders.md`, `models.md`, `worktree.md`.
- One executable script: `codex-run.sh`.
"No such file" means the terminal was not in the project folder. `.claude` is hidden in Finder (`Cmd+Shift+.` shows it).

## Step 5. Make sure the folder is a git repo
The review step reads `git diff`. Skip this if your project already uses git.
```
git init
git add -A
git commit -m "start"
```

## Step 6. Start Claude Code and check the agents
```
claude
```
Type `/agents`. You should see `claude-sonnet-builder`, `claude-opus-builder`, `claude-haiku-builder`, `sonnet-reviewer` and `scout`. Not there? Quit, start again, re-check Step 4. Also run `scripts/codex-run.sh --status`: it should print "no codex limit active".

## Step 7. Run the test prompt
Open `module-7/test-prompt.md`, copy the prompt into Claude Code unchanged. Then use its "What to check" list.

## Approvals
The installer adds an allow-list to `.claude/settings.json`: the runner script, read-only git commands and the `.m7/` run folder. So a run does not stop to ask for each launch. It also blocks reading `.env` files. The installer also asks one question: may Claude edit files in this folder without asking each time? Yes sets `"defaultMode": "acceptEdits"` in that file (`--accept-edits` on Mac or `-AcceptEdits` on Windows answers yes up front); no leaves every edit asking as usual. The script never bypasses the Codex sandbox or approvals. Do not add flags that do.

# Part 2: How it works

## The cast
| Who | Role |
|---|---|
| **Opus** (your Claude session) | The boss. Plans, routes, reviews the big diffs. Never builds bulk work. |
| **sol** (`gpt-6.1-sol`) | Default builder (medium). Hard multi-file or tricky logic (high). |
| **terra** (`gpt-6.1-terra`) | Docs, copy, content pages. |
| **luna** (`gpt-6-luna`) | Scout (low). Tests, formatting, boilerplate, mechanical edits (medium). |
| **`claude-sonnet-builder`** | Design shells and first drafts. Security, auth, secrets. Fix rounds. In Module 3 mode: design, S = 2, docs and the rest. |
| **`claude-opus-builder`** | The most important designs. Round-3 fixes for Sol tasks. |
| **`claude-haiku-builder`** | Module 3 mode only (Codex limit hit, you said Module 3): easy tasks. |
| **`scout`** | Module 3 mode only (Codex limit hit, you said Module 3): all read-only work (search, explain, research), with file and line evidence. Never edits. |
| **`sonnet-reviewer`** | Reads one task's diff, returns PASS or FAIL. Read-only. |

Model IDs are from learn.chatgpt.com/docs/models, checked 2026-10-29. Astra (`gpt-6-astra`) is deliberately not used.

**Why Claude reviews and fixes:** third-party benchmarks (vals.ai, benchlm.ai) put both Sol and Terra below Claude Sonnet 5.5 at coding. So Codex builds the volume, and Claude checks it.

**Design never goes to a Codex model.** Design shells and first drafts go to Sonnet (high), or Opus (medium) for the most important ones.

## How tasks are distributed
Opus scores every build task from 0 to 2 on seven dimensions (from Module 3):

| | 0 | 1 | 2 |
|---|---|---|---|
| **A** Ambiguity | exact spec, diff describable in one sentence | clear goal, small local choices | open-ended, approach undecided |
| **N** Novelty | copies an existing pattern | adapts a pattern | no precedent; new abstraction |
| **C** Coupling | 1–2 files, no shared types | 3+ files or shared type/interface | cross-cutting, public API |
| **R** Reversibility | `git revert` undoes it | user-visible behavior or config | prod data, releases, money, external side effects |
| **S** Sensitivity | none | near auth/PII | auth, crypto, secrets, payments, PHI, tenancy |
| **V** Verifiability | a test/type/lint/build check fully covers it | partly covered | races, performance, security, UX judgment |
| **D** Diagnosis | cause known / none needed | reproducible, cause unknown | intermittent, prod-only, no repro |

**Small job rule.** If the whole request plans to 2 or fewer build tasks and none scores S = 2 or D = 2, it runs as ONE sol-medium task with the normal review. No scout unless something is unknown.

Otherwise the first match wins:
0. Read-only (find, explain, research, summarize): luna-low. No review.
1. Design shell or first design draft: `claude-sonnet-builder` (`claude-opus-builder` for key designs). Never Codex.
2. S = 2: Opus writes the spec, `claude-sonnet-builder` builds. Opus reviews.
3. Hard (any of: D = 2, two or more dimensions = 2, A = 2 and C = 2): sol-high. Opus reviews.
4. Easy (A, R, S, V, D all 0, total 2 or less, spec complete, a tool can verify it): luna-medium.
5. Docs, copy, content pages: terra-medium.
6. Otherwise: sol-medium.

Unsure luna or sol? Sol. Unsure sol-medium or sol-high? Sol-medium, unless D = 2.

Opus logs one line per task in `.m7/TASKS.md` (`ID | phase | route | score | reviewer | rounds | result | notes`), so you can tune the routing later.

## A build in 5 beats
```
 1 PLAN        Opus prints a task table: id, phase, model, score, owned files, after
      |
 2 PHASE 0     foundation alone (design shell, styles, schema), built by Claude
      |
 3 PHASE 1+    tasks run in parallel on Codex, one owner per file
      |
 4 REVIEW      each phase is reviewed and fixed before the next starts
      |
 5 SUMMARY     a few plain lines to you; the table (phase, task, score, model, limit hit, reviewer, rounds, result) goes to .m7/last-run.md
```
- **Phases.** If your prompt is not phased, Opus phases it. Phase 0 is the foundation. Each later phase builds on the previous one. A multi-step phase is split into parallel tasks on separate files. A single-step phase is one job.
- **One owner per file.** Two tasks never touch the same file in a phase.
- **Shared names.** If tasks depend on shared names (functions, ids, classes), the foundation task writes them to `.m7/contract.md` and later briefs say "read it first". Nobody copies the list into briefs.
- **Worktree mode** (optional, off by default) gives each task its own git worktree and a `codex/<task>` branch, for work that cannot be split into separate files.

## Who reviews
| Implementer | Reviewer |
|---|---|
| luna or terra | `sonnet-reviewer` |
| sol medium, diff of 400 changed lines or fewer | `sonnet-reviewer` |
| sol medium over 400 lines, or sol high | Opus reads the diff itself |
| Tasks routed by S = 2 or the hard rule | Opus reads the diff itself |
| Claude builders (design, security) | Opus reads the diff itself |

The 400-line rule and the scores come from Module 3. Opus never spawns a separate Opus reviewer. In the Module 3 cost test, fresh Opus reviewers were 23% of the bill and changed nothing.

## When a review fails (up to 3 rounds)
| Implementer | Round 1 | Round 2 | Round 3 |
|---|---|---|---|
| sol | same model | `claude-sonnet-builder` | `claude-opus-builder` |
| luna or terra | same model | sol high | `claude-sonnet-builder` |
| Claude builders | same agent | `claude-opus-builder` | record and continue |

Still failing after round 3? It goes in the final summary and the build keeps going.

## When quota runs out
The Codex plan has TWO limits: a 5-hour limit and a weekly limit. Both are shared by all Codex models (luna, terra, sol), one pool. There is no Codex-to-Codex fallback. The script keeps one marker per limit (`.claude/codex-quota/5h` and `.claude/codex-quota/weekly`, each with `until=` and `reason=` lines) and exits with a different code for each.

| Limit | Script exit | What Opus does |
|---|---|---|
| 5-hour | 3: `drained: codex 5h limit until <time>` | Stops launching Codex tasks, lets running ones finish, then STOPS and tells you: "Codex 5-hour limit hit. Codex is back at <time>. Re-run me after that and I continue from the next task." No Claude builders and no question, unless you say "use Module 3" (now or in your first prompt). |
| Weekly | 5: `drained: codex weekly limit until <time>` | Stops launching Codex tasks, lets running ones finish, then asks: "Codex weekly limit hit (until <time>). Wait (I re-check Codex in 24 hours) or switch the remaining tasks to Module 3 mode now?" Nothing runs on Claude until you say Module 3. If you wait, the next run after the until time re-checks and asks again if it is still weekly. |

- Check the state any time with `scripts/codex-run.sh --status`: it prints each active marker with its until time and the time remaining, and exits 0 (none active), 3 (5-hour active) or 5 (weekly active). Opus runs it before planning and before each phase.
- The weekly question is the one question Opus asks in a build. The 5-hour case is a stop-and-tell.
- Delete a marker file to clear it by hand. An old single `.claude/codex-quota/codex` file from an earlier version is ignored: delete it.
- A run that hits a limit still prints its report, including any partial edits.
- In interactive Codex, the `/status` command shows both "5h limit" and "Weekly limit" with reset times. The usage page is chatgpt.com/codex/settings/usage.
- **Module 3 mode** (only when you say Module 3) is Claude only, routed by the same scores as Module 3: Opus-trigger tasks (D = 2, two or more 2s, S = 2 and N 1 or more, A = 2 and C = 2) go to `claude-opus-builder`. Read-only work (find, explain, research, summarize) goes to `scout`. Easy tasks go to `claude-haiku-builder`. Everything else (design, S = 2, docs) goes to `claude-sonnet-builder`.
- Module 3 mode reviews: `sonnet-reviewer` up to 400 changed lines, Opus above that and for opus-builder work. Fixes: same agent, then the next tier up (haiku, sonnet, opus), then `claude-opus-builder`. Up to 3 tasks at once. Plan lines show `(Module 3 mode)`, and the summary lists those tasks.
- A hard (sol-high) task is never downgraded to luna or terra.

# Part 3: Good to know

- **Run folder.** `.m7/` holds the briefs (`briefs/`), the script's scratch files (`logs/`), the shared names file (`contract.md`), the task log (`TASKS.md`) and the detailed table of the last run (`last-run.md`). It is git-ignored and safe to delete between runs.
- **The final message is short.** At most 8 plain lines. The per-phase table and the other details are in `.m7/last-run.md`.
- **Rule files.** Rarely needed rules (Codex limits and Module 3 mode, fix ladder details, Claude agent table, worktree mode) live in `.claude/m7/`. Opus reads each one only when its trigger fires, which keeps every message cheaper. The one-line guards stay in `CLAUDE.md`.

- **Parallel runs use up the shared limits faster.** Prefer fewer, bigger tasks.
- **Default caps:** 3 tasks at once (sol 2, terra 2, luna 3). They limit parallel sessions, not quota. Claude builder runs count toward the total only. Edit the table in `CLAUDE.md`.
- **Claude-plan work** (design, security, fix rounds 2 and 3, Module 3 mode) uses your Claude plan, not ChatGPT quota.
- **Edit the tables.** Routing, caps, ladders and the model pool live in `CLAUDE.md`. Model IDs and flags also live at the top of `scripts/codex-run.sh`. Keep both in step.
- **Review every diff.** File ownership is enforced by instructions, not the filesystem.
- **Known unknowns:**
  - The `codex exec` flags come from third-party docs. Verify with `codex exec --help` on first run.
  - Codex concurrency limits are unpublished. The caps are guesses. They limit parallel sessions, not quota.
  - Confirmed: all Codex models share ONE pool with two limits (5-hour and weekly). Per-model draw rates are still unpublished.
  - The exact quota error wording is unverified. Known samples: "try again at 20 Aug 2026, 16:29.", "try again in 2 hours 3 minutes.", "You've reached your 5-hour work usage limit". The script parses these best effort, prints the raw matching line in its report, and stores it as `reason=` in the marker. If no reset time parses, 5h uses now + 5 hours and weekly uses now + 24 hours. The concurrency wording is unconfirmed too.
  - Whether `effort: medium` and `effort: high` in the agent files are honored is unverified.
  - Windows needs Git Bash or WSL for the script.
