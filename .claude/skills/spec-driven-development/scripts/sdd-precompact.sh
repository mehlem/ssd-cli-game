#!/usr/bin/env bash
# sdd-precompact.sh — PreCompact hook: append state snapshot to continuity.md
# Fires synchronously before context compaction (auto or manual).
# Captures: timestamp, phase, current task, task counts, last 3 scratchpad observations.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

source "$SCRIPT_DIR/sdd-lib.sh"

# Detect active feature and phase
IFS='|' read -r FEATURE RAW_PHASE <<< "$(sdd_detect_feature_phase)" || exit 0
[ "$FEATURE" = "none" ] && exit 0

FEATURE_DIR=".features/$FEATURE"
[ -d "$FEATURE_DIR" ] || exit 0
PHASE="$(sdd_feature_effective_phase "$FEATURE")"
[ -n "$PHASE" ] || PHASE="$RAW_PHASE"

STATE_FILE="$FEATURE_DIR/state.json"

# Refresh state.json + summary only when stale. The combined cost of
# sdd-status.sh + sdd-summary.sh is ~11s on a 25-task feature, which
# exceeds the 10s PreCompact hook timeout and silently truncates the
# continuity snapshot. The async cache-refresh hook keeps state.json fresh
# during normal sessions, so this branch fires only on cold compacts.
if ! sdd_state_is_fresh "$STATE_FILE" 30; then
  bash "$SCRIPT_DIR/sdd-status.sh" --json "$FEATURE" >/dev/null 2>&1 || true
  bash "$SCRIPT_DIR/sdd-summary.sh" "$FEATURE" >/dev/null 2>&1 || true
fi

CONTINUITY_FILE="$FEATURE_DIR/continuity.md"
SCRATCHPAD_FILE="$FEATURE_DIR/scratchpad.md"

# Get task counts and current task from state.json (fast) or regenerate
CURRENT_TASK="unknown"
COMPLETED=0
IN_PROGRESS=0
PENDING=0
BLOCKED=0

if [ -f "$STATE_FILE" ]; then
  CURRENT_TASK="$(jq -r '.current_task.id // "none"' "$STATE_FILE" 2>/dev/null)"
  CURRENT_HEADING="$(jq -r '.current_task.heading // ""' "$STATE_FILE" 2>/dev/null)"
  CURRENT_DISPLAY_REF="$(jq -r '.current_task.display_ref // ""' "$STATE_FILE" 2>/dev/null)"
  COMPLETED="$(jq -r '.tasks.completed // 0' "$STATE_FILE" 2>/dev/null)"
  IN_PROGRESS="$(jq -r '.tasks.in_progress // 0' "$STATE_FILE" 2>/dev/null)"
  PENDING="$(jq -r '.tasks.pending // 0' "$STATE_FILE" 2>/dev/null)"
  BLOCKED="$(jq -r '.tasks.blocked // 0' "$STATE_FILE" 2>/dev/null)"
else
  TASK_SUMMARY_JSON="$(sdd_feature_task_summary_json "$FEATURE_DIR")"
  COMPLETED="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.completed // 0' 2>/dev/null)"
  IN_PROGRESS="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.in_progress // 0' 2>/dev/null)"
  PENDING="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.pending // 0' 2>/dev/null)"
  BLOCKED="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.blocked // 0' 2>/dev/null)"
  CURRENT_TASK="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.current_task.id // "none"' 2>/dev/null)"
  CURRENT_HEADING="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.current_task.heading // ""' 2>/dev/null)"
  CURRENT_DISPLAY_REF="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.current_task.display_ref // ""' 2>/dev/null)"
fi

# Format current task display
TASK_DISPLAY="$CURRENT_TASK"
if [ -n "${CURRENT_DISPLAY_REF:-}" ] && [ "$CURRENT_DISPLAY_REF" != "null" ] && [ "$CURRENT_DISPLAY_REF" != "$CURRENT_TASK" ] && [ -n "${CURRENT_HEADING:-}" ] && [ "$CURRENT_HEADING" != "null" ] && [ "$CURRENT_HEADING" != "" ]; then
  TASK_DISPLAY="$CURRENT_DISPLAY_REF: $CURRENT_HEADING"
