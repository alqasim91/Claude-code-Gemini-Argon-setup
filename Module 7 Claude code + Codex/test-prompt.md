# Module 7 test prompt

Paste the prompt below, unchanged, into a fresh Claude Code session in an empty git folder with Module 7 installed.

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

- A plan table was printed before any work started: id, phase, model with a reason, owned files, after.
- The plan table shows a score per task (like `A0 N1 C1 R0 S0 V1 D0`), and each route matches the first-match list in `CLAUDE.md`. `TASKS.md` has one line per task.
- The work was split into phases. Phase 0 holds the shared design (`styles.css`), and it went to `claude-sonnet-builder` or `claude-opus-builder` (also in Module 3 mode). No design work went to a Codex model.
- Later tasks in one phase were launched together with `scripts/codex-run.sh`, and no two own the same file.
- Models matched the work: `products.js` and page logic to sol, care guides and copy to terra, scouting checks to luna.
- Reviews followed the ladder: `sonnet-reviewer` for luna, terra and small sol diffs; Opus read bigger diffs itself. No separate Opus reviewer was spawned.
- Fixes (if any) went in order. Sol tasks: same model, then Claude Sonnet high, then Claude Opus medium. Luna or Terra tasks: same model, then Sol high, then Claude Sonnet high. Check the final table for rounds.
- Limits: the Codex plan has a 5-hour and a weekly limit (one pool for all Codex models), with markers `.claude/codex-quota/5h` and `.claude/codex-quota/weekly`; `scripts/codex-run.sh --status` shows them. If the 5-hour limit hit (exit 3), Opus let running tasks finish, then stopped and told you "Codex 5-hour limit hit. Codex is back at <time>..." without asking about Module 3 and without using Claude builders. If the weekly limit hit (exit 5), Opus asked "Wait (I re-check Codex in 24 hours) or switch the remaining tasks to Module 3 mode now?" and did nothing on Claude until you said Module 3. There was no Codex-to-Codex fallback. After you chose Module 3, plan lines show `(Module 3 mode)`: Opus-trigger tasks on `claude-opus-builder`, easy tasks on `claude-haiku-builder`, read-only tasks on `scout`, the rest on `claude-sonnet-builder`.
- The final per-phase table (with its "limit hit (5h/weekly) -> what happened" column), the printed "Elapsed: Xm Ys" line, and the files on disk (open `index.html`, use the filter, add to cart, reload, submit the form empty).
