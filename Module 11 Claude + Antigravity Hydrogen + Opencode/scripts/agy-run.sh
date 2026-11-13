#!/usr/bin/env bash
# agy-run.sh: run ONE task on ONE Antigravity (agy) model and print a short report.
# The main session runs this directly with Bash (run_in_background: true). No relay subagent.
#
# Usage:
#   scripts/agy-run.sh --model <alias> --task <slug> --owns "<comma list|none>" --brief <file> [--worktree <path>]
#   scripts/agy-run.sh --status
#
# Aliases -> agy model ids (edit alias_id below and CLAUDE.md together):
#   hydrogen        -> gemini-4-hydrogen-high    DEFAULT BUILDER. --owns none is refused
#   hydrogen-high   -> gemini-4-hydrogen-high    same as hydrogen
#   hydrogen-medium -> gemini-4-hydrogen-medium  builds, lighter effort
#   hydrogen-low    -> gemini-4-hydrogen-low     builds, trivial work
#   hydrogen-xhigh  -> gemini-4-hydrogen-xhigh   builds, heaviest Hydrogen effort
#   flash-high -> gemini-3.8-flash-high      last-resort exact-spec builder (Hydrogen and OpenCode build drained). --owns none is refused
#   flash      -> gemini-3.8-flash-medium    read-only scouting. --owns must be none
#   flash-low  -> gemini-3.8-flash-low       read-only lookups. --owns must be none
#   argon      -> gemini-4-argon-medium      hard builds and fix steps
#   argon-high -> gemini-4-argon-high        the hardest builds
#   argon-low  -> gemini-4-argon-low         trivial work
#   sonnet     -> claude-sonnet-5-5-medium   fix tasks only: slug ends in -r1..-r5 and --owns is not none
#   opus       -> claude-opus-5-5-medium     fix tasks only: same rule
# One model per call. There is no chain walk: the main session re-routes.
#
# Exit codes:
#   0 success (report printed)
#   1 other error: login, crash, timeout (last 20 log lines printed)
#   2 agy missing, bad arguments, refused alias or combination, or model id not in `agy models`
#   3 drained: first output line is "drained: <model-id> until <UTC ISO>", then the report
#     (owned files may be partly edited)
#   4 suspected concurrency limit: first line "concurrency: <quoted text>". No marker is written
#
# Markers: .claude/agy-quota/<model-id>, two lines: until=<UTC ISO>, reason=<line>. Active while now < until.
# until = the reset time parsed from the output, else now + 6 hours (a guess: agy reset times are unpublished).
# Legacy markers (one line, a bare ISO time) count as active for 6 hours from that time.
# With --status: prints active markers and "agy: N models limited". Always exit 0.
#
# Limit rules. rc != 0: any QUOTA_RE match in the log = limit hit. rc == 0: a limit only when a short log
# (under 40 lines) has a matching line that also contains "error" AND the owned files did not gain changed
# lines during the run (read-only tasks: just the error match).
# Concurrency: CONC_RE matches in the log AND (rc != 0, or a short log with no gain in owned changed lines).
# The wording of agy's concurrency and quota errors is UNVERIFIED.
# Timeout: RUN_TIMEOUT seconds (default 1800, 0 = off) when `timeout` or `gtimeout` exists.
#
# agy -p --mode accept-edits allows file edits but DENIES shell commands. The model cannot run tests or
# linters. The brief tells it so. The reviewer runs the read-only checks.
# NEVER add --dangerously-skip-permissions (auto mode blocks it). If a run stalls on a permission check,
# stop and report. Do not look for a way around it.
set -euo pipefail

# ---- Flags (confirmed on the user's machine; `agy` has no -m flag) ----
AGY_BIN="agy"
FLAG_PROMPT="-p"
FLAG_MODEL="--model"
MODE_ARGS=(--mode accept-edits --print-timeout 0)

# ---- Tunables ----
LIMIT_DEFAULT=21600                 # seconds a drained model stays skipped when no reset time is found (6h, a guess)
DAY=86400
RUN_TIMEOUT=1800                    # seconds per run; 0 = off. Needs `timeout` (or `gtimeout` on macOS)
QUOTA_RE='rate.?limit|429|quota|usage limit|limit reached|exhausted|too many requests|try again later|FreeUsageLimit|resource_exhausted|not available to'
CONC_RE='concurrent|too many sessions|another session|already running|locked'

