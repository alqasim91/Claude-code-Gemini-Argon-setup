# Claude plans, other models build

Setup guides and ready-to-copy files for running Claude Code (Opus) as the planner and reviewer, with other models building through a CLI: Google's Antigravity (`agy`) or OpenAI's Codex (`codex`).

## Start here

| What | Where |
|---|---|
| First-time Mac setup (install `agy`, sign in, first project) | [setup/mac-setup-en.md](setup/mac-setup-en.md) |
| Same guide in Egyptian Arabic | [setup/mac-setup-ar.md](setup/mac-setup-ar.md) |

## Modules

| Module | What it does | Folder |
|---|---|---|
| Module 3: Claude only | Opus plans, scores and reviews. Haiku scouts, Haiku, Sonnet and Opus build by task difficulty, an Opus fixer takes over after failed reviews. Pro plan only, no `agy` needed. | [Module 3 Claude only](<Module 3 Claude only>) |
| Module 6: Claude Code + Antigravity (parallel) | Opus plans in waves. Argon, Flash, Sonnet and Opus build several tasks at once through `agy`. Three fix rounds, quota fallback. | [Module 6 Claude code + Antigravity](<Module 6 Claude code + Antigravity>) |
| Module 7: Claude Code + Codex (parallel) | Opus plans in phases. Luna, Terra and Sol build several tasks at once through `codex exec` on a ChatGPT plan. No relay subagent, graded reviews, three fix rounds, quota fallback. | [Module 7 Claude code + Codex](<Module 7 Claude code + Codex>) |

Open the module's `README.md` for the step-by-step setup on Mac and Windows, and `test-prompt.md` for a ready test prompt.

## Layout

```
setup/                                  first-time setup guides
Module 3 Claude only/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  agents/                               6 subagents (go to .claude/agents/)
Module 6 Claude code + Antigravity/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             same rules for other tools (project root)
  agents/                               subagents (go to .claude/agents/)
  test-prompt.md
Module 7 Claude code + Codex/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             shared rules for Codex and builders (project root)
  agents/                               3 subagents (go to .claude/agents/)
  scripts/codex-run.sh                  Codex runner (go to scripts/, chmod +x)
  test-prompt.md
```
