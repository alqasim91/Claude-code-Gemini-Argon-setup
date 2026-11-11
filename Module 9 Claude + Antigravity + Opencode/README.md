# Module 9: Claude plans, Antigravity Flash and OpenCode free models build, Argon takes the hard tasks

Claude Opus is the boss. It splits your request into phases and tasks and sends each task to the right pool:
- **Antigravity Flash** builds every task that splits into small, exact pieces. Flash has its own quota, so it never touches your Argon weekly limit.
- **OpenCode free models** take the same pieces when Flash runs dry, plus scouting, image/audio/large-context work, and tasks that are not hard but cannot be specced exactly.
- **Argon** (Antigravity) only takes hard tasks, and fix rounds. **agy Sonnet and agy Opus** take fix rounds only.
- **Your Claude plan** does design, sensitive work, every review, and fix steps when agy Sonnet or Opus is drained.
- **Module 3** (Claude only) is the last fallback, only when you say so.

Flash, Argon, agy Sonnet and agy Opus run through `scripts/agy-run.sh`, straight from a script, with no helper agent in between. OpenCode runs the same way through `scripts/opencode-run.sh`. So launching an outside model costs no Claude usage.

It combines Module 6 Flash builder and Module 8. Same rules as both: the main chat never implements, reviews by diff size (800 lines), "Phases", no decision boxes except one question when pools are drained.

# Part 1: Setup

Short on time? Skip to Step 4 (Install the files): Claude Code can do most of this for you.

Each step shows **Mac** (Terminal) and **Windows** (PowerShell).

**Windows note:** the two runner scripts are bash scripts. Claude Code on Windows needs Git for Windows and runs its commands through Git Bash, so this normally works. If the scripts do not start, run Claude Code from Git Bash or WSL.

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
Run `agy`, choose **Google OAuth**, sign in with your AI Pro account, quit, then run `agy models`. This module uses `gemini-3.8-flash-high`, `gemini-3.8-flash-medium`, `gemini-4-argon-medium`, `claude-sonnet-5-5-medium`, `claude-opus-5-5-medium` (the last two for fix rounds only).

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
Then `opencode models opencode`. The free ones end in `-free` (plus `big-pickle`). Built for these ten, checked 2026-11-04: `beam-free`, `big-pickle`, `crouton-alpha-free`, `deepseek-v4.1-flash-free`, `flint-40b-free`, `glm-5.3-flash-free`, `mimo-v2.6-flash-free`, `nemotron-3.5-lightning-free`, `nemotron-3.5-super-vl-free`, `pulse-alpha-free`. You do not need to keep this list up to date: the script asks OpenCode which free models exist at run time. The script uses `-m`, `--variant`, `--dir`, `--agent` and never `--auto`. Check that a read-only `plan` agent exists with `opencode agent list`; if not, edit `AGENT_READONLY` at the top of the script.

## Step 4. Install the files (one command)

**Easiest: let Claude Code set it up**

1. Put `module-9-files.zip` in your project folder.
2. Open the Claude desktop app. Click **New session** and pick your project folder.
3. Paste this line:
   ```
   Unzip module-9-files.zip in this folder, then read module-9/SETUP.md and follow it.
   ```

Claude Code unzips the files, asks you one question (may it edit files without asking each time), installs the module, checks the outside tools and tells you what is left. It will ask your approval for the first one or two commands; that is normal, the approvals list does not exist yet. Signing in to `agy` stays with you, because it opens a browser. OpenCode needs no sign-in. When it finishes, start a new session and choose Opus.

**Or run the installer yourself**

Unzip `module-9-files.zip` **inside your project folder** (it creates a `module-9` folder). Open a terminal in the project folder. Run one command.

**Mac**
```bash
bash module-9/install.sh
```
**Windows (PowerShell)**
```powershell
powershell -ExecutionPolicy Bypass -File module-9\install.ps1
```
It prints one line per step. Running it again is safe: it changes nothing the second time.

The installer asks one question: may Claude edit files in this folder without asking each time? Answer `y` for runs you can leave alone, or `n` to approve each edit yourself. To answer yes up front, add `--accept-edits` to the Mac command or `-AcceptEdits` to the Windows command. You can change it later in `.claude/settings.json`.

**What it does**
- Copies the 7 agents to `.claude/agents/` and the rule files to `.claude/m9/`.
- Copies `scripts/agy-run.sh` and `scripts/opencode-run.sh` and makes them runnable.
- Copies `CLAUDE.md` and `AGENTS.md`. If you already have your own, it does not overwrite them: it saves the new text as `CLAUDE.module-9.md` and tells you to paste it in. An older Module 9 copy is backed up and replaced.
- Adds the approvals list to `.claude/settings.json` (merged, your other settings stay).
- Asks the one edit question described above and, only if you say yes, sets `"defaultMode": "acceptEdits"` in that file.
- Adds three lines to `.gitignore`.
- Starts git and makes a first commit if the folder has none. It never touches your `.env` files.
- Checks that `agy` and `opencode` are installed and tells you how to get them if not.

