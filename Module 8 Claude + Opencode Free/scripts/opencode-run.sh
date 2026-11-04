#!/usr/bin/env bash
# opencode-run.sh: run ONE task on an OpenCode free-plan model and print a short report.
# Opus runs this directly with Bash (run_in_background: true). No relay subagent.
#
# Usage:
#   scripts/opencode-run.sh --role <role> --task <slug> --owns "<comma list|none>" --brief <file> \
#       [--start <id[:variant]>] [--private] [--worktree <path>]
#   scripts/opencode-run.sh --status [--role <role>]
#
# Roles: scout mech build hard large vision av   (chains are defined below, edit them with CLAUDE.md)
# The script walks the role's chain. A model with an active quota marker is skipped. A model that
# hits a limit gets a marker and the script moves to the next model in the chain, by itself.
# Markers: .claude/opencode-quota/<model-id>, two lines: until=<UTC ISO>, reason=<line>.
#
# Exit codes:
#   0 success (report printed)         1 other error (last 20 log lines printed)
#   2 opencode missing or bad arguments
#   3 every model in the chain is drained: prints "drained: <role> ... until <time>" and the report
#
# Limit rules. rc != 0: any QUOTA_RE match in the log = limit hit. rc == 0: a limit only when a short log
# (under 40 lines) has a matching line that also contains "error" AND the owned files did not gain changed
# lines during this model's run (read-only tasks: just the error match). A normal answer that mentions
# "rate limiter" is therefore not a limit.
# Unavailable models: rc != 0 and the log matches UNAVAIL_RE (model not found, region-blocked, not supported).
# The model gets a marker for 24 hours (reason "unavailable: ...") and the walk goes on, like a limit. These
# do not count toward the shared-limit note. Free models change often; Beam and Pulse are blocked in some countries.
# Timeout: RUN_TIMEOUT seconds per model (default 1800, 0 = off) when `timeout` or `gtimeout` exists. A timed-out
# model is NOT skipped: the script prints "opencode timed out on <id> after <n>s ..." plus the log tail, exit 1
# (often a permission prompt nobody can answer).
# With --status: prints active markers. Exit 3 if every model of --role (default build) is drained, else 0.
set -euo pipefail

# ---- Flags (confirmed from `opencode run --help` on the user's machine, 2026-11-04) ----
# NEVER add --auto (auto-approves permissions). If a run stalls on a permission prompt, allow the
# specific tool in opencode.json instead.
OC_BIN="opencode"
PROVIDER="opencode"                 # models are passed as opencode/<id>
FLAG_MODEL="-m"
FLAG_VARIANT="--variant"            # reasoning effort; only for models that have variants
FLAG_DIR="--dir"
FLAG_AGENT="--agent"
AGENT_READONLY="plan"               # UNVERIFIED: built-in read-only agent, check with `opencode agent list`

# ---- Tunables ----
LIMIT_DEFAULT=3600                  # seconds a limited model stays skipped when no reset time is found (guess)
DAY=86400
RUN_TIMEOUT=1800                    # seconds per model run; 0 = off. Needs `timeout` (or `gtimeout` on macOS)
QUOTA_RE='rate.?limit|429|quota|usage limit|limit reached|exhausted|too many requests|try again later|FreeUsageLimit'
UNAVAIL_RE='model not found|unknown model|not available|unavailable in your (region|country)|no such model|ProviderModelNotFound|model .*not supported'
ZERO_RETENTION="glm-5.3-flash-free deepseek-v4.1-flash-free"   # no training, no retention: the only models for private code

