#!/usr/bin/env bash
# Module 7 installer. Run it from YOUR project folder:
#   bash path/to/install.sh
# Works on macOS, Linux and Git Bash. Safe to run twice.
# Options: --accept-edits (answer yes to the edit question), --no-accept-edits (answer no).
set -eu

SRC="$(cd "$(dirname "$0")" && pwd -P)"
DEST="$(pwd -P)"
CHANGED=0

say() { printf '%s\n' "$*"; }
changed() { CHANGED=1; }

usage() { printf '%s\n' "Usage: bash install.sh [--accept-edits | --no-accept-edits]" >&2; exit 2; }
ACCEPT=ask
for arg in "$@"; do
  case "$arg" in
    --accept-edits) if [ "$ACCEPT" = no ]; then usage; fi; ACCEPT=yes ;;
    --no-accept-edits) if [ "$ACCEPT" = yes ]; then usage; fi; ACCEPT=no ;;
    *) usage ;;
  esac
done

if [ "$DEST" = "$SRC" ]; then
  say "Run this from your project folder, not from inside the module folder."
  say "Example: cd my-project, then: bash module-7/install.sh"
  exit 1
fi

say "Installing Module 7 into: $DEST"

# Copy one file only when it is new or different. Returns 0 if it copied.
copy_file() {
  if [ -f "$2" ] && cmp -s "$1" "$2"; then return 1; fi
  cp "$1" "$2"
  return 0
}

# 1. Folders
made=0
for d in .claude/agents .claude/m7 .claude/codex-quota scripts; do
  if [ ! -d "$DEST/$d" ]; then mkdir -p "$DEST/$d"; made=1; fi
done
if [ "$made" = 1 ]; then changed; say "ok: folders created"; else say "skipped: folders already there"; fi

