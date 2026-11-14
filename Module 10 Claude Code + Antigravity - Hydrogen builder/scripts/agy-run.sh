#!/usr/bin/env bash
# agy-run.sh: run ONE task on an Antigravity (agy) model, walk the fallback chain, print a short report.
# The main session runs this directly with Bash (run_in_background: true). No relay subagent.
#
# Usage:
#   scripts/agy-run.sh --model <alias[-low|-medium|-high]> --task <slug> --owns "<comma list|none>" --brief <file> \
#       [--exact] [--no-fallback] [--worktree <path>]
#   scripts/agy-run.sh --status
# Examples:
#   scripts/agy-run.sh --model hydrogen --exact --task w1-pages-m1 --owns "site/about.html" --brief .m10/briefs/w1-pages-m1.md
#   scripts/agy-run.sh --model hydrogen --task w1-home --owns "site/index.html" --brief .m10/briefs/w1-home.md
#   scripts/agy-run.sh --model hydrogen --no-fallback --task w1-home-r1 --owns "site/index.html" --brief .m10/briefs/w1-home-r1.md
#   scripts/agy-run.sh --model argon-high --task w2-engine --owns "src/engine.js" --brief .m10/briefs/w2-engine.md
#   scripts/agy-run.sh --model flash --task s1-links --owns none --brief .m10/briefs/s1-links.md   (read-only scout)
# --exact marks a build as an exact mini-task: only then may the chain use Flash high as a fallback.
# The brief file is body-only (.m10/briefs/<task>.md). The script adds task:, owns:, "Read AGENTS.md first and
# follow it.", the read-only line and the no-shell line. A design task must never be sent here (CLAUDE.md rule;
# the script also refuses a brief whose first line is the bare word "design").
# --model missing = hydrogen (the default builder, high effort). --task missing = a generated slug (said in the report). --owns missing = the run
# goes ahead unscoped and the report says so (a Flash call without --owns is a read-only scout; a Flash build as first choice is refused).
# Hydrogen = gemini-4-hydrogen-<low|medium|high|xhigh>. The alias `hydrogen` means high; `hydrogen-medium`,
# `hydrogen-low`, `hydrogen-xhigh` pick another effort. Every other alias defaults to medium.
#
# Exit codes:
#   0 success (report printed)
#   1 other error: login, crash, timeout, unknown flag (last 20 log lines printed). No fallback
#   2 agy missing, bad arguments, refused (design, Flash fix, Flash build as first choice), or every model unavailable / not in `agy models`
#   3 drained. First line "drained: <model-id>, no fallback" (--no-fallback) or
#     "drained: all models drained or unavailable (tried: ...)" when the chain is used up, or
#     "drained: max fallbacks reached ..." Owned files may be partly edited (the report shows them)
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
# Timeout: RUN_TIMEOUT seconds (default 1800, 0 = off; env AGY_RUN_TIMEOUT overrides) when `timeout` or
# `gtimeout` exists. Max fallbacks per task: MAX_FALLBACKS (default 2; env AGY_MAX_FALLBACKS overrides).
#
# agy -p --mode accept-edits allows file edits but DENIES shell commands. The model cannot run tests or
# linters. The brief tells it so. The reviewer runs the read-only checks.
# NEVER add --dangerously-skip-permissions (auto mode blocks it). If a run stalls on a permission check,
# stop and report. Do not look for a way around it.
set -euo pipefail

RUN_DIR=".m10"                      # run folder in the project (briefs, logs, contract.md, last-run.md)

# ---- Flags (confirmed on the user's machine; `agy` has no -m flag) ----
AGY_BIN="agy"
FLAG_PROMPT="-p"
FLAG_MODEL="--model"
MODE_ARGS=(--mode accept-edits --print-timeout 0)

