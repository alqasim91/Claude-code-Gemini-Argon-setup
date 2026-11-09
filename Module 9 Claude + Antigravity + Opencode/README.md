# Module 9: Claude plans, Antigravity Flash and OpenCode free models build, Argon takes the hard tasks

Claude Opus is the boss. It splits your request into phases and tasks and sends each task to the right pool:
- **Antigravity Flash** builds every task that splits into small, exact pieces. Flash has its own quota, so it never touches your Argon weekly limit.
- **OpenCode free models** take the same pieces when Flash runs dry, plus scouting, image/audio/large-context work, and tasks that are not hard but cannot be specced exactly.
- **Argon** (Antigravity) only takes hard tasks, and fixes Flash's work when a review fails.
- **Your Claude plan** does design, sensitive work, every review and the late fix steps.
- **Module 3** (Claude only) is the last fallback, only when you say so.

It combines Module 6 Flash builder and Module 8. Same rules as both: the main chat never implements, reviews by diff size (400 lines), "Phases", no decision boxes except one question when pools are drained.

# Part 1: Setup

Each step shows **Mac** (Terminal) and **Windows** (PowerShell). `opencode-run.sh` is a bash script: on Windows run Claude Code from Git Bash or WSL.

## Step 1. Your plans
- **Google AI Pro** for `agy` (Flash and Argon).
- **Claude Pro** for Claude Code (design, reviews, fixes).
- **OpenCode**: no plan needed. The free models are free, for a limited time.

## Step 2. Install and sign in to `agy`
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
Run `agy`, choose **Google OAuth**, sign in with your AI Pro account, quit, then run `agy models`. This module uses `gemini-3.8-flash-high`, `gemini-3.8-flash-medium`, `gemini-4-argon-medium` (agy Sonnet and agy Opus are not used).

## Step 3. Install OpenCode and check the models
**Mac**
```bash
curl -fsSL https://opencode.ai/install | bash   # or: npm i -g opencode-ai
opencode --version
```
**Windows (PowerShell)**
```powershell
npm i -g opencode-ai
opencode --version
```
Then `opencode models opencode`. The free ones end in `-free` (plus `big-pickle`). Built for these ten, checked 2026-11-04: `beam-free`, `big-pickle`, `crouton-alpha-free`, `deepseek-v4.1-flash-free`, `flint-40b-free`, `glm-5.3-flash-free`, `mimo-v2.6-flash-free`, `nemotron-3.5-lightning-free`, `nemotron-3.5-super-vl-free`, `pulse-alpha-free`. A model that disappeared makes its chain step fail: edit `chain_for` in the script and the chain table in `CLAUDE.md` together. The script uses `-m`, `--variant`, `--dir`, `--agent` and never `--auto`. Check that a read-only `plan` agent exists with `opencode agent list`; if not, edit `AGENT_READONLY` at the top of the script.

## Step 4. Copy the files into your project
Unzip `module-9-files.zip` **inside your project folder** (it creates a `module-9` folder), then open a terminal in the project folder.

You are copying: `CLAUDE.md` and `AGENTS.md` to the project root; 8 agent files to `.claude/agents/`; `scripts/opencode-run.sh` to `scripts/` (executable); two new quota folders, hidden from git.

**Mac**
```bash
mkdir -p .claude/agents .claude/agy-quota .claude/opencode-quota scripts
cp module-9/CLAUDE.md module-9/AGENTS.md .
cp module-9/agents/*.md .claude/agents/
cp module-9/scripts/opencode-run.sh scripts/
chmod +x scripts/opencode-run.sh
printf '.claude/agy-quota/\n.claude/opencode-quota/\n' >> .gitignore
```
Files already in the project root (`CLAUDE.md`, `AGENTS.md`, `agents/`, `scripts/` side by side, no `module-9` folder)?
```bash
mkdir -p .claude/agents .claude/agy-quota .claude/opencode-quota
mv agents/*.md .claude/agents/ && rmdir agents
chmod +x scripts/opencode-run.sh
printf '.claude/agy-quota/\n.claude/opencode-quota/\n' >> .gitignore
```
**Windows (PowerShell)**
```powershell
New-Item -ItemType Directory -Force .claude\agents, .claude\agy-quota, .claude\opencode-quota, scripts | Out-Null
Copy-Item module-9\CLAUDE.md, module-9\AGENTS.md .
Copy-Item module-9\agents\*.md .claude\agents\
Copy-Item module-9\scripts\opencode-run.sh scripts\
Add-Content .gitignore ".claude/agy-quota/"
Add-Content .gitignore ".claude/opencode-quota/"
```
Already have a `CLAUDE.md` or `AGENTS.md`? Do not overwrite it: paste the new text into your existing file. Both `agy` and `opencode` read `AGENTS.md`, which is how the free models get the rules.

**Check it worked:** `ls -la .claude/agents scripts`. You should see 8 agent files (`agy-delegate`, `claude-sonnet-builder`, `claude-opus-builder`, `claude-sonnet-fixer`, `claude-haiku-builder`, `scout`, `sonnet-reviewer`, `opus-reviewer`) and an executable `opencode-run.sh`.

## Step 5. Make sure the folder is a git repo
The review step reads `git diff`. Skip if you already use git: `git init && git add -A && git commit -m "start"`.

