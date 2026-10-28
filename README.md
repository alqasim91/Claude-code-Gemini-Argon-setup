# Claude plans, Antigravity models build

Setup guides and ready-to-copy files for running Claude Code (Opus) as the planner and reviewer, with Gemini and other models building through Google's Antigravity CLI (`agy`).

## Start here

| What | Where |
|---|---|
| First-time Mac setup (install `agy`, sign in, first project) | [setup/mac-setup-en.md](setup/mac-setup-en.md) |
| Same guide in Egyptian Arabic | [setup/mac-setup-ar.md](setup/mac-setup-ar.md) |

## Modules

| Module | What it does | Folder |
|---|---|---|
| 6: Antigravity models (parallel) | Opus plans in waves. Argon, Flash, Sonnet and Opus build several tasks at once through `agy`. Three fix rounds, quota fallback. | [modules/module-6](modules/module-6) |

Open the module's `README.md` for the step-by-step setup on Mac and Windows, and `test-prompt.md` for a ready test prompt.

## Layout

```
setup/            first-time setup guides
modules/
  module-6/
    README.md     steps and how it works
    CLAUDE.md     routing rules (goes to your project root)
    AGENTS.md     same rules for other tools (project root)
    agents/       subagents (go to .claude/agents/)
    test-prompt.md
```
