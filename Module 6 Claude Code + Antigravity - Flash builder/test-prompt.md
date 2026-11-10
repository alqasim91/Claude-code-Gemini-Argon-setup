# Module 6 Flash builder test prompt

Paste one prompt, unchanged, into a fresh Claude Code session in an empty folder with Module 6 Flash builder installed.

## Prompt A: Driftwood landing site

```
Build a small multi-page landing site for a fictional product, "Driftwood", a focus-music app.

SPEC
- Plain HTML, CSS and vanilla JavaScript. No framework, no external URLs, fonts, images or CDNs.
- Files: styles.css, index.html, features.html, pricing.html, faq.html, app.js.
- styles.css is the shared design system everything else uses: color tokens as CSS variables (warm sand, driftwood brown, deep sea blue), system font stack, type scale, spacing scale, container (1000px max), nav, footer, card grid, buttons, form/toggle styles, responsive down to 360px, visible focus styles.
- index.html: hero with headline, subline and CTA to pricing.html, a three-step "how it works" row, and a short testimonial strip.
- features.html: six feature cards (sound mixes, focus timer, offline mode, sleep sounds, playlists, stats) and a comparison table.
- pricing.html: Free, Pro and Team plan cards with a monthly/yearly toggle that updates the prices (yearly saves 20%).
- faq.html: eight questions as an accordion that opens one at a time and works with the keyboard.
- app.js: the pricing toggle and the FAQ accordion, loaded only by the pages that need it.
- Every page: <title>, lang attribute, viewport meta, stylesheet link, the same nav (current page highlighted) and footer.

SELF-CHECK
Before finishing, check that all six files exist, every href and src points to a real file, every page uses styles.css, list any accessibility issues (missing alt, unlabeled controls, heading order, low contrast, no focus style), and find any leftover placeholder text (TODO, lorem ipsum, console.log, http:// or https://). Fix everything you find, then re-check.

TIMING
As your very first action, run `date +%s` and remember the number. As your very last action, run `date +%s` again, subtract, and print "Elapsed: Xm Ys".

FINISH
Print: files created, whether the self-check passed, issues found and fixed, and one line on anything not done.
```

## Prompt B: Orbit Catch game

```
Build a light browser game, "Orbit Catch", where you move a paddle to catch falling stars and dodge dark meteors.

SPEC
- Plain HTML, CSS and vanilla JavaScript. No framework, no external URLs, no images, and no audio files.
- Files: styles.css, index.html, game.html, game.js, effects.js, scores.js, how-to-play.html.
- styles.css is the shared design system for every page: color tokens as CSS variables (deep space navy, star gold, meteor red, soft white), system font stack, type and spacing scales, buttons, panels, HUD text, canvas frame, responsive down to 360px, visible focus styles.
- index.html: the menu with the title, Play, How to Play and a top-5 high score list read from scores.js.
- game.html: a canvas, a HUD (score, lives, level) and pause/restart buttons; loads game.js, effects.js and scores.js.
- game.js: the game loop with requestAnimationFrame, arrow keys and touch/mouse paddle control, falling stars and meteors with collision checks, rising speed per level, game over screen.
- effects.js: a small particle system (sparkle on a catch, burst on a hit, screen shake) that game.js calls.
- scores.js: save and load the top 10 scores in localStorage, safe if storage is blocked.
- how-to-play.html: controls, scoring rules and tips.
- Every page: <title>, lang attribute, viewport meta, stylesheet link, and a link back to the menu.

SELF-CHECK
Before finishing, check that all seven files exist, every href and src points to a real file, every function game.js calls from effects.js and scores.js is actually defined there, list any accessibility issues (missing labels, focus, contrast, canvas without a text fallback), and find any leftover placeholder text (TODO, lorem ipsum, console.log, http:// or https://). Fix everything you find, then re-check.

TIMING
As your very first action, run `date +%s` and remember the number. As your very last action, run `date +%s` again, subtract, and print "Elapsed: Xm Ys".

FINISH
Print: files created, whether the self-check passed, issues found and fixed, and one line on anything not done.
```

## What to look for

- A plan table is printed first, before any work starts or any file is edited, with a route for every task (sensitive ones labeled `opus-sensitive (reason)`). `scripts/agy-run.sh --status` ran before it.
- The main chat edits no project files and runs no builds: every edit, even sensitive work, comes from a builder. It only launches builders and scripts, writes files under `.m6/`, and reads short reports.
- Sensitive means the sensitive files only (migrations, access policies, money or stock functions, auth, crypto) and those go to `claude-opus-builder`; the UI, types and labels of the same feature go through normal routing.
- The design and styles task went to `claude-sonnet-builder` or `claude-opus-builder`, never to `agy` (not Argon, not Flash). That task owned `.m6/contract.md` and wrote it; mini-task briefs say "Read `.m6/contract.md` first" and do not repeat the names.
- Parallel tasks were launched together in one message, and no two of them own the same file. Flash and Argon tasks ran as background `scripts/agy-run.sh` calls (no relay sub-agent).
- The scout checks (links, accessibility, leftover text) went to Flash, and Opus verified what they reported before anything was changed.
- The plan shows the Flash test applied to each non-design build task: tasks that split appear as Flash-high tasks with mini-tasks (`-m1`, `-m2`, ... about 4 each, same-file mini-tasks in sequence, briefs that point to the shared contract file). Tasks Opus could not spec exactly appear on Argon (medium by default).
- Every task that edits files got a reviewer sub-agent. Each task was reviewed ONCE, after all its mini-tasks finished, never per mini-task. `sonnet-reviewer` reviewed it with 400 changed lines or fewer (combined diff); `opus-reviewer` (a sub-agent) reviewed it above 400, and the main chat never read a full diff. Flash never reviewed or fixed anything.
- A failed review of Flash-built work went to Argon medium first (`<task>-r1`, with the whole task diff and defect list), then Claude Sonnet medium (`claude-sonnet-fixer`), then Claude Opus medium, and `.claude/m6/fix-ladders.md` was read first. With Argon drained, it started at Sonnet medium.
- If more than 1 in 3 Flash-built tasks failed their first review (from the 3rd reviewed task on), the plan says the Flash safety switch tripped and new tasks go to Argon, and `.m6/last-run.md` repeats it.
- The final message to the user is at most 8 short lines (what was built, what is open, who did the work, what you must decide, "Details: .m6/last-run.md") plus the "Elapsed: Xm Ys" line. The per-wave table is in `.m6/last-run.md`.

## Optional: test the drained pools

Fake a drained Antigravity before you paste a prompt. In the project folder (Mac, or Git Bash on Windows):

```bash
mkdir -p .claude/agy-quota
for m in gemini-4-argon-medium gemini-4-argon-high claude-sonnet-5-5-medium claude-opus-5-5-medium; do printf 'until=2099-01-01T00:00:00Z\nreason=test\n' > ".claude/agy-quota/$m"; done
```

Then paste Prompt A. `scripts/agy-run.sh --status` should list the four markers. Flash should keep building the pieces it can (the plan still shows Flash-high mini-tasks), and the design shell still goes to a Claude builder. Opus should ask ONE question only if some task cannot be split into exact mini-tasks: "wait for the reset, or switch to Module 3?". It must not pick for you, and it must not ask the old "switch to Flash" question. To test the Flash-built fix ladder with Argon drained, check that a failed Flash-built task skips Argon and starts at `claude-sonnet-fixer`. Delete the marker files when you are done: `rm .claude/agy-quota/*`.