elif [ -n "${CURRENT_HEADING:-}" ] && [ "$CURRENT_HEADING" != "null" ] && [ "$CURRENT_HEADING" != "" ]; then
  TASK_DISPLAY="$CURRENT_TASK: $CURRENT_HEADING"
fi

# Get last 3 scratchpad observations
OBSERVATIONS=""
if [ -f "$SCRATCHPAD_FILE" ]; then
  OBSERVATIONS="$(grep -E '^\- \[' "$SCRATCHPAD_FILE" 2>/dev/null | tail -3)" || true
fi

TIMESTAMP="$(date +%Y-%m-%dT%H:%M:%S)"

customization_learned_section() {
  local project_file=".sdd/customization.yaml"
  local feature_file="$FEATURE_DIR/customization.yaml"
  local project_learned="" feature_learned="" bullet

  project_learned="$(sdd_read_customization_file "$project_file" learned 2>/dev/null || true)"
  feature_learned="$(sdd_read_customization_file "$feature_file" learned 2>/dev/null || true)"

  [ -n "$project_learned" ] || [ -n "$feature_learned" ] || return 0

  printf '\n## customization.learned\n'
  if [ -n "$project_learned" ]; then
    printf '\n[project]\n'
    while IFS= read -r bullet; do
      [ -n "$bullet" ] || continue
      printf -- '- %s\n' "$bullet"
    done <<EOF
$project_learned
EOF
  fi
  if [ -n "$feature_learned" ]; then
    printf '\n[feature]\n'
    while IFS= read -r bullet; do
      [ -n "$bullet" ] || continue
      printf -- '- %s\n' "$bullet"
    done <<EOF
$feature_learned
EOF
  fi
}

CUSTOMIZATION_LEARNED_SECTION="$(customization_learned_section)"

# Create continuity.md if it doesn't exist
if [ ! -f "$CONTINUITY_FILE" ]; then
  cat > "$CONTINUITY_FILE" <<EOF
# Continuity: $FEATURE

## Compaction Snapshot ($TIMESTAMP)

- Phase: $PHASE
- Current task: $TASK_DISPLAY
- Tasks: $COMPLETED completed, $IN_PROGRESS in-progress, $PENDING pending, $BLOCKED blocked
EOF
  if [ -n "$OBSERVATIONS" ]; then
    printf '\n### Recent Observations\n\n' >> "$CONTINUITY_FILE"
    printf '%s\n' "$OBSERVATIONS" >> "$CONTINUITY_FILE"
  fi
  if [ -n "$CUSTOMIZATION_LEARNED_SECTION" ]; then
    printf '%s\n' "$CUSTOMIZATION_LEARNED_SECTION" >> "$CONTINUITY_FILE"
  fi
  SUMMARY_COMPACT="$FEATURE_DIR/summary-compact.md"
  if [ -f "$SUMMARY_COMPACT" ] && [ -s "$SUMMARY_COMPACT" ]; then
    printf '\n### Compact Summary\n\n' >> "$CONTINUITY_FILE"
    grep '^- ' "$SUMMARY_COMPACT" >> "$CONTINUITY_FILE" || true
  fi
  exit 0
fi

# Append snapshot to existing continuity.md
{
  printf '\n## Compaction Snapshot (%s)\n\n' "$TIMESTAMP"
  printf -- '- Phase: %s\n' "$PHASE"
  printf -- '- Current task: %s\n' "$TASK_DISPLAY"
  printf -- '- Tasks: %s completed, %s in-progress, %s pending, %s blocked\n' \
    "$COMPLETED" "$IN_PROGRESS" "$PENDING" "$BLOCKED"
  if [ -n "$OBSERVATIONS" ]; then
    printf '\n### Recent Observations\n\n'
    printf '%s\n' "$OBSERVATIONS"
  fi
  if [ -n "$CUSTOMIZATION_LEARNED_SECTION" ]; then
    printf '%s\n' "$CUSTOMIZATION_LEARNED_SECTION"
  fi
} >> "$CONTINUITY_FILE"

SUMMARY_COMPACT="$FEATURE_DIR/summary-compact.md"
if [ -f "$SUMMARY_COMPACT" ] && [ -s "$SUMMARY_COMPACT" ]; then
  printf '\n### Compact Summary\n\n' >> "$CONTINUITY_FILE"
  grep '^- ' "$SUMMARY_COMPACT" >> "$CONTINUITY_FILE" || true
fi

exit 0
