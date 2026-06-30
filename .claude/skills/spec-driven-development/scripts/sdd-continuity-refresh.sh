#!/usr/bin/env bash
# sdd-continuity-refresh.sh — Refresh generated continuity.md state block.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

source "$SCRIPT_DIR/sdd-lib.sh"

usage() {
  echo "Usage: sdd-continuity-refresh.sh [--feature] <feature-id>" >&2
}

FEATURE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --feature)
      shift
      FEATURE="${1:-}"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      usage
      exit "$SDD_EXIT_USAGE"
      ;;
    *)
      FEATURE="$1"
      ;;
  esac
  shift || true
done

[ -n "$FEATURE" ] || { usage; exit "$SDD_EXIT_USAGE"; }

FEATURE_DIR="$SDD_FEATURE_ROOT/$FEATURE"
STATE_FILE="$FEATURE_DIR/state.json"
TASKS_FILE="$FEATURE_DIR/tasks.md"
CONTINUITY_FILE="$FEATURE_DIR/continuity.md"

[ -d "$FEATURE_DIR" ] || exit 0
[ -f "$CONTINUITY_FILE" ] || exit 0

feature_task_files() {
  if sdd_feature_has_work_packages "$FEATURE_DIR"; then
    sdd_feature_wp_task_files "$FEATURE_DIR"
  elif [ -f "$TASKS_FILE" ]; then
    sdd_task_normalize_file_path "$TASKS_FILE"
  fi
}

TASK_ROWS_JSON="[]"
while IFS= read -r task_file; do
  [ -n "$task_file" ] || continue
  [ -f "$task_file" ] || continue
  work_package="$(sdd_task_work_package_from_tasks_file "$task_file")"
  task_prefix=""
  [ -n "$work_package" ] && task_prefix="$(sdd_task_wp_ref_prefix "$work_package")"
  rows_json="$(sdd_task_rows_json "$task_file" 2>/dev/null | jq -c \
    --arg tasks_file "$task_file" \
    --arg work_package "$work_package" \
    --arg task_prefix "$task_prefix" \
    'map(. + {
      tasks_file: $tasks_file,
      work_package: (if $work_package == "" then null else $work_package end),
      display_ref: (if $task_prefix == "" then .id else "\($task_prefix)/\(.id)" end),
      display_heading: (if $task_prefix == "" then .heading else "\($task_prefix)/\(.heading)" end)
    })' 2>/dev/null || printf '[]')"
  TASK_ROWS_JSON="$(jq -nc --argjson existing "$TASK_ROWS_JSON" --argjson rows "$rows_json" '$existing + $rows')"
done <<EOF
$(feature_task_files)
EOF

state_value() {
  local jq_expr="$1" fallback="$2"
  if [ -f "$STATE_FILE" ]; then
    jq -r "$jq_expr // \"$fallback\"" "$STATE_FILE" 2>/dev/null || printf '%s\n' "$fallback"
  else
    printf '%s\n' "$fallback"
  fi
}

task_count() {
  local status="$1" state_key="$2" fallback
  fallback="$(printf '%s\n' "$TASK_ROWS_JSON" | jq -r --arg status "$status" '[.[] | select(.status == $status)] | length' 2>/dev/null || printf '0')"
  state_value ".tasks.$state_key" "$fallback"
}

