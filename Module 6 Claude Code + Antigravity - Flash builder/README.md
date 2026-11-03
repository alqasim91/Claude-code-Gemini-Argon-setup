# Module 6: Claude Code + Antigravity, Flash builder

**How this differs from plain Module 6:** Gemini Flash (high) builds first. Any task that splits into small, exact pieces goes to Flash, which saves the small Argon pool. Argon then builds only what can't be spelled out exactly, and it fixes Flash's work when a review fails.
Not sure which Module 6 to use? Pick this one if your Argon pool runs out fast. Pick plain Module 6 if you want Argon to do most of the building.

Claude Opus is the boss. It splits your request into tasks, and each task into small mini-tasks when it can write an exact spec for every piece. Builds go out through the Antigravity CLI (`agy`) and run at the same time. Design, reviews and the later fix steps stay on your Claude plan.

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
Make sure these five are in the list:
- `gemini-3.8-flash-high`
- `gemini-4-argon-medium`
- `gemini-3.8-flash-medium`
- `claude-sonnet-5-5-medium`
- `claude-opus-5-5-medium`

## Step 4. Copy the files into your project
Get the `module-6-flash` folder inside your project folder. Two ways: download `module-6-flash-files.zip` from this folder and unzip it into your project, or copy this folder (the one with this README) into your project and rename it `module-6-flash`. Then open a terminal in the project folder (the one that contains `module-6-flash`).

You are copying:
- `CLAUDE.md` and `AGENTS.md` to the project root.
- 7 agent files from `agents/` to `.claude/agents/`: `agy-delegate.md`, `claude-sonnet-builder.md`, `claude-opus-builder.md`, `claude-sonnet-fixer.md`, `claude-haiku-builder.md`, `scout.md` and `sonnet-reviewer.md`.
- A new `.claude/agy-quota/` folder, hidden from git.

**Mac**
```bash
mkdir -p .claude/agents .claude/agy-quota
cp module-6-flash/CLAUDE.md module-6-flash/AGENTS.md .
cp module-6-flash/agents/agy-delegate.md \
   module-6-flash/agents/claude-sonnet-builder.md \
   module-6-flash/agents/claude-opus-builder.md \
   module-6-flash/agents/claude-sonnet-fixer.md \
   module-6-flash/agents/claude-haiku-builder.md \
   module-6-flash/agents/scout.md \
   module-6-flash/agents/sonnet-reviewer.md \
   .claude/agents/
echo ".claude/agy-quota/" >> .gitignore
```
Files already sitting in the project root (not in a `module-6-flash` folder)? Use this instead:
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
Copy-Item module-6-flash\CLAUDE.md, module-6-flash\AGENTS.md .
Copy-Item -Destination .claude\agents\ -Path module-6-flash\agents\agy-delegate.md,
          module-6-flash\agents\claude-sonnet-builder.md,
          module-6-flash\agents\claude-opus-builder.md,
          module-6-flash\agents\claude-sonnet-fixer.md,
          module-6-flash\agents\claude-haiku-builder.md,
          module-6-flash\agents\scout.md,
          module-6-flash\agents\sonnet-reviewer.md
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
1. Open `module-6-flash/test-prompt.md`.
2. Copy **Prompt A** (the Driftwood site) or **Prompt B** (the Orbit Catch game) into Claude Code, unchanged.
3. Watch for: a task plan table first, the design shell built by `claude-sonnet-builder` or `claude-opus-builder` (never by `agy`), page and script tasks split into Flash-high mini-tasks launched together, ONE Sonnet review per task (after all its mini-tasks), and a final per-wave table.

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
| **Flash high** (`gemini-3.8-flash-high`) | The first-choice builder. Gets small mini-tasks with an exact spec (files, names, markup, a check to run). Nearly unlimited. Never fixes or reviews. |
| **Argon** (`gemini-4-argon-medium`) | Builds what Opus can't spec exactly (medium; high only for hard tasks). Also the first fixer of Flash's work. Small pool. |
| **Sonnet / Opus via agy** | Specialists for non-design builds. Sonnet for careful edits and docs. Opus for hard multi-file work. Small pools. |
| **Flash scout** (`gemini-3.8-flash-medium`) | Read-only: lookups, summaries, checks. Nearly unlimited. |
| **`agy-delegate`** | The relay. Sends one task or mini-task to one Antigravity model and reports what changed. It refuses design. |
| **`claude-sonnet-builder`** | Design shells and first drafts (Sonnet high). Fix step 2 for work Argon, agy Sonnet or agy Opus built. |
| **`claude-opus-builder`** | The most important designs (Opus medium). Fix step 3 for agy-built and Flash-built work. |
| **`claude-sonnet-fixer`** | Fix step 2 for Flash-built work (Sonnet medium), step 1 if Argon is drained. Fixes only. |
| **`sonnet-reviewer`** | Reads one task's diff of 400 changed lines or fewer. Returns PASS or FAIL. |
| **`claude-haiku-builder`** and **`scout`** | Module 3 mode only: easy builds, and all read-only work. |