# ---- Tunables ----
LIMIT_DEFAULT=21600                 # seconds a drained model stays skipped when no reset time is found (6h, a guess)
DAY=86400
RUN_TIMEOUT="${AGY_RUN_TIMEOUT:-1800}"   # seconds per run; 0 = off. Needs `timeout` (or `gtimeout` on macOS)
MAX_FALLBACKS="${AGY_MAX_FALLBACKS:-2}"  # max fallbacks per task (a skipped or drained model counts as one)
QUOTA_RE='rate.?limit|429|quota|usage limit|limit reached|exhausted|too many requests|try again later|FreeUsageLimit|resource_exhausted|not available to'
CONC_RE='concurrent|too many sessions|another session|already running|locked'

# ================= ALIASES, EFFORT SUFFIX, CHAINS (edit together with CLAUDE.md) =================
# Alias -> agy model id. A -low / -medium / -high suffix on the alias picks the effort (default medium):
#   hydrogen -> gemini-4-hydrogen-<effort> (default high; also xhigh)
#   argon -> gemini-4-argon-<effort>   sonnet -> claude-sonnet-5-5-<effort>   opus -> claude-opus-5-5-<effort>
#   flash -> gemini-3.8-flash-<effort> (read-only scouting only; Flash builds only as the fallback gemini-3.8-flash-high, never a first choice)
#   A -xhigh suffix exists for hydrogen only (other families: the id is checked against `agy models`).
# A full model id is used as given (no chain, except that a known family id behaves like its alias).
alias_family() {   # $1 alias word (no suffix); prints the family or returns 1
  case "$1" in hydrogen|flash|argon|sonnet|opus) echo "$1" ;; *) return 1 ;; esac
}
family_id() {      # $1 family  $2 effort
  case "$1" in
    hydrogen) echo "gemini-4-hydrogen-$2" ;;
    flash)  echo "gemini-3.8-flash-$2" ;;
    argon)  echo "gemini-4-argon-$2" ;;
    sonnet) echo "claude-sonnet-5-5-$2" ;;
    opus)   echo "claude-opus-5-5-$2" ;;
  esac
}
# Fallback chain after the first choice, builders only. Tokens are alias[-effort]. Never a Claude (non-agy) model.
#   hydrogen (exact mini-task, --exact) -> flash-high -> argon.   hydrogen (not exact) -> argon -> sonnet.
#   hydrogen (read-only) -> argon.   Flash is never a fallback for work that is not an exact mini-task.
#   argon -> sonnet -> opus.  sonnet -> argon -> opus.  opus -> sonnet -> argon-high.
#   A read-only Flash scout: flash -> argon-low -> stop.  A Flash build as first choice is refused (exit 2); flash-high is reached only through hydrogen --exact.
# Argon high is never in a chain after Hydrogen or Flash.
chain_after() {    # $1 family  $2 readonly(0|1)  $3 exact(0|1)
  case "$1:$2:$3" in
    hydrogen:1:*) echo "argon" ;;
    hydrogen:0:1) echo "flash-high argon" ;;
    hydrogen:0:*) echo "argon sonnet" ;;
    argon:*)      echo "sonnet opus" ;;
    sonnet:*)     echo "argon opus" ;;
    opus:*)       echo "sonnet argon-high" ;;
    flash:1:*)    echo "argon-low" ;;
    *)            echo "" ;;
  esac
}
# ======================= end of the marked block =======================

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
MODEL="" TASK="" OWNS="" BRIEF="" WORKTREE="" NOFB=0 OWNS_SET=0 EXACT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --model)       MODEL="${2:-}"; shift 2 ;;
    --task)        TASK="${2:-}"; shift 2 ;;
    --owns)        OWNS="${2:-}"; OWNS_SET=1; shift 2 ;;
    --brief)       BRIEF="${2:-}"; shift 2 ;;
    --worktree)    WORKTREE="${2:-}"; shift 2 ;;
    --exact)       EXACT=1; shift ;;
    --no-fallback) NOFB=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$BRIEF" ] \
  || die "usage: agy-run.sh --model <alias> --task <slug> --owns \"<list|none>\" --brief <file> [--exact] [--no-fallback] [--worktree <path>] | --status"