task_heading_by_id() {
  local task_id="$1" tasks_file="${2:-}"
  [ -n "$task_id" ] && [ "$task_id" != "none" ] && [ "$task_id" != "null" ] || return 0
  printf '%s\n' "$TASK_ROWS_JSON" | jq -r --arg id "$task_id" --arg tasks_file "$tasks_file" '
    ([.[] | select(.id == $id and ($tasks_file == "" or .tasks_file == $tasks_file)) | (.display_heading // .heading)] | first) // empty
  ' 2>/dev/null
}

task_heading_by_status() {
  local status="$1" limit="${2:-0}"
  if [ "$limit" -gt 0 ]; then
    printf '%s\n' "$TASK_ROWS_JSON" | jq -r --arg status "$status" --argjson limit "$limit" '
      [.[] | select(.status == $status) | (.display_heading // .heading)][0:$limit][]
    ' 2>/dev/null
  else
    printf '%s\n' "$TASK_ROWS_JSON" | jq -r --arg status "$status" '.[] | select(.status == $status) | (.display_heading // .heading)' 2>/dev/null
  fi
}

current_files_raw() {
  local current_id="$1" tasks_file="${2:-}"
  if [ -n "$current_id" ] && [ "$current_id" != "none" ] && [ "$current_id" != "null" ]; then
    printf '%s\n' "$TASK_ROWS_JSON" | jq -r --arg id "$current_id" --arg tasks_file "$tasks_file" '
      ([.[] | select(.id == $id and ($tasks_file == "" or .tasks_file == $tasks_file)) | .files_raw] | first) // empty
    ' 2>/dev/null
  else
    printf '%s\n' "$TASK_ROWS_JSON" | jq -r '([.[] | select(.status == "in-progress") | .files_raw] | first) // empty' 2>/dev/null
  fi
}

format_bullets() {
  local text="$1" fallback="$2" line had_line=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf -- '- %s\n' "$line"
    had_line=1
  done <<EOF
$text
EOF
  [ "$had_line" -eq 1 ] || printf -- '- %s\n' "$fallback"
}

format_files() {
  local raw="$1"
  if [ -z "$raw" ] || [ "$raw" = "null" ]; then
    printf -- '- None listed.\n'
    return 0
  fi
  if printf '%s\n' "$raw" | jq -e 'type == "array"' >/dev/null 2>&1; then
    printf '%s\n' "$raw" | jq -r '.[] | "- " + .' 2>/dev/null
  else
    printf -- '- %s\n' "$raw"
  fi
}

PHASE="$(state_value '.effective_phase // .phase' 'unknown')"
CURRENT_TASK="$(state_value '.current_task.id' 'none')"
CURRENT_HEADING="$(state_value '.current_task.heading' '')"
CURRENT_TASKS_FILE="$(state_value '.current_task.tasks_file' '')"
CURRENT_DISPLAY_REF="$(state_value '.current_task.display_ref' '')"
if [ -z "$CURRENT_HEADING" ] || [ "$CURRENT_HEADING" = "null" ]; then
  CURRENT_HEADING="$(task_heading_by_id "$CURRENT_TASK" "$CURRENT_TASKS_FILE")"
fi
if [ -z "$CURRENT_TASK" ] || [ "$CURRENT_TASK" = "null" ]; then
  CURRENT_TASK="none"
fi

FEATURE_TASK_SUMMARY_JSON="$(sdd_feature_task_summary_json "$FEATURE_DIR")"
COMPLETED="$(state_value '.tasks.completed' "$(printf '%s\n' "$FEATURE_TASK_SUMMARY_JSON" | jq -r '.completed // 0')")"
IN_PROGRESS="$(state_value '.tasks.in_progress' "$(printf '%s\n' "$FEATURE_TASK_SUMMARY_JSON" | jq -r '.in_progress // 0')")"
PENDING="$(state_value '.tasks.pending' "$(printf '%s\n' "$FEATURE_TASK_SUMMARY_JSON" | jq -r '.pending // 0')")"
BLOCKED="$(state_value '.tasks.blocked' "$(printf '%s\n' "$FEATURE_TASK_SUMMARY_JSON" | jq -r '.blocked // 0')")"

COMPLETED_HEADINGS="$(task_heading_by_status completed)"
PENDING_HEADINGS="$(task_heading_by_status pending 3)"
FILES_RAW="$(current_files_raw "$CURRENT_TASK" "$CURRENT_TASKS_FILE")"

CURRENT_DISPLAY="$CURRENT_TASK"
if [ -n "$CURRENT_DISPLAY_REF" ] && [ "$CURRENT_DISPLAY_REF" != "null" ] && [ "$CURRENT_DISPLAY_REF" != "$CURRENT_TASK" ] && [ -n "$CURRENT_HEADING" ] && [ "$CURRENT_HEADING" != "null" ]; then
  CURRENT_DISPLAY="$CURRENT_DISPLAY_REF: $CURRENT_HEADING"
elif [ -n "$CURRENT_HEADING" ] && [ "$CURRENT_HEADING" != "null" ]; then
  CURRENT_DISPLAY="$CURRENT_HEADING"
fi

FENCED_BLOCK="$(
  cat <<EOF
<!-- SDD-AUTO-START -->
### Done

- Phase: $PHASE
- Tasks: $COMPLETED completed, $IN_PROGRESS in-progress, $PENDING pending, $BLOCKED blocked
$(format_bullets "$COMPLETED_HEADINGS" "No completed tasks yet.")

### Now

- Current task: $CURRENT_DISPLAY

### Next

$(format_bullets "$PENDING_HEADINGS" "No pending tasks.")

### Working Set

$(format_files "$FILES_RAW")
<!-- SDD-AUTO-END -->
EOF
)"
BLOCK_FILE="$(sdd_tmp_for_target "$CONTINUITY_FILE.block")"
sdd_cleanup_push "$BLOCK_FILE"
printf '%s\n' "$FENCED_BLOCK" > "$BLOCK_FILE"

if grep -qx '<!-- SDD-AUTO-START -->' "$CONTINUITY_FILE" 2>/dev/null && \
   grep -qx '<!-- SDD-AUTO-END -->' "$CONTINUITY_FILE" 2>/dev/null; then
  NEW_CONTENT="$(
    awk -v block_file="$BLOCK_FILE" '
      function emit_block(  line) {
        while ((getline line < block_file) > 0) print line
        close(block_file)
      }
      $0 == "<!-- SDD-AUTO-START -->" {
        emit_block()
        in_auto = 1
        next
      }
      $0 == "<!-- SDD-AUTO-END -->" {
        in_auto = 0
        next
      }
      !in_auto { print }
    ' "$CONTINUITY_FILE"
  )"
else
  NEW_CONTENT="$(
    awk -v block_file="$BLOCK_FILE" '
      function emit_block(  line) {
        while ((getline line < block_file) > 0) print line
        close(block_file)
      }
      BEGIN { inserted = 0; in_state = 0 }
      /^## State[[:space:]]*$/ && !inserted {
        print
        print ""
        emit_block()
        inserted = 1
        in_state = 1
        next
      }
      in_state && /^## / {
        in_state = 0
      }
      in_state { next }
      { print }
      END {
        if (!inserted) {
          print ""
          print "## State"
          print ""
          emit_block()
        }
      }
    ' "$CONTINUITY_FILE"
  )"
fi

sdd_write_file_atomic "$CONTINUITY_FILE" "$NEW_CONTENT" >/dev/null
sdd_cleanup_file "$BLOCK_FILE"
