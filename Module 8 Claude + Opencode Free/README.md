# Module 8: Claude plans, OpenCode free models build in parallel

Claude Opus is the boss. It splits your request into phases and tasks, and runs them on the free OpenCode models through the OpenCode CLI (`opencode run -m opencode/<model>`). Independent tasks run at the same time. Claude does design, security, late fixes and reviews. When one free model hits its limit, the script moves to the next model in line by itself. Module 3 is the last fallback.

Same shape as Module 7 (Codex): Opus runs `scripts/opencode-run.sh` itself in the background, no relay subagent per task. The difference: ten free models instead of one paid pool, so the script keeps a quota marker per model and a fallback chain per kind of work.

# Part 1: Setup

Each step shows **Mac** (Terminal) and **Windows** (PowerShell).

## Step 1. Install OpenCode
**Mac**
```bash
curl -fsSL https://opencode.ai/install | bash
# or: npm i -g opencode-ai
opencode --version
```
**Windows (PowerShell)**
```powershell
npm i -g opencode-ai
opencode --version
```
Command not found? Close the terminal, open a new one. `opencode-run.sh` is a bash script: on Windows run Claude Code from Git Bash or WSL.

## Step 2. List your free models
```
opencode models opencode
```
The free ones end in `-free` (plus `big-pickle`). This module is built for these ten, checked 2026-11-04: `beam-free`, `big-pickle`, `crouton-alpha-free`, `deepseek-v4.1-flash-free`, `flint-40b-free`, `glm-5.3-flash-free`, `mimo-v2.6-flash-free`, `nemotron-3.5-lightning-free`, `nemotron-3.5-super-vl-free`, `pulse-alpha-free`. The free list is "limited time" and changes. A model that disappeared makes its chain step fail: edit `chain_for` in the script and the chain table in `CLAUDE.md`.

For the effort variants and context sizes of one model: `opencode models opencode --verbose`.

## Step 3. Check the flags
```
opencode run --help
```
This module uses `-m`, `--variant`, `--dir`, `--agent`. They are confirmed on your install (2026-11-04). It never uses `--auto`. One flag is still unverified: the script runs read-only scouting with `--agent plan`. Check with `opencode agent list` that a read-only `plan` agent exists. If not, edit `AGENT_READONLY` at the top of the script.

## Step 4. Copy the files into your project
Unzip `module-8-files.zip` **inside your project folder**. It creates a `module-8` folder there. Open a terminal in the project folder (the one that now contains `module-8`).

You are copying:
- `CLAUDE.md` and `AGENTS.md` to the project root.
- `agents/*.md` (5 files) to `.claude/agents/`.
- `scripts/opencode-run.sh` to `scripts/`, made executable.
- A new `.claude/opencode-quota/` folder, hidden from git.

**Mac**
```bash
mkdir -p .claude/agents .claude/opencode-quota scripts
cp module-8/CLAUDE.md module-8/AGENTS.md .
cp module-8/agents/*.md .claude/agents/
cp module-8/scripts/opencode-run.sh scripts/
chmod +x scripts/opencode-run.sh
echo ".claude/opencode-quota/" >> .gitignore
```
Files already sitting in the project root (`CLAUDE.md`, `AGENTS.md`, `agents/`, `scripts/` next to each other, no `module-8` folder)? Use this instead. It moves the agents into `.claude/agents/` and removes the empty `agents` folder:
```bash
mkdir -p .claude/agents .claude/opencode-quota
mv agents/*.md .claude/agents/ && rmdir agents
chmod +x scripts/opencode-run.sh
echo ".claude/opencode-quota/" >> .gitignore
```
**Check it worked.** In Terminal: `ls -la .claude/agents scripts`. You should see `claude-sonnet-builder.md`, `claude-opus-builder.md`, `claude-haiku-builder.md`, `sonnet-reviewer.md`, `scout.md` and an executable `opencode-run.sh`.

**Windows (PowerShell)**
```powershell
New-Item -ItemType Directory -Force .claude\agents, .claude\opencode-quota, scripts | Out-Null
Copy-Item module-8\CLAUDE.md, module-8\AGENTS.md .
Copy-Item module-8\agents\*.md .claude\agents\
Copy-Item module-8\scripts\opencode-run.sh scripts\
Add-Content .gitignore ".claude/opencode-quota/"
```
Files already in the project root (no `module-8` folder)? Use this instead:
```powershell
New-Item -ItemType Directory -Force .claude\agents, .claude\opencode-quota | Out-Null
Move-Item agents\*.md .claude\agents\
Remove-Item agents
Add-Content .gitignore ".claude/opencode-quota/"
```
Already have a `CLAUDE.md` or `AGENTS.md`? Do not overwrite it. Paste the new text into your existing file instead. OpenCode reads `AGENTS.md` too, which is how the free models get the rules.

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
Type `/agents`. You should see `claude-sonnet-builder`, `claude-opus-builder`, `claude-haiku-builder`, `sonnet-reviewer` and `scout`.