[ -f "$BRIEF" ] || die "brief not found: $BRIEF"
NOTES=""   # extra report lines (defaults applied, forced settings)
note() { NOTES="${NOTES}$*"$'\n'; }
[ -n "$MODEL" ] || MODEL="hydrogen"
if [ -z "$TASK" ]; then TASK="t-$(date +%s)-$$"; note "task slug missing: generated $TASK"; fi
[[ "$TASK" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "bad --task slug (use lowercase letters, digits, dashes): $TASK"
[ -z "$OWNS" ] && OWNS_SET=0

# A design task never runs on agy (the relay refused a bare `design` header line).
first_line=$(grep -m1 -v '^[[:space:]]*$' "$BRIEF" | tr -d '\r[:space:]' || true)
[ "$first_line" != "design" ] || die "refused: design never runs on agy (design builds go to Claude subagents)"

# ---- Model: alias with optional effort suffix, or a full id ----
FAMILY="" EFFORT="" ID=""
_a="$MODEL"; _e=""
case "$_a" in
  *-xhigh)  _e=xhigh;  _a="${_a%-xhigh}" ;;
  *-low)    _e=low;    _a="${_a%-low}" ;;
  *-medium) _e=medium; _a="${_a%-medium}" ;;
  *-high)   _e=high;   _a="${_a%-high}" ;;
esac
if FAMILY=$(alias_family "$_a"); then
  _d=medium; [ "$FAMILY" = "hydrogen" ] && _d=high       # the alias `hydrogen` means high
  EFFORT="${_e:-$_d}"
  ID=$(family_id "$FAMILY" "$EFFORT")
else
  FAMILY=""; ID="$MODEL"             # full id, used as given
  case "$ID" in
    gemini-4-hydrogen-*)   FAMILY=hydrogen; EFFORT="${ID##*-}" ;;
    gemini-3.8-flash-*)    FAMILY=flash;  EFFORT="${ID##*-}" ;;
    gemini-4-argon-*)      FAMILY=argon;  EFFORT="${ID##*-}" ;;
    claude-sonnet-5-5-*)   FAMILY=sonnet; EFFORT="${ID##*-}" ;;
    claude-opus-5-5-*)     FAMILY=opus;   EFFORT="${ID##*-}" ;;
  esac
fi

# ---- Owned pathspecs ----
OWNED=(); READONLY=0
if [ $OWNS_SET -eq 0 ] && [ "$FAMILY" = "flash" ]; then
  OWNS="none"; OWNS_SET=1; note "owns missing: a Flash call without owns is a read-only scout"
fi
if [ $OWNS_SET -eq 0 ]; then
  OWNED=("."); note "owns missing, results unscoped"
elif [ "$OWNS" = "none" ]; then
  READONLY=1
