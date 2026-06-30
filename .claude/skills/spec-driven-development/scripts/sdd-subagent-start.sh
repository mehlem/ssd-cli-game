#!/usr/bin/env bash
set -euo pipefail
command -v jq >/dev/null 2>&1 || exit 0
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

INPUT="$(cat)"
AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null)" || AGENT_ID=""
AGENT_TYPE="$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)" || AGENT_TYPE=""

case "$AGENT_TYPE" in
  sdd-implementer|sdd-spec-reviewer|sdd-quality-reviewer|sdd-research-scout|sdd-plan-drafter) ;;
  *) exit 0 ;;
esac

IFS='|' read -r FEATURE PHASE <<< "$(sdd_detect_feature_phase)" || exit 0
[ "$FEATURE" = "none" ] && exit 0

STATE_FILE=".features/$FEATURE/state.json"
TASK_ID=""
if [ -f "$STATE_FILE" ]; then
  TASK_ID="$(jq -r '.current_task.id // empty' "$STATE_FILE" 2>/dev/null)" || TASK_ID=""
fi
[ "$TASK_ID" = "null" ] && TASK_ID=""

CURRENT_FLAGS="$(sdd_read_session_flags)"
LOCK_BASE="$(dirname "$(sdd_state_cache_path)")"
LOCK_DIR="$LOCK_BASE/dispatch-epoch.lock"
mkdir -p "$LOCK_BASE"
LOCK_ACQUIRED=0
for _attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_ACQUIRED=1
    break
  fi
  sleep 0.1
done

if [ "$LOCK_ACQUIRED" -eq 1 ]; then
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
fi

CURRENT_FLAGS="$(sdd_read_session_flags)"
CURRENT_EPOCH="$(printf '%s' "$CURRENT_FLAGS" | jq -r '.dispatch_epoch // 0' 2>/dev/null)" || CURRENT_EPOCH=0
NEXT_EPOCH=$((CURRENT_EPOCH + 1))
if [ -z "$AGENT_ID" ]; then
  AGENT_ID="dispatch-$NEXT_EPOCH"
fi
sdd_set_session_flag "dispatch_epoch" "$NEXT_EPOCH" || true

if [ "$LOCK_ACQUIRED" -eq 1 ]; then
  rmdir "$LOCK_DIR" 2>/dev/null || true
  trap - EXIT
fi

PACKET="$(sdd_build_dispatch_packet "$AGENT_TYPE" "$FEATURE" "$PHASE" "$TASK_ID" "$AGENT_ID" "$NEXT_EPOCH" 2>/dev/null || true)"
[ -n "$PACKET" ] || exit 0

DISPATCH_JSON="$(printf '%s\n' "$PACKET" | sdd_extract_machine_dispatch_record)"
[ -n "$DISPATCH_JSON" ] || exit 0

DISPATCH_PATH="$(sdd_dispatch_record_path "$FEATURE" "$AGENT_ID")"
sdd_write_file_atomic "$DISPATCH_PATH" "$DISPATCH_JSON" || exit 0

jq -n \
  --arg ctx "$PACKET" \
  --arg evt "SubagentStart" \
  '{hookSpecificOutput: {hookEventName: $evt, additionalContext: $ctx}}'
