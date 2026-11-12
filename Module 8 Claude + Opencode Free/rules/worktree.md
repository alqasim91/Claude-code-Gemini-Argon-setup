Read this only when file sets cannot be disjoint. Worktree mode is optional, default off.

Needs a git repo with at least one commit; commit what the model needs first (including AGENTS.md), since a worktree has only committed files.
1. `git worktree add ../wt-<task> -b oc/<task>`
2. Pass `--worktree ../wt-<task>` to the script (or `worktree:` in a Claude builder brief).
3. After the phase, review `git -C ../wt-<task> diff`. Commit approved work on the throwaway branch only (`git -C ../wt-<task> add -A && git -C ../wt-<task> commit -m "oc/<task>"`), then `git merge --squash oc/<task>` in the main tree without committing. Resolve conflicts directly or send back.
4. `git worktree remove ../wt-<task>` and `git branch -D oc/<task>`.
Never commit on the user's branch, never push. `owns:` still applies inside a worktree. The contract file path in briefs must be absolute.