else
  IFS=',' read -ra _parts <<< "$OWNS"
  for p in "${_parts[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"; p="${p%"${p##*[![:space:]]}"}"
    [ -n "$p" ] && OWNED+=("$p")
  done
  [ ${#OWNED[@]} -gt 0 ] || die "--owns is empty (use \"none\" for read-only)"
fi

# ---- Refusals and forced settings (exit 2, nothing runs) ----
if [ "$FAMILY" = "flash" ]; then
  # Flash never fixes or reviews.
  if [[ "$TASK" =~ -r[1-9]$ ]]; then die "refused: Flash never fixes or reviews (slug $TASK looks like a fix round)"; fi
  if [ $READONLY -eq 0 ]; then
    # Flash builds only as the fallback of hydrogen --exact (chain_after), never as a first choice.
    die "refused: Flash builds only as the fallback of --model hydrogen --exact (use --owns none for a read-only Flash scout)"
  fi
fi
# A fix round (slug ends in -r1..-r9) never falls back: no other agy model (Flash included) may serve a fix.
if [[ "$TASK" =~ -r[1-9]$ ]] && [ $NOFB -eq 0 ]; then
  NOFB=1; note "fix task ($TASK): --no-fallback forced, no other model may serve a fix"
fi
if [ $EXACT -eq 1 ] && [ "$FAMILY" != "hydrogen" ]; then note "--exact only matters for hydrogen builds: ignored"; fi

# ---- Preflight ----
command -v "$AGY_BIN" >/dev/null 2>&1 || die "agy not installed"
RUNDIR="$ROOT"; [ -n "$WORKTREE" ] && RUNDIR="$WORKTREE"
[ -d "$RUNDIR" ] || die "run dir not found: $RUNDIR"
# Model ids must be listed by `agy models`. If that command fails or prints nothing, skip the check.
MODELS_OUT=$("$AGY_BIN" models < /dev/null 2>/dev/null || true)
mkdir -p "$QDIR" "$LOGDIR"
TMO=""
if [[ "$RUN_TIMEOUT" =~ ^[0-9]+$ ]] && [ "$RUN_TIMEOUT" -gt 0 ]; then
  if command -v timeout >/dev/null 2>&1; then TMO=timeout
  elif command -v gtimeout >/dev/null 2>&1; then TMO=gtimeout; fi
fi

# ---- Model queue: the first choice, then its chain (empty for no-fallback mode) ----
QUEUE=("$ID")
if [ $NOFB -eq 0 ] && [ -n "$FAMILY" ]; then
  for tok in $(chain_after "$FAMILY" "$READONLY" "$EXACT"); do
    _t="$tok"; _te=""
    case "$_t" in
      *-xhigh)  _te=xhigh;  _t="${_t%-xhigh}" ;;
      *-low)    _te=low;    _t="${_t%-low}" ;;
      *-medium) _te=medium; _t="${_t%-medium}" ;;
      *-high)   _te=high;   _t="${_t%-high}" ;;
    esac
    QUEUE+=("$(family_id "$_t" "${_te:-medium}")")
  done
fi

BEFORE="$LOGDIR/agy-before-$TASK.txt"; AFTER="$LOGDIR/agy-after-$TASK.txt"
BRIEF_OUT="$LOGDIR/agy-brief-$TASK.md"; LOG="$LOGDIR/agy-log-$TASK.txt"
: > "$LOG"                          # no stale log from an earlier run of the same task slug
IS_GIT=0
git -C "$RUNDIR" rev-parse --git-dir >/dev/null 2>&1 && IS_GIT=1
if [ $IS_GIT -eq 1 ]; then git -C "$RUNDIR" status --short | sort > "$BEFORE"; else : > "$BEFORE"; fi

