# Module 6 test prompt

Paste one prompt, unchanged, into a fresh Claude Code session in an empty folder with Module 6 installed.

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

- A plan table is printed before any work starts, with a model chosen for each task.
- The design and styles task went to Sonnet or Opus, never Gemini.
- Parallel tasks were launched together in one message, and no two of them own the same file.
- The scout checks (links, accessibility, leftover text) went to Flash, and Opus verified what they reported before anything was changed.
- Also check the printed "Elapsed: Xm Ys" line and the final per-wave summary.
