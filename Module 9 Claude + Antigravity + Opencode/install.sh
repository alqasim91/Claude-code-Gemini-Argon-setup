#!/usr/bin/env bash
# Module 9 installer. Run it from YOUR project folder:
#   bash path/to/install.sh
# Works on macOS, Linux and Git Bash. Safe to run twice.
set -eu

SRC="$(cd "$(dirname "$0")" && pwd -P)"
DEST="$(pwd -P)"
CHANGED=0

say() { printf '%s\n' "$*"; }
changed() { CHANGED=1; }

if [ "$DEST" = "$SRC" ]; then
  say "Run this from your project folder, not from inside the module folder."
  say "Example: cd my-project, then: bash module-9/install.sh"
  exit 1
fi

say "Installing Module 9 into: $DEST"

# Copy one file only when it is new or different. Returns 0 if it copied.
copy_file() {
  if [ -f "$2" ] && cmp -s "$1" "$2"; then return 1; fi
  cp "$1" "$2"
  return 0
}

# 1. Folders
made=0
for d in .claude/agents .claude/m9 .claude/agy-quota .claude/opencode-quota scripts; do
  if [ ! -d "$DEST/$d" ]; then mkdir -p "$DEST/$d"; made=1; fi
done
if [ "$made" = 1 ]; then changed; say "ok: folders created"; else say "skipped: folders already there"; fi

