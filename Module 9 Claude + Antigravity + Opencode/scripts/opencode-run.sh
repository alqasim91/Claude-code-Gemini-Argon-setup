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
# Scratch files (log, before/after lists, generated brief) live in .m9/logs/ of the project, not in /tmp,
# so two projects running the same task slug do not collide.
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
# Timeout: RUN_TIMEOUT seconds per model (default 1800, 0 = off) when `timeout` or `gtimeout` exists. The first
# timeout is not a quota drain: the model gets NO marker, the walk notes "<id>(timed out after <n>s)" and goes on
# with the next model. A second timeout in a row stops the script with exit 1 and the log tail (usually a
# permission prompt nobody can answer: allow the tool in opencode.json). A run that ends any other way resets
# the count. If the chain runs out right after one timeout, exit 1 (not 3: it is not a quota drain).
# Model discovery (DISCOVER=1, 0 = off): `opencode models opencode` lists the ids offered now. The list is cached
# in .claude/opencode-quota/.models for 6 hours. Chain entries that are not offered are skipped without a marker
# (shown as "not offered now, skipped"). For roles build and hard, a new "*-free" id that no chain names is added
# at the tail (never with --private). If the list is empty or the command fails, discovery is "unknown" and the
# chain is used as written. If every entry would be dropped, the full chain is used (discovery may be wrong).
# With --private and no zero-retention model offered: exit 3, never a fallback to another model.
# With --status: prints active markers and "not offered now: <ids>". Models not offered count as limited.
# Exit 3 if every model of --role (default build) is drained, else 0.
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
DISCOVER=1                          # 1 = ask `opencode models` which ids are offered now; 0 = trust the chains
MODELS_MAX_AGE=21600                # seconds the discovered model list is reused (6 hours)
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

timeout_tool() {   # prints timeout or gtimeout if one exists, else nothing
  if command -v timeout >/dev/null 2>&1; then echo timeout
  elif command -v gtimeout >/dev/null 2>&1; then echo gtimeout; fi
  return 0
}

# available_models: prints the model ids OpenCode offers now, one per line. Prints nothing when unknown
# (discovery off, command failed, no ids). Cache: $QDIR/.models, reused while under MODELS_MAX_AGE old.
available_models() {
  local cache="$QDIR/.models" now m raw line tok out="" t tb cmd
  [ "$DISCOVER" = "1" ] || return 0
  command -v "$OC_BIN" >/dev/null 2>&1 || return 0
  now=$(date +%s)
  if [ -s "$cache" ]; then
    m=$(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null || echo 0)
    [[ "$m" =~ ^[0-9]+$ ]] || m=0
    if [ $((now - m)) -ge 0 ] && [ $((now - m)) -lt "$MODELS_MAX_AGE" ]; then cat "$cache"; return 0; fi
  fi
  tb=$(timeout_tool)
  if [ -n "$tb" ]; then raw=$("$tb" 30 "$OC_BIN" models "$PROVIDER" 2>/dev/null < /dev/null) || return 0
  else raw=$("$OC_BIN" models "$PROVIDER" 2>/dev/null < /dev/null) || return 0; fi
  while IFS= read -r line || [ -n "$line" ]; do
    tok=""; read -r tok _ <<< "$line" || true
    tok=${tok%$'\r'}; tok=${tok#"$PROVIDER/"}
    if [[ "$tok" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
      case " $out " in *" $tok "*) ;; *) out="$out $tok" ;; esac
    fi
  done <<< "$raw"
  [ -n "$out" ] || return 0
  out=$(printf '%s\n' $out)
  t=$(mktemp "$QDIR/.tmp.XXXXXX") || { echo "$out"; return 0; }
  printf '%s\n' "$out" > "$t" && mv -f "$t" "$cache" || rm -f "$t"
  echo "$out"
  return 0
}

in_disc() { case "$DISC_SP" in *" $1 "*) return 0 ;; esac; return 1; }

# apply_discovery <role> <chain> <private 0|1>: sets globals CHAIN (filtered), NA_IDS (dropped ids),
# NEW_FREE (ids appended at the tail), DISCOVERED (the list, newline separated), DISC_SP (same, space padded).
apply_discovery() {
  local role=$1 private=${3:-0} e id kept="" allids="" r
  CHAIN=$2; NA_IDS=""; NEW_FREE=""; DISC_SP=""
  DISCOVERED=$(available_models)
  [ -n "$DISCOVERED" ] || return 0
  DISC_SP=" $(printf '%s\n' "$DISCOVERED" | tr '\n' ' ')"
  for e in $2; do
    id=${e%%:*}
    if in_disc "$id"; then kept="$kept $e"; else NA_IDS="$NA_IDS $id"; fi
  done
  if [ -z "$kept" ]; then NA_IDS=""; return 0; fi     # nothing left: discovery may be wrong, use the full chain
  CHAIN="${kept# }"
  if [ "$private" -eq 0 ] && { [ "$role" = build ] || [ "$role" = hard ]; }; then
    for r in scout mech build hard large vision av; do
      for e in $(chain_for "$r"); do allids="$allids ${e%%:*}"; done
    done
    for id in $DISCOVERED; do
      case "$id" in *-free) ;; *) continue ;; esac
      case " $allids " in *" $id "*) continue ;; esac
      NEW_FREE="$NEW_FREE $id"
    done
    NEW_FREE="${NEW_FREE# }"
    if [ -n "$NEW_FREE" ]; then CHAIN="$CHAIN $NEW_FREE"; fi
  fi
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
  apply_discovery "$role" "$chain" 0
  now=$(date +%s)
  for id in $NA_IDS; do total=$((total + 1)); drained=$((drained + 1)); done
  for e in $CHAIN; do
    id=${e%%:*}; total=$((total + 1))
    u=$(marker_until "$id")
    if [ -n "$u" ]; then
      drained=$((drained + 1))
      echo "  $id limited until $u (remaining $(fmt_remaining $(( $(to_epoch "$u") - now )))). $(sed -n 's/^reason=/reason: /p' "$QDIR/$id" | head -n 1)"
      if [ -z "$earliest" ] || [[ "$u" < "$earliest" ]]; then earliest="$u"; fi
    fi
  done
  if [ -n "$NA_IDS" ]; then echo "not offered now: ${NA_IDS# }"; fi
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

