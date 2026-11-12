Read this only when file sets cannot be disjoint. Self-contained. Cross-rules: never commit on the user's branch, never push; `owns:` still applies inside a worktree.

# Worktree mode (optional, default off)
Needs a git repo with at least one commit; commit what Codex needs first (including AGENTS.md), since a worktree has only committed files.
1. `git worktree add ../wt-<task> -b codex/<task>`
2. Pass `--worktree ../wt-<task>` to the script (or `worktree:` in a Claude builder brief). Briefs and `.m7/` stay in the main tree: give the brief path from the main tree as usual.
3. After the phase, review `git -C ../wt-<task> diff`. Commit approved work on the throwaway branch only (`git -C ../wt-<task> add -A && git -C ../wt-<task> commit -m "codex/<task>"`), then `git merge --squash codex/<task>` in the main tree without committing. Resolve conflicts directly or send back.
4. `git worktree remove ../wt-<task>` and `git branch -D codex/<task>`.
Never commit on the user's branch, never push. `owns:` still applies inside a worktree. Record worktree use in `.m7/last-run.md`.