Everything in the Claude rows runs on your Claude plan. No Antigravity model ever reviews.

## A build in 5 beats
```
 1 PLAN        Opus prints a task table: id, model, owned files, after
      |
 2 WAVE 0      design shell alone, built by Claude (Sonnet high or Opus medium)
      |
 3 WAVE 1+     tasks run in parallel: Flash-high mini-tasks when Opus can spec them
               exactly, Argon when it can't. One owner per file
      |
 4 SCOUTS      Flash checks links, leftovers, accessibility
      |
 5 REVIEW      once per task, after all its mini-tasks: Sonnet reviews small diffs,
               Opus reads big ones; defects go back for fixing
```
- **One owner per file.** Two tasks never touch the same file in a wave. Mini-tasks on the same file run one after another.
- **Flash first.** While planning, Opus checks every non-design build task: can I write an exact spec for each small piece? Yes (4 mini-tasks by default, more if needed) means Flash high, with no question to you. No means Argon.
- **Waves.** Each wave is reviewed fully before the next one starts.
- **Opus keeps** security-sensitive work, auth and secrets, and quick jobs (under about 5 minutes).
- **Design never goes to Antigravity** (not Flash, not Argon). Shells and first design drafts always go to a Claude builder.

## Who reviews
Opus counts the changed lines of the task (added plus removed, plus new files). A task built from mini-tasks is reviewed ONCE, after all its mini-tasks finish, on the combined diff, never per mini-task.

| Changed lines | Reviewer |
|---|---|
| 400 or fewer | `sonnet-reviewer` |
| More than 400 | Opus reads the diff itself |

Same rule for every builder. Flash never reviews. If a fix pushes a task over 400, the next review moves up to Opus.

## When a review fails
Up to 3 steps. Who fixes depends on who built it.

| Built by | Step 1 | Step 2 | Step 3 |
|---|---|---|---|
| Flash | Argon medium (`gemini-4-argon-medium`) | `claude-sonnet-fixer` (Sonnet medium) | `claude-opus-builder` (Opus medium) |
| Argon, agy Sonnet or agy Opus | the same model | `claude-sonnet-builder` (Sonnet high) | `claude-opus-builder` (Opus medium) |
| `claude-sonnet-builder` (design) | the same agent | `claude-opus-builder` | record and continue |
| `claude-opus-builder` (design) | the same agent | record and continue | - |

- Original Antigravity model drained (for Flash-built work: Argon drained)? Skip straight to the Claude steps.
- Flash never fixes and never reviews. Argon gets the whole task's diff and the defect list, and fixes the whole task.
- Still failing after the last step? It goes in the final summary and the build keeps going.

## The Flash safety switch
Opus keeps score. From the 3rd reviewed Flash-built task on, if more than 1 in 3 failed their first review, Opus stops sending new tasks to Flash for the rest of that run. Those tasks go to Argon instead, and Opus says so in the plan and the final summary.

## When quota runs out
- A drained model gets a marker file in `.claude/agy-quota/`. Opus skips it for 6 hours. Delete a marker to clear it.
- A non-Flash build moves to the next Antigravity builder: Argon, then Sonnet, then Opus.
- **Argon, Sonnet and Opus all drained?** Flash keeps building everything that can be split into exact mini-tasks. Tasks that can't be split are held, and Opus asks you ONE question: **"wait for the reset, or switch to Module 3?"** It never switches on its own.
- **Flash drained on a build?** Opus stops and asks: **"Flash is drained. Wait for the reset, or switch to Module 3?"**
- **Module 3 mode.** Claude builds the rest, with no Antigravity. Opus scores each task, then picks `claude-haiku-builder` (easy), `claude-sonnet-builder` (normal and design) or `claude-opus-builder` (hardest). Read-only work goes to `scout`. Reviews use the same 400-line rule.

# Part 3: Good to know

- **Parallel runs drain quota faster.** Several models spend your Google quota at once. Prefer fewer, bigger tasks.
- **Default caps:** 4 tasks total (argon 2, flash 3, agy sonnet 1, agy opus 1). Claude subagent runs count toward the total only. Edit the caps table in `CLAUDE.md`.
- **Flash high saves Argon.** Most of the building runs on the nearly unlimited Flash pool. Argon spends quota only on tasks that can't be split and on fixing Flash's mistakes.
- **Design, reviews and the Sonnet and Opus fix steps use your Claude plan**, not Google quota. Watch your Claude usage too.
- **Review every diff.** File ownership is enforced by instructions, not the filesystem. Fallbacks can switch models mid-task.
- **Unverified:** whether `agy` allows concurrent sessions, the real quota error text, whether the `effort` setting in the Claude agent files is honored, whether accept-edits lets models run shell commands, and whether the shell-and-`/tmp` flow works on Windows (likely needs Git Bash).
