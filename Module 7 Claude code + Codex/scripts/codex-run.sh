#!/usr/bin/env bash
# codex-run.sh: run ONE task on a Codex model (ChatGPT sign-in) and print a short report.
# Opus runs this directly with Bash (run_in_background: true). No relay subagent.
#
# Usage:
#   scripts/codex-run.sh --model <alias[-effort]|full-id> --task <slug> \
#       --owns "<comma list|none>" --brief <file> [--worktree <path>] [--no-fallback] [--effort <level>]
#
# Exit codes:
#   0 success (report printed)    1 other error (last 20 log lines printed)
#   2 codex not installed or bad arguments
#   3 drained (quota); prints "drained: <chain>". Opus then uses Claude (or the fix ladder)
#   4 suspected concurrency limit (no marker written)
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
QUOTA_MARKER_MINUTES=360                   # guess: skip a drained model for 6 hours
CONCURRENCY_RE='concurrent|too many sessions|already running|locked'
QUOTA_RE='quota|rate limit|usage limit|limit reached|429|exhausted|try again later'

# Model pool. Edit IDs here and in CLAUDE.md together.
ID_LUNA="gpt-6-luna"
ID_TERRA="gpt-6.1-terra"
ID_SOL="gpt-6.1-sol"
# Astra (gpt-6-astra) is deliberately not used.

die() { echo "$*" >&2; exit "${2:-2}"; }

# ---- Arguments ----
MODEL_ARG="" TASK="" OWNS="" BRIEF="" WORKTREE="" NO_FALLBACK=0 EFFORT_FLAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --model)       MODEL_ARG="${2:-}"; shift 2 ;;
    --task)        TASK="${2:-}"; shift 2 ;;
    --owns)        OWNS="${2:-}"; shift 2 ;;
    --brief)       BRIEF="${2:-}"; shift 2 ;;
    --worktree)    WORKTREE="${2:-}"; shift 2 ;;
    --effort)      EFFORT_FLAG="${2:-}"; shift 2 ;;
    --no-fallback) NO_FALLBACK=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$MODEL_ARG" ] && [ -n "$TASK" ] && [ -n "$OWNS" ] && [ -n "$BRIEF" ] \
  || die "usage: codex-run.sh --model <alias[-effort]|full-id> --task <slug> --owns \"<list|none>\" --brief <file> [--worktree <path>] [--no-fallback]"
[[ "$TASK" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "bad --task slug (use lowercase letters, digits, dashes): $TASK"
[ -f "$BRIEF" ] || die "brief not found: $BRIEF"

# ---- Preflight ----
command -v "$CODEX_BIN" >/dev/null 2>&1 || die "codex not installed" 2
ROOT="$PWD"                                 # quota markers always live here, even in worktree mode
QDIR="$ROOT/.claude/codex-quota"
mkdir -p "$QDIR"
RUNDIR="$ROOT"
[ -n "$WORKTREE" ] && RUNDIR="$WORKTREE"
[ -d "$RUNDIR" ] || die "run dir not found: $RUNDIR"

# ---- Resolve model alias, effort and fallback chain ----
EFFORT="medium"
CHAIN=()
if [[ "$MODEL_ARG" =~ ^(luna|terra|sol)(-(low|medium|high|xhigh))?$ ]]; then
  BASE="${BASH_REMATCH[1]}"
  [ -n "${BASH_REMATCH[3]}" ] && EFFORT="${BASH_REMATCH[3]}"
  case "$BASE" in
    luna)  CHAIN=("$ID_LUNA" "$ID_TERRA" "$ID_SOL") ;;
    terra) CHAIN=("$ID_TERRA" "$ID_SOL") ;;
    sol)   CHAIN=("$ID_SOL") ;;
  esac
