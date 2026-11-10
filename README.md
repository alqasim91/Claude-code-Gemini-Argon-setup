# Claude plans, other models build

Setup guides and ready-to-copy files for running Claude Code (Opus) as the planner and reviewer, with other models building through a CLI: Google's Antigravity (`agy`), OpenAI's Codex (`codex`) or OpenCode's free models.

## Start here

| What | Where |
|---|---|
| **Pick the module that matches what you have. Each module's README has a one-command install for Mac and Windows.** | See the Modules table below |
| Original minimal setup (one Argon helper, Mac only, older flags), English | [setup/mac-setup-en.md](setup/mac-setup-en.md) |
| Original minimal setup, Egyptian Arabic | [setup/mac-setup-ar.md](setup/mac-setup-ar.md) |

## Modules

| Module | You need | What it does | Folder |
|---|---|---|---|
| Module 3: Claude only | Claude Pro | Opus plans, scores and reviews. Haiku scouts, Haiku, Sonnet and Opus build by task difficulty, an Opus fixer takes over after failed reviews. Pro plan only, no `agy` needed. | [Module 3 Claude only](<Module 3 Claude only>) |
| Module 6: Claude Code + Antigravity (parallel) | Claude Pro + Google AI Pro | Opus plans in waves. Argon, Flash, Sonnet and Opus build several tasks at once through `agy`. Runs `agy` from a script, with no relay agent. Three fix rounds, quota fallback. | [Module 6 Claude code + Antigravity](<Module 6 Claude code + Antigravity>) |
| Module 6: Claude Code + Antigravity, Flash builder | Claude Pro + Google AI Pro | Same as Module 6, but Gemini Flash (high) builds every task that splits into small, exact pieces; Argon builds the rest and fixes Flash's work. Saves the small Argon pool. | [Module 6 Claude Code + Antigravity - Flash builder](<Module 6 Claude Code + Antigravity - Flash builder>) |
| Module 7: Claude Code + Codex (parallel) | Claude Pro + a ChatGPT plan with Codex | Opus plans in phases. Luna, Terra and Sol build several tasks at once through `codex exec` on a ChatGPT plan. No relay subagent, graded reviews, three fix rounds, quota fallback. | [Module 7 Claude code + Codex](<Module 7 Claude code + Codex>) |
| Module 8: Claude Code + OpenCode free models (parallel) | Claude Pro (OpenCode free models need no plan) | Opus plans in phases. Ten free OpenCode models build tasks at once through `opencode run`; the script falls back to the next model when one hits its free limit. Zero-retention models for private code, graded reviews, four fix rounds, Module 3 fallback. | [Module 8 Claude + Opencode Free](<Module 8 Claude + Opencode Free>) |
| Module 9: Claude + Antigravity + OpenCode (parallel) | Claude Pro + Google AI Pro (OpenCode is free) | Combines Module 6 Flash builder and Module 8. Outside models run from scripts, with no relay agent. Flash builds exact mini-tasks first, OpenCode free models take over silently when Flash is drained (and handle scouting, images, big inputs), Argon only takes hard tasks and Flash fixes. Claude plan designs, reviews and fixes. Module 3 fallback. | [Module 9 Claude + Antigravity + Opencode](<Module 9 Claude + Antigravity + Opencode>) |

Open the module's `README.md` for the step-by-step setup on Mac and Windows, and `test-prompt.md` for a ready test prompt. Every module installs with one command; see its README.

## Layout

```
setup/                                  first-time setup guides
Module 3 Claude only/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               7 subagents (go to .claude/agents/)
  module-3-files.zip                    the same files, zipped
Module 6 Claude code + Antigravity/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             same rules for other tools (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               7 subagents (go to .claude/agents/)
  rules/                                3 on-demand rule files (go to .claude/m6/)
  scripts/agy-run.sh                    agy runner (go to scripts/, chmod +x)
  module-6-files.zip                    the same files, zipped
  test-prompt.md
Module 6 Claude Code + Antigravity - Flash builder/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             same rules for other tools (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               7 subagents (go to .claude/agents/)
  rules/                                5 on-demand rule files (go to .claude/m6/)
  scripts/agy-run.sh                    agy runner (go to scripts/, chmod +x)
  module-6-flash-files.zip              the same files, zipped
  test-prompt.md
Module 7 Claude code + Codex/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             shared rules for Codex and builders (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               5 subagents (go to .claude/agents/)
  rules/                                4 on-demand rule files (go to .claude/m7/)
  scripts/codex-run.sh                  Codex runner (go to scripts/, chmod +x)
  module-7-files.zip                    the same files, zipped
  test-prompt.md
Module 8 Claude + Opencode Free/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             shared rules for OpenCode models and builders (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               5 subagents (go to .claude/agents/)
  rules/                                4 on-demand rule files (go to .claude/m8/)
  scripts/opencode-run.sh               OpenCode runner (go to scripts/, chmod +x)
  module-8-files.zip                    the same files, zipped
  test-prompt.md
  model-research.md                     notes on the free models
Module 9 Claude + Antigravity + Opencode/
  README.md                             steps and how it works
  CLAUDE.md                             routing rules (project root)
  AGENTS.md                             shared rules for all builders (project root)
  install.sh / install.ps1              one-command installer (Mac, Linux, Windows)
  settings.json                         approvals list (merged into .claude/settings.json)
  agents/                               7 subagents (go to .claude/agents/)
  rules/                                5 on-demand rule files (go to .claude/m9/)
  scripts/agy-run.sh                    agy runner (go to scripts/, chmod +x)
  scripts/opencode-run.sh               OpenCode runner (go to scripts/, chmod +x)
  module-9-files.zip                    the same files, zipped
  test-prompt.md
```