# 2. Agents, rule files, scripts
n=0
for f in "$SRC"/agents/*.md; do
  [ -f "$f" ] || continue
  if copy_file "$f" "$DEST/.claude/agents/$(basename "$f")"; then n=$((n + 1)); fi
done
if [ "$n" -gt 0 ]; then changed; say "ok: $n agent file(s) copied to .claude/agents"; else say "skipped: agents already up to date"; fi

n=0
for f in "$SRC"/rules/*.md; do
  [ -f "$f" ] || continue
  if copy_file "$f" "$DEST/.claude/m7/$(basename "$f")"; then n=$((n + 1)); fi
done
if [ "$n" -gt 0 ]; then changed; say "ok: $n rule file(s) copied to .claude/m7"; else say "skipped: rule files already up to date"; fi

n=0
for s in codex-run.sh; do
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
  alt="${name%.md}.module-7.md"
  if [ ! -f "$src" ]; then say "skipped: $name is missing from the module folder"; return 0; fi
  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"; changed; say "ok: $name copied"
  elif cmp -s "$src" "$dst"; then
    say "skipped: $name is already up to date"
  elif grep -m1 '^#' "$dst" 2>/dev/null | grep -q 'Orchestration (Module 7'; then
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
ALT="$DEST/.claude/settings.module-7.json"
settings_by_hand() {
  cp "$SRC/settings.json" "$ALT"
  say "      I saved the module's list as .claude/settings.module-7.json."
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

# 4b. Edit approval: ask once whether Claude may edit files without asking each time.
# Only ever sets permissions.defaultMode to "acceptEdits". Never any other mode.
MJS='
const fs = require("fs");
let cur;
try { cur = JSON.parse(fs.readFileSync(process.argv[1], "utf8").replace(/^﻿/, "")); } catch (e) { process.exit(3); }
if (cur === null || typeof cur !== "object" || Array.isArray(cur)) process.exit(3);
const p = cur.permissions;
if (p !== undefined && (p === null || typeof p !== "object" || Array.isArray(p))) process.exit(3);
if (process.argv[2] === "get") {
  if (p !== undefined && p.defaultMode !== undefined && p.defaultMode !== null) { console.log(String(p.defaultMode)); process.exit(0); }
  process.exit(5);
}
if (p === undefined) cur.permissions = {};
cur.permissions.defaultMode = "acceptEdits";
fs.writeFileSync(process.argv[1], JSON.stringify(cur, null, 2) + "\n");
'
MPY='
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8-sig") as f:
        cur = json.load(f)
except Exception:
    sys.exit(3)
if not isinstance(cur, dict):
    sys.exit(3)
perm = cur.get("permissions")
if "permissions" in cur and not isinstance(perm, dict):
    sys.exit(3)
if sys.argv[2] == "get":
    if perm is not None and perm.get("defaultMode") is not None:
        print(perm["defaultMode"])
        sys.exit(0)
    sys.exit(5)
if perm is None:
    perm = cur["permissions"] = {}
perm["defaultMode"] = "acceptEdits"
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(cur, f, indent=2, ensure_ascii=False)
    f.write("\n")
'
# json_mode get|set : exit 0 ok, 3 invalid JSON, 5 (get) not set, 99 no node or python3
json_mode() {
  if command -v node >/dev/null 2>&1 && node -e '0' >/dev/null 2>&1; then
    node -e "$MJS" "$SET" "$1"
  elif command -v python3 >/dev/null 2>&1 && python3 -c 'import json' >/dev/null 2>&1; then
    python3 -c "$MPY" "$SET" "$1"
  else
    return 99
  fi
}
edits_by_hand() {
  say "      To allow edits without asking, add \"defaultMode\": \"acceptEdits\" inside \"permissions\" in .claude/settings.json by hand."
}
mode_rc=0
cur_mode=""
if [ ! -f "$SET" ]; then
  mode_rc=98
else
  cur_mode=$(json_mode get) || mode_rc=$?
fi
case "$mode_rc" in
  0) say "skipped: edit approval is already set to $cur_mode" ;;
  5)
    answer="$ACCEPT"
    if [ "$answer" = ask ]; then
      # Read from the terminal, not stdin, so it also works when the script is piped.
      if { : </dev/tty; } 2>/dev/null; then
        say "Claude's builders write and change files in this folder while they work."
        say "Let them do that without asking you each time? Runs can then finish while you are away."
        say "You can change this later in .claude/settings.json."
        printf '%s ' "Allow edits without asking? [y/N]"
        reply=""
        IFS= read -r reply </dev/tty || reply=""
        reply=$(printf '%s' "$reply" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        case "$reply" in
          y|Y|yes|Yes|YES) answer=yes ;;
          *) answer=no ;;
        esac
      else
        answer=none
      fi
    fi
    case "$answer" in
      yes)
        if json_mode set; then
          changed; say "ok: Claude can edit files in this folder without asking (acceptEdits)"
        else
          say "NOTE: could not update .claude/settings.json, so I left it alone."
          edits_by_hand
        fi ;;
      no) say "ok: Claude will ask before each file edit. To change later, run this installer again with --accept-edits" ;;
      *) say "skipped: no terminal to ask on. To allow edits without asking, run this installer again with --accept-edits" ;;
    esac ;;
  3) say "NOTE: .claude/settings.json is not valid JSON, so I left edit approval alone."
     edits_by_hand ;;
  98) say "skipped: there is no .claude/settings.json to change."
     edits_by_hand ;;
  *) say "NOTE: I need node or python3 to change .claude/settings.json, so I left edit approval alone."
     edits_by_hand ;;
esac

# 5. .gitignore
GI="$DEST/.gitignore"
added=0
for line in .claude/codex-quota/ .m7/; do
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
if command -v codex >/dev/null 2>&1; then
  say "ok: codex found"
else
  say "NOTE: codex not found. Install it:  npm i -g @openai/codex   (Mac also: brew install codex)"
fi

# 8. Done
say ""
say "Module 7 is installed."
if [ "$CHANGED" = 0 ]; then say "Nothing changed this time. It was already up to date."; fi
say "Next:"
say "  1. Sign in to Codex with ChatGPT if you have not yet: run  codex login"
say "  2. Start Claude Code in this folder and choose Opus."
say "  3. Paste a prompt from test-prompt.md."
