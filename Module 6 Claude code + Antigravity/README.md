# Module 6: Claude plans, Antigravity builds, your Claude plan designs, reviews and fixes

Claude Opus is the boss. It splits your request into tasks. Builds go out to Argon and friends through the Antigravity CLI (`agy`) and run at the same time. Design, reviews and fixes stay on your Claude plan, so your small Google pools last longer.

# Part 1: Setup

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

## Step 4. Copy the files into your project
Get the `module-6` folder inside your project folder: unzip `module-6-files.zip`, or copy this folder (the one with this README) into your project and rename it `module-6`. Then open a terminal in the project folder (the one that contains `module-6`).

You are copying:
- `CLAUDE.md` and `AGENTS.md` to the project root.
- 7 agent files from `agents/` to `.claude/agents/`: `agy-delegate.md`, `claude-sonnet-builder.md`, `claude-opus-builder.md`, `claude-sonnet-fixer.md`, `claude-haiku-builder.md`, `scout.md` and `sonnet-reviewer.md`.
- A new `.claude/agy-quota/` folder, hidden from git.

**Mac**
```bash
mkdir -p .claude/agents .claude/agy-quota
cp module-6/CLAUDE.md module-6/AGENTS.md .
cp module-6/agents/agy-delegate.md \
   module-6/agents/claude-sonnet-builder.md \
   module-6/agents/claude-opus-builder.md \
   module-6/agents/claude-sonnet-fixer.md \
   module-6/agents/claude-haiku-builder.md \
   module-6/agents/scout.md \
   module-6/agents/sonnet-reviewer.md \
   .claude/agents/
echo ".claude/agy-quota/" >> .gitignore
```
Files already sitting in the project root (not in a `module-6` folder)? Use this instead:
```bash
mkdir -p .claude/agents .claude/agy-quota
mv agy-delegate.md claude-sonnet-builder.md claude-opus-builder.md claude-sonnet-fixer.md claude-haiku-builder.md scout.md sonnet-reviewer.md .claude/agents/
echo ".claude/agy-quota/" >> .gitignore
```
**Check it worked.** No output means success. `.claude` is hidden, so Finder won't show it (press `Cmd+Shift+.` to show hidden files). Confirm in Terminal:
```bash
ls -la .claude/agents
```
You should see all 7 files: `agy-delegate.md`, `claude-sonnet-builder.md`, `claude-opus-builder.md`, `claude-sonnet-fixer.md`, `claude-haiku-builder.md`, `scout.md` and `sonnet-reviewer.md`. "No such file" means the terminal was not in the project folder: run `cd ` (with a space), drag the project folder into Terminal, press Enter, and run the commands again.

**Windows (PowerShell)**
```powershell
New-Item -ItemType Directory -Force .claude\agents, .claude\agy-quota | Out-Null
Copy-Item module-6\CLAUDE.md, module-6\AGENTS.md .
Copy-Item -Destination .claude\agents\ -Path module-6\agents\agy-delegate.md,
          module-6\agents\claude-sonnet-builder.md,
          module-6\agents\claude-opus-builder.md,
          module-6\agents\claude-sonnet-fixer.md,
          module-6\agents\claude-haiku-builder.md,
          module-6\agents\scout.md,
          module-6\agents\sonnet-reviewer.md
Add-Content .gitignore ".claude/agy-quota/"
```
Already have a `CLAUDE.md` or `AGENTS.md`? Do not overwrite it. Paste the new text into your existing file instead.

## Step 5. Make sure the folder is a git repo
The review step reads `git diff`, so you need git. Skip this step if your project already uses git.

Same on Mac and Windows:
```
git init
git add -A
git commit -m "start"
```

## Step 6. Start Claude Code and check the agents
```
claude
```
Inside Claude Code, type:
```
/agents
```
You should see all 7: `agy-delegate`, `claude-sonnet-builder`, `claude-opus-builder`, `claude-sonnet-fixer`, `claude-haiku-builder`, `scout` and `sonnet-reviewer`. Not there? Quit `claude`, start it again, and re-check Step 4.

## Step 7. Run a test prompt
1. Open `module-6/test-prompt.md`.
2. Copy **Prompt A** (the Driftwood site) or **Prompt B** (the Orbit Catch game) into Claude Code, unchanged.
3. Watch for: a task plan table first, the design shell built by `claude-sonnet-builder` or `claude-opus-builder` (never by `agy`), builds on Argon launched together, a Sonnet review of each task, and a final per-wave table.

## If Claude Code blocks the agy command
Optional: add an allow rule to `.claude/settings.json`.
```json
{
  "permissions": {
    "allow": ["Bash(agy -p:*)"]
  }
}
```
Unverified: it is not confirmed that auto mode honors this rule.

# Part 2: How it works