alias_id() {   # prints the agy model id for an alias, or returns 1
  case "$1" in
    hydrogen|hydrogen-high) echo "gemini-4-hydrogen-high" ;;
    hydrogen-medium) echo "gemini-4-hydrogen-medium" ;;
    hydrogen-low)    echo "gemini-4-hydrogen-low" ;;
    hydrogen-xhigh)  echo "gemini-4-hydrogen-xhigh" ;;
    flash-high) echo "gemini-3.8-flash-high" ;;
    flash)      echo "gemini-3.8-flash-medium" ;;
    flash-low)  echo "gemini-3.8-flash-low" ;;
    argon)      echo "gemini-4-argon-medium" ;;
    argon-high) echo "gemini-4-argon-high" ;;
    argon-low)  echo "gemini-4-argon-low" ;;
    sonnet)     echo "claude-sonnet-5-5-medium" ;;
    opus)       echo "claude-opus-5-5-medium" ;;
    *) return 1 ;;
  esac
}

die() { echo "$*" >&2; exit "${2:-2}"; }

ROOT="$PWD"                         # markers always live here, even in worktree mode
QDIR="$ROOT/.claude/agy-quota"
LOGDIR="$ROOT/.m11/logs"

# ---- Time helpers (GNU date, with a macOS/BSD fallback) ----
to_epoch() { date -u -d "$1" +%s 2>/dev/null || date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null || true; }
to_iso()   { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ; }
fmt_remaining() {
  local s=$1 d h m out=""
  [ "$s" -lt 0 ] && s=0
  d=$((s / 86400)); h=$(((s % 86400) / 3600)); m=$(((s % 3600) / 60))
  [ "$d" -gt 0 ] && out="${d}d "
  { [ "$d" -gt 0 ] || [ "$h" -gt 0 ]; } && out="$out${h}h "
  echo "$out${m}m"
}
marker_until() {    # prints the until time (UTC ISO) if the model's marker is active, else nothing
  local f="$QDIR/$1" u e
  [ -f "$f" ] || return 0
  u=$(sed -n 's/^until=//p' "$f" | head -n 1 | tr -d '\r')
  if [ -n "$u" ]; then
    e=$(to_epoch "$u")
  else                                # legacy marker: one bare ISO time, active for 6 hours from it
    u=$(head -n 1 "$f" | tr -d '\r')
    e=$(to_epoch "$u")
    [[ "$e" =~ ^[0-9]+$ ]] || return 0
    e=$((e + LIMIT_DEFAULT)); u=$(to_iso "$e")
  fi
  [[ "$e" =~ ^[0-9]+$ ]] || return 0
  [ "$(date +%s)" -lt "$e" ] && echo "$u"
  return 0
}

if [ "${1:-}" = "--status" ]; then
  mkdir -p "$QDIR"
  n=0; now=$(date +%s)
  for f in "$QDIR"/*; do
    [ -f "$f" ] || continue
    id=${f##*/}
    case "$id" in .tmp.*) continue ;; esac
    u=$(marker_until "$id")
    [ -n "$u" ] || continue
    n=$((n + 1))
    why=$(sed -n 's/^reason=//p' "$f" | head -n 1 | tr -d '\r')
    [ -n "$why" ] || why="legacy marker"
    echo "  $id limited until $u (remaining $(fmt_remaining $(( $(to_epoch "$u") - now )))). reason: $why"
  done
  echo "agy: $n models limited"
  exit 0
fi

# ---- Arguments ----
MODEL="" TASK="" OWNS="" BRIEF="" WORKTREE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --model)    MODEL="${2:-}"; shift 2 ;;
    --task)     TASK="${2:-}"; shift 2 ;;
    --owns)     OWNS="${2:-}"; shift 2 ;;
    --brief)    BRIEF="${2:-}"; shift 2 ;;
    --worktree) WORKTREE="${2:-}"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$MODEL" ] && [ -n "$TASK" ] && [ -n "$OWNS" ] && [ -n "$BRIEF" ] \
  || die "usage: agy-run.sh --model <alias> --task <slug> --owns \"<list|none>\" --brief <file> [--worktree <path>] | --status"
[[ "$TASK" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "bad --task slug (use lowercase letters, digits, dashes): $TASK"
[ -f "$BRIEF" ] || die "brief not found: $BRIEF"

# ---- Owned pathspecs ----
OWNED=(); READONLY=0
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

# ---- Refusals (exit 2, nothing runs) ----
ID=$(alias_id "$MODEL") || die "refused: model not allowed in this module ($MODEL)"
case "$MODEL" in
  hydrogen|hydrogen-*)
    [ $READONLY -eq 0 ] || die "refused: $MODEL builds need a real --owns list (use OpenCode scout or flash for read-only scouting)" ;;
  flash-high)
    [ $READONLY -eq 0 ] || die "refused: flash-high builds need a real --owns list (use flash for read-only scouting)"
    if [[ "$TASK" =~ -r[1-9]$ ]]; then die "refused: Flash never fixes or reviews (slug $TASK looks like a fix round)"; fi ;;
  flash|flash-low)
    [ $READONLY -eq 1 ] || die "refused: $MODEL is read-only scouting, --owns must be none" ;;
  sonnet|opus)
    if [ $READONLY -eq 1 ] || ! [[ "$TASK" =~ -r[1-5]$ ]]; then die "refused: sonnet/opus are fix-only (slug ends in -r1..-r5, owns is not none)"; fi ;;
