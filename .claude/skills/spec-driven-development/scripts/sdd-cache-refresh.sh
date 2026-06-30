#!/usr/bin/env bash
# sdd-cache-refresh.sh — Async PostToolUse hook: refresh state.json + append changes.log
# Runs in background after every Bash/Edit/Write tool use.
# Pure side-effect — exit 0 always (async hooks can't influence Claude).

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_install_cleanup_trap

# Singleton guard — only one cache-refresh runs at a time per project.
# Extra invocations exit immediately; the running instance handles the update.
sdd_lock_or_exit "cache-refresh"

# Read JSON from stdin — extract tool_name and file_path in one jq call
INPUT="$(cat)"
IFS=$'\t' read -r TOOL_NAME FILE_PATH <<< "$(echo "$INPUT" | jq -r '[.tool_name // empty, .tool_input.file_path // empty] | @tsv')"
REL_FILE_PATH=""
FILE_PATH_IN_PROJECT=0
if [ -n "$FILE_PATH" ]; then
  REL_FILE_PATH="$(sdd_project_relative_path "$FILE_PATH" "$PROJECT_DIR" 2>/dev/null || true)"
  case "$FILE_PATH" in
    /*)
      case "$FILE_PATH" in
        "${PROJECT_DIR%/}"/*) FILE_PATH_IN_PROJECT=1 ;;
      esac
      ;;
    *)
      FILE_PATH_IN_PROJECT=1
      ;;
  esac
fi

# For Bash tool calls (no file_path), capture the command so non-mutating
# commands can be skipped. Read via a separate jq — NOT by widening the 2-field
# @tsv read above — because an empty file_path would let `IFS=$'\t' read`
# collapse fields and shift the command into the wrong variable.
COMMAND=""
if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
fi

# Detect active feature and phase. FEATURE is the feature-root-relative path
# (flat ID for legacy features, group/path/id for nested features).
FEATURE_CONTEXT="$(sdd_feature_context_tsv || true)"
IFS=$'\t' read -r FEATURE PHASE _SOURCE _WP_ID _WP_PHASE _WP_COUNT _WP_DONE _WP_ACTIVE _WP_PENDING <<EOF
$FEATURE_CONTEXT
EOF

[ -z "${FEATURE:-}" ] || [ "$FEATURE" = "none" ] && exit 0

FEATURE_DIR=".features/$FEATURE"
[ -d "$FEATURE_DIR" ] || exit 0

# Derive feature from edited file path when possible (fixes stale refresh when
# auto-detected feature differs from the feature whose files were edited —
# e.g., editing 0016's review.md while 0013 is auto-detected as active)
REFRESH_FEATURE="$FEATURE"
REFRESH_DIR="$FEATURE_DIR"
if [ -n "$FILE_PATH" ]; then
  DERIVED="$(sdd_feature_path_for_file "$FILE_PATH" "$PROJECT_DIR" 2>/dev/null || true)"
  if [ -n "$DERIVED" ] && [ -d ".features/$DERIVED" ]; then
    REFRESH_FEATURE="$DERIVED"
    REFRESH_DIR=".features/$DERIVED"
  fi
fi

# Determine raw/effective phase of the refresh target feature.
RAW_PHASE="$(sdd_feature_phase "$REFRESH_FEATURE")"
PHASE="$(sdd_feature_effective_phase "$REFRESH_FEATURE")"

WP_ARTIFACT_EDIT=0
if [ -n "$FILE_PATH" ]; then
  case "$FILE_PATH" in
    *"$REFRESH_DIR"/wp-*/tasks.md|*"$REFRESH_DIR"/wp-*/review.md|*"$REFRESH_FEATURE"/wp-*/tasks.md|*"$REFRESH_FEATURE"/wp-*/review.md)
      WP_ARTIFACT_EDIT=1
      ;;
  esac
fi

# Skip expensive refreshes for closed features — their state won't change.
# Also skip when the edit is not inside .features/ (non-artifact file edits
# don't affect feature state — e.g., editing sdd-lib.sh, README.md, etc.).
SKIP_EXPENSIVE=0
if [ "$PHASE" = "close" ] && [ "$REFRESH_FEATURE" = "$FEATURE" ]; then
  SKIP_EXPENSIVE=1
