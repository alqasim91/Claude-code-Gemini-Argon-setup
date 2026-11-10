# Project rules (shared by Claude Code, Antigravity models, OpenCode free models, and the Claude builder agents)

- Your brief lists the files you own (`owns:`). Edit only those files. Reading any file is fine.
- Your brief may say you are one mini-task of a larger task. Build only your piece, exactly as specced, and match the names and signatures the brief gives. Pieces you were not given are built by other runs: do not build or fix them.
- Need a change in a file you do not own? Do not make it. Add `needs: <file>: <change>` to your report; an integration task will pick it up.
- Other agents may be editing other files at the same time. Never revert, reformat or delete changes you did not make. Modified files you did not touch are probably theirs: leave them alone.
- Do not run repo-wide formatters or codemods, `git checkout`, `git stash`, `git reset`, `git clean`, or dependency installs (npm, pip, etc.) unless your task owns that.
- Never commit or push. Leave changes uncommitted for review.
- Antigravity (`agy`) headless runs cannot run shell commands (they are denied): do not try, and say in the report which checks you could not run. Run the project's tests/lint before reporting done, if they exist and your mode allows shell commands; scope them to your files where possible. Failures in files you do not own: report them, do not fix them. If checks were not run, say so.
- Never read, edit, copy or link secrets: env files (`.env`, `.env.local` and so on), keys, credentials. This includes copying or linking an env file into a worktree. If your task seems to need one, stop and report it as a blocker; do not work around it.
- Scratch databases: you may test migrations on a local, throwaway database (for example a temporary local Postgres) that holds no real data and uses no real credentials. Never touch a real or shared database.
- Scratch files go in `.m9/logs/` or /tmp, not elsewhere in the repo.
- If the brief tells you to read `.m9/contract.md`, read it first and use only the names in it.
- Read-only task (`owns: none`)? Change nothing. Report findings only.
- Do exactly what the brief says. Do not add features, files or refactors it does not ask for. Use only the tools you have; if a tool call fails twice, say so in the report instead of retrying.
- Final report: files changed, checks run, `needs:` lines, anything not done. Max 10 lines.
