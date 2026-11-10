Read this only when file sets cannot be disjoint (worktree mode, optional, default off). Self-contained.

# Worktree mode
Requires a git repo with at least one commit; commit the files the builders need first (including AGENTS.md), since a worktree has only committed files (untracked files such as `node_modules` and `.env` are absent). Never copy or link a `.env` file into a worktree to make it work: that touches secrets, so stop and ask.
Per task, Opus:
1. `git worktree add ../wt-<task> -b agy/<task>`
2. agy tasks: `scripts/agy-run.sh ... --worktree ../wt-<task>` (the script runs `agy` with that directory as working directory; markers and `.m6/` stay in the project root). Claude builders work only inside it. Briefs that point at `.m6/contract.md` give its absolute path.
3. After the wave, a reviewer sub-agent reads `git -C ../wt-<task> diff` (the main session reads only `--stat` / `--numstat`). Commit approved work on the throwaway branch only (`git -C ../wt-<task> add -A && git -C ../wt-<task> commit -m "agy/<task>"`), then bring it into the main tree without committing there: `git merge --squash agy/<task>`. Merge conflicts are never resolved in the main session: send them to a sub-agent (the original builder's fix route under the fix ladders, or `claude-sonnet-builder`) with the conflicted files in `owns:`.
4. `git worktree remove ../wt-<task>` and `git branch -D agy/<task>`.
Never commit on the user's branch, never push. The `owns:` list still applies inside a worktree (keeps merges clean).
