# Module 6: Claude plans, Antigravity models build in parallel

Claude Opus is the boss. It splits your request into tasks and sends them out to other models through the Antigravity CLI (`agy`). Independent tasks run at the same time.

# Part 1: Setup

Do the steps in order. Each step shows **Mac** (Terminal) and **Windows** (PowerShell).

## Step 1. Get Google AI Pro
Subscribe to Google AI Pro with the Google account you will use for `agy`. Your models run on this plan.

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
Get the `module-6` folder inside your project folder: unzip `module-6-files.zip`, or copy the `modules/module-6` folder from this repo and keep the name `module-6`. Then open a terminal in the project folder (the one that contains `module-6`).

You are copying:
- `CLAUDE.md` and `AGENTS.md` to the project root.
- `agents/agy-delegate.md` and `agents/claude-opus-fixer.md` to `.claude/agents/`.
- A new `.claude/agy-quota/` folder, hidden from git.

**Mac**
```bash
mkdir -p .claude/agents .claude/agy-quota
cp module-6/CLAUDE.md module-6/AGENTS.md .
cp module-6/agents/agy-delegate.md module-6/agents/claude-opus-fixer.md .claude/agents/
echo ".claude/agy-quota/" >> .gitignore
```
Files already sitting in the project root (not in a `module-6` folder)? Use this instead:
```bash
mkdir -p .claude/agents .claude/agy-quota
mv agy-delegate.md claude-opus-fixer.md .claude/agents/
echo ".claude/agy-quota/" >> .gitignore
```
**Check it worked.** No output means success. `.claude` is hidden, so Finder won't show it (press `Cmd+Shift+.` to show hidden files). Confirm in Terminal:
```bash
ls -la .claude/agents
```
You should see `agy-delegate.md` and `claude-opus-fixer.md`. "No such file" means the terminal was not in the project folder: run `cd ` (with a space), drag the project folder into Terminal, press Enter, and run the commands again.

**Windows (PowerShell)**
```powershell
New-Item -ItemType Directory -Force .claude\agents, .claude\agy-quota | Out-Null
Copy-Item module-6\CLAUDE.md, module-6\AGENTS.md .
Copy-Item module-6\agents\agy-delegate.md, module-6\agents\claude-opus-fixer.md .claude\agents\
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
You should see `agy-delegate` and `claude-opus-fixer`. Not there? Quit `claude`, start it again, and re-check Step 4.

## Step 7. Run a test prompt
1. Open `module-6/test-prompt.md`.
2. Copy **Prompt A** (the Driftwood site) or **Prompt B** (the Orbit Catch game) into Claude Code, unchanged.
3. Watch for: a task plan table first, design work on Sonnet or Opus (never Gemini), tasks launched together, and a final per-wave table.

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
| **Opus** (your Claude session) | The boss. Plans, routes, reviews every diff. |
| **Argon** (`gemini-4-argon-medium`) | The builder. Default for bulk code, tests, refactors. Biggest quota. |
| **Sonnet / Opus via agy** | Designers and specialists. Sonnet for design and careful edits. Opus for hard multi-file work. |
| **Flash** (`gemini-3.8-flash-medium`) | The scout. Read-only: lookups, summaries, checks. |
| **`claude-opus-fixer`** | Last-resort fixer. Runs on your Claude plan, not Google quota. |

## A build in 5 beats
```
 1 PLAN        Opus prints a task table: id, model, owned files, after
      |
 2 WAVE 0      design shell alone (Sonnet high or Opus medium)
      |
 3 WAVE 1+     independent tasks run in parallel, one owner per file
      |
 4 SCOUTS      Flash checks links, leftovers, accessibility
      |
 5 REVIEW      Opus reads every diff; defects go back for fixing
```
- **One owner per file.** Two tasks never touch the same file in a wave.
- **Waves.** Each wave is reviewed fully before the next one starts.
- **Opus keeps** security-sensitive work, auth and secrets, and quick jobs (under about 5 minutes).

## When a review fails
1. **Round 1:** same model fixes it.
2. **Round 2:** agy Opus medium, no fallback.
3. **Round 3:** `claude-opus-fixer` on your Claude plan. Only when agy Opus is drained or already ran the task.

Still failing after the last round? It goes in the final summary and the build keeps going.

## When quota runs out
- A drained model gets a marker file in `.claude/agy-quota/`. Opus skips it for 6 hours.
- The task moves to the next model: Argon, then Sonnet, then Opus. Design tasks swap between Sonnet high and Opus medium only. Delete a marker to clear it.

# Part 3: Good to know

- **Parallel runs drain quota faster.** Several models spend your Google quota at once. Prefer fewer, bigger tasks.
- **Default caps:** 4 tasks total (argon 2, flash 3, sonnet 1, opus 1). Edit the caps table in `CLAUDE.md`.
- **Round-3 fixes use your Claude plan**, not Google quota.
- **Review every diff.** File ownership is enforced by instructions, not the filesystem. Fallbacks can switch models mid-task.
- **Unverified:** whether `agy` allows concurrent sessions, the real quota error text, whether `effort: medium` in `claude-opus-fixer` is honored, whether accept-edits lets models run shell commands, and whether the shell-and-`/tmp` flow works on Windows (likely needs Git Bash).
