#!/usr/bin/env bash
# sdd-advisor-postauthoring.sh — PostToolUse command hook: rubric-advisor review
#
# Fires on Edit|Write of .features/*/(brief|spec|research|plan|review).md.
# Reads the FULL current artifact from disk (not the tool_input diff) so the
# grounding-citation requirement holds identically for Edit and Write. Invokes
# Haiku via `claude -p --bare` against the matching rubric, formats findings
# into tagged blocks, and emits hookSpecificOutput.additionalContext.
#
# Never blocks. Never persists. Exit 0 on every path; silent when no findings
# or on any failure. Hook recursion is prevented by `--bare` in the shared
# invoke helper (see sdd-lib.sh::sdd_advisor_invoke_haiku).

set -euo pipefail

# Graceful degradation: missing jq short-circuits to silent exit 0.
command -v jq >/dev/null 2>&1 || exit 0

# Kill switch (FR-016).
[ "${SDD_ADVISOR_DISABLED:-0}" = "1" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

sdd_has_active_feature || exit 0

INPUT="$(cat)"

# Extract tool name, file path, and session id.
IFS=$'\t' read -r TOOL_NAME FILE_PATH SESSION_ID <<< "$(
  echo "$INPUT" | jq -r '[.tool_name // "", .tool_input.file_path // "", .session_id // ""] | @tsv'
)"

# Only Edit and Write carry a file_path we care about.
case "${TOOL_NAME:-}" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

[ -n "${FILE_PATH:-}" ] || exit 0

FEATURE="$(sdd_feature_path_for_file "$FILE_PATH" "$PROJECT_DIR" 2>/dev/null || true)"
ARTIFACT="$(sdd_feature_artifact_for_file "$FILE_PATH" "$FEATURE" "$PROJECT_DIR" 2>/dev/null || true)"

[ -n "$FEATURE" ] || exit 0
[ -n "$ARTIFACT" ] || exit 0

# Iteration 1 covers five artifacts; tasks.md is deferred.
case "$ARTIFACT" in
  brief|spec|research|plan|review) ;;
  *) exit 0 ;;
esac

ARTIFACT_PATH=".features/$FEATURE/$ARTIFACT.md"
[ -r "$ARTIFACT_PATH" ] || exit 0

RUBRIC_PATH="$(sdd_rubric_path_for "$ARTIFACT" 2>/dev/null || true)"
[ -n "$RUBRIC_PATH" ] && [ -r "$RUBRIC_PATH" ] || exit 0

# Correlate stderr logging with the current hook session for debugging.
export SDD_ADVISOR_SESSION_ID="${SESSION_ID:-unknown}"

FINDINGS="$(sdd_advisor_invoke_haiku "$RUBRIC_PATH" "$ARTIFACT_PATH" || true)"
[ -n "$FINDINGS" ] || exit 0

FINDING_COUNT="$(printf '%s' "$FINDINGS" | jq -r '.findings | length' 2>/dev/null || echo 0)"
[ "$FINDING_COUNT" -gt 0 ] || exit 0

CONTEXT="$(sdd_advisor_format_context "$FINDINGS" postauthoring)"
[ -n "$CONTEXT" ] || exit 0

jq -n --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $ctx}}'
exit 0
