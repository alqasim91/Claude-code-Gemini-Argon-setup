Read this only when file sets cannot be disjoint. Self-contained. Cross-rules: never copy or link a `.env` file into a worktree (stop and ask); the main session never resolves merge conflicts or edits project files.

# Worktree mode (optional, default off)
Needs a git repo with at least one commit; commit the files the builders need first (including AGENTS.md), since a worktree has only committed files. Never copy or link a `.env` file into a worktree: stop and ask.
1. `git worktree add ../wt-<task> -b m11/<task>`
2. The brief gets `worktree: ../wt-<task>` (Claude sub-agents), or `--worktree ../wt-<task>` on `scripts/agy-run.sh` and `scripts/opencode-run.sh`. Briefs and `.m11/contract.md` stay in the main tree: the brief gives the absolute path of the contract file.
3. After the phase, a reviewer sub-agent reads `git -C ../wt-<task> diff`. Commit approved work on the throwaway branch only (`git -C ../wt-<task> add -A && git -C ../wt-<task> commit -m "m11/<task>"`), then `git merge --squash m11/<task>` in the main tree without committing. Merge conflicts are never resolved in the main session: send them to a sub-agent with the conflicted files in `owns:`.
4. `git worktree remove ../wt-<task>` and `git branch -D m11/<task>`.
Never commit on the user's branch, never push. Record worktree use in `.m11/last-run.md`.
