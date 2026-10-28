# Claude plans, Gemini 4 Argon builds: Mac setup with agy

Claude Code (desktop app, Opus) plans, reviews and verifies. Gemini 4 Argon writes the code through Google's Antigravity command line tool, `agy`. Follow the steps in order. Copy each command exactly.

## What you need

- A Mac
- The Claude Code desktop app
- A Google AI Pro plan. Argon needs a non-trial AI Pro plan. Its quota refreshes every five hours, up to a weekly limit.

## Step 0: install agy and sign in

1. Open Terminal (press Cmd+Space, type Terminal, press Return) and run Google's install command:

```
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

2. Check the install. The binary lands in `~/.local/bin/agy`.

```
agy --version
```

3. Sign in. Run `agy`, and at the sign-in menu type `1` (Google OAuth). Your browser opens. Sign in with your Google AI Pro account, copy the code, paste it into the terminal and press Return.

```
agy
```

4. List the models and copy Argon's exact name:

```
agy models
```

## Step 1: create the project folder

In Finder, open your user folder, then `Projects` (or press Cmd+Shift+H and double-click `Projects`). Choose File > New Folder (or press Shift+Cmd+N), type `my-app` and press Return. The folder is `~/Projects/my-app`.

## Step 2: create the two files

Create two plain text files with the exact contents below and put both in `my-app`. (In the video they are dragged in from Downloads.)

In `argon-builder.md`, replace `gemini-4-argon` with the exact name printed by `agy models`.

**CLAUDE.md**

```md
# Delegation rule
You (Claude) plan, review and verify. You do not write implementation code.
1. Plan: break the task into steps with acceptance criteria.
2. Delegate implementation to the argon-builder agent, one full spec per call.
3. Review the files it changed against each criterion; send fixes back through argon-builder.
4. Deliver only verified work.
```

**argon-builder.md**

```md
---
name: argon-builder
description: Hands implementation specs to Gemini 4 Argon through agy and reports back.
tools: Bash, Read
---
Run: agy -p "<full spec + acceptance criteria>" --model gemini-4-argon --print-timeout 20m < /dev/null
For fixes: agy -c -p "<fixes>" < /dev/null
Tell Argon to write every file in full, with no placeholders. Return the list of files it changed.
```

## Step 3: run one command

1. In Finder, right-click the `my-app` folder and choose **New Terminal at Folder**.
2. If you do not see it, look under **Services**, or turn it on in System Settings > Keyboard > Keyboard Shortcuts > Services.
3. Paste this command and press Return:

```
mkdir -p .claude/agents && find . -maxdepth 1 -name "*.md" ! -name "CLAUDE.md" -exec mv {} .claude/agents/ \;
```

What it does: it creates a hidden folder named `.claude` and moves every other markdown file into `.claude/agents/`, so only `CLAUDE.md` stays visible in `my-app`. To check, open `my-app` in Finder and press **Cmd+Shift+.** to show hidden files. You will see `.claude/agents/argon-builder.md`.

## Step 4: start a new session

Open the Claude Code desktop app (from Applications, or press Cmd+Space) and click **New session** at the top of the sidebar.

## Step 5: choose the folder and Opus

1. Click the folder button under the message box. In the picker choose `Projects`, then `my-app`, then **Open**.
2. Click the model picker at the bottom of the message box and choose **Opus**, the planner.

## Step 6: send a prompt

Type this prompt and send it:

```
Build a one-page landing page for my AI course with a signup form.
```

Claude does not start coding. It posts a plan with acceptance criteria, then delegates to Argon by running `agy` headless, using this call from `argon-builder.md`:

```
agy -p "Build index.html: a one-page landing page for my AI course with a signup form. Criteria: single file, works at phone width, signup form validates the email, no placeholder text." --model gemini-4-argon --print-timeout 20m < /dev/null
```

Then Claude reads the changed file and checks each criterion. If one fails, it sends a fix back with `agy -c`, which continues the same conversation:

```
agy -c -p "Fix: validate the email field before submit and show an error message." < /dev/null
```

Claude checks the file again and delivers only verified work.

## Troubleshooting

- **agy: command not found.** Open a new Terminal window, or check that `~/.local/bin` is on your PATH.
- **Argon is missing from `agy models`.** Argon needs a non-trial Google AI Pro plan.
- **Big jobs time out.** Raise `--print-timeout` (the example uses `20m`).
- **`.claude` is invisible in Finder.** Folders that start with a dot are hidden on macOS. Press Cmd+Shift+. in a Finder window to show or hide them.
