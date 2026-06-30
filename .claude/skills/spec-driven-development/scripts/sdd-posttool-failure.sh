#!/usr/bin/env bash
set -euo pipefail
command -v jq >/dev/null 2>&1 || exit 0
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

INPUT="$(cat)"

TOOL_NAME="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)" || TOOL_NAME=""
ERROR_TEXT="$(printf '%s' "$INPUT" | jq -r '.error // empty' 2>/dev/null)" || ERROR_TEXT=""
IS_INTERRUPT="$(printf '%s' "$INPUT" | jq -r '.is_interrupt // false' 2>/dev/null)" || IS_INTERRUPT="false"
COMMAND_TEXT="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)" || COMMAND_TEXT=""

[ -z "$TOOL_NAME" ] && [ -z "$ERROR_TEXT" ] && exit 0
[ "$IS_INTERRUPT" = "true" ] && exit 0

IFS='|' read -r FEATURE _ <<< "$(sdd_detect_feature_phase)" || exit 0
[ "$FEATURE" = "none" ] && exit 0

FEATURE_DIR=".features/$FEATURE"
STATE_FILE="$FEATURE_DIR/state.json"
CURRENT_VERIFY=""
IS_VERIFICATION="false"

if [ "$TOOL_NAME" = "Bash" ] && [ -f "$STATE_FILE" ]; then
  CURRENT_VERIFY="$(jq -r '.current_task.verification_cmd // empty' "$STATE_FILE" 2>/dev/null)" || CURRENT_VERIFY=""
  if [ -n "$CURRENT_VERIFY" ] && [ -n "$COMMAND_TEXT" ]; then
    case "$CURRENT_VERIFY" in
      *"$COMMAND_TEXT"*) IS_VERIFICATION="true" ;;
    esac
    case "$COMMAND_TEXT" in
      *"$CURRENT_VERIFY"*) IS_VERIFICATION="true" ;;
    esac
  fi
fi

FAILURE_JSON="$(jq -nc \
  --arg tool "$TOOL_NAME" \
  --arg error "$ERROR_TEXT" \
  --argjson is_verification "$IS_VERIFICATION" \
  --arg timestamp "$(date +%Y-%m-%dT%H:%M:%S)" \
  '{tool: $tool, error: $error, is_verification: $is_verification, timestamp: $timestamp}')"
sdd_set_session_flag "last_tool_failure" "$FAILURE_JSON" || true

RECOVERY_HINT="Tool failure: ${TOOL_NAME:-unknown} — ${ERROR_TEXT:-unknown error}."
if [ "$IS_VERIFICATION" = "true" ]; then
  RECOVERY_HINT="$RECOVERY_HINT This was a verification command. Investigate root cause before retrying."
fi

jq -n \
  --arg ctx "$RECOVERY_HINT" \
  --arg evt "PostToolUseFailure" \
  '{hookSpecificOutput: {hookEventName: $evt, additionalContext: $ctx}}'