Both `agy` and `opencode` read `AGENTS.md`, which is how the other models get the rules.

<details>
<summary>Manual install (only if you prefer to copy by hand)</summary>

**Mac**
```bash
mkdir -p .claude/agents .claude/m9 .claude/agy-quota .claude/opencode-quota scripts
cp module-9/CLAUDE.md module-9/AGENTS.md .
cp module-9/agents/*.md .claude/agents/
cp module-9/rules/*.md .claude/m9/
cp module-9/scripts/agy-run.sh module-9/scripts/opencode-run.sh scripts/
chmod +x scripts/agy-run.sh scripts/opencode-run.sh
cp module-9/settings.json .claude/settings.json
printf '.claude/agy-quota/\n.claude/opencode-quota/\n.m9/\n' >> .gitignore
git init && git add -A && git commit -m "start"
```
**Windows (PowerShell)**
```powershell
New-Item -ItemType Directory -Force .claude\agents, .claude\m9, .claude\agy-quota, .claude\opencode-quota, scripts | Out-Null
Copy-Item module-9\CLAUDE.md, module-9\AGENTS.md .
Copy-Item module-9\agents\*.md .claude\agents\
Copy-Item module-9\rules\*.md .claude\m9\
Copy-Item module-9\scripts\agy-run.sh, module-9\scripts\opencode-run.sh scripts\
Copy-Item module-9\settings.json .claude\settings.json
Add-Content .gitignore ".claude/agy-quota/", ".claude/opencode-quota/", ".m9/"
```
Already have a `CLAUDE.md`, `AGENTS.md` or `.claude/settings.json`? Do not overwrite them: paste the new text into your file. Not using git yet? The review step reads `git diff`, so run `git init && git add -A && git commit -m "start"` once.
Want Claude to edit files here without asking each time? Add `"defaultMode": "acceptEdits"` inside `"permissions"` in `.claude/settings.json`.
</details>

**Check it worked:** `ls -la .claude/agents .claude/m9 scripts`. You should see:
- 7 agents: `claude-sonnet-builder`, `claude-opus-builder`, `claude-sonnet-fixer`, `claude-haiku-builder`, `scout`, `sonnet-reviewer`, `opus-reviewer`.
- 5 files in `.claude/m9/`.
- Two executable scripts: `agy-run.sh` and `opencode-run.sh`.

## Step 5. Start Claude Code and smoke-test
```
claude
```
`/agents` should list the 7 agents. Choose Opus. Then check one model in each tool:
```
agy -p "Reply with the word ok" --model gemini-3.8-flash-high
opencode run -m opencode/deepseek-v4.1-flash-free --variant high "Reply with the word ok"
```
Then check the scripts can see their quota markers:
```
scripts/agy-run.sh --status
scripts/opencode-run.sh --status --role build
```
Then run a prompt from `module-9/test-prompt.md`.

## Approvals
The installer adds an allow-list to `.claude/settings.json`: the two runner scripts, read-only git commands and the `.m9/` run folder. So a run does not stop to ask for each launch. It also blocks reading `.env` files. The installer also asks one question: may Claude edit files in this folder without asking each time? Yes sets `"defaultMode": "acceptEdits"` in that file (`--accept-edits` on Mac or `-AcceptEdits` on Windows answers yes up front); no leaves every edit asking as usual. Never add `--auto` or `--dangerously-skip-permissions`.

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
| A failed review | see the fix table below: OpenCode, Argon, agy Sonnet, agy Opus | Claude Sonnet / Opus of the same tier (silent) |
| Not hard, cannot be specced exactly (docs, logic, tests) | OpenCode `build` | held |
| Images, audio/video, over 150k tokens | OpenCode `vision` / `av` / `large` | held |

## Quota is separate per pool
Flash, Argon, agy Sonnet, agy Opus and each OpenCode model have their own markers (`.claude/agy-quota/`, `.claude/opencode-quota/`). Flash use does not touch Argon. Argon is kept for hard tasks and fixes so the weekly limit lasts.
- Check any time: `scripts/agy-run.sh --status` and `scripts/opencode-run.sh --status --role build`.
- Delete a marker file to clear it by hand.
- An agy marker holds a reset time. If the tool gives none, the script uses 6 hours from now (a guess).

## OpenCode models
The script asks OpenCode which free models exist right now. It skips ones that were removed and tries brand-new free ones last (never for private code). You no longer edit the model list by hand when a model disappears. The preferred order lives in `chain_for` at the top of the script, for people who want to change it.