# ---- Chains: <model-id>[:variant], in fallback order. Edit here and in CLAUDE.md together. ----
# Models without variants (nemotron lightning, mimo, big-pickle) take no :variant.
# pulse-alpha-free and crouton-alpha-free are alpha test models: kept as the experimental tail.
chain_for() {
  case "$1" in
    scout)  echo "nemotron-3.5-lightning-free flint-40b-free:low glm-5.3-flash-free:low deepseek-v4.1-flash-free:low" ;;
    mech)   echo "flint-40b-free:medium nemotron-3.5-lightning-free deepseek-v4.1-flash-free:low glm-5.3-flash-free:low" ;;
    build)  echo "deepseek-v4.1-flash-free:high glm-5.3-flash-free:high flint-40b-free:high beam-free:medium big-pickle pulse-alpha-free:high crouton-alpha-free:high" ;;
    hard)   echo "beam-free:high deepseek-v4.1-flash-free:max glm-5.3-flash-free:max big-pickle pulse-alpha-free:high crouton-alpha-free:high" ;;
    large)  echo "beam-free:high nemotron-3.5-super-vl-free:high crouton-alpha-free:high" ;;
    vision) echo "glm-5.3-flash-free:high nemotron-3.5-super-vl-free:high pulse-alpha-free:high crouton-alpha-free:high" ;;
    av)     echo "mimo-v2.6-flash-free glm-5.3-flash-free:high crouton-alpha-free:high" ;;
    *) return 1 ;;
  esac
}

die() { echo "$*" >&2; exit "${2:-2}"; }

ROOT="$PWD"                         # markers always live here, even in worktree mode
QDIR="$ROOT/.claude/opencode-quota"

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
  u=$(sed -n 's/^until=//p' "$f" | head -n 1)
  e=$(to_epoch "$u")
  [[ "$e" =~ ^[0-9]+$ ]] || return 0
  [ "$(date +%s)" -lt "$e" ] && echo "$u"
  return 0
}

# filter_private "<chain>": keep only zero-retention models; if none left, use glm and deepseek high
filter_private() {
  local out="" e id z
  for e in $1; do
    id=${e%%:*}
    for z in $ZERO_RETENTION; do [ "$id" = "$z" ] && out="$out $e"; done
  done
  [ -n "$out" ] || out="glm-5.3-flash-free:high deepseek-v4.1-flash-free:high"
  echo "${out# }"
}

# status_for_role <role>: print markers of that chain; return 3 if all drained
status_for_role() {
  local role=$1 chain e id u total=0 drained=0 now earliest=""
  chain=$(chain_for "$role") || die "unknown role: $role"
  now=$(date +%s)
  for e in $chain; do
    id=${e%%:*}; total=$((total + 1))
    u=$(marker_until "$id")
    if [ -n "$u" ]; then
      drained=$((drained + 1))
      echo "  $id limited until $u (remaining $(fmt_remaining $(( $(to_epoch "$u") - now )))). $(sed -n 's/^reason=/reason: /p' "$QDIR/$id" | head -n 1)"
      if [ -z "$earliest" ] || [[ "$u" < "$earliest" ]]; then earliest="$u"; fi
    fi
  done
  echo "role $role: $drained of $total models limited"
  if [ "$drained" -eq "$total" ]; then echo "drained: $role chain until $earliest"; return 3; fi
  return 0
}

if [ "${1:-}" = "--status" ]; then
  shift; R="build"
  [ "${1:-}" = "--role" ] && R="${2:-build}"
  mkdir -p "$QDIR"
  rc=0; status_for_role "$R" || rc=$?
  exit $rc
fi

# ---- Arguments ----
ROLE="" TASK="" OWNS="" BRIEF="" WORKTREE="" START="" PRIVATE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --role)     ROLE="${2:-}"; shift 2 ;;
    --task)     TASK="${2:-}"; shift 2 ;;
    --owns)     OWNS="${2:-}"; shift 2 ;;
    --brief)    BRIEF="${2:-}"; shift 2 ;;
    --worktree) WORKTREE="${2:-}"; shift 2 ;;
    --start)    START="${2:-}"; shift 2 ;;
    --private)  PRIVATE=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$ROLE" ] && [ -n "$TASK" ] && [ -n "$OWNS" ] && [ -n "$BRIEF" ] \
  || die "usage: opencode-run.sh --role <role> --task <slug> --owns \"<list|none>\" --brief <file> [--start <id[:variant]>] [--private] [--worktree <path>]"
