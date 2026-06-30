#!/usr/bin/env bash
# sdd-postcompact.sh — PostCompact hook: capture compact_summary and refresh state.
# Fires synchronously after context compaction (auto or manual).
# Side-effect only: writes to continuity.md, refreshes derived artifacts, exits 0.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

[ -f "$SCRIPT_DIR/sdd-lib.sh" ] || exit 0
source "$SCRIPT_DIR/sdd-lib.sh"

INPUT="$(cat)"

TRIGGER="$(printf '%s' "$INPUT" | jq -r '.trigger // empty' 2>/dev/null)" || TRIGGER=""
COMPACT_SUMMARY="$(printf '%s' "$INPUT" | jq -r '.compact_summary // empty' 2>/dev/null)" || COMPACT_SUMMARY=""

# Detect active feature and phase
IFS='|' read -r FEATURE PHASE <<< "$(sdd_detect_feature_phase)" || exit 0
[ "$FEATURE" = "none" ] && exit 0

FEATURE_DIR=".features/$FEATURE"
[ -d "$FEATURE_DIR" ] || exit 0

CONTINUITY_FILE="$FEATURE_DIR/continuity.md"
TIMESTAMP="$(date +%Y-%m-%dT%H:%M:%S)"

[ -n "$TRIGGER" ] || TRIGGER="unknown"
[ -n "$COMPACT_SUMMARY" ] || COMPACT_SUMMARY="(empty compact_summary)"

if [ ! -f "$CONTINUITY_FILE" ]; then
  {
    printf '# Continuity: %s\n' "$FEATURE"
    printf '\n'
  } > "$CONTINUITY_FILE" 2>/dev/null || true
fi

{
  printf '\n## Compaction Summary (%s)\n\n' "$TIMESTAMP"
  printf -- '- Trigger: %s\n\n' "$TRIGGER"
  printf '%s\n' "$COMPACT_SUMMARY"
} >> "$CONTINUITY_FILE" 2>/dev/null || true

RECOVERY_FILE=".claude/tmp/sdd-customization-learned-recovery-$FEATURE.txt"
CUSTOMIZATION_LEARNED_RECOVERY="$(awk '
  /^## customization\.learned[[:space:]]*$/ {
    capture = 1
    source = ""
    project = ""
    feature = ""
    next
  }
  capture && /^## / {
    capture = 0
    next
  }
  capture && /^\[project\][[:space:]]*$/ {
    source = "project"
    next
  }
  capture && /^\[feature\][[:space:]]*$/ {
    source = "feature"
    next
  }
  capture && /^- / {
    if (source == "project") project = project $0 "\n"
    if (source == "feature") feature = feature $0 "\n"
    next
  }
  END {
    if (project != "") {
      printf "[project/learned]\n%s", project
    }
    if (feature != "") {
      if (project != "") printf "\n"
      printf "[feature/learned]\n%s", feature
    }
  }
' "$CONTINUITY_FILE" 2>/dev/null || true)"

if [ -n "$CUSTOMIZATION_LEARNED_RECOVERY" ]; then
  mkdir -p "$(dirname "$RECOVERY_FILE")" 2>/dev/null || true
  printf '%s\n' "$CUSTOMIZATION_LEARNED_RECOVERY" > "$RECOVERY_FILE" 2>/dev/null || true
else
  rm -f "$RECOVERY_FILE" 2>/dev/null || true
fi

# Refresh derived artifacts after appending the compact summary.
bash "$SCRIPT_DIR/sdd-status.sh" --json "$FEATURE" >/dev/null 2>&1 || true
bash "$SCRIPT_DIR/sdd-summary.sh" "$FEATURE" >/dev/null 2>&1 || true

# Flag the next prompt for re-anchoring when the compact summary dropped key state.
STATE_FILE="$FEATURE_DIR/state.json"
CURRENT_TASK="none"
if [ -f "$STATE_FILE" ]; then
  CURRENT_TASK="$(jq -r '.current_task.id // "none"' "$STATE_FILE" 2>/dev/null)" || CURRENT_TASK="none"
fi

SUMMARY_LOWER="$(printf '%s' "$COMPACT_SUMMARY" | tr '[:upper:]' '[:lower:]')"
FEATURE_LOWER="$(printf '%s' "$FEATURE" | tr '[:upper:]' '[:lower:]')"
PHASE_LOWER="$(printf '%s' "$PHASE" | tr '[:upper:]' '[:lower:]')"
POST_COMPACT_PENDING="false"

if ! printf '%s' "$SUMMARY_LOWER" | grep -qF "$FEATURE_LOWER"; then
  POST_COMPACT_PENDING="true"
fi
if ! printf '%s' "$SUMMARY_LOWER" | grep -qF "$PHASE_LOWER"; then
  POST_COMPACT_PENDING="true"
fi
if [ "$CURRENT_TASK" != "none" ]; then
  TASK_LOWER="$(printf '%s' "$CURRENT_TASK" | tr '[:upper:]' '[:lower:]')"
  if ! printf '%s' "$SUMMARY_LOWER" | grep -qF "$TASK_LOWER"; then
    POST_COMPACT_PENDING="true"
  fi
fi

sdd_set_session_flag "post_compact_pending" "$POST_COMPACT_PENDING" || true

exit 0
