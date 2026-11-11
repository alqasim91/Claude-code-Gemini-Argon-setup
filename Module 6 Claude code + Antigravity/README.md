# Module 6: Claude plans, Antigravity builds, your Claude plan designs, reviews and fixes

Claude Opus is the boss. It splits your request into tasks. Builds go out to Argon and friends through the Antigravity CLI (`agy`) and run at the same time. A script, `scripts/agy-run.sh`, sends each build straight to `agy`, with no helper agent in between, so launching a build costs no Claude usage. Design, reviews and fixes stay on your Claude plan, so your small Google pools last longer.

# Part 1: Setup

Short on time? Skip to Step 4 (Install the files): Claude Code can do most of this for you.

Do the steps in order. Each step shows **Mac** (Terminal) and **Windows** (PowerShell).

## Step 1. Get your two plans
- **Google AI Pro**: subscribe with the Google account you will use for `agy`. Your Antigravity builders run on this plan.
- **Claude Pro**: the plan you already use to sign in to Claude Code. Design, reviews and fixes run on it.

## Step 2. Install `agy`
**Mac**
```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
agy --version
```
**Windows (PowerShell)**
```powershell
irm https://antigravity.google/cli/install.ps1 | iex
agy --version
```
You should see a version number. If the command is not found, close the terminal, open a new one, and try again.

## Step 3. Log in
```
agy
```
1. Choose **Google OAuth**.
2. Sign in with your AI Pro account in the browser.
3. Quit `agy`, then check your models:
```
agy models
```
Make sure these four are in the list:
- `gemini-4-argon-medium`
- `gemini-3.8-flash-medium`
- `claude-sonnet-5-5-medium`
- `claude-opus-5-5-medium`

## Step 4. Install the files (one command)

**Easiest: let Claude Code set it up**

1. Put `module-6-files.zip` in your project folder.
2. Open the Claude desktop app. Click **New session** and pick your project folder.
3. Paste this line:
   ```
   Unzip module-6-files.zip in this folder, then read module-6/SETUP.md and follow it.
   ```

Claude Code unzips the files, asks you one question (may it edit files without asking each time), installs the module, checks the outside tools and tells you what is left. It will ask your approval for the first one or two commands; that is normal, the approvals list does not exist yet. Signing in to `agy` stays with you, because it opens a browser. When it finishes, start a new session and choose Opus.

**Or run the installer yourself**

Unzip `module-6-files.zip` **inside your project folder** (it creates a `module-6` folder). Open a terminal in the project folder (the one that contains `module-6`). Run one command.