[[ "$TASK" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "bad --task slug (use lowercase letters, digits, dashes): $TASK"
[ -f "$BRIEF" ] || die "brief not found: $BRIEF"
CHAIN=$(chain_for "$ROLE") || die "unknown role: $ROLE (scout mech build hard large vision av)"

# ---- Preflight ----
command -v "$OC_BIN" >/dev/null 2>&1 || die "opencode not installed" 2
mkdir -p "$QDIR"
RUNDIR="$ROOT"; [ -n "$WORKTREE" ] && RUNDIR="$WORKTREE"
[ -d "$RUNDIR" ] || die "run dir not found: $RUNDIR"
TMO=""
if [[ "$RUN_TIMEOUT" =~ ^[0-9]+$ ]] && [ "$RUN_TIMEOUT" -gt 0 ]; then
  if command -v timeout >/dev/null 2>&1; then TMO=timeout
  elif command -v gtimeout >/dev/null 2>&1; then TMO=gtimeout; fi
fi

[ $PRIVATE -eq 1 ] && CHAIN=$(filter_private "$CHAIN")
if [ -n "$START" ]; then            # fix round 1: start with the same model, then the rest of the chain
  [ $PRIVATE -eq 1 ] && { case " $ZERO_RETENTION " in *" ${START%%:*} "*) ;; *) die "--start is not a zero-retention model, cannot be used with --private" ;; esac; }
  rest=""
  for e in $CHAIN; do [ "${e%%:*}" = "${START%%:*}" ] || rest="$rest $e"; done
  CHAIN="$START$rest"
fi

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

BEFORE="/tmp/oc-before-$TASK.txt"; AFTER="/tmp/oc-after-$TASK.txt"
BRIEF_OUT="/tmp/oc-brief-$TASK.md"; LOG="/tmp/oc-log-$TASK.txt"
: > "$LOG"                          # no stale log from an earlier run of the same task slug
IS_GIT=0
git -C "$RUNDIR" rev-parse --git-dir >/dev/null 2>&1 && IS_GIT=1
if [ $IS_GIT -eq 1 ]; then git -C "$RUNDIR" status --short | sort > "$BEFORE"; else : > "$BEFORE"; fi

