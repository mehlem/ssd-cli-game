#!/usr/bin/env bash
set -euo pipefail
command -v jq >/dev/null 2>&1 || exit 0
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

INPUT="$(cat)"
REASON="$(printf '%s' "$INPUT" | jq -r '.reason // empty' 2>/dev/null)" || REASON=""

IFS='|' read -r FEATURE PHASE <<< "$(sdd_detect_feature_phase)" || exit 0
[ "$FEATURE" = "none" ] && exit 0

FEATURE_DIR=".features/$FEATURE"
[ -d "$FEATURE_DIR" ] || exit 0

CONTINUITY_FILE="$FEATURE_DIR/continuity.md"
SCRATCHPAD_FILE="$FEATURE_DIR/scratchpad.md"
TASKS_FILE="$FEATURE_DIR/tasks.md"
STATE_FILE="$FEATURE_DIR/state.json"

CURRENT_TASK="none"
COMPLETED=0
IN_PROGRESS=0
PENDING=0
BLOCKED=0

if [ -f "$STATE_FILE" ]; then
  CURRENT_TASK="$(jq -r '.current_task.id // "none"' "$STATE_FILE" 2>/dev/null)" || CURRENT_TASK="none"
  CURRENT_HEADING="$(jq -r '.current_task.heading // empty' "$STATE_FILE" 2>/dev/null)" || CURRENT_HEADING=""
  COMPLETED="$(jq -r '.tasks.completed // 0' "$STATE_FILE" 2>/dev/null)" || COMPLETED=0
  IN_PROGRESS="$(jq -r '.tasks.in_progress // 0' "$STATE_FILE" 2>/dev/null)" || IN_PROGRESS=0
  PENDING="$(jq -r '.tasks.pending // 0' "$STATE_FILE" 2>/dev/null)" || PENDING=0
  BLOCKED="$(jq -r '.tasks.blocked // 0' "$STATE_FILE" 2>/dev/null)" || BLOCKED=0
elif [ -f "$TASKS_FILE" ]; then
  COMPLETED="$(sdd_count_task_status "$TASKS_FILE" "completed")"
  IN_PROGRESS="$(sdd_count_task_status "$TASKS_FILE" "in-progress")"
  PENDING="$(sdd_count_task_status "$TASKS_FILE" "pending")"
  BLOCKED="$(sdd_count_task_status "$TASKS_FILE" "blocked")"
  CURRENT_HEADING=""
fi

TASK_DISPLAY="$CURRENT_TASK"
if [ -n "${CURRENT_HEADING:-}" ] && [ "$CURRENT_HEADING" != "null" ]; then
  TASK_DISPLAY="$CURRENT_TASK: $CURRENT_HEADING"
fi

OBSERVATIONS=""
if [ -f "$SCRATCHPAD_FILE" ]; then
  OBSERVATIONS="$(grep -E '^\- \[' "$SCRATCHPAD_FILE" 2>/dev/null | tail -3)" || true
fi

TIMESTAMP="$(date +%Y-%m-%dT%H:%M:%S)"

if [ ! -f "$CONTINUITY_FILE" ]; then
  {
    printf '# Continuity: %s\n\n' "$FEATURE"
  } > "$CONTINUITY_FILE" 2>/dev/null || true
fi

{
  printf '\n## Session End (%s)\n\n' "$TIMESTAMP"
  [ -n "$REASON" ] && printf -- '- Reason: %s\n' "$REASON"
  printf -- '- Phase: %s\n' "$PHASE"
  printf -- '- Current task: %s\n' "$TASK_DISPLAY"
  printf -- '- Tasks: %s completed, %s in-progress, %s pending, %s blocked\n' \
    "$COMPLETED" "$IN_PROGRESS" "$PENDING" "$BLOCKED"
  if [ -n "$OBSERVATIONS" ]; then
    printf '\n### Recent Observations\n\n'
    printf '%s\n' "$OBSERVATIONS"
  fi
} >> "$CONTINUITY_FILE" 2>/dev/null || true

sdd_summary_maybe "$FEATURE"

sdd_reset_session_flags || true
exit 0
