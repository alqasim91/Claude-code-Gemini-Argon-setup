# Module 8 test prompt

Paste the prompt below, unchanged, into a fresh Claude Code session in an empty git folder with Module 8 installed.

## Prompt

```
Build a small multi-page website for a fictional plant shop, "Fernwick".

SPEC
- Plain HTML, CSS and vanilla JavaScript. No framework, no external URLs, fonts, images or CDNs.
- Files: styles.css, index.html, shop.html, care.html, contact.html, products.js, shop.js, contact.js.
- styles.css is the shared look for every page: color tokens as CSS variables (leaf green, clay orange, cream, charcoal), system font stack, type and spacing scales, container (1100px max), nav, footer, product card grid, buttons, form styles, responsive down to 360px, visible focus styles.
- index.html: hero with headline and a button to shop.html, a row of three featured plants, and a short "why Fernwick" section.
- products.js: an array of 12 plants, each with id, name, category (low light, bright light, pet safe), price and a one-line description. No DOM code.
- shop.html and shop.js: the product grid built from products.js, filter buttons by category, a sort by price, and a cart counter in the nav. Add to cart saves to localStorage and survives a reload. It must not crash if storage is blocked.
- care.html: six plant care guides as cards, each with watering, light and a common mistake.
- contact.html and contact.js: a form with name, email and message. Validate on submit, show inline error messages tied to each field, and show a thank-you message when valid. Nothing is sent anywhere.
- Every page: <title>, lang attribute, viewport meta, stylesheet link, the same nav (current page highlighted) and footer. Scripts load only on the pages that need them.

SELF-CHECK
Before finishing, check that all eight files exist, every href and src points to a real file, every function shop.js calls from products.js is defined, every page uses styles.css, list any accessibility issues (unlabeled controls, heading order, low contrast, no focus style), and find any leftover placeholder text (TODO, lorem ipsum, console.log, http:// or https://). Fix everything you find, then re-check.

TIMING
As your very first action, run `date +%s` and remember the number. As your very last action, run `date +%s` again, subtract, and print "Elapsed: Xm Ys".

FINISH
Print: files created, whether the self-check passed, issues found and fixed, and one line on anything not done.
```

## What to check after the run

- A plan table was printed before any work started: id, phase, route with a reason, score, owned files, after. `scripts/opencode-run.sh --status --role <role>` ran before it.
- Each route matches the first-match list in `CLAUDE.md`. `.m8/TASKS.md` has one line per task, with the model that ran.
- Phase 0 holds the shared design (`styles.css`) and went to `claude-sonnet-builder` or `claude-opus-builder`. No design work went to a free model. That task owned `.m8/contract.md` and wrote it; briefs of later tasks say "Read `.m8/contract.md` first" and do not repeat the names.
- Briefs are in `.m8/briefs/<task>.md`. Later tasks in one phase were launched together with `scripts/opencode-run.sh` (background Bash calls, no relay sub-agent), and no two own the same file. Script scratch files are in `.m8/logs/`.
- Roles matched the work: `products.js` and page logic on `build`, mechanical pages or checks on `mech` or `scout`. Nothing near secrets ran on a non-zero-retention model with `--private` missing (this prompt has no secrets).
- Reports show `chain walk:`. If a model hit its limit, `.claude/opencode-quota/<model-id>` exists, `scripts/opencode-run.sh --status --role build` lists it, and the next model took the task without Opus stopping.
- Reviews followed the ladder: `sonnet-reviewer` for diffs up to 400 changed lines; Opus read bigger diffs itself. No separate Opus reviewer was spawned.
- Fixes (if any) went in order: same model, `hard` role, Claude Sonnet high, Claude Opus medium, and `.claude/m8/fix-ladders.md` was read first. Check the table in `.m8/last-run.md` for rounds.
- If a whole chain drained (exit 3), `.claude/m8/drained-chain.md` was read and Opus asked "wait or Module 3?" in words and did nothing on Claude for build work until you answered. After Module 3, plan lines end with `(Module 3 mode)`.
- The final message to the user is at most 8 short lines (what was built, what is open, who did the work, what you must decide, "Details: .m8/last-run.md") plus the "Elapsed: Xm Ys" line. The per-phase table is in `.m8/last-run.md`. Check the files on disk (open `index.html`, use the filter, add to cart, reload, submit the form empty).
