Read this before the first Claude builder or `scout` launch of a run. Self-contained. Cross-rules: design never goes to a Codex model; S = 2 stays on Claude; Claude builders never take build work from Codex without the user saying Module 3 (design, S = 2 and fix rounds 2 and 3 are routed in CLAUDE.md).

# Claude-plan agents (in `.claude/agents/`)

| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first design drafts. Security, auth, secrets, unclear-spec tasks (Opus writes the spec). Fix rounds. Module 3 mode only: design, S = 2, docs and everything not easy or Opus-trigger |
| `claude-opus-builder` | opus, effort medium | The most important designs. Round-3 fixes for Sol tasks. Builds and fixes |
| `claude-haiku-builder` | haiku | Module 3 mode only (Codex limit hit, user said Module 3): easy tool-verifiable build tasks |
| `scout` | haiku | Module 3 mode only: all read-only work (search, explain, research), with file:line or URL evidence. Never edits |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff, read-only. Returns PASS or FAIL |

Launch with the Agent tool (`subagent_type` = the agent name, `run_in_background: true`), prompt = header (`task:`, `owns:`, optional `worktree:`, optional bare `design` line for builders) then the body.
