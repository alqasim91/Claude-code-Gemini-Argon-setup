# Module 3: Claude-only orchestration (Opus · Sonnet · Haiku)

Opus plans and scores. Haiku scouts and does simple edits. Sonnet builds the normal work and reviews normal tasks. Opus builds only the hardest tasks and reviews the large or sensitive ones. An Opus fixer takes over after repeated failures. Everything runs inside your Claude Pro plan. No other subscription is needed.

Tuned for Pro limits: the 5-hour and weekly limits are shared with claude.ai.

## What's in the zip

```
Module-3/
├── CLAUDE.md              ← the orchestrator's rules (routing, scoring, review loop)
└── agents/
    ├── scout.md           ← Haiku · read-only search and research
    ├── haiku-implementer.md ← Haiku · simple, fully specified edits
    ├── implementer.md     ← Sonnet · default builder
    ├── opus-implementer.md ← Opus · hard diagnosis, security, architecture
    ├── reviewer.md        ← Sonnet · default reviewer
    ├── opus-reviewer.md   ← Opus · reviews large/sensitive tasks
    └── fixer.md           ← Opus · takes over after failed reviews
```

## What you need

- A Claude Pro plan (or higher)
- The Claude Code desktop app, or the Claude Code CLI
- The files in this folder, downloaded from GitHub (or `module-3-files.zip`, unzipped)

## Setup (Mac and Windows)

1. **Create the project folder.** Any name, anywhere. Example: `my-app`.
2. **Paste the files in the project folder.** Get the files from this folder on GitHub (or unzip `module-3-files.zip` and open `Module-3`). Copy the two items, `CLAUDE.md` and the `agents` folder, into `my-app`.
3. **Open a terminal in the folder.**
   - Mac: right-click `my-app` > **New Terminal at Folder**. (If missing: System Settings > Keyboard > Keyboard Shortcuts > Services.)
   - Windows: open `my-app` in File Explorer, click the address bar, type `powershell` and press Enter.
4. **Paste this command** and press Enter. It moves `agents` into the hidden `.claude` folder where Claude Code looks for it.
   - Mac:
     ```
     mkdir -p .claude && mv agents .claude/agents
     ```
   - Windows (PowerShell):
     ```
     New-Item -ItemType Directory -Force .claude | Out-Null; Move-Item agents .claude\agents
     ```

Result:

```
my-app/
├── CLAUDE.md
└── .claude/agents/   ← the seven agent files
```

5. **Start Claude Code in `my-app`.** Desktop app: **New session**, then pick the folder. CLI: type `claude` in the same terminal (Windows CLI needs Git for Windows).
6. **Choose Opus** in the model picker. The main chat must be Opus: it is the orchestrator.
7. **Test it:**

```
Add a README.md to this project with a one-paragraph description.
```

Opus should post a plan with a score and route per task, delegate, then report PASS or FAIL after a review. In the CLI, `/agents` lists all seven agents.

Don't rename any file: the agent names in `CLAUDE.md` must match the file names.

---

## How it behaves

1. **Plan.** Opus sends `scout` (Haiku) to look things up, then splits your request into tasks, grouped in waves. Shared foundations go first. Then independent tasks run in parallel, up to four at a time.
2. **Small jobs.** 2 tasks or fewer, nothing sensitive: one Sonnet build, one Sonnet review.
3. **Score.** Each task gets 0-2 on seven dimensions (ambiguity, novelty, coupling, reversibility, sensitivity, verifiability, diagnosis).
4. **Route.** Simple and checkable goes to Haiku. Normal work goes to Sonnet. Hard or sensitive work goes to Opus.
5. **Review.** Sonnet `reviewer` checks normal tasks. `opus-reviewer` checks large (over 5 files or ~400 lines), sensitive or Opus-built tasks.
6. **Fix.** One fix round by Sonnet, then `fixer` (Opus). After three failed reviews it stops and asks you.
7. **Log.** Each task is recorded in `TASKS.md` so you can tune the routing later.

## Saving Pro quota

- Send `/clear` between unrelated pieces of work.
- Small jobs skip the full pipeline automatically. Each extra agent costs 45-80k tokens of setup.
- If you hit the 5-hour limit, wait for the reset. Weekly limits are shared with claude.ai chats.

## Troubleshooting

- **Opus writes code itself.** The main chat is not reading `CLAUDE.md`. Check it sits in the project root, then start a new session.
- **`/agents` shows nothing.** The files are not in `.claude/agents/`. Re-run the step 4 command from inside `my-app`.
- **Can't see `.claude`.** Hidden folder. Mac: Cmd+Shift+. in Finder. Windows: File Explorer > View > Show > Hidden items.
- **Everything runs on Opus.** Make sure the model picker was set before the session started, and each agent file keeps its `model:` line.
