# Setup for Module 10 Hydrogen builder (Claude Code + Antigravity)

You are setting up Module 10 Hydrogen builder (Claude Code + Antigravity) for a user who is not technical. Do the steps in order. Use plain, short sentences with the user. Run the commands yourself; do not ask the user to open a terminal unless a step says so. Setup is the one job you do yourself in this folder: do not build anything, do not start the user's project work, and do not read any `.env` file.

1. Check the place. `module-10/install.sh` must exist here. If not, or if the folder looks wrong (for example the home folder), stop and tell the user to put `module-10-files.zip` in their project folder, open Claude Code there and paste the line again.

2. Ask ONE plain question in the chat, no choice box, and wait: "While it works, Claude writes and changes files in this folder. Should it do that without asking you each time? Yes lets a run finish while you are away. No means you approve each change. You can change this later."

3. Run `bash module-10/install.sh --accept-edits` for yes or `bash module-10/install.sh --no-accept-edits` for no. If `bash` is not found, run `powershell -ExecutionPolicy Bypass -File module-10\install.ps1 -AcceptEdits` (or `-NoAcceptEdits`).

4. Read the output (lines start `ok:`, `skipped:` or `NOTE:`). Tell only what matters, plainly. Cases:
- "you already have your own" `CLAUDE.md`/`AGENTS.md` (saved as `CLAUDE.module-10.md`/`AGENTS.module-10.md`): the module does not work until its rules are in that file. Ask whether to put them at the top of their file, their text below; do it only on a yes.
- "not valid JSON" or "I need node or python3": approvals not merged. Show the lines in `.claude/settings.module-10.json` to add by hand (and `"defaultMode": "acceptEdits"` if they said yes).
- "git is not installed": reviews need git. Mac: `xcode-select --install`. Windows: Git for Windows (git-scm.com).
- "could not make the first commit": ask for a name and email, then run `git config user.name "<name>"` and `git config user.email "<email>"` (no `--global`) and `git add -A -- . ':(exclude,glob)**/.env*' && git commit -q -m start`.

5. Outside tools. For each tool below, run `command -v <tool>`. Missing: say in one sentence what it is, ask "May I install it?". Yes: run the install command. No: give them the command, go on. Still missing: suggest a restart. Installed: run its check, 20 second timeout. You cannot sign in for the user (it opens a browser): if the check fails, hangs or lacks the models, give them the terminal steps and go on.
- `agy`: Google's Antigravity, a builder. Needs a Google AI Pro plan. Install: Mac/Linux `curl -fsSL https://antigravity.google/cli/install.sh | bash`; Windows `powershell -c "irm https://antigravity.google/cli/install.ps1 | iex"`. Check: `agy models`, listing gemini-4-hydrogen-high, gemini-4-argon-medium, gemini-3.8-flash-high, gemini-3.8-flash-medium, claude-sonnet-5-5-medium, claude-opus-5-5-medium. Sign-in (user, in a terminal): `agy`, choose Google OAuth, sign in with the AI Pro account, quit, `agy models`.

6. Check. Run `scripts/agy-run.sh --status` (expect `agy: 0 models limited`). `ls .claude/agents | wc -l` (7+) and `ls .claude/m10 | wc -l` (5+). Report in one line.

7. Finish in at most 6 short lines: what is installed; what is left (sign-ins, rules to paste); START A NEW Claude Code session here (rules load at session start) and choose Opus; then they can paste a request or a test prompt from `module-10/test-prompt.md`; the `module-10` folder and zip can stay or go.

## Rules
- Never add `--dangerously-skip-permissions`, `--auto` or any flag that bypasses permissions.
- Never read, print or ask for `.env` files, keys, tokens or passwords.
- If a command fails twice, stop and show the user the exact error. Edit no project files beyond these steps.
