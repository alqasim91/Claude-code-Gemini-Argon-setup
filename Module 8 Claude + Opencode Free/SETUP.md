# Setup for Module 8 (Claude + OpenCode free models)

You are setting up Module 8 (Claude + OpenCode free models) for a user who is not technical. Do the steps in order. Use plain, short sentences with the user. Run the commands yourself; do not ask the user to open a terminal unless a step says so. Setup is the one job you do yourself in this folder: do not build anything, do not start the user's project work, and do not read any `.env` file.

1. Check the place. `module-8/install.sh` must exist here. If not, or if the folder looks wrong (for example the home folder), stop and tell the user to put `module-8-files.zip` in their project folder, open Claude Code there and paste the line again.

2. Ask ONE plain question in the chat, no choice box, and wait: "While it works, Claude writes and changes files in this folder. Should it do that without asking you each time? Yes lets a run finish while you are away. No means you approve each change. You can change this later."

3. Run `bash module-8/install.sh --accept-edits` for yes or `bash module-8/install.sh --no-accept-edits` for no. If `bash` is not found, run `powershell -ExecutionPolicy Bypass -File module-8\install.ps1 -AcceptEdits` (or `-NoAcceptEdits`).

4. Read the output (lines start `ok:`, `skipped:` or `NOTE:`). Tell only what matters, plainly. Cases:
- "you already have your own" `CLAUDE.md`/`AGENTS.md` (saved as `CLAUDE.module-8.md`/`AGENTS.module-8.md`): the module does not work until its rules are in that file. Ask whether to put them at the top of their file, their text below; do it only on a yes.
- "not valid JSON" or "I need node or python3": approvals not merged. Show the lines in `.claude/settings.module-8.json` to add by hand (and `"defaultMode": "acceptEdits"` if they said yes).
- "git is not installed": reviews need git. Mac: `xcode-select --install`. Windows: Git for Windows (git-scm.com).
- "could not make the first commit": ask for a name and email, then run `git config user.name "<name>"` and `git config user.email "<email>"` (no `--global`) and `git add -A -- . ':(exclude,glob)**/.env*' && git commit -q -m start`.

5. Outside tools. For each tool below, run `command -v <tool>`. Missing: say in one sentence what it is, ask "May I install it?". Yes: run the install command. No: give them the command, go on. Still missing: suggest a restart. Installed: run its check, 20 second timeout. You cannot sign in for the user (it opens a browser): if the check fails, hangs or lacks the models, give them the terminal steps and go on.
- `opencode`: OpenCode, builds with free models. Install: `curl -fsSL https://opencode.ai/install | bash` (Mac/Linux) or `npm i -g opencode-ai` (any). Check: `opencode models opencode`. Then `opencode run -m opencode/deepseek-v4.1-flash-free --variant high "Reply with the word ok"` should print `ok`. No sign-in.

6. Check. Run `scripts/opencode-run.sh --status --role build` (expect `role build: 0 of 7 models limited`). `ls .claude/agents | wc -l` (5+) and `ls .claude/m8 | wc -l` (4+). Report in one line.

7. Finish in at most 6 short lines: what is installed; what is left (sign-ins, rules to paste); START A NEW Claude Code session here (rules load at session start) and choose Opus; then they can paste a request or a test prompt from `module-8/test-prompt.md`; the `module-8` folder and zip can stay or go.

## Rules
- Never add `--dangerously-skip-permissions`, `--auto` or any flag that bypasses permissions.
- Never read, print or ask for `.env` files, keys, tokens or passwords.
- If a command fails twice, stop and show the user the exact error. Edit no project files beyond these steps.
