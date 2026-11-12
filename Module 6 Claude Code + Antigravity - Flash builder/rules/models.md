Read this only when picking an agy effort level or model for a task that is not a plain Flash build, or when editing the pool. Reference: `scripts/agy-run.sh` is the source of truth for aliases, effort suffixes and chains (the marked block at its top); keep CLAUDE.md in step.

Model IDs confirmed from `agy models` on 2026-10-25. Each ID embeds effort (low/medium/high). An alias takes a `-low`, `-medium` or `-high` suffix (`sonnet-high`); a full ID is used as given.

# Antigravity models (run through `scripts/agy-run.sh`, on the Google AI Pro plan)

| Alias | agy model ID | Use for | Quota notes |
|---|---|---|---|
| flash (build) | `gemini-3.8-flash-high` | **First-choice builder** for any non-design task Opus can split into small, exactly specced mini-tasks. Always with a real `owns:` list. Never fixes, never reviews | Nearly unlimited |
| flash (scout) | `gemini-3.8-flash-medium` (`-low` for pure lookups) | Scouting: file lookup, grep-style questions, summaries, extraction, formatting. Read-only | Nearly unlimited |
| argon | `gemini-4-argon-medium` (`-high` for hard tasks, `-low` for trivial) | Builds what Opus cannot spec exactly: bulk code, tests, refactors, large-context work. **Fix step 1 for Flash-built work** (medium) | Small pool; weekly |
| sonnet | `claude-sonnet-5-5-medium` (`-low` for trivial) | Non-design tasks that need Claude-style judgment: nuanced edits, careful refactors, writing/docs | Small pool |
| opus | `claude-opus-5-5-medium` (`-high`, `-low` also exist) | Hard multi-file or architecture-heavy implementation only | Smallest pool; spend rarely |

# Claude-plan agents (in `.claude/agents/`, on the Claude Pro plan, never relays)

| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first design drafts. Fix step 2 for agy-built work (Argon, agy Sonnet, agy Opus). Module 3 mode: design, docs, and everything not easy or Opus-trigger |
| `claude-opus-builder` | opus, effort medium | **Sensitive work** (Routing 2) and the most important or complex designs. Fix step 3 for agy-built and Flash-built work, step 2 for Claude-built design work. Module 3 mode: Opus-trigger tasks and last-step fixes |
| `claude-sonnet-fixer` | sonnet, effort medium | Fix step 2 for Flash-built work (step 1 when Argon is drained). Fixes only |
| `claude-haiku-builder` | haiku | Tiny, exactly described edits (Routing 3). Module 3 mode: easy, tool-verifiable build tasks |
| `scout` | haiku | Module 3 mode only: all read-only work, with file:line or URL evidence. Never edits |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff of 400 changed lines or fewer (`claude-opus-builder` work included), read-only. Returns PASS or FAIL |
| `opus-reviewer` | opus, effort medium | Reviews ONE task's diff of more than 400 changed lines, read-only, so the main session never reads a full diff. Returns PASS or FAIL with a numbered defect list |
