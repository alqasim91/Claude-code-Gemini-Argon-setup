# Project rules, Module 6 Flash builder (shared by Claude Code subagents and Antigravity models)

- Your brief lists the files you own (`owns:`). Edit only those files. Reading any file is fine.
- Your brief may say you are one mini-task of a larger task. Build only your piece, exactly as specced, and match the names and signatures the brief gives. Pieces you were not given are built by other runs: do not build or fix them.
- Need a change in a file you do not own? Do not make it. Add `needs: <file>: <change>` to your report; an integration task will pick it up.
- Other agents may be editing other files at the same time. Never revert, reformat or delete changes you did not make. Modified files you did not touch are probably theirs: leave them alone.
- Do not run repo-wide formatters or codemods, `git checkout`, `git stash`, `git reset`, `git clean`, or dependency installs (npm, pip, etc.) unless your task owns that.
- Never commit or push. Leave changes uncommitted for review.
- Run the project's tests/lint before reporting done, if they exist and your mode allows shell commands; scope them to your files where possible. Failures in files you do not own: report them, do not fix them. If checks were not run, say so.
- Do not read or edit secrets (.env, keys, credentials).
- Scratch files go in /tmp, not in the repo.
- Final report: files changed, checks run, `needs:` lines, anything not done. Max 10 lines.