A free model that hangs for 30 minutes is skipped and the next one is tried. Two hangs in a row stop the task.

## Caps (parallel tasks, all guesses)
4 total. Flash 3, OpenCode 3 (`hard` or `large` 1), Argon 1, agy Sonnet 1, agy Opus 1. Claude sub-agents count toward the total only. Opus lowers a cap when it sees a concurrency error or a shared free limit.

## What may go to which model
- Normal code: any pool.
- Code near auth or personal data (S = 1): OpenCode `--private` (only `deepseek-v4.1-flash-free` and `glm-5.3-flash-free`, which keep nothing and do not train), or Flash or Argon.
- Secrets, auth, crypto, payments (S = 2): never a free model. Claude builds it.
- A client's or employer's repo: `--private` on every OpenCode task including scouting. Gemini (Flash, Argon) is allowed, as in Module 6. If you do not want Gemini to see that code, say so in the prompt.

## Who reviews and fixes
| Diff size | Reviewer |
|---|---|
| 800 changed lines or fewer | `sonnet-reviewer` |
| more than 800 | `opus-reviewer` sub-agent |
| any size, hard-routed (Argon, OpenCode `hard`) or sensitive | `opus-reviewer` |

One review per task (after all its mini-tasks). No agy or OpenCode model reviews, because a reviewer must not edit.

| Built by | r1 | r2 | r3 | r4 |
|---|---|---|---|---|
| Flash | OpenCode `hard` | Argon medium | agy Sonnet | agy Opus |
| OpenCode build/mech | same model | Argon medium | agy Sonnet | agy Opus |
| Argon | same Argon | agy Sonnet | agy Opus | |
| OpenCode hard | same model | agy Sonnet | agy Opus | |
| OpenCode large/vision/av | same model | Claude Sonnet | Claude Opus | |

A drained agy Sonnet or Opus step is replaced by Claude Sonnet or Opus of the same tier. A drained Argon or OpenCode step is skipped. Design, sensitive and tiny-edit fixes stay on Claude. Still failing after the last step: recorded in the summary.

## Safety switches
Opus tallies first-review failures per pool (Flash, OpenCode). From the 3rd reviewed task, more than 1 in 3 failing trips that pool for the rest of the run. Flash tripped: its work goes to OpenCode. OpenCode tripped: splittable work goes to Flash, the rest to Argon medium. Both tripped: Argon medium, then the question below.

## When pools are drained
Fallbacks between pools are silent. A task is held only when every pool that may take it is drained. Opus then asks once: "Free pools are drained for <tasks>. Wait for the reset, or switch the held tasks to Module 3?" Nothing runs on Claude for build work until you answer. Module 3 mode is Claude only: scout, Haiku, Sonnet, Opus by the same scores, 800-line review rule.

# Part 3: Good to know
- **No relay.** All outside models are launched by scripts. The main chat only reads their short reports.
- **Run folder.** `.m9/` holds briefs, logs, the shared contract (`contract.md`), the task log (`TASKS.md`) and the detailed table of the last run (`last-run.md`). It is git-ignored and safe to delete between runs.
- **The final message is short.** A few plain lines. Details are in `.m9/last-run.md`.
- **Rule files.** Rarely needed rules live in `.claude/m9/`. Opus reads them only when needed, which keeps every message cheaper.
- **agy Sonnet and Opus are fix-only.** They never build first, review or design, so their small pools are spent only when a review failed.
- **A non-hard task that cannot be specced is held when OpenCode `build` is drained**, rather than spending Argon. Edit Routing 7 in `CLAUDE.md` if you prefer Argon there.
- **agy runs have no shell.** Headless `agy` (`--mode accept-edits`) edits files but denies shell commands, so Flash, Argon, agy Sonnet and Opus can't run tests. The reviewer runs the safe, read-only checks.
- **Free models can say "done" and change nothing.** The script prints `changed lines (owned)`; 0 on a build task is a failure.
- **Edit the tables.** Routing and caps live in `CLAUDE.md`. The preferred order of the free models lives in `chain_for` at the top of `scripts/opencode-run.sh`.
- **Review every diff.** File ownership is enforced by instructions, not by the filesystem.
- **Known unknowns:** there has been one real run so far (a landing-site test, all tasks passed, only Flash and Claude Sonnet took part). The OpenCode route, Argon, the fix ladders and the drained-pool paths have not been run on the real tools. The scripts were tested against stand-in tools. Exact quota wording and reset times, whether `opencode run` exits non-zero on a limit, whether `--agent plan` is read-only, concurrency caps, and free-model benchmarks (vendor-reported) are also unconfirmed.
