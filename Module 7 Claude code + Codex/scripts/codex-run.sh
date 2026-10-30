#!/usr/bin/env bash
# codex-run.sh: run ONE task on a Codex model (ChatGPT sign-in) and print a short report.
# Opus runs this directly with Bash (run_in_background: true). No relay subagent.
#
# Usage:
#   scripts/codex-run.sh --model <alias[-effort]|full-id> --task <slug> \
#       --owns "<comma list|none>" --brief <file> [--worktree <path>] [--effort <level>]
#
# All Codex models share ONE quota pool, so there is one marker and no Codex-to-Codex fallback.
#
# Exit codes:
#   0 success (report printed)    1 other error (last 20 log lines printed)
#   2 codex not installed or bad arguments
#   3 drained (quota): prints "drained: codex pool (shared by all models)". Opus then uses
#     claude-sonnet-builder (or the next fix-ladder step). Also exit 3, without running, when
#     the marker is under 24 hours old.
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
QUOTA_MARKER_MINUTES=1440                  # the pool resets weekly: treat it as drained for 24 hours
CONCURRENCY_RE='concurrent|too many sessions|already running|locked'
QUOTA_RE='quota|rate limit|usage limit|limit reached|429|exhausted|try again later'

# Model IDs. Edit IDs here and in CLAUDE.md together.
ID_LUNA="gpt-6-luna"
ID_TERRA="gpt-6.1-terra"
ID_SOL="gpt-6.1-sol"
# Astra (gpt-6-astra) is deliberately not used.

die() { echo "$*" >&2; exit "${2:-2}"; }

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
ROOT="$PWD"                                 # the quota marker always lives here, even in worktree mode
QDIR="$ROOT/.claude/codex-quota"
MARKER="$QDIR/codex"                        # ONE marker: every Codex model shares one quota pool
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
write_marker() {   # atomic: temp file in the same dir, then mv
  local t
  t=$(mktemp "$QDIR/.tmp.XXXXXX")
  date -u +%Y-%m-%dT%H:%M:%SZ > "$t"
  mv -f "$t" "$MARKER"
}

marker_fresh() {
  [ -n "$(find "$QDIR" -type f -name codex -mmin "-$QUOTA_MARKER_MINUTES" 2>/dev/null | head -n 1)" ]
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
if marker_fresh; then
  echo "drained: codex pool (marker $(head -n 1 "$MARKER" 2>/dev/null || echo unknown), shared by all models)"
  exit 3
fi

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
  write_marker
  echo "drained: codex pool (shared by all models)"
  echo "reason: $(grep -Ei "$QUOTA_RE" "$LOG" | head -n 1 | cut -c1-160)"
  report "none (stopped on quota; owned files may be partly edited)"
  exit 3
fi

echo "codex failed on $MODEL (exit $rc). Last 20 log lines:"
tail -n 20 "$LOG"
exit 1