build_brief() {   # $1 = 1 to add the partial-edit note
  {
    echo "Read AGENTS.md first and follow it."
    echo "task: $TASK"
    echo "owns: $OWNS"
    [ $READONLY -eq 1 ] && echo "Read-only: do not edit any file."
    [ "${1:-0}" = 1 ] && echo "A previous model may have partly edited the owned files before it stopped. Inspect them first, then finish the task."
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
# Free-plan error wording is UNVERIFIED; handles "try again at <date>", "try again in 2 hours 3 minutes", "in 1h 30m".
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

report() {   # $1 = model that ran (id[:variant]) or "none"; $2 = path tried summary
  echo "task: $TASK"
  echo "role: $ROLE$([ $PRIVATE -eq 1 ] && echo ' (private: zero-retention models only)')"
  echo "model that ran: $1"
  echo "chain walk: $2"
  if [ $IS_GIT -eq 0 ]; then
    echo "not a git repo: no diff or change count"
  else
    echo "changed lines (owned): $(changed_lines)"
    if [ ${#OWNED[@]} -gt 0 ]; then
      echo "diff stat (owned):"
      git -C "$RUNDIR" diff --stat -- "${OWNED[@]}" | sed 's/^/  /'
      git -C "$RUNDIR" status --short -- "${OWNED[@]}" | sed 's/^/  /'
    fi
    local ex=(":(exclude).claude/opencode-quota")
    for p in "${OWNED[@]}"; do ex+=(":(exclude)$p"); done
    git -C "$RUNDIR" status --short -- . "${ex[@]}" | sort > "$AFTER"
    local out
    out=$(comm -13 "$BEFORE" "$AFTER" || true)
    if [ -n "$out" ]; then
      if [ -n "$WORKTREE" ]; then echo "outside owned files (the model left its scope):"
      else echo "outside owned files (possibly from other parallel tasks):"; fi
      echo "$out" | sed 's/^/  /'
    else
      echo "outside owned files: none"
    fi
  fi
  echo "--- model output (last 40 lines) ---"
  if [ -s "$LOG" ]; then tail -n 40 "$LOG"; else echo "(none)"; fi
}

# ---- Walk the chain ----
WALK="" HITS=0 PARTIAL=0 EARLIEST=""
for entry in $CHAIN; do
  id=${entry%%:*}; var=""; [[ "$entry" == *:* ]] && var=${entry#*:}
  u=$(marker_until "$id")
  if [ -n "$u" ]; then
    WALK="$WALK $id(skipped, limited until $u)"
    if [ -z "$EARLIEST" ] || [[ "$u" < "$EARLIEST" ]]; then EARLIEST="$u"; fi
    continue
  fi
  build_brief "$PARTIAL"
  args=("$FLAG_MODEL" "$PROVIDER/$id")
  [ -n "$var" ] && args+=("$FLAG_VARIANT" "$var")
  args+=("$FLAG_DIR" "$RUNDIR")
  [ $READONLY -eq 1 ] && args+=("$FLAG_AGENT" "$AGENT_READONLY")
  cl_before=$(changed_lines)
  cmd=("$OC_BIN" run "${args[@]}" -- "$(cat "$BRIEF_OUT")")
  [ -n "$TMO" ] && cmd=("$TMO" "$RUN_TIMEOUT" "${cmd[@]}")
  rc=0
  (cd "$RUNDIR" && "${cmd[@]}") > "$LOG" 2>&1 < /dev/null || rc=$?

  if [ $rc -eq 124 ] && [ -n "$TMO" ]; then
    echo "opencode timed out on $PROVIDER/$id after ${RUN_TIMEOUT}s (possibly waiting on a permission prompt). Last 20 log lines:"
    tail -n 20 "$LOG"
    exit 1
  fi

  limited=0 unavail=0
  qline=$(grep -Ei "$QUOTA_RE" "$LOG" | head -n 1 | tr -d '\r' | cut -c1-160 || true)
  if [ $rc -ne 0 ]; then
    [ -n "$qline" ] && limited=1
  elif [ "$(wc -l < "$LOG")" -lt 40 ]; then
    # exit 0 is a normal answer unless a short log has an error line with a limit word and nothing was written
    qline=$(grep -Ei "$QUOTA_RE" "$LOG" | grep -Ei 'error' | head -n 1 | tr -d '\r' | cut -c1-160 || true)
    if [ -n "$qline" ]; then
      if [ $READONLY -eq 1 ] || [ "$(changed_lines)" -le "$cl_before" ]; then limited=1; fi
    fi
  fi
  if [ $limited -eq 0 ] && [ $rc -ne 0 ] && grep -Eiq "$UNAVAIL_RE" "$LOG"; then unavail=1; fi

  if [ $limited -eq 0 ] && [ $unavail -eq 0 ]; then
    if [ $rc -eq 0 ]; then
      [ $HITS -ge 2 ] && echo "note: limits hit on $HITS models in this run; the free limit may be shared (IP-level). Lower the parallel cap."
      report "$id${var:+:$var}" "${WALK# } $id${var:+:$var}(ran)"
      exit 0
    fi
    echo "opencode failed on $PROVIDER/$id (exit $rc). Last 20 log lines:"
    tail -n 20 "$LOG"
    exit 1
  fi

  now=$(date +%s)
  if [ $unavail -eq 1 ]; then
    reason="unavailable: $(grep -Ei "$UNAVAIL_RE" "$LOG" | head -n 1 | tr -d '\r' | cut -c1-140)"
    until_e=$((now + DAY))
    write_marker "$id" "$until_e" "$reason"
    WALK="$WALK $id(unavailable, skipped 24h)"
  else
    reset=$(parse_reset "$LOG")
    reason="$qline"
    until_e=$((now + LIMIT_DEFAULT)); [ -n "$reset" ] && until_e=$reset
    write_marker "$id" "$until_e" "$reason"
    HITS=$((HITS + 1))
    WALK="$WALK $id(limit hit, back $(to_iso "$until_e"))"
  fi
  if [ -z "$EARLIEST" ] || [[ "$(to_iso "$until_e")" < "$EARLIEST" ]]; then EARLIEST="$(to_iso "$until_e")"; fi
  # partial edits possible if anything owned changed
  if [ $IS_GIT -eq 1 ] && [ $READONLY -eq 0 ] && [ "$(changed_lines)" -gt 0 ]; then PARTIAL=1; fi
done

echo "drained: $ROLE chain until $EARLIEST"
echo "tried:${WALK}"
report "none (every model in the $ROLE chain is limited; owned files may be partly edited)" "${WALK# }"
exit 3
