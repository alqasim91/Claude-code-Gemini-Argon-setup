# Module 7: Claude plans, Codex models build in parallel

Claude Opus is the boss. It splits your request into phases and tasks, and runs them on OpenAI Codex models through the Codex CLI (`codex exec`), signed in with your ChatGPT plan. Independent tasks run at the same time. Claude does design, security, fixes and reviews.

What changed from Module 6: `agy` is replaced by Codex. There is no relay subagent per task any more. Opus runs `scripts/codex-run.sh` itself in the background. In Module 6 each relay subagent paid about 50k tokens just to start, so removing it is the main cost saving.

# Part 1: Setup

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

## Step 4. Copy the files into your project
Unzip `module-7-files.zip` so the `module-7` folder sits **inside your project folder**. Open a terminal in the project folder.

You are copying:
- `CLAUDE.md` and `AGENTS.md` to the project root.
- `agents/*.md` (3 files) to `.claude/agents/`.
- `scripts/codex-run.sh` to `scripts/`, made executable.
- A new `.claude/codex-quota/` folder, hidden from git.

**Mac**
```bash
mkdir -p .claude/agents .claude/codex-quota scripts
cp module-7/CLAUDE.md module-7/AGENTS.md .
cp module-7/agents/*.md .claude/agents/
cp module-7/scripts/codex-run.sh scripts/
chmod +x scripts/codex-run.sh
echo ".claude/codex-quota/" >> .gitignore
```
**Check it worked.** `.claude` is hidden in Finder (`Cmd+Shift+.` shows it). In Terminal:
```bash
ls -la .claude/agents scripts
```
You should see `claude-sonnet-builder.md`, `claude-opus-builder.md`, `sonnet-reviewer.md` and an executable `codex-run.sh`. "No such file" means the terminal was not in the project folder.

**Windows (PowerShell)**
```powershell
New-Item -ItemType Directory -Force .claude\agents, .claude\codex-quota, scripts | Out-Null
Copy-Item module-7\CLAUDE.md, module-7\AGENTS.md .
Copy-Item module-7\agents\*.md .claude\agents\
Copy-Item module-7\scripts\codex-run.sh scripts\
Add-Content .gitignore ".claude/codex-quota/"
```
Already have a `CLAUDE.md` or `AGENTS.md`? Do not overwrite it. Paste the new text into your existing file instead.

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
Type `/agents`. You should see `claude-sonnet-builder`, `claude-opus-builder` and `sonnet-reviewer`. Not there? Quit, start again, re-check Step 4.

## Step 7. Run the test prompt
Open `module-7/test-prompt.md`, copy the prompt into Claude Code unchanged. Then use its "What to check" list.

## If Claude Code blocks the script
Optional: add an allow rule to `.claude/settings.json`.
```json
{
  "permissions": {
    "allow": ["Bash(scripts/codex-run.sh:*)"]
  }
}
```
The script never bypasses the Codex sandbox or approvals. Do not add flags that do.

# Part 2: How it works

## The cast
| Who | Role |
|---|---|
| **Opus** (your Claude session) | The boss. Plans, routes, reviews the big diffs. Never builds bulk work. |
| **sol** (`gpt-6.1-sol`) | Default builder (medium). Hard multi-file or tricky logic (high). |
| **terra** (`gpt-6.1-terra`) | Docs, copy, content pages. |
| **luna** (`gpt-6-luna`) | Scout (low). Tests, formatting, boilerplate, mechanical edits (medium). |
| **`claude-sonnet-builder`** | Design shells and first drafts. Security, auth, secrets. Fix rounds. Fallback. |
| **`claude-opus-builder`** | The most important designs. Round-3 fixes for Sol tasks. |
| **`sonnet-reviewer`** | Reads one task's diff, returns PASS or FAIL. Read-only. |

Model IDs are from learn.chatgpt.com/docs/models, checked 2026-10-29. Astra (`gpt-6-astra`) is deliberately not used.

**Why Claude reviews and fixes:** third-party benchmarks (vals.ai, benchlm.ai) put both Sol and Terra below Claude Sonnet 5.5 at coding. So Codex builds the volume, and Claude checks it.