else
  case "$MODEL_ARG" in            # full id: chain still follows the pool
    "$ID_LUNA")  CHAIN=("$ID_LUNA" "$ID_TERRA" "$ID_SOL") ;;
    "$ID_TERRA") CHAIN=("$ID_TERRA" "$ID_SOL") ;;
    *)           CHAIN=("$MODEL_ARG") ;;
  esac
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
write_marker() {   # atomic: temp file in the same dir, then mv
  local t
  t=$(mktemp "$QDIR/.tmp.XXXXXX")
  date -u +%Y-%m-%dT%H:%M:%SZ > "$t"
  mv -f "$t" "$QDIR/$1"
}

marker_fresh() {
  [ -n "$(find "$QDIR" -type f -name "$1" -mmin "-$QUOTA_MARKER_MINUTES" 2>/dev/null | head -n 1)" ]
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

report() {   # $1 = model that ran (or "none"), $2 = fallback notes
  echo "task: $TASK"
  echo "model requested: $MODEL_ARG (effort $EFFORT)"
  echo "model that ran: $1"
  echo "fallbacks: ${2:-none}"
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

# ---- Run loop ----
NOTES=""            # fallback history for the report
FALLBACKS=0
RAN=""
i=0
while [ $i -lt ${#CHAIN[@]} ]; do
  M="${CHAIN[$i]}"
  if marker_fresh "$M"; then
    [ $NO_FALLBACK -eq 1 ] && { echo "drained: $M, no fallback (fix round)"; exit 3; }
    NOTES="$NOTES skipped $M (marker);"
    FALLBACKS=$((FALLBACKS + 1)); i=$((i + 1)); continue
  fi

  SANDBOX="$SANDBOX_WRITE"; [ $READONLY -eq 1 ] && SANDBOX="$SANDBOX_READ"
  rc=0
  (cd "$RUNDIR" && "$CODEX_BIN" exec "$FLAG_MODEL" "$M" -c "$FLAG_EFFORT_KEY=$EFFORT" \
      "$FLAG_SANDBOX" "$SANDBOX" "$FLAG_OUT" "$LAST" - < "$BRIEF_OUT") > "$LOG" 2>&1 || rc=$?

  if [ $rc -eq 0 ]; then RAN="$M"; break; fi

  if grep -Eiq "$CONCURRENCY_RE" "$LOG"; then
    echo "suspected concurrency limit on $M (no marker written). Log excerpt:"
    grep -Ei "$CONCURRENCY_RE" "$LOG" | head -n 3
    exit 4
  fi

  if grep -Eiq "$QUOTA_RE" "$LOG"; then
    write_marker "$M"
    REASON=$(grep -Ei "$QUOTA_RE" "$LOG" | head -n 1 | cut -c1-160)
    if [ $NO_FALLBACK -eq 1 ]; then
      echo "drained: $M, no fallback (fix round)"
      echo "reason: $REASON"
      report "none (stopped on quota)" "none"
      exit 3
    fi
    NOTES="$NOTES $M drained (\"$REASON\");"
    FALLBACKS=$((FALLBACKS + 1)); i=$((i + 1))
    if [ $i -lt ${#CHAIN[@]} ] && [ $FALLBACKS -le 2 ]; then
      printf '\nA previous model stopped partway on a quota error; some of your owned files may be partly edited. Inspect them and finish the task.\n' >> "$BRIEF_OUT"
    fi
    continue
  fi

  echo "codex failed on $M (exit $rc). Last 20 log lines:"
  tail -n 20 "$LOG"
  exit 1
done

if [ -z "$RAN" ]; then
  # Every Codex model in the chain was skipped or drained: Opus uses Claude next.
  CH=""
  for m in "${CHAIN[@]}"; do CH="${CH:+$CH -> }$m"; done
  echo "drained: $CH -> claude"
  echo "history:$NOTES"
  [ $IS_GIT -eq 1 ] && report "none" "$NOTES"
  exit 3
fi

report "$RAN" "${NOTES:-none}"
exit 0