# 2. Agents, rule files, scripts
n=0
for f in "$SRC"/agents/*.md; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = "agy-delegate.md" ] && continue
  if copy_file "$f" "$DEST/.claude/agents/$(basename "$f")"; then n=$((n + 1)); fi
done
if [ "$n" -gt 0 ]; then changed; say "ok: $n agent file(s) copied to .claude/agents"; else say "skipped: agents already up to date"; fi

if [ -f "$DEST/.claude/agents/agy-delegate.md" ]; then
  rm -f "$DEST/.claude/agents/agy-delegate.md"
  changed
  say "ok: removed the old agy-delegate agent (a script replaced it)"
fi

n=0
for f in "$SRC"/rules/*.md; do
  [ -f "$f" ] || continue
  if copy_file "$f" "$DEST/.claude/m9/$(basename "$f")"; then n=$((n + 1)); fi
done
if [ "$n" -gt 0 ]; then changed; say "ok: $n rule file(s) copied to .claude/m9"; else say "skipped: rule files already up to date"; fi

n=0
for s in agy-run.sh opencode-run.sh; do
  if [ ! -f "$SRC/scripts/$s" ]; then say "skipped: scripts/$s is missing from the module folder"; continue; fi
  if copy_file "$SRC/scripts/$s" "$DEST/scripts/$s"; then n=$((n + 1)); fi
  if [ ! -x "$DEST/scripts/$s" ]; then chmod +x "$DEST/scripts/$s"; n=$((n + 1)); fi
done
if [ "$n" -gt 0 ]; then changed; say "ok: scripts copied to scripts/ and made runnable"; else say "skipped: scripts already up to date"; fi

# 3. CLAUDE.md and AGENTS.md
place_doc() {
  name="$1"
  src="$SRC/$name"
  dst="$DEST/$name"
  alt="${name%.md}.module-9.md"
  if [ ! -f "$src" ]; then say "skipped: $name is missing from the module folder"; return 0; fi
  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"; changed; say "ok: $name copied"
  elif cmp -s "$src" "$dst"; then
    say "skipped: $name is already up to date"
  elif grep -m1 '^#' "$dst" 2>/dev/null | grep -q 'Orchestration (Module 9'; then
    bak="$dst.bak-$(date +%Y%m%d-%H%M%S)"
    cp "$dst" "$bak"
    cp "$src" "$dst"
    changed
    say "ok: $name updated (your old copy is saved as $(basename "$bak"))"
  else
    if ! { [ -f "$DEST/$alt" ] && cmp -s "$src" "$DEST/$alt"; }; then
      cp "$src" "$DEST/$alt"; changed
    fi
    say "NOTE: you already have your own $name, so I did not change it."
    say "      Open $alt and paste its text into your $name."
  fi
}
place_doc CLAUDE.md
place_doc AGENTS.md

# 4. .claude/settings.json (merge, never overwrite)
SET="$DEST/.claude/settings.json"
ALT="$DEST/.claude/settings.module-9.json"
settings_by_hand() {
  cp "$SRC/settings.json" "$ALT"
  say "      I saved the module's list as .claude/settings.module-9.json."
  say "      Add its \"allow\" and \"deny\" lines to your .claude/settings.json by hand."
}
if [ ! -f "$SRC/settings.json" ]; then
  say "skipped: settings.json is missing from the module folder"
elif [ ! -f "$SET" ]; then
  cp "$SRC/settings.json" "$SET"; changed; say "ok: .claude/settings.json created"
else
  JS='
const fs = require("fs");
const read = p => fs.readFileSync(p, "utf8").replace(/^﻿/, "");
let cur, tpl;
try { cur = JSON.parse(read(process.argv[1])); } catch (e) { process.exit(3); }
tpl = JSON.parse(read(process.argv[2]));
if (cur === null || typeof cur !== "object" || Array.isArray(cur)) process.exit(3);
if (cur.permissions === undefined) cur.permissions = {};
if (cur.permissions === null || typeof cur.permissions !== "object" || Array.isArray(cur.permissions)) process.exit(3);
let added = 0;
for (const k of ["allow", "deny"]) {
  if (cur.permissions[k] === undefined) cur.permissions[k] = [];
  if (!Array.isArray(cur.permissions[k])) process.exit(3);
  for (const e of tpl.permissions[k]) if (!cur.permissions[k].includes(e)) { cur.permissions[k].push(e); added++; }
}
if (added === 0) process.exit(4);
fs.writeFileSync(process.argv[1], JSON.stringify(cur, null, 2) + "\n");
'
  PY='
import json, sys
def rd(p):
    with open(p, encoding="utf-8-sig") as f:
        return json.load(f)
try:
    cur = rd(sys.argv[1])
except Exception:
    sys.exit(3)
tpl = rd(sys.argv[2])
if not isinstance(cur, dict):
    sys.exit(3)
perm = cur.setdefault("permissions", {})
if not isinstance(perm, dict):
    sys.exit(3)
added = 0
for k in ("allow", "deny"):
    lst = perm.setdefault(k, [])
    if not isinstance(lst, list):
        sys.exit(3)
    for e in tpl["permissions"][k]:
        if e not in lst:
            lst.append(e)
            added += 1
if added == 0:
    sys.exit(4)
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(cur, f, indent=2, ensure_ascii=False)
    f.write("\n")
'
  rc=99
  if command -v node >/dev/null 2>&1 && node -e '0' >/dev/null 2>&1; then
    rc=0; node -e "$JS" "$SET" "$SRC/settings.json" || rc=$?
  elif command -v python3 >/dev/null 2>&1 && python3 -c 'import json' >/dev/null 2>&1; then
    rc=0; python3 -c "$PY" "$SET" "$SRC/settings.json" || rc=$?
  fi
  case "$rc" in
    0) changed; say "ok: .claude/settings.json updated (your other settings are untouched)" ;;
    4) say "skipped: .claude/settings.json already has the allow-list" ;;
    3) say "NOTE: .claude/settings.json is not valid JSON, so I did not touch it."
       settings_by_hand ;;
    99) say "NOTE: I need node or python3 to merge your .claude/settings.json, so I left it alone."
       settings_by_hand ;;
    *) say "NOTE: could not update .claude/settings.json, so I left it alone."
       settings_by_hand ;;
  esac
fi

# 5. .gitignore
GI="$DEST/.gitignore"
added=0
for line in .claude/agy-quota/ .claude/opencode-quota/ .m9/; do
  if [ -f "$GI" ] && { grep -qxF "$line" "$GI" || grep -qxF "${line%/}" "$GI"; }; then continue; fi
  if [ -s "$GI" ] && [ -n "$(tail -c1 "$GI")" ]; then printf '\n' >> "$GI"; fi
  printf '%s\n' "$line" >> "$GI"
  added=$((added + 1))
done
if [ "$added" -gt 0 ]; then changed; say "ok: .gitignore updated ($added line(s) added)"; else say "skipped: .gitignore already has the lines"; fi

# 6. Git (reviews read git diff)
if ! command -v git >/dev/null 2>&1; then
  say "NOTE: git is not installed. Reviews need git."
  say "      Mac: run  xcode-select --install   Windows: install Git for Windows (git-scm.com)."
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  say "skipped: this folder is already a git repo (left as it is)"
else
  git init -q
  changed
  say "ok: git repo started"
  if ! git rev-parse --verify -q HEAD >/dev/null 2>&1; then
    git add -A -- . ':(exclude,glob)**/.env' ':(exclude,glob)**/.env.*' >/dev/null 2>&1 || true
    if git commit -q -m "start" >/dev/null 2>&1; then
      say "ok: first commit made (your .env files were left out)"
    else
      say "NOTE: I could not make the first commit. Git needs your name and email. Run these two lines, then make the first commit:"
      say "      git config --global user.name \"Your Name\""
      say "      git config --global user.email \"you@example.com\""
      say "      git add -A && git commit -m start"
    fi
  fi
fi

# 7. Tool checks (report only)
if command -v agy >/dev/null 2>&1; then
  say "ok: agy found"
else
  say "NOTE: agy not found. Install it:"
  say "      Mac:     curl -fsSL https://antigravity.google/cli/install.sh | bash"
  say "      Windows: irm https://antigravity.google/cli/install.ps1 | iex"
fi
if command -v opencode >/dev/null 2>&1; then
  say "ok: opencode found"
else
  say "NOTE: opencode not found. Install it:"
  say "      Mac:     curl -fsSL https://opencode.ai/install | bash"
  say "      Any:     npm i -g opencode-ai"
fi

# 8. Done
say ""
say "Module 9 is installed."
if [ "$CHANGED" = 0 ]; then say "Nothing changed this time. It was already up to date."; fi
say "Next:"
say "  1. Sign in to agy and opencode if you have not yet (run each once)."
say "  2. Start Claude Code in this folder and choose Opus."
say "  3. Paste a prompt from test-prompt.md."
