#!/usr/bin/env bash
# agy-run.sh: run ONE task on an Antigravity (agy) model, walking the fallback chain when a model is
# drained, and print a short report. The main session runs this directly with Bash (run_in_background: true).
# No relay subagent.
#
# Usage:
#   scripts/agy-run.sh --model <alias[-low|-medium|-high]> --task <slug> --owns "<comma list|none>" \
#                      --brief <file> [--no-fallback] [--worktree <path>]
#   scripts/agy-run.sh --status
#
# The brief file is body-only. This script adds "Read AGENTS.md first", task:, owns:, the read-only line
# and the no-shell line. NEVER send a design task here (design belongs to the Claude builders; CLAUDE.md
# says so, this script cannot see it).
#
# Aliases, effort suffix and chains are in ONE block below (MODEL TABLE). Keep CLAUDE.md in step with it.
#
# Exit codes:
#   0 success (report printed, includes a "fallbacks:" line)
#   1 other error: login, crash, timeout (last 20 log lines printed). No fallback
#   2 agy missing, bad arguments, refused, or the model id is not in `agy models` (nothing ran)
#   3 drained. First line "drained: <model-id>, no fallback" in no-fallback mode (and always for a Flash
#     build), else "drained: all models drained or unavailable" plus what was tried. Owned files may be
#     partly edited
#   4 suspected concurrency limit: first line "concurrency: <quoted text>". No marker, no fallback
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

# ---- Run folder (one variable) ----
RUN_DIR=".m6"

# ---- Tunables ----
LIMIT_DEFAULT=21600                 # seconds a drained model stays skipped when no reset time is found (6h, a guess)
DAY=86400
RUN_TIMEOUT="${AGY_RUN_TIMEOUT:-1800}"   # seconds per run; 0 = off. Needs `timeout` (or `gtimeout` on macOS)
MAX_FALLBACKS="${AGY_MAX_FALLBACKS:-2}"  # max models taken after the first choice, per task
QUOTA_RE='rate.?limit|429|quota|usage limit|limit reached|exhausted|too many requests|try again later|FreeUsageLimit|resource_exhausted|not available to'
CONC_RE='concurrent|too many sessions|another session|already running|locked'

# =====================================================================================================
# MODEL TABLE: aliases, effort suffix, fallback chains (edit here and the pool table in CLAUDE.md together)
#   alias    -> agy model id (medium effort by default; a -low / -medium / -high suffix on the alias picks
#               that effort, e.g. sonnet-high -> claude-sonnet-5-5-high; a full model id is used as given)
#   argon    -> gemini-4-argon-<effort>        sonnet -> claude-sonnet-5-5-<effort>
#   opus     -> claude-opus-5-5-<effort>       flash  -> gemini-3.8-flash-<effort>
# Chains (builders): argon -> sonnet -> opus.  sonnet -> argon -> opus.  opus -> sonnet -> argon-high.
#   Only the FIRST model takes the requested effort; later models are the ids written below.
#   Read-only Flash scout: flash -> argon-low -> stop.  A Flash build has no chain.
#   Never walk to a Claude-plan model: Claude work is the main session's call.
# =====================================================================================================
alias_prefix() {   # prints the model id prefix for an alias base, or returns 1
  case "$1" in
    argon)  echo "gemini-4-argon-" ;;
    sonnet) echo "claude-sonnet-5-5-" ;;
    opus)   echo "claude-opus-5-5-" ;;
    flash)  echo "gemini-3.8-flash-" ;;
    *) return 1 ;;
  esac
}
family_of_id() {   # prints the chain family of a model id, or "other"
  case "$1" in
    gemini-4-argon-*)     echo argon ;;
    claude-sonnet-5-5-*)  echo sonnet ;;
    claude-opus-5-5-*)    echo opus ;;
    gemini-3.8-flash-*)   echo flash ;;
    *) echo other ;;
  esac
}
chain_for() {      # $1 family  $2 requested id  $3 read-only (1/0). Prints the chain, one model id per line
  case "$1" in
    argon)  echo "$2"; echo "claude-sonnet-5-5-medium"; echo "claude-opus-5-5-medium" ;;
    sonnet) echo "$2"; echo "gemini-4-argon-medium"; echo "claude-opus-5-5-medium" ;;
    opus)   echo "$2"; echo "claude-sonnet-5-5-medium"; echo "gemini-4-argon-high" ;;
    flash)  echo "$2"; if [ "$3" = 1 ]; then echo "gemini-4-argon-low"; fi ;;
    *)      echo "$2" ;;
  esac
}
resolve_model() {  # $1 alias[-effort] or full id. Prints the model id
  local m="$1" base eff="medium" p
  case "$m" in
    *-low)    base="${m%-low}"; eff=low ;;
    *-medium) base="${m%-medium}"; eff=medium ;;
    *-high)   base="${m%-high}"; eff=high ;;
    *)        base="$m" ;;
  esac
  if p=$(alias_prefix "$base"); then echo "${p}${eff}"; else echo "$m"; fi
}
# ======================================== end of MODEL TABLE =========================================

