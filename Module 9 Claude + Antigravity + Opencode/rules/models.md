Read this only when choosing `--start`, judging a data-policy question beyond the Data rule in CLAUDE.md, or editing chains. Reference only: the script is the source of truth for chains (`chain_for` in `scripts/opencode-run.sh`), and it now discovers which free models are offered and skips missing ones itself. Cross-rules: S = 2 never goes to a free model; `--private` keeps only zero-retention models.

IDs confirmed from `agy models` (2026-10-25) and `opencode models opencode --verbose` (2026-11-04).

# Antigravity models (through `scripts/agy-run.sh`, on the Google AI Pro plan)

| Alias | agy model ID | Use for | Quota notes |
|---|---|---|---|
| flash-high (build) | `gemini-3.8-flash-high` | **First-choice builder** for any non-design task Opus can split into small, exactly specced mini-tasks. Needs a real `owns:` list. Never fixes, never reviews | Own marker. Nearly unlimited |
| flash (scout) | `gemini-3.8-flash-medium` (`flash-low` = `-low` for pure lookups) | Scouting fallback when the OpenCode `scout` chain is drained. Read-only | Own marker |
| argon | `gemini-4-argon-medium` (`argon-high` for the hardest, `argon-low` for trivial) | **Hard tasks only.** Fix steps (medium) | Small pool; weekly |
| sonnet (fix only) | `claude-sonnet-5-5-medium` | Fix steps of the ladders only. Never a first build, review, scout or design | Small pool. Own marker |
| opus (fix only) | `claude-opus-5-5-medium` | Last agy fix step only | Smallest pool. Own marker |

agy Sonnet and agy Opus never build first and never review: a reviewer that can edit would change the work after the check.

# OpenCode free models (called as `opencode/<id>`; effort via `--variant`; all benchmarks vendor-reported, none matches Claude Sonnet on hard work)

| Model ID | Context / out | Input | Efforts | Data policy | Use for |
|---|---|---|---|---|---|
| `deepseek-v4.1-flash-free` | 200k / 32k | text, image | low, high, max | zero retention, no training | Default OpenCode builder (high). Private code |
| `glm-5.3-flash-free` | 200k / 32k | text, image, video | low, high, max | zero retention, no training | Second builder. Screenshots. Private code |
| `beam-free` | 1M / 131k | text | low to max | not trained on, kept 30 days | Hard or large-context builds. Unavailable in some countries |
| `big-pickle` | 200k / 32k | text | none | trains on data | Late fallback. Unknown model, no published specs |
| `flint-40b-free` | 262k / 65k | text | low to max | trains on data, kept 30 days | Fast scoped edits, tests, boilerplate |
| `nemotron-3.5-lightning-free` | 262k / 262k | text | none | logged by NVIDIA | Scouting, formatting. Not a reasoning model |
| `nemotron-3.5-super-vl-free` | 1M / 131k | text, image | none to xhigh | logged by NVIDIA | Image reading, big-context fallback |
| `mimo-v2.6-flash-free` | 200k / 32k | text, image, audio, video | none | trains on data | Audio or video input only |
| `pulse-alpha-free` | 1M / 131k | text, image | low, high, max | trains on data | Alpha test model. Experimental tail |
| `crouton-alpha-free` | 1M / 270k | text, image, video, pdf | minimal to max | unknown | Alpha test model. Experimental tail |

# OpenCode roles and chains
A role is a chain of models in fallback order. `:x` is the variant.

| Role | Chain |
|---|---|
| `scout` | nemotron-3.5-lightning-free, flint-40b-free:low, glm-5.3-flash-free:low, deepseek-v4.1-flash-free:low |
| `mech` | flint-40b-free:medium, nemotron-3.5-lightning-free, deepseek-v4.1-flash-free:low, glm-5.3-flash-free:low |
| `build` | deepseek-v4.1-flash-free:high, glm-5.3-flash-free:high, flint-40b-free:high, beam-free:medium, big-pickle, pulse-alpha-free:high, crouton-alpha-free:high |
| `hard` | beam-free:high, deepseek-v4.1-flash-free:max, glm-5.3-flash-free:max, big-pickle, pulse-alpha-free:high, crouton-alpha-free:high |
| `large` (input over about 150k tokens) | beam-free:high, nemotron-3.5-super-vl-free:high, crouton-alpha-free:high |
| `vision` (screenshots, images) | glm-5.3-flash-free:high, nemotron-3.5-super-vl-free:high, pulse-alpha-free:high, crouton-alpha-free:high |
| `av` (audio or video input) | mimo-v2.6-flash-free, glm-5.3-flash-free:high, crouton-alpha-free:high |

`--private` keeps only the zero-retention models of any chain (glm-5.3-flash-free, deepseek-v4.1-flash-free; if the chain has neither, it uses both at high).