## Step 6. Start Claude Code and smoke-test
```
claude
```
`/agents` should list the 8 agents. Then check one model in each tool:
```
agy -p "Reply with the word ok" --model gemini-3.8-flash-high
opencode run -m opencode/deepseek-v4.1-flash-free --variant high "Reply with the word ok"
```
Then run a prompt from `module-9/test-prompt.md`.

## If Claude Code blocks the script
Optional allow rule in `.claude/settings.json`: `{"permissions":{"allow":["Bash(scripts/opencode-run.sh:*)"]}}`. Never add `--auto` or `--dangerously-skip-permissions`.

# Part 2: How it works

## Who builds what
| Task kind | First choice | If drained |
|---|---|---|
| Design shell, first design draft | Claude Sonnet high (Opus medium for key designs) | never waits |
| Sensitive files (migrations, access policies, money functions, auth, crypto) | Claude Opus medium | never waits |
| Tiny exact edit | Claude Haiku (or one Flash mini-task) | never waits |
| Read-only scouting | OpenCode `scout` | Flash scout |
| Splits into exact mini-tasks | **Flash high** | OpenCode `build` (silent) |
| Hard (D = 2, two 2s, or A = 2 with C = 2) | **Argon** | OpenCode `hard` (silent) |
| Not hard, cannot be specced exactly (docs, logic, tests) | OpenCode `build` | held |
| Images, audio/video, over 150k tokens | OpenCode `vision` / `av` / `large` | held |

## Quota is separate per pool
Flash, Argon and each OpenCode model have their own markers (`.claude/agy-quota/`, `.claude/opencode-quota/`). Flash use does not touch Argon. Argon is kept for hard tasks and Flash fixes so the weekly limit lasts.
- Check any time: `scripts/opencode-run.sh --status --role build`, and `find .claude/agy-quota -type f -mmin -360`.
- Delete a marker file to clear it by hand.
- agy reset times are unpublished: a marker under 6 hours old counts as drained (a guess).

## Caps (parallel tasks, all guesses)
4 total. Flash 3, OpenCode 3 (`hard` or `large` 1), Argon 1. Claude sub-agents count toward the total only. Opus lowers a cap when it sees a concurrency error or a shared free limit.

## What may go to which model
- Normal code: any pool.
- Code near auth or personal data (S = 1): OpenCode `--private` (only `deepseek-v4.1-flash-free` and `glm-5.3-flash-free`, which keep nothing and do not train), or Flash or Argon.
- Secrets, auth, crypto, payments (S = 2): never a free model. Claude builds it.
- A client's or employer's repo: `--private` on every OpenCode task including scouting. Gemini (Flash, Argon) is allowed, as in Module 6. If you do not want Gemini to see that code, say so in the prompt.

## Who reviews and fixes
| Diff size | Reviewer |
|---|---|
| 400 changed lines or fewer | `sonnet-reviewer` |
| more than 400 | `opus-reviewer` sub-agent |

One review per task (after all its mini-tasks). No Gemini or OpenCode model reviews.

| Built by | r1 | r2 | r3 | r4 |
|---|---|---|---|---|
| Flash | Argon medium | Sonnet medium | Opus medium | |
| OpenCode build/mech | same model | Argon medium | Sonnet high | Opus medium |
| Argon | same Argon | Sonnet high | Opus medium | |
| OpenCode hard/large/vision/av | same model | Sonnet high | Opus medium | |

A drained step is skipped. Still failing after the last step: recorded in the summary.

## Safety switches
Opus tallies first-review failures per pool (Flash, OpenCode). From the 3rd reviewed task, more than 1 in 3 failing trips that pool for the rest of the run. Flash tripped: its work goes to OpenCode. OpenCode tripped: splittable work goes to Flash, the rest to Argon medium. Both tripped: Argon medium, then the question below.

## When pools are drained
Fallbacks between pools are silent. A task is held only when every pool that may take it is drained. Opus then asks once: "Free pools are drained for <tasks>. Wait for the reset, or switch the held tasks to Module 3?" Nothing runs on Claude for build work until you answer. Module 3 mode is Claude only: scout, Haiku, Sonnet, Opus by the same scores, 400-line review rule.

# Part 3: Good to know
- **Relay cost:** Flash and Argon run through a Sonnet relay sub-agent (`agy-delegate`), which uses a little of your Claude plan per task. OpenCode runs straight from a script, with no relay. That is why scouting goes to OpenCode first.
- **No agy Sonnet or Opus.** Their pools are the smallest, so they are left out.
- **A non-hard task that cannot be specced is held when OpenCode `build` is drained**, rather than spending Argon. Edit Routing 7 in `CLAUDE.md` if you prefer Argon there.
- **Free models can say "done" and change nothing.** The script prints `changed lines (owned)`; 0 on a build task is a failure.
- **Edit the tables.** Routing, chains and caps live in `CLAUDE.md`; OpenCode chains also live in `chain_for` at the top of the script. Keep both in step.
- **Review every diff.** File ownership is enforced by instructions, not by the filesystem.
- **Known unknowns:** exact quota wording and reset times of both tools; whether `opencode run` exits non-zero on a limit; whether `--agent plan` is read-only; concurrency caps; free-model benchmarks are vendor-reported. Module 9 has not been run on the real CLIs yet; the OpenCode script was tested only against a stub.