esac

# ---- Preflight ----
command -v "$AGY_BIN" >/dev/null 2>&1 || die "agy not installed"
RUNDIR="$ROOT"; [ -n "$WORKTREE" ] && RUNDIR="$WORKTREE"
[ -d "$RUNDIR" ] || die "run dir not found: $RUNDIR"
# The model id must be listed by `agy models`. If that command fails or prints nothing, skip the check.
MODELS_OUT=$("$AGY_BIN" models < /dev/null 2>/dev/null || true)
if [ -n "$MODELS_OUT" ] && ! printf '%s\n' "$MODELS_OUT" | grep -Fq -- "$ID"; then
  die "unavailable: $MODEL ($ID not in agy models)"
fi
mkdir -p "$QDIR" "$LOGDIR"
TMO=""
if [[ "$RUN_TIMEOUT" =~ ^[0-9]+$ ]] && [ "$RUN_TIMEOUT" -gt 0 ]; then
  if command -v timeout >/dev/null 2>&1; then TMO=timeout
  elif command -v gtimeout >/dev/null 2>&1; then TMO=gtimeout; fi
fi

# ---- Marker check: a drained model is not run ----
u=$(marker_until "$ID")
if [ -n "$u" ]; then
  echo "drained: $ID until $u (marker)"
  exit 3
fi

BEFORE="$LOGDIR/agy-before-$TASK.txt"; AFTER="$LOGDIR/agy-after-$TASK.txt"
BRIEF_OUT="$LOGDIR/agy-brief-$TASK.md"; LOG="$LOGDIR/agy-log-$TASK.txt"
: > "$LOG"                          # no stale log from an earlier run of the same task slug
IS_GIT=0
git -C "$RUNDIR" rev-parse --git-dir >/dev/null 2>&1 && IS_GIT=1
if [ $IS_GIT -eq 1 ]; then git -C "$RUNDIR" status --short | sort > "$BEFORE"; else : > "$BEFORE"; fi

build_brief() {
  {
    echo "Read AGENTS.md first and follow it."
    echo "task: $TASK"
    echo "owns: $OWNS"
    [ $READONLY -eq 1 ] && echo "Read-only: do not edit any file."
    echo "You cannot run shell commands in this mode. Do not try. List any check you could not run in your report."
    echo
    cat "$BRIEF"
  } > "$BRIEF_OUT"
}

write_marker() {   # $1 model id  $2 until epoch  $3 reason. Atomic: temp file in the same dir, then mv
  local t
  t=$(mktemp "$QDIR/.tmp.XXXXXX")
  { echo "until=$(to_iso "$2")"; echo "reason=$3"; } > "$t"
  mv -f "$t" "$QDIR/$1"
}

# parse_reset <logfile>: prints a reset time as epoch seconds, or nothing. Best effort.
# agy error wording is UNVERIFIED; handles "try again at <date>", "try again in 2 hours 3 minutes", "in 1h 30m".
parse_reset() {
  local seg n=0 e="" now
  now=$(date +%s)
  seg=$(grep -Eio '(resets? (at|after)|try again at|retry at) +[^.;]{3,40}' "$1" | head -n 1 \
    | sed -E 's/^(resets? (at|after)|try again at|retry at) +//I' | tr -d ',' || true)
  if [ -n "$seg" ]; then
    e=$(date -d "$seg" +%s 2>/dev/null || date -j -f "%d %b %Y %H:%M" "$seg" +%s 2>/dev/null || true)
    [[ "$e" =~ ^[0-9]+$ ]] && n=$((e - now))
  fi
  if [ "$n" -le 0 ]; then
    n=0
    seg=$(grep -Eio '(try again|retry|resets?)[^0-9]{0,12}[0-9][0-9a-z :,]{0,30}' "$1" | head -n 1 || true)
    if [[ "$seg" =~ ([0-9]+)\ *(d|days?)([^a-z]|$) ]]; then n=$((n + BASH_REMATCH[1] * 86400)); fi
    if [[ "$seg" =~ ([0-9]+)\ *(h|hrs?|hours?)([^a-z]|$) ]]; then n=$((n + BASH_REMATCH[1] * 3600)); fi
    if [[ "$seg" =~ ([0-9]+)\ *(m|mins?|minutes?)([^a-z]|$) ]]; then n=$((n + BASH_REMATCH[1] * 60)); fi
  fi
  if [ "$n" -ge 60 ] && [ "$n" -le $((30 * DAY)) ]; then echo $((now + n)); fi
  return 0
}