## Step 7. Smoke test one model
Before a big run, check one free model works headless:
```
opencode run -m opencode/deepseek-v4.1-flash-free --variant high "Reply with the word ok"
```
You should see `ok`. Then run the test prompt in `module-8/test-prompt.md`.

## If Claude Code blocks the script
Optional: add an allow rule to `.claude/settings.json`.
```json
{
  "permissions": {
    "allow": ["Bash(scripts/opencode-run.sh:*)"]
  }
}
```
If a free model stalls waiting for a permission, allow that specific tool in `opencode.json`. Do not add `--auto`.

# Part 2: How it works

## The cast
| Who | Role |
|---|---|
| **Opus** (your Claude session) | The boss. Plans, routes, reviews the big diffs. Never builds bulk work. |
| **deepseek-v4.1-flash-free** | Default builder (high). Zero retention. |
| **glm-5.3-flash-free** | Second builder, screenshots. Zero retention. |
| **beam-free** | Hard and large-context builds (high). |
| **big-pickle** | Late fallback. Hidden model, no published specs. |
| **flint-40b-free** | Fast scoped edits, tests, boilerplate. |
| **nemotron-3.5-lightning-free** | Scouting and formatting. |
| **nemotron-3.5-super-vl-free** | Image reading, big-context fallback. |
| **mimo-v2.6-flash-free** | Audio or video input only. |
| **pulse-alpha-free, crouton-alpha-free** | Alpha test models. Last in the chains. |
| **`claude-sonnet-builder`** | Design shells and first drafts. Security. Fix round 3. |
| **`claude-opus-builder`** | The most important designs. Fix round 4. |
| **`claude-haiku-builder`, `scout`** | Module 3 mode only. |
| **`sonnet-reviewer`** | Reads one task's diff, returns PASS or FAIL. Read-only. |

**Why Claude reviews and fixes:** free models are below Claude Sonnet at coding, and the scores are vendor-reported. So the free models build the volume, and Claude checks it.

**Design never goes to a free model.** Design shells and first drafts go to Sonnet (high), or Opus (medium) for the most important ones.

## Roles and fallback chains
Opus picks a role per task. The script walks that role's chain.

| Role | Chain, in order |
|---|---|
| `scout` | nemotron-lightning, flint low, glm low, deepseek low |
| `mech` | flint medium, nemotron-lightning, deepseek low, glm low |
| `build` | deepseek high, glm high, flint high, beam medium, big-pickle, pulse-alpha, crouton-alpha |
| `hard` | beam high, deepseek max, glm max, big-pickle, pulse-alpha, crouton-alpha |
| `large` | beam high, nemotron-super-vl, crouton-alpha |
| `vision` | glm high, nemotron-super-vl, pulse-alpha, crouton-alpha |
| `av` | mimo, glm (video), crouton-alpha |

## What may go to which model
Only `glm-5.3-flash-free` and `deepseek-v4.1-flash-free` have a zero-retention, no-training policy. The others may train on your prompts or log them (Beam keeps data 30 days, the NVIDIA models log, Big Pickle, MiMo, Flint and Pulse train). So:
- Normal code: any chain.
- Code near auth, personal data or private business logic (S = 1): Opus adds `--private`, which keeps only deepseek and glm.
- Secrets, auth, crypto, payments (S = 2): never a free model. Claude builds it.
- Private code (a client's or employer's): Opus adds `--private` to every free-model task, including `scout`.

## How tasks are distributed
Opus scores every build task from 0 to 2 on seven dimensions (from Module 3): Ambiguity, Novelty, Coupling, Reversibility, Sensitivity, Verifiability, Diagnosis. Then the first match wins:
0. Read-only: `scout`. No review.
1. Design shell or first draft: Claude Sonnet (Opus for key designs).
2. S = 2: Claude Sonnet builds from an Opus spec.
3. Hard (D = 2, two or more 2s, A = 2 and C = 2): `hard`.
4. Special input: images `vision`, audio/video `av`, over about 150k tokens `large`.
5. Easy (A, R, S, V, D all 0, total 2 or less, complete spec, tool-checkable): `mech`.
6. Otherwise: `build`.

