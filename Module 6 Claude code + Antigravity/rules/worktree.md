Read this only when file sets cannot be disjoint. Self-contained. Cross-rules: never copy or link a `.env` file into a worktree (stop and ask); the main session never resolves merge conflicts or edits project files.

# Worktree mode (optional, default off)
Needs a git repo with at least one commit; commit the files the builders need first (including AGENTS.md), since a worktree has only committed files (untracked files such as `node_modules` and `.env` are absent). Never copy or link a `.env` file into a worktree to make it work: that touches secrets, so stop and ask.
Per task, Opus:
1. `git worktree add ../wt-<task> -b agy/<task>`
2. The brief gets `worktree: ../wt-<task>` (Claude sub-agents work only inside it), or `--worktree ../wt-<task>` on `scripts/agy-run.sh` (agy runs with that directory as working directory). Briefs and `.m6/contract.md` stay in the main tree: a brief gives the absolute path of the contract file.
3. After the wave, a reviewer sub-agent reads `git -C ../wt-<task> diff` (the main session reads only `--stat` / `--numstat`). Commit approved work on the throwaway branch only (`git -C ../wt-<task> add -A && git -C ../wt-<task> commit -m "agy/<task>"`), then bring it into the main tree without committing there: `git merge --squash agy/<task>`. Merge conflicts are never resolved in the main session: send them to a sub-agent (the original builder's fix route under Fix ladders, or `claude-sonnet-builder`) with the conflicted files in `owns:`.
4. `git worktree remove ../wt-<task>` and `git branch -D agy/<task>`.
Never commit on the user's branch, never push. The `owns:` list still applies inside a worktree (keeps merges clean). Record worktree use in `.m6/last-run.md`.
