#!/usr/bin/env bash
# codex-run.sh: run ONE task on a Codex model (ChatGPT sign-in) and print a short report.
# Opus runs this directly with Bash (run_in_background: true). No relay subagent.
#
# Usage:
#   scripts/codex-run.sh --model <alias[-effort]|full-id> --task <slug> \
#       --owns "<comma list|none>" --brief <file> [--worktree <path>] [--effort <level>]
#   scripts/codex-run.sh --status      (print active limit markers; no other arguments)
#
# The Codex plan has TWO limits, a 5-hour limit and a weekly limit, both shared by all Codex
# models (one pool). There is no Codex-to-Codex fallback. Each limit has its own marker in
# .claude/codex-quota/ (5h, weekly). Each marker holds two lines: until=<UTC ISO>, reason=<line>.
# A marker is active while now < until. Weekly takes precedence over 5h. A leftover old
# single "codex" marker file is ignored.
#
# Exit codes:
#   0 success (report printed)    1 other error (last 20 log lines printed)
#   2 codex not installed or bad arguments
#   3 5-hour limit hit or active: prints "drained: codex 5h limit until <time>"
#   4 suspected concurrency limit (no marker written)
#   5 weekly limit hit or active: prints "drained: codex weekly limit until <time>"
# With --status: 0 none active, 3 only 5h active, 5 weekly active.
# On a limit hit during a run, the report (with partial edits) is still printed.
set -euo pipefail

# ---- Flags (from third-party docs; verify with `codex exec --help` on first run) ----
# NEVER add a flag that bypasses the sandbox or approvals (for example
# --dangerously-bypass-approvals-and-sandbox or --yolo). Not here, not ever.
CODEX_BIN="codex"
FLAG_MODEL="-m"
FLAG_EFFORT_KEY="model_reasoning_effort"   # passed as: -c model_reasoning_effort=<level>
FLAG_SANDBOX="--sandbox"
SANDBOX_WRITE="workspace-write"
SANDBOX_READ="read-only"
FLAG_OUT="-o"                              # writes the final message to a file

# ---- Tunables ----
FIVE_H=18000                               # seconds: the 5-hour window
DAY=86400                                  # weekly limit: re-check every 24 hours
WEEKLY_RE='week|weekly|7 days|7-day'
FIVEH_RE='5-hour|5 hour|5h limit'
CONCURRENCY_RE='concurrent|too many sessions|already running|locked'
QUOTA_RE='quota|rate limit|usage limit|limit reached|429|exhausted|try again later'

# Model IDs. Edit IDs here and in CLAUDE.md together.
ID_LUNA="gpt-6-luna"
ID_TERRA="gpt-6.1-terra"
ID_SOL="gpt-6.1-sol"
# Astra (gpt-6-astra) is deliberately not used.

die() { echo "$*" >&2; exit "${2:-2}"; }

ROOT="$PWD"                                 # the quota markers always live here, even in worktree mode
QDIR="$ROOT/.claude/codex-quota"

# ---- Time helpers (GNU date, with a macOS/BSD fallback) ----
to_epoch() {      # UTC ISO "YYYY-MM-DDTHH:MM:SSZ" -> epoch seconds (empty on failure)
  date -u -d "$1" +%s 2>/dev/null \
    || date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null \
    || true
}
to_iso() {        # epoch seconds -> UTC ISO
  date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ
}
fmt_remaining() { # seconds -> "1d 2h 5m"
  local s=$1 d h m out=""
  [ "$s" -lt 0 ] && s=0
  d=$((s / 86400)); h=$(((s % 86400) / 3600)); m=$(((s % 3600) / 60))
  [ "$d" -gt 0 ] && out="${d}d "
  { [ "$d" -gt 0 ] || [ "$h" -gt 0 ]; } && out="$out${h}h "
  echo "$out${m}m"
}

# marker_until <kind>: prints the until time (UTC ISO) if the marker is active, else nothing.
marker_until() {
  local f="$QDIR/$1" u e
  [ -f "$f" ] || return 0
  u=$(sed -n 's/^until=//p' "$f" | head -n 1)
  e=$(to_epoch "$u")
  [[ "$e" =~ ^[0-9]+$ ]] || return 0         # unparseable marker: ignored
  [ "$(date +%s)" -lt "$e" ] && echo "$u"
  return 0
}