Small job rule: 2 or fewer build tasks and no S = 2 or D = 2 means one `build` task, no phases.

Free models get tighter briefs than Claude would: exact file names, function names and a check command. Opus logs one line per task in `TASKS.md`.

## A build in 5 beats
```
 1 PLAN        Opus prints a task table: id, phase, route, score, owned files, after
      |
 2 PHASE 0     foundation alone (design shell, styles, schema), built by Claude
      |
 3 PHASE 1+    tasks run in parallel on free models, one owner per file
      |
 4 REVIEW      each phase is reviewed and fixed before the next starts
      |
 5 SUMMARY     one table: phase, task, score, route, model that ran, chain walk, reviewer, rounds, result
```

## Who reviews
| Implementer | Reviewer |
|---|---|
| any free model, diff of 400 changed lines or fewer | `sonnet-reviewer` |
| any free model over 400 lines, or the `hard` role | Opus reads the diff itself |
| Tasks routed by S = 2 or the hard rule | Opus reads the diff itself |
| Claude builders (design, security) | Opus reads the diff itself |

If more than 1 in 3 free-built tasks fail their first review, the rest of the run goes to Claude Sonnet.

## When a review fails (up to 4 rounds)
| Implementer | Round 1 | Round 2 | Round 3 | Round 4 |
|---|---|---|---|---|
| free model (not `hard`) | same model | `hard` role | `claude-sonnet-builder` | `claude-opus-builder` |
| `hard` role | same model | `claude-sonnet-builder` | `claude-opus-builder` | record and continue |
| Claude builders | same agent | `claude-opus-builder` | record and continue | |

Tasks on `vision`, `av` or `large` skip the `hard` role: round 2 is `claude-sonnet-builder`, round 3 `claude-opus-builder` (the hard chain cannot read images or audio).

## When a free model runs out
- **One model limited:** the script writes `.claude/opencode-quota/<model-id>` (`until=`, `reason=`), skips that model, and moves to the next in the chain. Opus does nothing. The report's `chain walk:` line shows it.
- **Whole chain drained** (exit 3): Opus lets running tasks finish, then asks: "Free models for <role> are drained (earliest back <time>). Wait or switch the remaining tasks to Module 3 mode now?" Nothing runs on Claude for build work until you say Module 3.
- Check any time: `scripts/opencode-run.sh --status --role build`. It lists limited models with the time left and exits 3 only if the whole chain is drained.
- Delete a marker file to clear it by hand.
- **Module 3 mode** (only when you say Module 3) is Claude only, routed by the same scores: Opus-trigger tasks to `claude-opus-builder`, read-only to `scout`, easy to `claude-haiku-builder`, the rest to `claude-sonnet-builder`. Sonnet reviews up to 400 lines, Opus above.

# Part 3: Good to know

- **Free limits are IP-level and unpublished.** Default cap: 3 free tasks at once, 1 `hard` or `large`. If a report says limits hit on 3 or more models in one run, Opus lowers the cap by 1.
- **Claude-plan work** (design, security, fix rounds 3 and 4, Module 3 mode) uses your Claude plan.
- **A free model can say "done" and change nothing.** Opus checks `changed lines (owned)` and the review catches the rest.
- **Edit the tables.** Chains and routing live in `CLAUDE.md` and in `chain_for` at the top of the script. Keep both in step.
- **Review every diff.** File ownership is enforced by instructions, not the filesystem.
- **Known unknowns:**
  - Exact rate-limit wording of the free plan is unverified. The script matches `rate limit`, `429`, `quota`, `usage limit`, `too many requests` and similar, prints the raw line, and uses a 1-hour wait if no reset time is found.
  - Whether `opencode run` exits non-zero on a limit is unverified. On exit 0 the script counts a limit only if a short log has a limit word on an `error` line and the owned files gained no changed lines, so a normal answer that mentions a rate limiter is not a limit.
  - Models that are unavailable (model not found, blocked in your country, not supported) are marked for 24 hours and skipped like a limit. Free models change often and Beam and Pulse are blocked in some countries.
  - Each model run has a timeout (`RUN_TIMEOUT`, default 1800 seconds, 0 = off; needs `timeout`, or `gtimeout` on macOS). A timeout is reported as exit 1 with the last log lines, often a permission prompt nobody answered.
  - Whether `--agent plan` is read-only on your install.
  - Concurrency caps are guesses.
  - Benchmarks for these models are vendor-reported. Pulse Alpha and Crouton Alpha have no public information.
  - Tested only against a stub `opencode` so far, not the real CLI.
  - Windows needs Git Bash or WSL for the script.