elif [ -n "$FILE_PATH" ]; then
  case "$REL_FILE_PATH" in
    .features/*) ;;  # artifact edit — proceed with refresh
    *) SKIP_EXPENSIVE=1 ;;  # non-artifact edit — skip expensive calls
  esac
elif [ "$TOOL_NAME" = "Bash" ]; then
  # Bash calls have no file_path and cannot mutate SDD state unless they invoke
  # the sdd CLI. Bias toward proceeding (false positives are merely slow; a
  # missed mutation would leave stale state).
  case " $COMMAND " in
    *" sdd "*|*"/sdd "*) ;;  # invokes the sdd CLI — proceed with refresh
    *) SKIP_EXPENSIVE=1 ;;   # non-sdd command — skip expensive calls
  esac
fi

if [ "$SKIP_EXPENSIVE" -eq 0 ]; then
  # Staleness guard — skip if state.json was refreshed in the last 10 seconds
  if [ "$WP_ARTIFACT_EDIT" -eq 1 ] || ! sdd_state_is_fresh "$REFRESH_DIR/state.json" 10; then
    # Refresh state.json via sdd-status.sh --json
    bash "$SCRIPT_DIR/sdd-status.sh" --json "$REFRESH_FEATURE" > /dev/null 2>&1 || true
    # Also refresh auto-detected feature if different
    [ "$REFRESH_FEATURE" != "$FEATURE" ] && bash "$SCRIPT_DIR/sdd-status.sh" --json "$FEATURE" > /dev/null 2>&1 || true
  fi

  # Summary refresh: lazy via sdd_summary_maybe (mtime gate skips when fresh).
  # Singleton lock inside sdd-summary.sh prevents fork-storm. Async hook with
  # 30s timeout absorbs the ~0.5s typical regen cost. Original 22-min issue
  # was the sdd-index.sh cascade (since removed from sdd-summary.sh).
  if [ -n "$FILE_PATH" ]; then
    case "$FILE_PATH" in
      *"$REFRESH_DIR"/wp-*/tasks.md|*"$REFRESH_DIR"/wp-*/review.md|*"$REFRESH_FEATURE"/wp-*/tasks.md|*"$REFRESH_FEATURE"/wp-*/review.md)
        bash "$SCRIPT_DIR/sdd-summary.sh" "$REFRESH_FEATURE" >/dev/null 2>&1 || true
        [ "$REFRESH_FEATURE" != "$FEATURE" ] && sdd_summary_maybe "$FEATURE"
        ;;
      *"$REFRESH_DIR/brief.md"|*"$REFRESH_DIR/spec.md"|*"$REFRESH_DIR/research.md"|*"$REFRESH_DIR/plan.md"|*"$REFRESH_DIR/tasks.md"|*"$REFRESH_DIR/review.md"|*"$REFRESH_DIR/continuity.md"|*"$REFRESH_FEATURE/brief.md"|*"$REFRESH_FEATURE/spec.md"|*"$REFRESH_FEATURE/research.md"|*"$REFRESH_FEATURE/plan.md"|*"$REFRESH_FEATURE/tasks.md"|*"$REFRESH_FEATURE/review.md"|*"$REFRESH_FEATURE/continuity.md")
        sdd_summary_maybe "$REFRESH_FEATURE"
        [ "$REFRESH_FEATURE" != "$FEATURE" ] && sdd_summary_maybe "$FEATURE"
        ;;
    esac
  fi

  # Auto-refresh scope.txt when research.md changes
  if [ -n "$FILE_PATH" ]; then
    case "$FILE_PATH" in
      *"$REFRESH_DIR/research.md"|*"$REFRESH_FEATURE/research.md")
        bash "$SCRIPT_DIR/sdd-scope.sh" refresh "$REFRESH_FEATURE" >/dev/null 2>&1 || true
        ;;
    esac
  fi

  # Refresh trace.json after artifact edits (use ensure — only rebuilds when stale)
  if [ -n "$FILE_PATH" ]; then
    case "$FILE_PATH" in
      *"$REFRESH_DIR/brief.md"|*"$REFRESH_DIR/spec.md"|*"$REFRESH_DIR/research.md"|*"$REFRESH_DIR/plan.md"|*"$REFRESH_DIR/tasks.md"|*"$REFRESH_DIR/review.md"|*"$REFRESH_DIR"/wp-*/tasks.md|*"$REFRESH_DIR"/wp-*/review.md|*"$REFRESH_FEATURE/brief.md"|*"$REFRESH_FEATURE/spec.md"|*"$REFRESH_FEATURE/research.md"|*"$REFRESH_FEATURE/plan.md"|*"$REFRESH_FEATURE/tasks.md"|*"$REFRESH_FEATURE/review.md")
        if [ "$(sdd_profile "$REFRESH_FEATURE")" != "lite" ]; then
          bash "$SCRIPT_DIR/sdd-trace.sh" ensure "$REFRESH_FEATURE" >/dev/null 2>&1 || true
        fi
        ;;
    esac
  fi
