# Module 11 test prompt

Paste one prompt, unchanged, into a fresh Claude desktop app session in an empty folder with Module 11 installed (agy and opencode both signed in).

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

- A plan table is printed first, before any file is touched, with a route and a score for every task (sensitive ones labeled `opus-sensitive (reason)`). Quota checks (`scripts/agy-run.sh --status` and `scripts/opencode-run.sh --status`) ran before it.
- The main chat edits no project files and runs no builds. It only launches builders and scripts, writes files under `.m11/`, and reads short reports.
- The design shell went to `claude-sonnet-builder` or `claude-opus-builder`, never to agy or OpenCode. That task owned `.m11/contract.md` and wrote it; mini-task briefs say "Read `.m11/contract.md` first" and do not repeat the names.
- Tasks that split appear as Hydrogen mini-tasks (`-m1`, `-m2`...), run by `scripts/agy-run.sh` in background Bash calls (no relay sub-agent). The self-check (links, accessibility, leftover text) is a scout row in the plan and ran on OpenCode `scout` (Flash scout only if that chain was drained), not in the main chat. Hydrogen also takes non-exact bulk work (docs, copy, logic). Argon appears only for a hard task or a fix.
- Every task that edits files got ONE review: `sonnet-reviewer` at 800 changed lines or fewer, `opus-reviewer` above (or for hard/sensitive work). No agy or OpenCode model reviewed anything.
- A failed review followed the ladder for whoever built it (Hydrogen: Hydrogen high, Argon medium, agy Sonnet, agy Opus; OpenCode: same model, Hydrogen high, Argon medium, agy Sonnet, agy Opus), and `.claude/m11/fix-ladders.md` was read first. A drained agy Sonnet or Opus step was replaced by the Claude agent of the same tier.
- The final message to the user is at most 8 short lines (what was built, what is open, who did the work, what you must decide, "Details: .m11/last-run.md") plus the "Elapsed" line. The one-row-per-task table is in `.m11/last-run.md`, and `.m11/TASKS.md` got one line per task.

## Optional: test the silent fallbacks

In a separate chat in the Claude desktop app on the same folder, ask Claude to run the command for you (it is only a marker file), then start a fresh session and paste Prompt A.

1. **Hydrogen drained.** `mkdir -p .claude/agy-quota && printf 'until=2099-01-01T00:00:00Z\nreason=test\n' > .claude/agy-quota/gemini-4-hydrogen-high`. Expect: the plan shows the build tasks on OpenCode `build` with a "Hydrogen drained; silent re-route" line, and no question to you.
2. **OpenCode build drained.** `mkdir -p .claude/opencode-quota && for m in deepseek-v4.1-flash-free glm-5.3-flash-free flint-40b-free beam-free big-pickle pulse-alpha-free crouton-alpha-free; do printf 'until=2099-01-01T00:00:00Z\nreason=test\n' > ".claude/opencode-quota/$m"; done`. Expect: all builds stay on Hydrogen; nothing is held.
3. **Everything drained.** Do both 1 and 2, plus `for m in gemini-4-hydrogen-medium gemini-3.8-flash-high gemini-3.8-flash-medium gemini-4-argon-medium gemini-4-argon-high claude-sonnet-5-5-medium claude-opus-5-5-medium; do printf 'until=2099-01-01T00:00:00Z\nreason=test\n' > ".claude/agy-quota/$m"; done`. Expect: design and sensitive work still run on Claude, and Opus asks ONE question: wait for the reset, or switch to Module 3? It must not choose for you.

`scripts/agy-run.sh --status` should list the agy markers you set. When you are done, ask Claude to delete the marker files in `.claude/agy-quota/` and `.claude/opencode-quota/`.