changed_lines() {
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

report() {   # $1 = model that ran (id) or "none (drained)"
  echo "task: $TASK"
  echo "model requested: $MODEL ($ID)"
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
    local ex=(":(exclude).claude/agy-quota" ":(exclude).claude/opencode-quota" ":(exclude).m11") p
    if [ ${#OWNED[@]} -gt 0 ]; then
      for p in "${OWNED[@]}"; do ex+=(":(exclude)$p"); done
    fi
    git -C "$RUNDIR" status --short -- . "${ex[@]}" | sort > "$AFTER"
    local out
    out=$(comm -13 "$BEFORE" "$AFTER" || true)
    if [ -n "$out" ]; then
      if [ $READONLY -eq 1 ]; then echo "read-only task changed files:"
      elif [ -n "$WORKTREE" ]; then echo "outside owned files (the model left its scope):"
      else echo "outside owned files (possibly from other parallel tasks):"; fi
      echo "$out" | sed 's/^/  /'
    else
      echo "outside owned files: none"
    fi
  fi
  echo "--- model output (last 40 lines) ---"
  if [ -s "$LOG" ]; then tail -n 40 "$LOG"; else echo "(none)"; fi
}

# ---- Run ----
build_brief
cl_before=$(changed_lines)
cmd=("$AGY_BIN" "$FLAG_PROMPT" "$(cat "$BRIEF_OUT")" "$FLAG_MODEL" "$ID" "${MODE_ARGS[@]}")
[ -n "$TMO" ] && cmd=("$TMO" "$RUN_TIMEOUT" "${cmd[@]}")
rc=0
(cd "$RUNDIR" && "${cmd[@]}") > "$LOG" 2>&1 < /dev/null || rc=$?

# ---- Classify ----
if [ $rc -eq 124 ] && [ -n "$TMO" ]; then
  echo "agy timed out on $ID after ${RUN_TIMEOUT}s (possibly waiting on a permission prompt). Last 20 log lines:"
  tail -n 20 "$LOG"
  exit 1
fi

loglines=$(wc -l < "$LOG" | tr -d ' ')
gained=1; [ "$(changed_lines)" -le "$cl_before" ] && gained=0

# Concurrency. For exit 0 the log must be short too, so a long normal answer that mentions "locked" is not flagged.
cline=$(grep -Ei "$CONC_RE" "$LOG" | head -n 1 | tr -d '\r' | cut -c1-160 || true)
if [ -n "$cline" ]; then
  if [ $rc -ne 0 ] || { [ "$loglines" -lt 40 ] && [ $gained -eq 0 ]; }; then
    echo "concurrency: $cline"
    echo "possible concurrency limit. No marker written."
    exit 4
  fi
fi

limited=0
qline=$(grep -Ei "$QUOTA_RE" "$LOG" | head -n 1 | tr -d '\r' | cut -c1-160 || true)
if [ $rc -ne 0 ]; then
  [ -n "$qline" ] && limited=1
elif [ "$loglines" -lt 40 ]; then
  # exit 0 is a normal answer unless a short log has an error line with a limit word and nothing was written
  qline=$(grep -Ei "$QUOTA_RE" "$LOG" | grep -Ei 'error' | head -n 1 | tr -d '\r' | cut -c1-160 || true)
  if [ -n "$qline" ]; then
    if [ $READONLY -eq 1 ] || [ $gained -eq 0 ]; then limited=1; fi
  fi
fi

if [ $limited -eq 1 ]; then
  now=$(date +%s)
  reset=$(parse_reset "$LOG")
  until_e=$((now + LIMIT_DEFAULT)); [ -n "$reset" ] && until_e=$reset   # 6h default is a guess
  write_marker "$ID" "$until_e" "$qline"
  echo "drained: $ID until $(to_iso "$until_e")"
  report "none (drained)"
  exit 3
fi

if [ $rc -ne 0 ]; then
  echo "agy failed on $ID (exit $rc). Last 20 log lines:"
  tail -n 20 "$LOG"
  exit 1
fi

report "$ID"
exit 0
