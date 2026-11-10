# Project rules (shared by Claude Code, the OpenCode free models, and the Claude builder agents)

- Your brief lists the files you own (`owns:`). Edit only those files. Reading any file is fine.
- Need a change in a file you do not own? Do not make it. Add `needs: <file>: <change>` to your report; an integration task will pick it up.
- Other agents may be editing other files at the same time. Never revert, reformat or delete changes you did not make. Modified files you did not touch are probably theirs: leave them alone.
- Do not run repo-wide formatters or codemods, `git checkout`, `git stash`, `git reset`, `git clean`, or dependency installs (npm, pip, etc.) unless your task owns that.
- Never commit or push. Leave changes uncommitted for review.
- Run the project's tests/lint before reporting done, if they exist and your tools allow shell commands; scope them to your files where possible. Failures in files you do not own: report them, do not fix them. If checks were not run, say so.
- Do not read or edit secrets (.env, keys, credentials).
- Scratch files go in `.m8/logs/` or /tmp, not in the repo (`.m8/` is git-ignored).
- Read-only task (`owns: none`)? Change nothing. Report findings only.
- Do exactly what the brief says. Do not add features, files or refactors it does not ask for. Use only the tools you have; if a tool call fails twice, say so in the report instead of retrying.
- Final report: files changed, checks run, `needs:` lines, anything not done. Max 10 lines.