**Mac**
```bash
bash module-6/install.sh
```
**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -File module-6\install.ps1
```
It prints one line per step. Running it again is safe: it changes nothing the second time.

The installer asks one question: may Claude edit files in this folder without asking each time? Answer `y` for runs you can leave alone, or `n` to approve each edit yourself. To answer yes up front, add `--accept-edits` to the Mac command or `-AcceptEdits` to the Windows command. You can change it later in `.claude/settings.json`.

**What it does**
- Copies the 7 agents to `.claude/agents/` and the 3 rule files to `.claude/m6/`.
- Copies `scripts/agy-run.sh` and makes it runnable.
- Copies `CLAUDE.md` and `AGENTS.md`. If you already have your own, it does not overwrite them: it saves the new text as `CLAUDE.module-6.md` and tells you to paste it in. An older Module 6 copy is backed up and replaced.
- Removes the old `agy-delegate` agent if you have it (a script replaced it).
- Adds the approvals list to `.claude/settings.json` (merged, your other settings stay).
- Asks the one edit question described above and, only if you say yes, sets `"defaultMode": "acceptEdits"` in that file.
- Adds two lines to `.gitignore`: `.claude/agy-quota/` and `.m6/`.
- Starts git and makes a first commit if the folder has none. It never touches your `.env` files.
- Checks that `agy` is installed and tells you how to get it if not.

<details>
<summary>Manual install (only if you prefer to copy by hand)</summary>

**Mac**
```bash
mkdir -p .claude/agents .claude/m6 .claude/agy-quota scripts
cp module-6/CLAUDE.md module-6/AGENTS.md .
cp module-6/agents/*.md .claude/agents/
cp module-6/rules/*.md .claude/m6/
cp module-6/scripts/agy-run.sh scripts/
chmod +x scripts/agy-run.sh
cp module-6/settings.json .claude/settings.json
printf '.claude/agy-quota/\n.m6/\n' >> .gitignore
rm -f .claude/agents/agy-delegate.md
git init && git add -A && git commit -m "start"
```
**Windows (PowerShell)**
```powershell
New-Item -ItemType Directory -Force .claude\agents, .claude\m6, .claude\agy-quota, scripts | Out-Null
Copy-Item module-6\CLAUDE.md, module-6\AGENTS.md .
Copy-Item module-6\agents\*.md .claude\agents\
Copy-Item module-6\rules\*.md .claude\m6\
Copy-Item module-6\scripts\agy-run.sh scripts\
Copy-Item module-6\settings.json .claude\settings.json
Add-Content .gitignore ".claude/agy-quota/", ".m6/"
Remove-Item -ErrorAction SilentlyContinue .claude\agents\agy-delegate.md
```
Already have a `CLAUDE.md`, `AGENTS.md` or `.claude/settings.json`? Do not overwrite them: paste the new text into your file. Not using git yet? The review step reads `git diff`, so run `git init && git add -A && git commit -m "start"` once.
Want Claude to edit files here without asking each time? Add `"defaultMode": "acceptEdits"` inside `"permissions"` in `.claude/settings.json`.
</details>

**Check it worked:** `ls -la .claude/agents .claude/m6 scripts`. `.claude` is hidden, so Finder will not show it (press `Cmd+Shift+.`). You should see:
- 7 agents: `claude-sonnet-builder`, `claude-opus-builder`, `claude-sonnet-fixer`, `claude-haiku-builder`, `scout`, `sonnet-reviewer`, `opus-reviewer`.
- 3 files in `.claude/m6/`: `fix-ladders.md`, `drained-builders.md`, `worktree.md`.
- One executable script: `agy-run.sh`.

"No such file" means the terminal was not in the project folder: run `cd ` (with a space), drag the project folder into Terminal, press Enter, and run the command again.

## Step 5. Start Claude Code and check the agents
```
claude
```
Inside Claude Code, type `/agents`. You should see all 7 agents. Not there? Quit `claude`, start it again, and re-check Step 4. Then check the script can see its quota markers:
```
scripts/agy-run.sh --status
```
It should print `agy: 0 models limited`.

## Step 6. Run a test prompt
1. Open `module-6/test-prompt.md`.
2. Copy **Prompt A** (the Driftwood site) or **Prompt B** (the Orbit Catch game) into Claude Code, unchanged.
3. Watch for: a task plan table first, the design shell built by `claude-sonnet-builder` or `claude-opus-builder` (never by `agy`), builds on Argon launched together, a Sonnet review of each task, and a short final message. The main chat itself edits no files and reads no full diff.

## Approvals
The installer adds an allow-list to `.claude/settings.json`: the runner script, read-only git commands and the `.m6/` run folder. So a run does not stop to ask for each launch. It also blocks reading `.env` files. The installer also asks one question: may Claude edit files in this folder without asking each time? Yes sets `"defaultMode": "acceptEdits"` in that file (`--accept-edits` on Mac or `-AcceptEdits` on Windows answers yes up front); no leaves every edit asking as usual. Never add `--dangerously-skip-permissions`. Unverified: it is not confirmed that auto mode honors the allow rules.

## The run folder
Claude keeps its working files in `.m6/` in your project (hidden from git): `briefs/` (one brief per task), `logs/` (script scratch), `contract.md` (the shared names list on the Flash route), and `last-run.md` (the detailed record of the last run).

# Part 2: How it works

**The main chat stays clean on purpose.** Opus is the head chef who never touches a pan: it only plans and judges, and every line of code gets cooked in a sub-agent.

## The cast
| Who | Role |
|---|---|
| **Opus** (your Claude session) | The boss. Only plans and judges: launches sub-agents, reads their short reports, and never edits files, runs builds or reads a full diff. |
| **Argon** (`gemini-4-argon-medium`) | The builder. Default for bulk code, tests, refactors. Runs on Antigravity. |
| **Sonnet / Opus via agy** | Specialists for non-design builds. Sonnet for careful edits and docs. Opus for hard multi-file work. Small pools. |
| **Flash** (`gemini-3.8-flash-medium`) | The scout. Read-only: lookups, summaries, checks. Nearly unlimited. Builds small pieces too, but only on the Flash route. |
| **`scripts/agy-run.sh`** | The runner script. Sends one task to one Antigravity model, walks the fallback chain if a model is drained, and reports what changed. Design never goes through it. |
| **`claude-sonnet-builder`** | Design shells and first drafts (Sonnet high). Fix step 2 for work Argon, agy Sonnet or agy Opus built. |
| **`claude-opus-builder`** | Sensitive work (migrations, access policies, money and stock functions, auth, crypto) and the most important designs (Opus medium). Fix step 3 for agy-built work, and step 2 for Flash-built work. |
| **`claude-sonnet-fixer`** | Fix step 1 for Flash-built work (Sonnet medium). Fixes only. |
| **`sonnet-reviewer`** | Reads one task's diff of 400 changed lines or fewer. Returns PASS or FAIL. |
| **`opus-reviewer`** | Reads one task's diff of more than 400 changed lines (Opus medium). Returns PASS or FAIL. |
| **`claude-haiku-builder`** | Tiny, exactly described edits. In Module 3 mode: easy builds. |
| **`scout`** | Module 3 mode only: all read-only work. |

Everything in the Claude rows runs on your Claude plan. No Antigravity model ever reviews. Rare cases (fix steps, drained builders, worktrees) live in three rule files that Opus reads only when they apply.

## A build in 5 beats
```
 1 PLAN        Opus prints a task table first, before any work: id, model, owned files, after
      |
 2 WAVE 0      design shell alone, built by Claude (Sonnet high or Opus medium)
      |
 3 WAVE 1+     independent tasks run in parallel on Argon, one owner per file
      |
 4 SCOUTS      Flash checks links, leftovers, accessibility
      |
 5 REVIEW      Sonnet reviews small diffs, an Opus reviewer reads big ones; defects go back for fixing
```
- **One owner per file.** Two tasks never touch the same file in a wave.
- **Waves.** Each wave is reviewed fully before the next one starts.
- **Sensitive files go to `claude-opus-builder`** (Opus medium, on your Claude plan): database migrations, access policies, functions that move money or stock, auth and crypto. It is judged by layer: the screens, types and labels of the same feature are ordinary builds.
- **Tiny edits go to `claude-haiku-builder`.** Opus itself never edits, not even a one-liner. Unclear specs and architecture choices: Opus decides them in the plan, then delegates.
- **Design never goes to Antigravity.** Shells and first design drafts always go to a Claude builder.

## Who reviews
Opus counts the changed lines of the task (added plus removed, plus new files).

| Changed lines | Reviewer |
|---|---|
| 400 or fewer | `sonnet-reviewer` |
| More than 400 | `opus-reviewer` (Opus medium) |

Same rule for every builder, `claude-opus-builder` included. The main chat never reads the full diff, only the verdict. If a fix pushes a task over 400, the next review moves up to `opus-reviewer`.

## When a review fails
Up to 3 steps. Who fixes depends on who built it.

| Built by | Step 1 | Step 2 | Step 3 |
|---|---|---|---|
| Argon, agy Sonnet or agy Opus | the same model | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| Flash | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium) | record and continue |
| `claude-sonnet-builder` (design) | the same agent | `claude-opus-builder` | record and continue |
| `claude-opus-builder` (design or sensitive) | the same agent | record and continue | - |
| `claude-haiku-builder` (tiny edit) | the same agent | `claude-sonnet-builder` | `claude-opus-builder` |

- Original Antigravity model drained? Skip straight to the Claude steps.
- Flash never fixes and never reviews.
- Still failing after the last step? It goes in the final summary and the build keeps going.

## When quota runs out
- A drained model gets a marker file in `.claude/agy-quota/` (an end time and a reason). The script skips it until that time, or for 6 hours when the error gives no time. Delete a marker to clear it. `scripts/agy-run.sh --status` lists the active ones.
- The script moves a build to the next Antigravity builder itself, at most 2 times: Argon, then Sonnet, then Opus. Fix rounds never move to another model.
- **All three builders drained?** Opus stops, lets the running reviews finish, and asks you ONE question. It never switches on its own.
  - If the rest of the work can be cut into small pieces that Flash can build reliably (4 per task by default), it asks: **"a) switch to Flash, or b) switch to Module 3?"**
  - If not, it asks: **"wait for the reset, or switch to Module 3?"**
- **a) Flash route.** Every remaining task is cut into mini-tasks and Flash builds them all. Each task is reviewed ONCE, after all its mini-tasks are done, with the same 400-line rule on the combined diff. Fixes go to `claude-sonnet-fixer`, then `claude-opus-builder`.
- **b) Module 3 mode.** Claude builds the rest, with no Antigravity. Opus scores each task, then picks `claude-haiku-builder` (easy), `claude-sonnet-builder` (normal and design) or `claude-opus-builder` (hardest). Read-only work goes to `scout`. Reviews use the same 400-line rule.

# Part 3: Good to know

- **Parallel runs drain quota faster.** Several models spend your Google quota at once. Prefer fewer, bigger tasks.
- **Default caps:** 4 tasks total (argon 2, flash 3, agy sonnet 1, agy opus 1). A running script call counts against its model. Claude subagent runs count toward the total only. Edit the caps table in `CLAUDE.md`.
- **Design, sensitive builds, reviews and fixes use your Claude plan**, not Google quota. Watch your Claude usage too.
- **Review every diff.** File ownership is enforced by instructions, not the filesystem. Fallbacks can switch models mid-task. Headless `agy` cannot run shell commands, so it cannot run tests itself; the reviewers run the read-only checks.
- **Unverified:** whether `agy` allows concurrent sessions, the real quota error text, whether the `effort` setting in the Claude agent files is honored, and whether the runner script works on Windows (it is a bash script: Claude Code runs it through Git Bash, so install Git for Windows).
- **After a context reset** the main chat re-reads `CLAUDE.md` and the rule files it already used, re-prints the plan with each task's status, and keeps delegating. It never carries on inline.
- **Secrets stay out.** Copying, linking or reading `.env` files, keys or credentials makes Claude stop and ask, and sub-agents follow the same rule. Sub-agents may test migrations only on a local throwaway database.
- **A short summary always arrives** (at most 8 lines), even when all the work went to one sub-agent. The details are in `.m6/last-run.md`.