fi

# Refresh epic rollup when a linked feature artifact changes. Use the current
# mode because linked feature state can change while EPIC.md itself is unchanged.
# Gated on SKIP_EXPENSIVE=0 so non-sdd Bash calls and non-artifact edits don't
# pay for a full epic rebuild. The anchor is resolved by profile (lite-safe).
if [ "$SKIP_EXPENSIVE" -eq 0 ] && [ -f "$SDD_FEATURE_ROOT/EPIC.md" ]; then
  EPIC_ANCHOR="$(sdd_feature_epic_anchor_path_from_dir "$REFRESH_DIR" 2>/dev/null || true)"
  EPIC_ENTRY=""
  [ -n "$EPIC_ANCHOR" ] && EPIC_ENTRY="$(sdd_frontmatter_value "$EPIC_ANCHOR" epic_entry 2>/dev/null || true)"
  if [ -n "$EPIC_ENTRY" ] && [ -f "$SCRIPT_DIR/sdd-epic-refresh.sh" ]; then
    bash "$SCRIPT_DIR/sdd-epic-refresh.sh" --current >/dev/null 2>&1 || true
  fi
fi

# Append to changes.log for Edit/Write only (they have a file_path)
if [ -n "$FILE_PATH" ] && [ "$FILE_PATH_IN_PROJECT" -eq 1 ]; then
  case "$TOOL_NAME" in
    Edit|Write)
      printf '%s | %s | %s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$TOOL_NAME" "$FILE_PATH" >> "$REFRESH_DIR/changes.log"
      ;;
  esac
fi

# Write state cache for T-007 event-aware nudge detection
CACHE_FILE="$(sdd_state_cache_path)"
mkdir -p "$(dirname "$CACHE_FILE")"

PREV_COUNTER=0
[ -f "$CACHE_FILE" ] && PREV_COUNTER="$(jq -r '.tool_calls_since_scratchpad // 0' "$CACHE_FILE" 2>/dev/null)" || true
PREV_CONTINUITY_COUNTER=0
[ -f "$CACHE_FILE" ] && PREV_CONTINUITY_COUNTER="$(jq -r '.tool_calls_since_continuity // 0' "$CACHE_FILE" 2>/dev/null)" || true
PREV_KNOWLEDGE_COUNTER=0
[ -f "$CACHE_FILE" ] && PREV_KNOWLEDGE_COUNTER="$(jq -r '.tool_calls_since_knowledge // 0' "$CACHE_FILE" 2>/dev/null)" || true
PREV_LAST_PHASE=""
[ -f "$CACHE_FILE" ] && PREV_LAST_PHASE="$(jq -r '.last_phase // empty' "$CACHE_FILE" 2>/dev/null)" || true
PREV_LAST_TASK=""
[ -f "$CACHE_FILE" ] && PREV_LAST_TASK="$(jq -r '.last_task // empty' "$CACHE_FILE" 2>/dev/null)" || true
SESSION_FLAGS_JSON="$(sdd_read_session_flags)"