## The cast
| Who | Role |
|---|---|
| **Opus** (your Claude session) | The boss. Plans, routes, and reads the big diffs (over 400 changed lines). |
| **Argon** (`gemini-4-argon-medium`) | The builder. Default for bulk code, tests, refactors. Runs on Antigravity. |
| **Sonnet / Opus via agy** | Specialists for non-design builds. Sonnet for careful edits and docs. Opus for hard multi-file work. Small pools. |
| **Flash** (`gemini-3.8-flash-medium`) | The scout. Read-only: lookups, summaries, checks. Nearly unlimited. Builds small pieces too, but only on the Flash route. |
| **`agy-delegate`** | The relay. Sends one task to one Antigravity model and reports what changed. It refuses design. |
| **`claude-sonnet-builder`** | Design shells and first drafts (Sonnet high). Fix step 2 for work Argon, agy Sonnet or agy Opus built. |
| **`claude-opus-builder`** | The most important designs (Opus medium). Fix step 3 for agy-built work, and step 2 for Flash-built work. |
| **`claude-sonnet-fixer`** | Fix step 1 for Flash-built work (Sonnet medium). Fixes only. |
| **`sonnet-reviewer`** | Reads one task's diff of 400 changed lines or fewer. Returns PASS or FAIL. |
| **`claude-haiku-builder`** and **`scout`** | Module 3 mode only: easy builds, and all read-only work. |

Everything in the Claude rows runs on your Claude plan. No Antigravity model ever reviews.

## A build in 5 beats
```
 1 PLAN        Opus prints a task table: id, model, owned files, after
      |
 2 WAVE 0      design shell alone, built by Claude (Sonnet high or Opus medium)
      |
 3 WAVE 1+     independent tasks run in parallel on Argon, one owner per file
      |
 4 SCOUTS      Flash checks links, leftovers, accessibility
      |
 5 REVIEW      Sonnet reviews small diffs, Opus reads big ones; defects go back for fixing
```
- **One owner per file.** Two tasks never touch the same file in a wave.
- **Waves.** Each wave is reviewed fully before the next one starts.
- **Opus keeps** security-sensitive work, auth and secrets, and quick jobs (under about 5 minutes).
- **Design never goes to Antigravity.** Shells and first design drafts always go to a Claude builder.

## Who reviews
Opus counts the changed lines of the task (added plus removed, plus new files).

| Changed lines | Reviewer |
|---|---|
| 400 or fewer | `sonnet-reviewer` |
| More than 400 | Opus reads the diff itself |

Same rule for every builder. If a fix pushes a task over 400, the next review moves up to Opus.

## When a review fails
Up to 3 steps. Who fixes depends on who built it.

| Built by | Step 1 | Step 2 | Step 3 |
|---|---|---|---|
| Argon, agy Sonnet or agy Opus | the same model | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| Flash | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium) | record and continue |
| `claude-sonnet-builder` (design) | the same agent | `claude-opus-builder` | record and continue |
| `claude-opus-builder` (design) | the same agent | record and continue | - |

- Original Antigravity model drained? Skip straight to the Claude steps.
- Flash never fixes and never reviews.
- Still failing after the last step? It goes in the final summary and the build keeps going.

## When quota runs out
- A drained model gets a marker file in `.claude/agy-quota/`. Opus skips it for 6 hours. Delete a marker to clear it.
- A build moves to the next Antigravity builder: Argon, then Sonnet, then Opus.
- **All three builders drained?** Opus stops, finishes reviewing what is running, and asks you ONE question. It never switches on its own.
  - If the rest of the work can be cut into small pieces that Flash can build reliably (4 per task by default), it asks: **"a) switch to Flash, or b) switch to Module 3?"**
  - If not, it asks: **"wait for the reset, or switch to Module 3?"**
- **a) Flash route.** Every remaining task is cut into mini-tasks and Flash builds them all. Opus reviews each task ONCE, after all its mini-tasks are done, with the same 400-line rule on the combined diff. Fixes go to `claude-sonnet-fixer`, then `claude-opus-builder`.
- **b) Module 3 mode.** Claude builds the rest, with no Antigravity. Opus scores each task, then picks `claude-haiku-builder` (easy), `claude-sonnet-builder` (normal and design) or `claude-opus-builder` (hardest). Read-only work goes to `scout`. Reviews use the same 400-line rule.

# Part 3: Good to know

- **Parallel runs drain quota faster.** Several models spend your Google quota at once. Prefer fewer, bigger tasks.
- **Default caps:** 4 tasks total (argon 2, flash 3, agy sonnet 1, agy opus 1). Claude subagent runs count toward the total only. Edit the caps table in `CLAUDE.md`.
- **Design, reviews and fixes use your Claude plan**, not Google quota. Watch your Claude usage too.
- **Review every diff.** File ownership is enforced by instructions, not the filesystem. Fallbacks can switch models mid-task.
- **Unverified:** whether `agy` allows concurrent sessions, the real quota error text, whether the `effort` setting in the Claude agent files is honored, whether accept-edits lets models run shell commands, and whether the shell-and-`/tmp` flow works on Windows (likely needs Git Bash).