if [ "${1:-}" = "--status" ]; then
  rc=0
  W=$(marker_until weekly); H=$(marker_until 5h); now=$(date +%s)
  if [ -n "$H" ]; then
    echo "5h limit active until $H (remaining $(fmt_remaining $(( $(to_epoch "$H") - now )))). $(sed -n 's/^reason=/reason: /p' "$QDIR/5h" | head -n 1)"
    rc=3
  fi
  if [ -n "$W" ]; then
    echo "weekly limit active until $W (remaining $(fmt_remaining $(( $(to_epoch "$W") - now )))). $(sed -n 's/^reason=/reason: /p' "$QDIR/weekly" | head -n 1)"
    rc=5
  fi
  [ $rc -eq 0 ] && echo "no codex limit active"
  exit $rc
fi

# ---- Arguments ----
MODEL_ARG="" TASK="" OWNS="" BRIEF="" WORKTREE="" EFFORT_FLAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --model)       MODEL_ARG="${2:-}"; shift 2 ;;
    --task)        TASK="${2:-}"; shift 2 ;;
    --owns)        OWNS="${2:-}"; shift 2 ;;
    --brief)       BRIEF="${2:-}"; shift 2 ;;
    --worktree)    WORKTREE="${2:-}"; shift 2 ;;
    --effort)      EFFORT_FLAG="${2:-}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$MODEL_ARG" ] && [ -n "$TASK" ] && [ -n "$OWNS" ] && [ -n "$BRIEF" ] \
  || die "usage: codex-run.sh --model <alias[-effort]|full-id> --task <slug> --owns \"<list|none>\" --brief <file> [--worktree <path>] [--effort <level>]"
[[ "$TASK" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "bad --task slug (use lowercase letters, digits, dashes): $TASK"
[ -f "$BRIEF" ] || die "brief not found: $BRIEF"

# ---- Preflight ----
command -v "$CODEX_BIN" >/dev/null 2>&1 || die "codex not installed" 2
mkdir -p "$QDIR"
RUNDIR="$ROOT"
[ -n "$WORKTREE" ] && RUNDIR="$WORKTREE"
[ -d "$RUNDIR" ] || die "run dir not found: $RUNDIR"

# ---- Resolve model alias and effort ----
EFFORT="medium"
if [[ "$MODEL_ARG" =~ ^(luna|terra|sol)(-(low|medium|high|xhigh))?$ ]]; then
  BASE="${BASH_REMATCH[1]}"
  [ -n "${BASH_REMATCH[3]}" ] && EFFORT="${BASH_REMATCH[3]}"
  case "$BASE" in
    luna)  MODEL="$ID_LUNA" ;;
    terra) MODEL="$ID_TERRA" ;;
    sol)   MODEL="$ID_SOL" ;;
  esac
else
  MODEL="$MODEL_ARG"                        # full model id
fi
[ -n "$EFFORT_FLAG" ] && EFFORT="$EFFORT_FLAG"
case "$EFFORT" in low|medium|high|xhigh) ;; *) die "bad effort: $EFFORT (low, medium, high, xhigh)" ;; esac

# ---- Owned pathspecs ----
OWNED=()
READONLY=0
if [ "$OWNS" = "none" ]; then
  READONLY=1