apply_discovery "$ROLE" "$CHAIN" "$PRIVATE"          # sets CHAIN, NA_IDS, NEW_FREE, DISCOVERED
if [ $PRIVATE -eq 1 ]; then
  CHAIN=$(filter_private "$CHAIN")
  if [ -n "$DISCOVERED" ]; then       # never fall back to a model that is not zero-retention, or not offered
    kept=""
    for e in $CHAIN; do
      if in_disc "${e%%:*}"; then kept="$kept $e"; else NA_IDS="$NA_IDS ${e%%:*}"; fi
    done
    CHAIN="${kept# }"
  fi
fi
if [ -n "$START" ]; then            # fix round 1: start with the same model, then the rest of the chain
  [ $PRIVATE -eq 1 ] && { case " $ZERO_RETENTION " in *" ${START%%:*} "*) ;; *) die "--start is not a zero-retention model, cannot be used with --private" ;; esac; }
  if [ -n "$DISCOVERED" ] && ! in_disc "${START%%:*}"; then
    case " $NA_IDS " in *" ${START%%:*} "*) ;; *) NA_IDS="$NA_IDS ${START%%:*}" ;; esac
  else
    rest=""
    for e in $CHAIN; do [ "${e%%:*}" = "${START%%:*}" ] || rest="$rest $e"; done
    CHAIN="$START$rest"
  fi
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

LOGDIR="$ROOT/.m9/logs"; mkdir -p "$LOGDIR"
BEFORE="$LOGDIR/oc-before-$TASK.txt"; AFTER="$LOGDIR/oc-after-$TASK.txt"
BRIEF_OUT="$LOGDIR/oc-brief-$TASK.md"; LOG="$LOGDIR/oc-log-$TASK.txt"
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
  if [ -n "$NEW_RAN" ]; then echo "new free models tried at the tail: ${NEW_RAN# }"; fi
  if [ $IS_GIT -eq 0 ]; then
    echo "not a git repo: no diff or change count"
  else
    echo "changed lines (owned): $(changed_lines)"
    if [ ${#OWNED[@]} -gt 0 ]; then
      echo "diff stat (owned):"
      git -C "$RUNDIR" diff --stat -- "${OWNED[@]}" | sed 's/^/  /'
      git -C "$RUNDIR" status --short -- "${OWNED[@]}" | sed 's/^/  /'
    fi
    local ex=(":(exclude).claude/opencode-quota" ":(exclude).claude/agy-quota" ":(exclude).m9")
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
WALK="" HITS=0 PARTIAL=0 EARLIEST="" CONSEC=0 LAST_TO="" NEW_RAN=""
for id in $NA_IDS; do WALK="$WALK $id(not offered now, skipped)"; done
if [ -z "$CHAIN" ]; then            # only possible with --private: no zero-retention model is offered
  echo "drained: $ROLE chain (no zero-retention model is offered now)"
  echo "tried:${WALK}"
  report "none (no zero-retention model is offered now)" "${WALK# }"
  exit 3
fi
for entry in $CHAIN; do
  id=${entry%%:*}; var=""; [[ "$entry" == *:* ]] && var=${entry#*:}
  u=$(marker_until "$id")
  if [ -n "$u" ]; then
    WALK="$WALK $id(skipped, limited until $u)"
    if [ -z "$EARLIEST" ] || [[ "$u" < "$EARLIEST" ]]; then EARLIEST="$u"; fi
    continue
  fi
  case " $NEW_FREE " in *" $id "*) NEW_RAN="$NEW_RAN $id" ;; esac
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
    CONSEC=$((CONSEC + 1))
    if [ $CONSEC -ge 2 ]; then
      echo "opencode timed out twice in a row ($LAST_TO, $id) after ${RUN_TIMEOUT}s each. Probably a permission prompt nobody can answer: allow the tool in opencode.json."
      tail -n 20 "$LOG"
      exit 1
    fi
    LAST_TO="$id"
    WALK="$WALK $id(timed out after ${RUN_TIMEOUT}s)"      # no marker: a timeout is not a quota drain
    if [ $IS_GIT -eq 1 ] && [ $READONLY -eq 0 ] && [ "$(changed_lines)" -gt 0 ]; then PARTIAL=1; fi
    continue
  fi
  CONSEC=0

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

if [ $CONSEC -eq 1 ]; then          # the last model that ran timed out and nothing is left: not a quota drain
  echo "opencode timed out on $PROVIDER/$LAST_TO after ${RUN_TIMEOUT}s and no other model in the $ROLE chain was left to try."
  echo "tried:${WALK}"
  report "none (timed out: $LAST_TO; owned files may be partly edited)" "${WALK# }"
  exit 1
fi
echo "drained: $ROLE chain until $EARLIEST"
echo "tried:${WALK}"
report "none (every model in the $ROLE chain is limited; owned files may be partly edited)" "${WALK# }"
exit 3