COUNTER=$((PREV_COUNTER + 1))
CONTINUITY_COUNTER=$((PREV_CONTINUITY_COUNTER + 1))
KNOWLEDGE_COUNTER=$((PREV_KNOWLEDGE_COUNTER + 1))
case "${FILE_PATH:-}" in
  *scratchpad.md) COUNTER=0 ;;
esac
case "${FILE_PATH:-}" in
  *continuity.md) CONTINUITY_COUNTER=0 ;;
esac
case "${FILE_PATH:-}" in
  *knowledge.md) KNOWLEDGE_COUNTER=0 ;;
esac

LAST_PHASE="$PHASE"
[ -z "$LAST_PHASE" ] && LAST_PHASE="none"

STATE_FILE="$REFRESH_DIR/state.json"
CURRENT_TASK="none"
CURRENT_STATUS="none"
if [ -f "$STATE_FILE" ]; then
  STATE_FIELDS="$(jq -r '[.effective_phase // .execution_phase // .phase // "none", .current_task.display_ref // .current_task.id // "none"] | @tsv' "$STATE_FILE" 2>/dev/null || printf '%s\tnone' "$LAST_PHASE")"
  IFS=$'\t' read -r LAST_PHASE CURRENT_TASK <<EOF
$STATE_FIELDS
EOF
  [ -n "$LAST_PHASE" ] || LAST_PHASE="$PHASE"
  [ -n "$CURRENT_TASK" ] || CURRENT_TASK="none"
  if [ "$CURRENT_TASK" != "none" ]; then
    TASK_SUMMARY_JSON="$(sdd_feature_task_summary_json "$REFRESH_DIR")"
    CURRENT_STATUS="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '
      .current_task as $task
      | if ($task.id // null) == null then
          "none"
        elif (.in_progress // 0) > 0 then
          "in-progress"
        else
          "pending"
        end
    ' 2>/dev/null)" || CURRENT_STATUS="none"
  fi
fi

CONTINUITY_REFRESH_NEEDED=0
if [ -n "$PREV_LAST_TASK" ] && [ "$CURRENT_TASK" != "$PREV_LAST_TASK" ]; then
  CONTINUITY_REFRESH_NEEDED=1
fi
if [ -n "$PREV_LAST_PHASE" ] && [ "$LAST_PHASE" != "$PREV_LAST_PHASE" ]; then
  CONTINUITY_REFRESH_NEEDED=1
fi
if [ "$WP_ARTIFACT_EDIT" -eq 1 ]; then
  CONTINUITY_REFRESH_NEEDED=1
fi
if [ "$CONTINUITY_REFRESH_NEEDED" -eq 1 ] && [ -f "$SCRIPT_DIR/sdd-continuity-refresh.sh" ]; then
  ( bash "$SCRIPT_DIR/sdd-continuity-refresh.sh" --feature "$REFRESH_FEATURE" >/dev/null 2>&1 || true ) &
fi

CACHE_JSON="$(jq -n \
  --arg phase "$LAST_PHASE" \
  --arg task "$CURRENT_TASK" \
  --arg status "$CURRENT_STATUS" \
  --argjson counter "$COUNTER" \
  --argjson continuity_counter "$CONTINUITY_COUNTER" \
  --argjson knowledge_counter "$KNOWLEDGE_COUNTER" \
  --argjson session_flags "$SESSION_FLAGS_JSON" \
  --arg ts "$(date +%Y-%m-%dT%H:%M:%S)" \
  '{last_phase: $phase, last_task: $task, last_task_status: $status, tool_calls_since_scratchpad: $counter, tool_calls_since_continuity: $continuity_counter, tool_calls_since_knowledge: $knowledge_counter, session_flags: $session_flags, timestamp: $ts}' 2>/dev/null)" || CACHE_JSON=""
[ -n "$CACHE_JSON" ] && sdd_write_file_atomic "$CACHE_FILE" "$CACHE_JSON" >/dev/null 2>&1 || true

exit 0