else
  IFS=',' read -ra _parts <<< "$OWNS"
  for p in "${_parts[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"; p="${p%"${p##*[![:space:]]}"}"
    [ -n "$p" ] && OWNED+=("$p")
  done
  [ ${#OWNED[@]} -gt 0 ] || die "--owns is empty (use \"none\" for read-only)"
fi

BEFORE="/tmp/codex-before-$TASK.txt"
AFTER="/tmp/codex-after-$TASK.txt"
BRIEF_OUT="/tmp/codex-brief-$TASK.md"
LOG="/tmp/codex-log-$TASK.txt"
LAST="/tmp/codex-last-$TASK.md"

IS_GIT=0
git -C "$RUNDIR" rev-parse --git-dir >/dev/null 2>&1 && IS_GIT=1
if [ $IS_GIT -eq 1 ]; then
  git -C "$RUNDIR" status --short | sort > "$BEFORE"
else
  : > "$BEFORE"
fi

# ---- Build the brief ----
{
  echo "Read AGENTS.md first and follow it."
  echo "task: $TASK"
  echo "owns: $OWNS"
  [ $READONLY -eq 1 ] && echo "Read-only: do not edit any file."
  echo
  cat "$BRIEF"
} > "$BRIEF_OUT"

# ---- Helpers ----
write_marker() {   # $1 kind (5h|weekly)  $2 until epoch  $3 reason. Atomic: temp file in the same dir, then mv
  local t
  t=$(mktemp "$QDIR/.tmp.XXXXXX")
  { echo "until=$(to_iso "$2")"; echo "reason=$3"; } > "$t"
  mv -f "$t" "$QDIR/$1"
}

# parse_reset <logfile>: prints a reset time as epoch seconds, or nothing. Best effort only.
# Known real wordings (the full set is still unconfirmed, the raw line is printed in the report):
#   "...or try again at 20 Aug 2026, 16:29."          absolute, local time zone, "%d %b %Y, %H:%M"
#   "...or try again in 2 hours 3 minutes."           relative (N days / hours / minutes)
#   "You've reached your 5-hour work usage limit"     names the window, no time
# Also handles "in 1h 30m" and "resets in 3 days". On any failure it prints nothing.
# Interactive Codex `/status` shows both "5h limit" and "Weekly limit" with reset times;
# the usage page is chatgpt.com/codex/settings/usage.
parse_reset() {
  local seg n=0 e="" now
  now=$(date +%s)
  # 1) absolute: "try again at <date time>" / "resets at|after <time>"
  seg=$(grep -Eio '(resets? (at|after)|try again at|retry at) +[^.;]{3,40}' "$1" | head -n 1 \
    | sed -E 's/^(resets? (at|after)|try again at|retry at) +//I' | tr -d ',' || true)
  if [ -n "$seg" ]; then
    e=$(date -d "$seg" +%s 2>/dev/null \
      || date -j -f "%d %b %Y %H:%M" "$seg" +%s 2>/dev/null || true)   # GNU, then macOS
    [[ "$e" =~ ^[0-9]+$ ]] && n=$((e - now))
  fi
  # 2) relative: "try again in 2 hours 3 minutes", "resets in 3 days", "in 1h 30m"
  if [ "$n" -le 0 ]; then
    n=0
    seg=$(grep -Eio '(try again|retry|resets?)[^0-9]{0,12}[0-9][0-9a-z :,]{0,30}' "$1" | head -n 1 || true)
    if [[ "$seg" =~ ([0-9]+)\ *(d|days?)([^a-z]|$) ]]; then n=$((n + BASH_REMATCH[1] * 86400)); fi
    if [[ "$seg" =~ ([0-9]+)\ *(h|hrs?|hours?)([^a-z]|$) ]]; then n=$((n + BASH_REMATCH[1] * 3600)); fi
    if [[ "$seg" =~ ([0-9]+)\ *(m|mins?|minutes?)([^a-z]|$) ]]; then n=$((n + BASH_REMATCH[1] * 60)); fi
  fi
  # sanity: between 1 minute and 60 days ahead
  if [ "$n" -ge 60 ] && [ "$n" -le $((60 * DAY)) ]; then echo $((now + n)); fi
  return 0
}

limit_exit() {   # $1 kind $2 until ISO: print the drained line and exit with the right code
  if [ "$1" = weekly ]; then echo "drained: codex weekly limit until $2"; exit 5; fi
  echo "drained: codex 5h limit until $2"; exit 3
}

changed_lines() {  # added + removed on owned files, plus lines in new untracked owned files
  local n=0 a r f
  [ $IS_GIT -eq 1 ] && [ ${#OWNED[@]} -gt 0 ] || { echo 0; return; }
  while read -r a r _; do
    [[ "$a" =~ ^[0-9]+$ ]] && n=$((n + a))
    [[ "$r" =~ ^[0-9]+$ ]] && n=$((n + r))
  done < <(git -C "$RUNDIR" diff --numstat -- "${OWNED[@]}" 2>/dev/null || true)
  while IFS= read -r f; do
    [ -f "$RUNDIR/$f" ] && n=$((n + $(wc -l < "$RUNDIR/$f")))
  done < <(git -C "$RUNDIR" ls-files --others --exclude-standard -- "${OWNED[@]}" 2>/dev/null || true)
  echo "$n"
}

report() {   # $1 = model that ran (or "none")
  echo "task: $TASK"
  echo "model requested: $MODEL_ARG (effort $EFFORT)"
  echo "model that ran: $1"
  if [ $IS_GIT -eq 0 ]; then
    echo "not a git repo: no diff or change count"
  else
    echo "changed lines (owned): $(changed_lines)"
    if [ ${#OWNED[@]} -gt 0 ]; then
      echo "diff stat (owned):"
      git -C "$RUNDIR" diff --stat -- "${OWNED[@]}" | sed 's/^/  /'
      git -C "$RUNDIR" status --short -- "${OWNED[@]}" | sed 's/^/  /'
    fi
    local ex=(":(exclude).claude/codex-quota")
    for p in "${OWNED[@]}"; do ex+=(":(exclude)$p"); done
    git -C "$RUNDIR" status --short -- . "${ex[@]}" | sort > "$AFTER"
    local out
    out=$(comm -13 "$BEFORE" "$AFTER" || true)
    if [ -n "$out" ]; then
      if [ -n "$WORKTREE" ]; then echo "outside owned files (codex left its scope):"
      else echo "outside owned files (possibly from other parallel tasks):"; fi
      echo "$out" | sed 's/^/  /'
    else
      echo "outside owned files: none"
    fi
  fi
  echo "--- codex final message (first 40 lines) ---"
  if [ -s "$LAST" ]; then head -n 40 "$LAST"; else echo "(none)"; fi
}

# ---- Run once ----
W=$(marker_until weekly); H=$(marker_until 5h)
[ -n "$W" ] && limit_exit weekly "$W"          # weekly takes precedence over 5h
[ -n "$H" ] && limit_exit 5h "$H"

rm -f "$LAST"                               # no stale final message from an earlier run
SANDBOX="$SANDBOX_WRITE"; [ $READONLY -eq 1 ] && SANDBOX="$SANDBOX_READ"
rc=0
(cd "$RUNDIR" && "$CODEX_BIN" exec "$FLAG_MODEL" "$MODEL" -c "$FLAG_EFFORT_KEY=$EFFORT" \
    "$FLAG_SANDBOX" "$SANDBOX" "$FLAG_OUT" "$LAST" - < "$BRIEF_OUT") > "$LOG" 2>&1 || rc=$?

if [ $rc -eq 0 ]; then
  report "$MODEL"
  exit 0
fi

if grep -Eiq "$CONCURRENCY_RE" "$LOG"; then
  echo "suspected concurrency limit on $MODEL (no marker written). Log excerpt:"
  grep -Ei "$CONCURRENCY_RE" "$LOG" | head -n 3
  exit 4
fi

if grep -Eiq "$QUOTA_RE" "$LOG"; then
  now=$(date +%s)
  reset=$(parse_reset "$LOG")
  reason=$(grep -Ei "$QUOTA_RE" "$LOG" | head -n 1 | tr -d '\r' | cut -c1-160)
  # "week"/"weekly" forces weekly; "5-hour" forces 5h; otherwise a reset more than 5 hours away is weekly.
  if grep -Eiq "$WEEKLY_RE" "$LOG" \
     || { ! grep -Eiq "$FIVEH_RE" "$LOG" && [ -n "$reset" ] && [ $((reset - now)) -gt $FIVE_H ]; }; then
    kind=weekly; until_e=$((now + DAY))      # weekly: re-check daily
    [ -n "$reset" ] && [ "$reset" -lt "$until_e" ] && until_e=$reset
  else
    kind=5h; until_e=$((now + FIVE_H))
    [ -n "$reset" ] && until_e=$reset
  fi
  write_marker "$kind" "$until_e" "$reason"
  if [ "$kind" = weekly ]; then echo "drained: codex weekly limit until $(to_iso "$until_e")"
  else echo "drained: codex 5h limit until $(to_iso "$until_e")"; fi
  echo "reason: $reason"
  report "none (stopped on quota; owned files may be partly edited)"
  [ "$kind" = weekly ] && exit 5
  exit 3
fi

echo "codex failed on $MODEL (exit $rc). Last 20 log lines:"
tail -n 20 "$LOG"
exit 1
