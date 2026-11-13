# Setup for Module 11 (Claude + Antigravity Hydrogen + OpenCode)

You are setting up Module 11 (Claude + Antigravity Hydrogen + OpenCode) for a user who is not technical. Do the steps in order. Use plain, short sentences with the user. Run the commands yourself; do not ask the user to open a terminal unless a step says so. Setup is the one job you do yourself in this folder: do not build anything, do not start the user's project work, and do not read any `.env` file.

1. Check the place. `module-11/install.sh` must exist here. If not, or if the folder looks wrong (for example the home folder), stop and tell the user to put `module-11-files.zip` in their project folder, open a new session of the Claude desktop app on that folder and paste the line again.

2. Ask ONE plain question in the chat, no choice box, and wait: "While it works, Claude writes and changes files in this folder. Should it do that without asking you each time? Yes lets a run finish while you are away. No means you approve each change. You can change this later."

3. Run `bash module-11/install.sh --accept-edits` for yes or `bash module-11/install.sh --no-accept-edits` for no. If `bash` is not found, run `powershell -ExecutionPolicy Bypass -File module-11\install.ps1 -AcceptEdits` (or `-NoAcceptEdits`).

4. Read the output (lines start `ok:`, `skipped:` or `NOTE:`). Tell only what matters, plainly. Cases:
- "you already have your own" `CLAUDE.md`/`AGENTS.md` (saved as `CLAUDE.module-11.md`/`AGENTS.module-11.md`): the module does not work until its rules are in that file. Ask whether to put them at the top of their file, their text below; do it only on a yes.
- "not valid JSON" or "I need node or python3": approvals not merged. Show the lines in `.claude/settings.module-11.json` to add by hand (and `"defaultMode": "acceptEdits"` if they said yes).
- "git is not installed": reviews need git. Mac: `xcode-select --install`. Windows: Git for Windows (git-scm.com).
- "could not make the first commit": ask for a name and email, then run `git config user.name "<name>"` and `git config user.email "<email>"` (no `--global`) and `git add -A -- . ':(exclude,glob)**/.env*' && git commit -q -m start`.

5. Outside tools. For each tool below, run `command -v <tool>`. Missing: say in one sentence what it is, ask "May I install it?". Yes: run the install command. No: give them the command, go on. Still missing: suggest a restart. Installed: run its check, 20 second timeout. You cannot sign in for the user: if the check fails, hangs or lacks the models, say which models are missing in plain words and go on. Never ask the user to open a terminal.
- `agy`: Google's Antigravity, a builder. Needs a Google AI Pro plan. Install: Mac/Linux `curl -fsSL https://antigravity.google/cli/install.sh | bash`; Windows `powershell -c "irm https://antigravity.google/cli/install.ps1 | iex"`. Check: `agy models`, listing gemini-4-hydrogen-high (and -low/-medium/-xhigh), gemini-4-argon-medium, gemini-3.8-flash-high/-medium, claude-sonnet-5-5-medium, claude-opus-5-5-medium. Sign-in (UNVERIFIED, not yet tried on the real tool): if the check says not signed in, start `agy` yourself (20 second timeout, Google OAuth) so the sign-in page opens in the user's browser, tell the user in plain words to finish it with the Google AI Pro account, then run `agy models` again. If no browser opens or the check still fails, tell the user in plain words to open the Antigravity app and sign in there with the Google AI Pro account, then run `agy models` again. No terminal instructions.
- `opencode`: OpenCode, builds with free models. Install: `curl -fsSL https://opencode.ai/install | bash` (Mac/Linux) or `npm i -g opencode-ai` (any). Check: `opencode models opencode`. No sign-in.

6. Check. Run `scripts/agy-run.sh --status` (expect `agy: 0 models limited`) and `scripts/opencode-run.sh --status --role build` (expect `role build: 0 of 7 models limited`). `ls .claude/agents | wc -l` (7+) and `ls .claude/m11 | wc -l` (5+). Report in one line.

7. Finish in at most 6 short lines: what is installed; what is left (sign-ins, rules to paste); START A NEW session in the Claude desktop app on this folder (rules load at session start) and choose Opus; then they can paste a request or a test prompt from `module-11/test-prompt.md`; the `module-11` folder and zip can stay or go.

## Rules
- Never add `--dangerously-skip-permissions`, `--auto` or any flag that bypasses permissions.
- Never read, print or ask for `.env` files, keys, tokens or passwords.
- If a command fails twice, stop and show the user the exact error. Edit no project files beyond these steps.
