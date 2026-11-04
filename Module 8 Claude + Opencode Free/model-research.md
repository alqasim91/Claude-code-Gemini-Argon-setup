# Module 8 research: OpenCode free models (2026-11-04)

Source for context/modalities: user's `opencode models opencode --verbose`. Benchmarks are vendor-reported unless noted. Rate limits are NOT published per model.

## Free plan limits
- Free models have IP-level usage limits (trial/light use). No request counts or windows are published. Symptom: "request rejected / rate limited". Fix: switch model or wait.
- Free access is "for a limited time", so the list can change. `opencode models opencode` is the authority.
- Pulse Alpha and Beam are unavailable in some countries.
- Quota is likely shared by IP, not per model (unconfirmed). Module 8 tracks a marker per model anyway and treats a run of limit errors across models as a global stop.

## Data policy (decides what code may go where)
| Policy | Models |
|---|---|
| Zero retention, no training | glm-5.3-flash-free, deepseek-v4.1-flash-free |
| Not trained on, kept 30 days | beam-free |
| Used to improve model | big-pickle, mimo-v2.6-flash-free, flint-40b-free (kept 30 days), pulse-alpha-free |
| Trial only, logged by NVIDIA, no personal/confidential data | nemotron-3.5-lightning-free, nemotron-3.5-super-vl-free |
| Unknown (new 2026-11-03, not on docs page) | crouton-alpha-free |

## Models
| Model | Context / out | Input | Efforts | What it is / evidence | Role |
|---|---|---|---|---|---|
| deepseek-v4.1-flash-free | 200k / 32k | text, image | low, high, max | DeepSeek V4.1 Flash. Reported DeepSWE 74.2, Terminal-Bench 90.6 (via Beam's table). Free tier caps context at 200k. | Default builder |
| glm-5.3-flash-free | 200k / 32k | text, image, video | low, high, max | Z.ai GLM-5.3-Flash, 320B. Terminal-Bench 2.1 84.3. | Second builder, UI-from-screenshot |
| beam-free | 1M / 131k | text | low to max | Reflection Beam, 501B MoE (23B active). SWE-bench Verified 80.9, Pro 65.5, DeepSWE 44.4. Strong on SWE, weaker on deep repo tasks. | Hard or large-context builder |
| flint-40b-free | 262k / 65k | text | low to max | Recursive Flint, 40B MoE (2.5B active). SWE-bench Verified 74.2, Terminal-Bench 54.9. Fast, rough early release, tested on simple tasks only. | Fast scoped builds, tests |
| nemotron-3.5-lightning-free | 262k / 262k | text | none | NVIDIA 30B (3B active). SWE-bench Verified 51.6, Terminal-Bench 24.6. Built for routine agent work, not reasoning. | Scout, formatting, mechanical edits |
| nemotron-3.5-super-vl-free | 1M / 131k | text, image | none to xhigh | NVIDIA 120B vision model. Terminal-Bench 66.7, below GLM-5.3-Flash. | Image/screenshot reading |
| mimo-v2.6-flash-free | 200k / 32k | text, image, audio, video | none | Xiaomi MiMo flash. No coding benchmark found. | Audio/video input tasks only |
| big-pickle | 200k / 32k | text | none | Hidden model, no published specs. | Late fallback |
| pulse-alpha-free | 1M / 131k | text, image | low, high, max | Alpha test model, nothing public. | Experimental fallback |
| crouton-alpha-free | 1M / 270k | text, image, video, pdf | minimal to max | Alpha test model released 2026-11-03, nothing public. | Experimental fallback |

None of these is Sonnet-level on hard work. The user rule applies: reviewer is a grade above implementer.

## Proposed routing
Phases as in Module 7 (Phase 0 = foundation). Opus scores each task, then picks model and effort.
| Task | Model + effort | Fallback order (next when quota/limit hit) |
|---|---|---|
| Scout / read-only survey | nemotron-3.5-lightning-free | flint low, glm-5.3-flash low, big-pickle |
| Mechanical edits, formatting, simple tests | flint-40b-free medium | nemotron-lightning, deepseek low, glm low |
| Standard build (default) | deepseek-v4.1-flash-free high | glm-5.3-flash high, flint high, beam medium, big-pickle |
| Hard or multi-file build | beam-free high | deepseek max, glm max, flint max |
| Large context (over 150k tokens) | beam-free high | nemotron-super-vl high, crouton-alpha high |
| Screenshot / image input | glm-5.3-flash-free high | nemotron-super-vl, pulse-alpha, crouton-alpha |
| Audio / video input | mimo-v2.6-flash-free | glm-5.3-flash (video), crouton-alpha (video) |
| Code with secrets or private data | glm-5.3-flash or deepseek-v4.1-flash only | none; else ask or Module 3 |
| Design shell / first draft | Claude Sonnet 5.5 high or Opus 5.5 medium | not on OpenCode |

Review: Claude Sonnet under 400 changed lines, Opus above. Fix ladder: same model once, next free model once, Claude Sonnet high, Claude Opus medium. Safety switch: more than 1 in 3 free-built tasks failing first review sends the rest of the run to the Claude fallback.
When every model for a role is drained: Module 3 (final fallback), asking you first.

## Open points to verify on your machine
1. `opencode run --help` shows the flags: `-m`, `--variant` (effort), `--format json`, `--dir`.
2. Whether `opencode run` exits non-zero on a rate-limit error (script will also grep for "rate", "429", "quota").
3. Models with no variants (nemotron-lightning, mimo, big-pickle) get no effort flag.
