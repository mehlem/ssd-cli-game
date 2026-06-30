#!/usr/bin/env bash
# sdd-scope-drift.sh — PreToolUse command hook: scope-drift detection
# Checks if an edited file is listed in task-scope.txt or scope.txt during implement phase.
# Non-blocking advisory: emits warning via additionalContext, never denies.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

source "$SCRIPT_DIR/sdd-lib.sh"

sdd_scope_trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

sdd_scope_brace_matches() {
  local pattern="$1" target="$2"
  case "$pattern" in
    *"{"*"}"*) ;;
    *) return 1 ;;
  esac

  local prefix rest choices suffix choice
  prefix="${pattern%%\{*}"
  rest="${pattern#*\{}"
  [ "$rest" != "$pattern" ] || return 1
  choices="${rest%%\}*}"
  suffix="${rest#*\}}"
  [ "$suffix" != "$rest" ] || return 1

  # Support the one brace-list group used by scope sidecars, e.g.
  # scripts/{sdd-close.sh,sdd-check.sh}. Nested brace expansion stays explicit.
  case "$choices" in
    *"{"*|*"}"*) return 1 ;;
  esac

  local IFS=',' parts=()
  read -r -a parts <<< "$choices"
  for choice in "${parts[@]}"; do
    choice="$(sdd_scope_trim "$choice")"
    if [ "${prefix}${choice}${suffix}" = "$target" ]; then
      return 0
    fi
  done

  return 1
}

sdd_scope_path_matches() {
  local pattern="$1" target="$2"
  [ -n "$pattern" ] || return 1
  [ "$pattern" = "$target" ] && return 0
  sdd_scope_brace_matches "$pattern" "$target"
}

sdd_scope_line_matches_target() {
  local line="$1" target="$2" candidate first
  line="$(sdd_scope_trim "$line")"
  [ -n "$line" ] || return 1
  case "$line" in
    \#*) return 1 ;;
    "- "*) line="${line#- }" ;;
  esac

  line="$(sdd_scope_trim "$line")"
  sdd_scope_path_matches "$line" "$target" && return 0

  candidate="$line"
  case "$candidate" in
    \`*) candidate="${candidate#\`}"; candidate="${candidate%%\`*}" ;;
    \"*) candidate="${candidate#\"}"; candidate="${candidate%%\"*}" ;;
  esac
  candidate="$(sdd_scope_trim "$candidate")"
  sdd_scope_path_matches "$candidate" "$target" && return 0

  first="${line%%[[:space:]]*}"
  if [ "$first" != "$line" ]; then
    first="${first#\`}"
    first="${first%\`}"
    first="${first#\"}"
    first="${first%\"}"
    sdd_scope_path_matches "$first" "$target" && return 0
  fi

  return 1
}

sdd_scope_contains_path() {
  local scope_file="$1" rel_path="$2" file_path="$3" line
  while IFS= read -r line || [ -n "$line" ]; do
    sdd_scope_line_matches_target "$line" "$rel_path" && return 0
    sdd_scope_line_matches_target "$line" "$file_path" && return 0
  done < "$scope_file"

  return 1
}

INPUT="$(cat)"

# Extract tool_name and file_path in one jq call
IFS=$'\t' read -r TOOL_NAME FILE_PATH <<< "$(echo "$INPUT" | jq -r '[.tool_name // empty, .tool_input.file_path // empty] | @tsv')"

# Only check Edit and Write (Bash has no unambiguous file_path)
case "${TOOL_NAME:-}" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

# Must have a file_path to check
[ -n "${FILE_PATH:-}" ] || exit 0

# Detect active feature and phase
IFS='|' read -r FEATURE PHASE <<< "$(sdd_detect_feature_phase)" || exit 0
[ "$FEATURE" = "none" ] && exit 0

REFRESH_FEATURE="$FEATURE"
REL_PATH="$(sdd_project_relative_path "$FILE_PATH" "$PROJECT_DIR")"

case "$REL_PATH" in
  ".features/$FEATURE/"*) exit 0 ;;
esac

if [ -n "${FILE_PATH:-}" ]; then
  DERIVED="$(sdd_feature_path_for_file "$FILE_PATH" "$PROJECT_DIR" 2>/dev/null || true)"
  if [ -n "$DERIVED" ] && [ -d ".features/$DERIVED" ]; then
    REFRESH_FEATURE="$DERIVED"
  fi
fi

if [ "$REFRESH_FEATURE" != "$FEATURE" ]; then
  PHASE="$(sdd_feature_effective_phase "$REFRESH_FEATURE")"
fi

# Only warn during implement phase
[ "$PHASE" = "implement" ] || exit 0

FEATURE_DIR=".features/$REFRESH_FEATURE"
SCOPE_FILE="$FEATURE_DIR/task-scope.txt"
SCOPE_LABEL="task-scope.txt"

if [ ! -f "$SCOPE_FILE" ]; then
  SCOPE_FILE="$FEATURE_DIR/scope.txt"
  SCOPE_LABEL="scope.txt"
fi

# Graceful exit if no scope file exists
[ -f "$SCOPE_FILE" ] || exit 0

# Check if file is in scope. Scope files store relative paths (authored in
# tasks.md / research.md), but hooks receive absolute file paths — compare both.
if sdd_scope_contains_path "$SCOPE_FILE" "$REL_PATH" "$FILE_PATH"; then
  exit 0
fi

# File not in scope — emit non-blocking warning
if [ "$SCOPE_LABEL" = "task-scope.txt" ]; then
  NEXT_HINT="update tasks.md's Files list and run 'sdd task scope-refresh $REFRESH_FEATURE <task-id>' to regenerate task-scope.txt without resetting task status"
else
  NEXT_HINT="update research.md and run 'sdd scope refresh $REFRESH_FEATURE'"
fi

WARNING="$(cat <<EOF
$(sdd_tagged_block "scope_drift_warning" "Scope drift warning: $FILE_PATH is not listed in $SCOPE_LABEL for $REFRESH_FEATURE.")
$(sdd_tagged_block "uncertain" "Uncertain: this edit is outside the recorded task scope.")
$(sdd_tagged_block "inspect" "Inspect: the current task's Files list plus $SCOPE_LABEL before changing code.")
$(sdd_tagged_block "next_steps" "Next: if the edit is intentional, $NEXT_HINT before proceeding.")
$(sdd_tagged_block "avoid" "Avoid: guessing scope, piggybacking drive-by cleanup, or broadening the change without artifact coverage.")
EOF
)"

jq -n --arg ctx "$WARNING" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