PARTIAL=0
build_brief() {
  {
    echo "Read AGENTS.md first and follow it."
    echo "task: $TASK"
    [ $OWNS_SET -eq 1 ] && echo "owns: $OWNS"
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

FALLBACKS=""   # one "; "-separated entry per fallback: why the model was left
add_fb() { if [ -n "$FALLBACKS" ]; then FALLBACKS="$FALLBACKS; $*"; else FALLBACKS="$*"; fi; }
TRIED=""       # models that were looked at, in order
ran_any=0

report() {   # $1 = model that ran (id) or "none (drained)"
  echo "task: $TASK"
  echo "model requested: $MODEL (${QUEUE[0]})"
  echo "model that ran: $1"
  echo "fallbacks: ${FALLBACKS:-none}"
  if [ -n "$NOTES" ]; then printf '%s' "$NOTES" | sed 's/^/note: /'; fi
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

# ---- Walk the queue ----
nfb=0 idx=0 total=${#QUEUE[@]} unavailable_only=1
while [ $idx -lt $total ]; do
  cid="${QUEUE[$idx]}"
  TRIED="${TRIED:+$TRIED, }$cid"

  # Which step failed for this model? reason is set when we must leave it.
  reason=""
  if [ -n "$MODELS_OUT" ] && ! printf '%s\n' "$MODELS_OUT" | grep -Fq -- "$cid"; then
    if [ $NOFB -eq 1 ]; then die "unavailable: $MODEL ($cid not in agy models), no fallback"; fi
    reason="unavailable: $cid not in agy models"
  else
    u=$(marker_until "$cid")
    if [ -n "$u" ]; then
      unavailable_only=0
      if [ $NOFB -eq 1 ]; then
        echo "drained: $cid, no fallback"
        echo "until: $u (skipped: marker, agy was not run)"
        exit 3
      fi
      reason="skipped: marker on $cid (until $u)"
    fi
  fi

  if [ -z "$reason" ]; then
    # ---- Run ----
    ran_any=1
    build_brief
    cl_before=$(changed_lines)
    cmd=("$AGY_BIN" "$FLAG_PROMPT" "$(cat "$BRIEF_OUT")" "$FLAG_MODEL" "$cid" "${MODE_ARGS[@]}")
    [ -n "$TMO" ] && cmd=("$TMO" "$RUN_TIMEOUT" "${cmd[@]}")
    : > "$LOG"
    rc=0
    (cd "$RUNDIR" && "${cmd[@]}") > "$LOG" 2>&1 < /dev/null || rc=$?
    fbline=""; [ -n "$FALLBACKS" ] && fbline="fallbacks: $FALLBACKS"

    # ---- Classify ----
    if [ $rc -eq 124 ] && [ -n "$TMO" ]; then
      [ -n "$fbline" ] && echo "$fbline"
      echo "agy timed out on $cid after ${RUN_TIMEOUT}s (possibly waiting on a permission prompt). Last 20 log lines:"
      tail -n 20 "$LOG"
      exit 1
    fi

    loglines=$(wc -l < "$LOG" | tr -d ' ')
    gained=1; [ "$(changed_lines)" -le "$cl_before" ] && gained=0

    # Concurrency. For exit 0 the log must be short too, so a long normal answer that mentions "locked" is not flagged.
    cline=$(grep -Ei "$CONC_RE" "$LOG" | head -n 1 | tr -d '\r' | cut -c1-160 || true)
    if [ -n "$cline" ]; then
      if [ $rc -ne 0 ] || { [ "$loglines" -lt 40 ] && [ $gained -eq 0 ]; }; then
        [ -n "$fbline" ] && echo "$fbline"
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
      unavailable_only=0
      now=$(date +%s)
      reset=$(parse_reset "$LOG")
      until_e=$((now + LIMIT_DEFAULT)); [ -n "$reset" ] && until_e=$reset   # 6h default is a guess
      write_marker "$cid" "$until_e" "$qline"
      if [ $NOFB -eq 1 ]; then
        echo "drained: $cid, no fallback"
        echo "until: $(to_iso "$until_e")"
        echo "error: $qline"
        report "none (drained)"
        exit 3
      fi
      reason="drained: $cid (\"$qline\")"
      PARTIAL=1
    elif [ $rc -ne 0 ]; then
      [ -n "$fbline" ] && echo "$fbline"
      echo "agy failed on $cid (exit $rc). Last 20 log lines:"
      tail -n 20 "$LOG"
      exit 1
    else
      report "$cid"
      exit 0
    fi
  fi

  # ---- Leave this model: count a fallback, take the next one ----
  add_fb "$reason"
  nfb=$((nfb + 1))
  idx=$((idx + 1))
  if [ $idx -lt $total ] && [ $nfb -gt "$MAX_FALLBACKS" ]; then
    echo "drained: max fallbacks reached ($MAX_FALLBACKS), tried: $TRIED"
    report "none (drained)"
    exit 3
  fi
done

# ---- Chain used up ----
if [ $unavailable_only -eq 1 ] && [ $ran_any -eq 0 ]; then
  echo "unavailable: no model of the chain is in agy models (tried: $TRIED). fallbacks: $FALLBACKS" >&2
  exit 2
fi
echo "drained: all models drained or unavailable (tried: $TRIED)"
report "none (drained)"
exit 3