die() { echo "$*" >&2; exit "${2:-2}"; }

ROOT="$PWD"                         # markers always live here, even in worktree mode
QDIR="$ROOT/.claude/agy-quota"
LOGDIR="$ROOT/$RUN_DIR/logs"

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
MODEL="" TASK="" OWNS="" BRIEF="" WORKTREE="" NOFB=0
while [ $# -gt 0 ]; do
  case "$1" in
    --model)       MODEL="${2:-}"; shift 2 ;;
    --task)        TASK="${2:-}"; shift 2 ;;
    --owns)        OWNS="${2:-}"; shift 2 ;;
    --brief)       BRIEF="${2:-}"; shift 2 ;;
    --worktree)    WORKTREE="${2:-}"; shift 2 ;;
    --no-fallback) NOFB=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$MODEL" ] && [ -n "$TASK" ] && [ -n "$OWNS" ] && [ -n "$BRIEF" ] \
  || die "usage: agy-run.sh --model <alias[-low|-medium|-high]> --task <slug> --owns \"<list|none>\" --brief <file> [--no-fallback] [--worktree <path>] | --status"
[[ "$TASK" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "bad --task slug (use lowercase letters, digits, dashes): $TASK"
[ -f "$BRIEF" ] || die "brief not found: $BRIEF"
[[ "$MAX_FALLBACKS" =~ ^[0-9]+$ ]] || die "bad AGY_MAX_FALLBACKS: $MAX_FALLBACKS"

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

# ---- Model, family, chain ----
REQID=$(resolve_model "$MODEL")
FAMILY=$(family_of_id "$REQID")
# A Flash build (Flash with a real --owns list, a mini-task) always runs in no-fallback mode.
if [ "$FAMILY" = "flash" ] && [ $READONLY -eq 0 ]; then NOFB=1; fi
CHAIN=()
while IFS= read -r _l; do [ -n "$_l" ] && CHAIN+=("$_l"); done < <(chain_for "$FAMILY" "$REQID" "$READONLY")
if [ $NOFB -eq 1 ]; then CHAIN=("$REQID"); fi

# ---- Preflight ----
command -v "$AGY_BIN" >/dev/null 2>&1 || die "agy not installed"
RUNDIR="$ROOT"; [ -n "$WORKTREE" ] && RUNDIR="$WORKTREE"
[ -d "$RUNDIR" ] || die "run dir not found: $RUNDIR"
# Model ids must be listed by `agy models`. If that command fails or prints nothing, skip the check.
MODELS_OUT=$("$AGY_BIN" models < /dev/null 2>/dev/null || true)
listed() { [ -z "$MODELS_OUT" ] || printf '%s\n' "$MODELS_OUT" | grep -Fq -- "$1"; }
mkdir -p "$QDIR" "$LOGDIR"
TMO=""
if [[ "$RUN_TIMEOUT" =~ ^[0-9]+$ ]] && [ "$RUN_TIMEOUT" -gt 0 ]; then
  if command -v timeout >/dev/null 2>&1; then TMO=timeout
  elif command -v gtimeout >/dev/null 2>&1; then TMO=gtimeout; fi
fi

BEFORE="$LOGDIR/agy-before-$TASK.txt"; AFTER="$LOGDIR/agy-after-$TASK.txt"
BRIEF_OUT="$LOGDIR/agy-brief-$TASK.md"; LOG="$LOGDIR/agy-log-$TASK.txt"
: > "$LOG"                          # no stale log from an earlier run of the same task slug
IS_GIT=0
git -C "$RUNDIR" rev-parse --git-dir >/dev/null 2>&1 && IS_GIT=1
if [ $IS_GIT -eq 1 ]; then git -C "$RUNDIR" status --short | sort > "$BEFORE"; else : > "$BEFORE"; fi

PARTIAL=0                           # set after a drain mid-run: the next model is told files may be partly edited
build_brief() {
  {
    echo "Read AGENTS.md first and follow it."
    echo "task: $TASK"
    echo "owns: $OWNS"
    [ $READONLY -eq 1 ] && echo "Read-only: do not edit any file."
    echo "You cannot run shell commands in this mode. Do not try. List any check you could not run in your report."
    echo
    cat "$BRIEF"
    if [ $PARTIAL -eq 1 ]; then
      echo
      echo "A previous model stopped partway on a quota error; some of your owned files may be partly edited. Inspect them and finish the task."
    fi
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

FB=""                               # fallbacks taken, "a -> b (why); ..."
TRIED=""                            # every model considered, "id (ran: drained)" and so on
add_fb()    { if [ -n "$FB" ]; then FB="$FB; $1"; else FB="$1"; fi; }
add_tried() { if [ -n "$TRIED" ]; then TRIED="$TRIED, $1"; else TRIED="$1"; fi; }

report() {   # $1 = model that ran (id) or "none (drained)"
  echo "task: $TASK"
  echo "model requested: $MODEL ($REQID)"
  echo "model that ran: $1"
  echo "fallbacks: ${FB:-none}"
  if [ $IS_GIT -eq 0 ]; then
    echo "not a git repo: no diff or change count"
  else
    echo "changed lines (owned): $(changed_lines)"
    if [ ${#OWNED[@]} -gt 0 ]; then
      echo "diff stat (owned):"
      git -C "$RUNDIR" diff --stat -- "${OWNED[@]}" | sed 's/^/  /'
      git -C "$RUNDIR" status --short -- "${OWNED[@]}" | sed 's/^/  /'
    fi
    local ex=(":(exclude).claude/agy-quota" ":(exclude)$RUN_DIR") p
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

exhausted() {   # chain used up. $1 = why it stopped. Exit 3, or 2 when nothing was drained (all unavailable)
  if [ "$ANY_DRAINED" -eq 0 ]; then
    echo "unavailable: no model of the chain is in agy models (tried: $TRIED)" >&2
    exit 2
  fi
  echo "drained: all models drained or unavailable ($1)"
  echo "tried: $TRIED"
  report "none (drained)"
  exit 3
}

# ---- Run: walk the chain ----
ANY_DRAINED=0
idx=0
n_chain=${#CHAIN[@]}
prev=""; prev_why=""
while :; do
  if [ "$idx" -ge "$n_chain" ]; then exhausted "chain exhausted"; fi
  if [ "$idx" -gt "$MAX_FALLBACKS" ]; then exhausted "fallback limit of $MAX_FALLBACKS reached"; fi
  ID="${CHAIN[$idx]}"
  if [ -n "$prev" ]; then add_fb "$prev -> $ID ($prev_why)"; fi

  # skip: model id not listed by `agy models`
  if ! listed "$ID"; then
    if [ $NOFB -eq 1 ] || [ "$n_chain" -le 1 ]; then die "unavailable: $MODEL ($ID not in agy models)"; fi
    add_tried "$ID (not in agy models)"
    prev="$ID"; prev_why="skipped: not in agy models"; idx=$((idx + 1)); continue
  fi

  # skip: active marker
  u=$(marker_until "$ID")
  if [ -n "$u" ]; then
    ANY_DRAINED=1
    if [ $NOFB -eq 1 ]; then
      echo "drained: $ID, no fallback (marker until $u)"
      report "none (drained)"
      exit 3
    fi
    add_tried "$ID (marker until $u)"
    prev="$ID"; prev_why="skipped: marker until $u"; idx=$((idx + 1)); continue
  fi

  # run
  build_brief
  cl_before=$(changed_lines)
  cmd=("$AGY_BIN" "$FLAG_PROMPT" "$(cat "$BRIEF_OUT")" "$FLAG_MODEL" "$ID" "${MODE_ARGS[@]}")
  [ -n "$TMO" ] && cmd=("$TMO" "$RUN_TIMEOUT" "${cmd[@]}")
  rc=0
  (cd "$RUNDIR" && "${cmd[@]}") > "$LOG" 2>&1 < /dev/null || rc=$?

  # classify
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
      echo "possible concurrency limit. No marker written, no fallback."
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
    ANY_DRAINED=1
    now=$(date +%s)
    reset=$(parse_reset "$LOG")
    until_e=$((now + LIMIT_DEFAULT)); [ -n "$reset" ] && until_e=$reset   # 6h default is a guess
    write_marker "$ID" "$until_e" "$qline"
    if [ $NOFB -eq 1 ]; then
      echo "drained: $ID, no fallback (until $(to_iso "$until_e"))"
      echo "error text: $qline"
      report "none (drained)"
      exit 3
    fi
    add_tried "$ID (drained: $qline)"
    PARTIAL=1
    prev="$ID"; prev_why="drained: $qline"; idx=$((idx + 1)); continue
  fi

  if [ $rc -ne 0 ]; then
    echo "agy failed on $ID (exit $rc). Last 20 log lines:"
    tail -n 20 "$LOG"
    exit 1
  fi

  report "$ID"
  exit 0
done
