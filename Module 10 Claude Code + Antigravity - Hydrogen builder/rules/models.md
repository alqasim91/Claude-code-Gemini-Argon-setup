Read this only when picking an agy effort level or model for a task that is not a plain Hydrogen build, or when editing the pool. Reference: `scripts/agy-run.sh` is the source of truth for aliases, effort suffixes and chains (the marked block at its top); keep CLAUDE.md in step.

Model IDs confirmed from the user's `agy models` output on 2026-11-13, including `gemini-4-hydrogen-low`, `-medium`, `-high` and `-xhigh`. Real runs on the real tool are not done yet. Each ID embeds effort. An alias takes a `-low`, `-medium` or `-high` suffix (`sonnet-high`), `hydrogen` also `-xhigh`; a full ID is used as given. The alias `hydrogen` alone means high; every other alias alone means medium.

# Antigravity models (run through `scripts/agy-run.sh`, on the Google AI Pro plan)

| Alias | agy model ID | Use for | Quota notes |
|---|---|---|---|
| hydrogen | `gemini-4-hydrogen-high` (`-medium`, `-low`, `-xhigh` selectable) | **Default builder** for every non-design build task, split into exact mini-tasks or bulk. Scored about the same as Argon on one index (secondary source, unverified); reported weaker on terminal and long-horizon work. Always with a real `owns:` list. Fix step 1 for its own work. Never reviews | Unverified; may share one quota pool with Argon and Flash (unverified) |
| argon | `gemini-4-argon-medium` (`-high` for the hardest, `-low` for trivial) | Hard tasks, long-horizon or terminal-heavy work, everything after a tripped safety switch. **Fix step 2 for Hydrogen- and Flash-built work** (medium) | Small pool; weekly |
| flash (scout) | `gemini-3.8-flash-medium` (`-low` for pure lookups) | Scouting: file lookup, grep-style questions, summaries, extraction, formatting. Read-only | Unverified; nearly unlimited so far |
| flash (build) | `gemini-3.8-flash-high` | Build **fallback** only: exact mini-tasks when Hydrogen is drained (`--exact`). Never fixes, never reviews, never design | As above |
| sonnet | `claude-sonnet-5-5-medium` (`-low` for trivial) | Non-design tasks that need Claude-style judgment: nuanced edits, careful refactors, writing/docs | Small pool |
| opus | `claude-opus-5-5-medium` (`-high`, `-low` also exist) | Hard multi-file or architecture-heavy implementation only | Smallest pool; spend rarely |

# Claude-plan agents (in `.claude/agents/`, on the Claude Pro plan, never relays)

| Agent | Model | Use for |
|---|---|---|
| `claude-sonnet-builder` | sonnet, effort high | Design shells and first design drafts. Fix step 2 for Argon-, agy Sonnet- and agy Opus-built work. Module 3 mode: design, docs, and everything not easy or Opus-trigger |
| `claude-opus-builder` | opus, effort medium | **Sensitive work** (Routing 2) and the most important or complex designs. Last fix step for agy-built work (step 3; step 4 for Hydrogen- and Flash-built), step 2 for Claude-built design work. Module 3 mode: Opus-trigger tasks and last-step fixes |
| `claude-sonnet-fixer` | sonnet, effort medium | Fix step 3 for Hydrogen- and Flash-built work (earlier when Hydrogen and Argon are skipped). Fixes only |
| `claude-haiku-builder` | haiku | Tiny, exactly described edits (Routing 3). Module 3 mode: easy, tool-verifiable build tasks |
| `scout` | haiku | Module 3 mode only: all read-only work, with file:line or URL evidence. Never edits |
| `sonnet-reviewer` | sonnet | Reviews ONE task's diff of 400 changed lines or fewer (`claude-opus-builder` work included), read-only. Returns PASS or FAIL |
| `opus-reviewer` | opus, effort medium | Reviews ONE task's diff of more than 400 changed lines, read-only, so the main session never reads a full diff. Returns PASS or FAIL with a numbered defect list |