**Design never goes to a Codex model.** Design shells and first drafts go to Sonnet (high), or Opus (medium) for the most important ones.

## How tasks are distributed
| Task type | Goes to |
|---|---|
| Small job (~1 file, under ~5 minutes) | One sol-medium run, no phases |
| Design shell or first design draft | `claude-sonnet-builder` (`claude-opus-builder` for key designs) |
| Scouting, lookups, read-only | luna-low |
| Tests, formatting, boilerplate, mechanical edits | luna-medium |
| Docs, copy, content pages | terra-medium |
| Standard implementation (default) | sol-medium |
| Hard: multi-file or tricky logic | sol-high |
| Security, auth, secrets, unclear spec | Opus writes the spec, `claude-sonnet-builder` builds |

## A build in 5 beats
```
 1 PLAN        Opus prints a task table: id, phase, model, owned files, after
      |
 2 PHASE 0     foundation alone (design shell, styles, schema), built by Claude
      |
 3 PHASE 1+    tasks run in parallel on Codex, one owner per file
      |
 4 REVIEW      each phase is reviewed and fixed before the next starts
      |
 5 SUMMARY     one table: phase, task, model, fallbacks, reviewer, rounds, result
```
- **Phases.** If your prompt is not phased, Opus phases it. Phase 0 is the foundation. Each later phase builds on the previous one. A multi-step phase is split into parallel tasks on separate files. A single-step phase is one job.
- **One owner per file.** Two tasks never touch the same file in a phase.
- **Worktree mode** (optional, off by default) gives each task its own git worktree and a `codex/<task>` branch, for work that cannot be split into separate files.

## Who reviews
| Implementer | Reviewer |
|---|---|
| luna or terra | `sonnet-reviewer` |
| sol medium, diff of 400 changed lines or fewer | `sonnet-reviewer` |
| sol medium over 400 lines, or sol high | Opus reads the diff itself |
| Claude builders (design, security) | Opus reads the diff itself |

Opus never spawns a separate Opus reviewer. In the Module 3 cost test, fresh Opus reviewers were 23% of the bill and changed nothing.

## When a review fails (up to 3 rounds)
| Implementer | Round 1 | Round 2 | Round 3 |
|---|---|---|---|
| sol | same model | `claude-sonnet-builder` | `claude-opus-builder` |
| luna or terra | same model | sol high | `claude-sonnet-builder` |
| Claude builders | same agent | `claude-opus-builder` | record and continue |

Still failing after round 3? It goes in the final summary and the build keeps going.

## When quota runs out
- A drained model gets a marker file in `.claude/codex-quota/`. Opus skips it for 6 hours.
- The task moves down the chain: luna, terra, sol, then Claude. Terra goes to sol, then Claude. Sol goes straight to Claude. When the script prints `drained: <chain>` and exits 3, Opus uses `claude-sonnet-builder` for that task.
- A hard (sol-high) task is never downgraded to luna or terra. Fix rounds never fall back.
- Delete a marker to clear it.

# Part 3: Good to know

- **Parallel runs drain quota faster.** Prefer fewer, bigger tasks.
- **Default caps:** 3 tasks at once (sol 2, terra 2, luna 3). Claude builder runs count toward the total only. Edit the table in `CLAUDE.md`.
- **Claude-plan work** (design, security, fix rounds 2 and 3, fallback) uses your Claude plan, not ChatGPT quota.
- **Edit the tables.** Routing, caps, ladders and the model pool live in `CLAUDE.md`. Model IDs and flags also live at the top of `scripts/codex-run.sh`. Keep both in step.
- **Review every diff.** File ownership is enforced by instructions, not the filesystem.
- **Known unknowns:**
  - The `codex exec` flags come from third-party docs. Verify with `codex exec --help` on first run.
  - Codex concurrency limits and plan limits are unpublished. The caps are guesses.
  - The 6-hour marker window is a guess.
  - ChatGPT plan limits may be shared across all Codex models. If so, every Codex model drains together and the work goes to Claude.
  - The real quota and concurrency error wording is unconfirmed. The script matches on guessed keywords.
  - Whether `effort: medium` and `effort: high` in the agent files are honored is unverified.
  - Windows needs Git Bash or WSL for the script.
