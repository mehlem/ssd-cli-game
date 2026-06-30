#!/usr/bin/env bash
# sdd-task.sh — CRUD operations on tasks in tasks.md
# Usage:
#   sdd-task.sh list    <feature>                    — list active task source tasks with status
#   sdd-task.sh list --all <feature>                 — list all WP tasks with attribution
#   sdd-task.sh next    <feature>                    — show next pending task
#   sdd-task.sh start   <feature> <task-id>          — set status to in-progress
#   sdd-task.sh complete <feature> <task-id>         — set status to completed
#   sdd-task.sh block   <feature> <task-id> [reason] — set status to blocked
#   sdd-task.sh reset   <feature> <task-id>          — reset to pending
#   sdd-task.sh scope-refresh <feature> <task-id>    — refresh task-scope.txt from Files
#   sdd-task.sh add     <feature> <phase> <fr-ids> <title> — add new task
#   sdd-task.sh lint    <feature>                    — statically lint Verification commands
#   sdd-task.sh graph   <feature>                    — emit dependency graph JSON

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FEATURE_ROOT=".features"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "task" "sdd task <cmd> <feature> [args]" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "task" \
      "Manage tasks inside tasks.md for an SDD feature." \
      "sdd task {list|next|start|complete|block|reset|scope-refresh|add|lint|graph} <feature> [args] [--force] [--feature <id|auto>] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd task list 0001-user-auth",
        "sdd task list --all 0001-user-auth",
        "sdd task next --feature auto --json",
        "sdd task start --feature auto T-001",
        "sdd task start --force 0001-user-auth T-002",
        "sdd task scope-refresh 0001-user-auth T-001",
        "sdd task complete --json --feature auto T-001",
        "sdd task lint --feature auto"
      ]'
    return 0
  fi

  echo "sdd-task.sh — Task CRUD operations"
  echo ""
  echo "Commands:"
  echo "  list     <feature>                          List active task source tasks"
  echo "  list --all <feature>                        List all WP tasks with attribution"
  echo "  next     <feature>                          Show next pending task"
  echo "  start    <feature> <task-id>                Mark as in-progress"
  echo "  complete <feature> <task-id>                Mark as completed"
  echo "  block    <feature> <task-id> [reason]       Mark as blocked"
  echo "  reset    <feature> <task-id>                Reset to pending"
  echo "  scope-refresh <feature> <task-id>           Refresh task-scope.txt from Files"
  echo "  add      <feature> <phase> <fr-ids> <title> Add new task"
  echo "  lint     <feature>                          Statically lint Verification commands"
  echo "  graph    <feature>                          Show dependency graph JSON"
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }
sdd_install_cleanup_trap

cmd="${SDD_ARGS[0]:-help}"
TASK_FORCE=0
TASK_ALL=0
TASK_ARGS=()
for arg in "${SDD_ARGS[@]:1}"; do
  case "$arg" in
    --force) TASK_FORCE=1 ;;
    --all) TASK_ALL=1 ;;
    *) TASK_ARGS+=("$arg") ;;
  esac
done

if [ "$TASK_ALL" -eq 1 ] && [ "$cmd" != "list" ]; then
  sdd_usage_error "task" "sdd task list --all <feature>" "--all is only supported for task list"
fi

if [ -n "$SDD_FEATURE_OVERRIDE" ]; then
  feature="$SDD_FEATURE_OVERRIDE"
  TASK_ARG_OFFSET=0
else
  feature="${TASK_ARGS[0]:-}"
  TASK_ARG_OFFSET=1
fi
feature_path="$feature"
feature_dir="$FEATURE_ROOT/$feature_path"

task_arg() {
  local index="$1"
  printf '%s\n' "${TASK_ARGS[$((TASK_ARG_OFFSET + index))]:-}"
}

task_arg_rest() {
  local index="$1"
  local start=$((TASK_ARG_OFFSET + index))
  if [ "$start" -ge "${#TASK_ARGS[@]}" ]; then
    return 0
  fi
  local values=("${TASK_ARGS[@]:$start}")
  printf '%s\n' "${values[*]}"
}

task_id="$(task_arg 0)"

# Resolve active WP directory name for this feature (empty if not WP mode)
_active_wp() {
  local phase_output
  phase_output="$(bash "$SCRIPT_DIR/sdd-phase.sh" "$feature_path" 2>/dev/null)" || true
  local wp
  wp="$(echo "$phase_output" | grep '^wp: ' | cut -d' ' -f2)" || true
  if [ -n "$wp" ] && [ "$wp" != "none" ]; then
    echo "$wp"
  fi
}

tasks_file() {
  local wp
  wp="$(_active_wp)"
  if [ -n "$wp" ]; then
    echo "$feature_dir/$wp/tasks.md"
  else
    echo "$feature_dir/tasks.md"
  fi
}

rewrite_file_with_awk() {
  local file="$1"
  shift
  local tmp

  tmp="$(sdd_tmp_for_target "$file")" || return 1
  sdd_cleanup_push "$tmp"
  if ! awk "$@" "$file" > "$tmp"; then
    sdd_cleanup_file "$tmp"
    return 1
  fi
  if ! sdd_atomic_replace "$tmp" "$file"; then
    sdd_cleanup_file "$tmp"
    return 1
  fi
}

task_metadata_tsv() {
  local tid="$1"
  local file="${2:-$(tasks_file)}"
  local heading title phase_id fr_ids

  heading="$(sdd_task_heading "$file" "$tid" || true)"
  [ -n "$heading" ] || return 1

  case "$heading" in
    *:*) title="${heading#*: }" ;;
    *) title="$heading" ;;
  esac

  phase_id="$(sdd_task_field_value "$file" "$tid" "Phase" || true)"
  fr_ids="$(sdd_task_field_value "$file" "$tid" "Implements" || true)"
  printf '%s\t%s\t%s\n' "$title" "$phase_id" "$fr_ids"
}

# Return the current status for a task ID, or nothing if the task is not found.
task_status() {
  local tid="$1"
  local file="${2:-$(tasks_file)}"

  awk -v tid="$tid" '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && index($0, "## " tid ":") == 1 { in_task = 1; next }
    !in_fence && in_task && /^## T-[0-9]+:/ { exit }
    !in_fence && in_task && /^> Status: / {
      sub(/^> Status: /, "", $0)
      print
      exit
    }
  ' "$file"
}

require_task_status() {
  local tid="$1"
  local file="$2"
  shift 2

  local current
  current="$(task_status "$tid" "$file")"

  if [ -z "$current" ]; then
    sdd_fail "task" "not_found" "$tid not found in $file" "{\"task_id\":\"$tid\",\"tasks_file\":\"$file\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi

  local allowed
  for allowed in "$@"; do
    if [ "$current" = "$allowed" ]; then
      return 0
    fi
  done

  sdd_fail "task" "precondition" "$tid is '$current' in $file (expected: $*)" "{\"task_id\":\"$tid\",\"tasks_file\":\"$file\",\"current_status\":\"$current\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
}

# Validate feature
validate_feature() {
  sdd_resolve_feature_target "$feature" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
    case "$SDD_RESOLUTION_STATUS" in
      not_found)
        sdd_fail "task" "not_found" "feature '$feature' not found" "{\"feature\":\"$feature\"}" "$feature" "arg"
        ;;
      ambiguous)
        sdd_fail "task" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
        ;;
      none)
        sdd_usage_error "task" "sdd task <cmd> <feature> [args]" "feature ID required"
        ;;
    esac
  }
  feature="$SDD_RESOLVED_FEATURE"
  feature_path="${SDD_RESOLVED_FEATURE_PATH:-$feature}"
  feature_dir="${SDD_RESOLVED_FEATURE_DIR:-$FEATURE_ROOT/$feature_path}"
  local tasks
  tasks="$(tasks_file)"
  if [ ! -f "$tasks" ]; then
    sdd_fail "task" "not_found" "$tasks not found" "{\"feature\":\"$feature\",\"tasks_file\":\"$tasks\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
}

# Update task status using awk + tmp + mv (safe from injection)
set_status() {
  local tid="$1"
  local new_status="$2"
  local file
  file="$(tasks_file)"

  # Verify task exists
  if [ -z "$(task_status "$tid" "$file")" ]; then
    sdd_fail "task" "not_found" "$tid not found in $file" "{\"task_id\":\"$tid\",\"tasks_file\":\"$file\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi

  # Update status line within the task section using awk
  rewrite_file_with_awk "$file" -v tid="$tid" -v status="$new_status" '
    /^```/ { print; in_fence = !in_fence; next }
    !in_fence && index($0, "## " tid ":") == 1 { in_task = 1; print; next }
    !in_fence && /^## T-[0-9]+:/ { if (in_task) in_task = 0 }
    !in_fence && in_task && /^> Status: / { print "> Status: " status; next }
    { print }
  ' || sdd_fail "task" "internal" "failed to update task status in $file" "{\"task_id\":\"$tid\",\"tasks_file\":\"$file\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

  # Update the updated date in frontmatter
  local today
  today="$(date +%Y-%m-%d)"
  sdd_portable_sed "$file" -e "s/^updated: .*/updated: $today/" || sdd_fail "task" "internal" "failed to refresh tasks.md updated date" "{\"tasks_file\":\"$file\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

  if ! sdd_is_json_mode; then
    echo "$tid → $new_status"
  else
    echo "$tid → $new_status" >&2
  fi
}

task_scope_file() {
  printf '%s/task-scope.txt\n' "$feature_dir"
}

write_task_scope_file() {
  local tid="$1"
  local file="${2:-$(tasks_file)}"
  local scope_file files_json paths
  scope_file="$(task_scope_file)"
  files_json="$(sdd_task_field_values_json "$file" "$tid" "Files")"
  paths="$(printf '%s\n' "$files_json" | jq -r '.[]? | sub(" \\([^)]*\\)$"; "")')"

  if [ -n "$paths" ]; then
    sdd_write_file_atomic "$scope_file" "$(printf '%s\n' "$paths")"
  else
    rm -f "$scope_file"
  fi
}

remove_task_scope_file() {
  rm -f "$(task_scope_file)"
}

# List tasks across every WP task source, with attribution for repeated task IDs.
cmd_list_all() {
  local files rows_json="[]" files_found=0

  sdd_resolve_feature_target "$feature" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
    case "$SDD_RESOLUTION_STATUS" in
      not_found)
        sdd_fail "task" "not_found" "feature '$feature' not found" "{\"feature\":\"$feature\"}" "$feature" "arg"
        ;;
      ambiguous)
        sdd_fail "task" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
        ;;
      none)
        sdd_usage_error "task" "sdd task list --all <feature>" "feature ID required"
        ;;
    esac
  }
  feature="$SDD_RESOLVED_FEATURE"
  feature_path="${SDD_RESOLVED_FEATURE_PATH:-$feature}"
  feature_dir="${SDD_RESOLVED_FEATURE_DIR:-$FEATURE_ROOT/$feature_path}"
  [ -d "$feature_dir" ] || sdd_fail "task" "not_found" "feature '$feature' not found" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

  if sdd_feature_has_work_packages "$feature_dir"; then
    files="$(sdd_feature_wp_task_files "$feature_dir")"
  elif [ -f "$feature_dir/tasks.md" ]; then
    files="$feature_dir/tasks.md"
  else
    sdd_fail "task" "not_found" "no tasks.md or wp-*/tasks.md found for $feature" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ -f "$file" ] || continue
    files_found=$((files_found + 1))
    local file_rows work_package work_package_path tasks_file_normalized
    file_rows="$(sdd_task_rows_json "$file")"
    work_package="$(sdd_task_work_package_from_tasks_file "$file")"
    tasks_file_normalized="$(sdd_task_normalize_file_path "$file")"
    if [ -n "$work_package" ]; then
      work_package_path="$(sdd_task_normalize_file_path "$(dirname "$file")")"
    else
      work_package_path=""
    fi

    while IFS= read -r row; do
      [ -n "$row" ] || continue
      local row_task_id display_ref enriched_row
      row_task_id="$(printf '%s\n' "$row" | jq -r '.id')"
      display_ref="$(sdd_task_display_ref "$file" "$row_task_id")"
      enriched_row="$(printf '%s\n' "$row" | jq -c \
        --arg work_package "$work_package" \
        --arg work_package_path "$work_package_path" \
        --arg tasks_file "$tasks_file_normalized" \
        --arg display_ref "$display_ref" \
        '. + {
          work_package: (if $work_package == "" then null else $work_package end),
          work_package_path: (if $work_package_path == "" then null else $work_package_path end),
          tasks_file: $tasks_file,
          display_ref: $display_ref
        }')"
      rows_json="$(jq -nc --argjson rows "$rows_json" --argjson row "$enriched_row" '$rows + [$row]')"
    done <<< "$(printf '%s\n' "$file_rows" | jq -c '.[]')"
  done <<< "$files"

  [ "$files_found" -gt 0 ] || sdd_fail "task" "not_found" "no task files found for $feature" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc --arg feature "$feature" --arg feature_path "$feature_path" --arg feature_dir "$feature_dir" --argjson tasks "$rows_json" '{feature:$feature, feature_id:$feature, feature_path:$feature_path, feature_dir:$feature_dir, scope:"all", tasks:$tasks}')"
    sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "$(sdd_feature_effective_phase "$feature_path" 2>/dev/null || sdd_feature_phase "$feature_path")" "$DATA_JSON" '{}' '[]')"
    exit 0
  fi

  echo "Tasks: $feature (all task sources)"
  echo ""
  printf "%-12s %-28s %-15s %-8s %-15s %s\n" "TASK" "WORK PACKAGE" "STATUS" "PHASE" "IMPLEMENTS" "TITLE"
  printf "%-12s %-28s %-15s %-8s %-15s %s\n" "----" "------------" "------" "-----" "----------" "-----"
  while IFS=$'\t' read -r display_ref work_package status phase_id fr_ids title; do
    [ -n "$display_ref" ] || continue
    printf "%-12s %-28s %-15s %-8s %-15s %s\n" "$display_ref" "${work_package:--}" "$status" "$phase_id" "$fr_ids" "$title"
  done <<< "$(printf '%s\n' "$rows_json" | jq -r '.[] | [.display_ref, (.work_package // "-"), (.status // ""), (.phase // ""), (.implements_raw // ""), .title] | @tsv')"
  echo ""
}

# List active task-source tasks
cmd_list() {
  if [ "$TASK_ALL" -eq 1 ]; then
    cmd_list_all
    return 0
  fi

  validate_feature
  local file rows_json rows_tsv
  file="$(tasks_file)"
  rows_json="$(sdd_task_rows_json "$file")"
  rows_tsv="$(printf '%s\n' "$rows_json" | jq -r '.[] | [.id, (.status // ""), (.phase // ""), (.implements_raw // ""), .title] | @tsv')"

  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc --arg feature "$feature" --arg feature_path "$feature_path" --arg feature_dir "$feature_dir" --argjson tasks "$rows_json" '{feature:$feature, feature_id:$feature, feature_path:$feature_path, feature_dir:$feature_dir, tasks: $tasks | map({id, status, phase, implements:(.implements_raw // ""), title})}')"
    sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "$(sdd_feature_phase "$feature_path")" "$DATA_JSON" '{}' '[]')"
    exit 0
  fi

  echo "Tasks: $feature"
  echo ""
  printf "%-8s %-15s %-8s %-15s %s\n" "TASK" "STATUS" "PHASE" "IMPLEMENTS" "TITLE"
  printf "%-8s %-15s %-8s %-15s %s\n" "----" "------" "-----" "----------" "-----"
  while IFS=$'\t' read -r id status phase_id fr_ids title; do
    [ -n "$id" ] || continue
    printf "%-8s %-15s %-8s %-15s %s\n" "$id" "$status" "$phase_id" "$fr_ids" "$title"
  done <<< "$rows_tsv"
  echo ""
}

# Show next pending task
cmd_next() {
  validate_feature
  local file graph_json next_task
  file="$(tasks_file)"
  graph_json="$(sdd_task_graph_json "$file")"
  next_task="$(printf '%s\n' "$graph_json" | jq -r '.ready_tasks[0] // empty')"

  if [ -z "$next_task" ]; then
    local pending_count blocked_preview
    pending_count="$(printf '%s\n' "$graph_json" | jq -r '[.tasks[] | select(.status == "pending")] | length')"
    blocked_preview="$(printf '%s\n' "$graph_json" | jq -r '
      [.tasks[]
       | select(.status == "pending" and (.blockers | length) > 0)
       | "\(.id) blocked by " + (.blockers | map(.ref + if .status then " (" + .status + ")" else "" end) | join(", "))
      ] | join("; ")
    ')"
    if sdd_is_json_mode; then
      DATA_JSON="$(jq -nc \
        --argjson graph "$graph_json" \
        '{task:null, ready_tasks:$graph.ready_tasks, blocked_tasks:$graph.blocked_tasks, problems:$graph.problems}')"
      sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "$(sdd_feature_phase "$feature_path")" "$DATA_JSON" '{}' '[]')"
    else
      if [ "$pending_count" -gt 0 ]; then
        echo "No dependency-ready tasks."
        [ -n "$blocked_preview" ] && echo "Blocked: $blocked_preview"
      else
        echo "No pending tasks — all done or blocked"
      fi
    fi
    return 0
  fi

  local task_title phase_id fr_ids ref_line pitfall_msg phase_skill_line
  IFS=$'\t' read -r task_title phase_id fr_ids <<< "$(task_metadata_tsv "$next_task" "$file")"
  ref_line="$(sdd_phase_reference_line "implement")"
  phase_skill_line="$(sdd_phase_skill_cli_hint implement)"
  if [ "$(sdd_profile "$feature_dir")" = "lite" ]; then
    pitfall_msg="do not widen scope beyond the listed files without updating spec.md and tasks.md first."
  else
    pitfall_msg="do not widen scope beyond the listed files without updating research.md and tasks.md first."
  fi

  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc --arg id "$next_task" --arg title "$task_title" --arg phase_id "$phase_id" --arg implements "$fr_ids" '{task:{id:$id,title:$title,phase:$phase_id,implements:$implements}}')"
    GUIDANCE_JSON="$(jq -nc --arg pitfall "$pitfall_msg" '{"next":"read this task Files, Acceptance Criteria, and Verification block end-to-end.","gate":"commit only when this task boundary is clear from its Files, Acceptance Criteria, and Verification block.","pitfall":$pitfall,"worker":"default to sdd-implementer for tasks touching multiple files or >30 lines; inline only for trivial deterministic edits — SubagentStart hook auto-injects the packet."}')"
    sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
    cat >&2 <<EOF
Next: $next_task: $task_title
Phase: $phase_id | Implements: $fr_ids
Start by: read this task's Files, Acceptance Criteria, and Verification block end-to-end.
${phase_skill_line:+$phase_skill_line
}Gate: commit only when this task boundary is clear from its Files, Acceptance Criteria, and Verification block.
Pitfall: $pitfall_msg
Delegate: default to sdd-implementer for tasks touching multiple files or >30 lines; inline only for trivial deterministic edits — SubagentStart hook auto-injects the dispatch packet.
Then: run \`sdd task start $feature_path $next_task\` when you are committing to this task.
EOF
    if [ -n "$ref_line" ]; then
      printf '%s\n' "$ref_line" >&2
    fi
    return 0
  fi

  cat <<EOF
Next: $next_task: $task_title
Phase: $phase_id | Implements: $fr_ids
Start by: read this task's Files, Acceptance Criteria, and Verification block end-to-end.
${phase_skill_line:+$phase_skill_line
}Gate: commit only when this task boundary is clear from its Files, Acceptance Criteria, and Verification block.
Pitfall: $pitfall_msg
Delegate: default to sdd-implementer for tasks touching multiple files or >30 lines; inline only for trivial deterministic edits — SubagentStart hook auto-injects the dispatch packet.
Then: run \`sdd task start $feature_path $next_task\` when you are committing to this task.
EOF
  if [ -n "$ref_line" ]; then
    printf '%s\n' "$ref_line"
  fi
}

# Start task
cmd_start() {
  validate_feature
  if [ -z "$task_id" ]; then sdd_usage_error "task" "sdd task start [--force] <feature> <task-id>" "task ID required"; fi
  local file graph_json blockers_json blockers_count blocker_summary
  local task_title phase_id fr_ids ref_line phase_skill_line
  file="$(tasks_file)"
  require_task_status "$task_id" "$file" "pending" "blocked"

  graph_json="$(sdd_task_graph_json "$file")"
  blockers_json="$(printf '%s\n' "$graph_json" | jq -c --arg task_id "$task_id" '([.tasks[] | select(.id == $task_id) | .blockers] | first) // []')"
  blockers_count="$(printf '%s\n' "$blockers_json" | jq -r 'length')"
  blocker_summary="$(printf '%s\n' "$blockers_json" | jq -r 'map(.ref + if .status then " (" + .status + ")" else "" end) | join(", ")')"

  if [ "$TASK_FORCE" -ne 1 ] && [ "$blockers_count" -gt 0 ]; then
    sdd_fail "task" "precondition" "$task_id has unresolved dependencies: $blocker_summary" "{\"task_id\":\"$task_id\",\"blockers\":$blockers_json}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement"
  fi

  local trace_file tasks_artifact_id suspect_json suspect_summary suspect_ids
  if [ "$(sdd_profile "$feature_dir")" != "lite" ]; then
    trace_file="$(sdd_trace_path "$feature_path")"
    if ! bash "$SCRIPT_DIR/sdd-trace.sh" ensure "$feature_path" >/dev/null 2>&1; then
      sdd_fail "task" "internal" "failed to refresh trace state for suspect validation" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement"
    fi
    tasks_artifact_id="$(sdd_frontmatter_value "$file" id 2>/dev/null || true)"
    suspect_json="$(jq -c --arg artifact_id "$tasks_artifact_id" '.basis[$artifact_id] // null' "$trace_file" 2>/dev/null || printf 'null')"
    if [ "$suspect_json" != "null" ] && [ "$(printf '%s\n' "$suspect_json" | jq -r '.suspect // false')" = "true" ]; then
      suspect_summary="$(printf '%s\n' "$suspect_json" | jq -r '[.reasons[]? | .message // (.upstream // .via // "unknown suspect reason")] | unique | join("; ")')"
      suspect_ids="$(printf '%s\n' "$suspect_json" | jq -r '[.reasons[]? | .upstream // .via // empty] | unique | join(", ")')"
      [ -n "$suspect_summary" ] || suspect_summary="$tasks_artifact_id is suspect"
      if [ "$TASK_FORCE" -ne 1 ]; then
        sdd_fail "task" "precondition" "$tasks_artifact_id is suspect: $suspect_summary" "{\"task_id\":\"$task_id\",\"artifact_id\":\"$tasks_artifact_id\",\"suspect\":$suspect_json,\"upstreams\":\"$suspect_ids\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement"
      fi
      sdd_warn "$tasks_artifact_id is suspect and --force was used: $suspect_summary"
    fi
  fi

  if [ "$(sdd_profile "$feature_dir")" = "deep" ]; then
    local check_out check_rc
    check_out="$(bash "$SCRIPT_DIR/sdd-check.sh" tasks "$feature_path" 2>&1)" && check_rc=0 || check_rc=$?
    if [ "$check_rc" -ne 0 ]; then
      printf '%s\n' "$check_out" >&2
      exit "$SDD_EXIT_PRECONDITION"
    fi
  fi

  set_status "$task_id" "in-progress"
  write_task_scope_file "$task_id" "$file"
  IFS=$'\t' read -r task_title phase_id fr_ids <<< "$(task_metadata_tsv "$task_id" "$file")"
  ref_line="$(sdd_phase_reference_line "implement")"
  phase_skill_line="$(sdd_phase_skill_cli_hint implement)"
  local pitfall_msg
  if [ "$(sdd_profile "$feature_dir")" = "lite" ]; then
    pitfall_msg="if scope expands or new files appear, update spec.md and tasks.md before continuing."
  else
    pitfall_msg="if scope expands or new files appear, update research.md and tasks.md before continuing."
  fi
  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc \
      --arg id "$task_id" \
      --arg title "$task_title" \
      --arg phase_id "$phase_id" \
      --arg implements "$fr_ids" \
      --arg scope_file ".features/$feature_path/task-scope.txt" \
      --argjson forced "$( [ "$TASK_FORCE" -eq 1 ] && printf 'true' || printf 'false' )" \
      '{task:{id:$id,title:$title,phase:$phase_id,implements:$implements,status:"in-progress"}, forced:$forced, task_scope:(if $scope_file == "" then null else $scope_file end)}')"
    GUIDANCE_JSON="$(jq -nc \
      --arg gate "do not run 'sdd task complete $feature_path $task_id' until the verification command passes." \
      --arg pitfall "$pitfall_msg" \
      '{"gate":$gate,"pitfall":$pitfall,"worker":"default to sdd-implementer for tasks touching multiple files or >30 lines; inline only for trivial deterministic edits — SubagentStart hook auto-injects the dispatch packet."}')"
    sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
    cat >&2 <<EOF
Task: $task_title | Phase: $phase_id | Implements: $fr_ids
Boundary: work only this task, using its Files, Acceptance Criteria, and Verification block as the scope.
${phase_skill_line:+$phase_skill_line
}Gate: do not run \`sdd task complete $feature_path $task_id\` until the verification command passes.
Pitfall: $pitfall_msg
Delegate: default to sdd-implementer for tasks touching multiple files or >30 lines; inline only for trivial deterministic edits — SubagentStart hook auto-injects the dispatch packet.
EOF
    if [ -n "$ref_line" ]; then
      printf '%s\n' "$ref_line" >&2
    fi
    bash "$SCRIPT_DIR/sdd-status.sh" --json "$feature_path" >/dev/null 2>&1 || true
  sdd_summary_maybe "$feature_path"
    return 0
  fi
  cat <<EOF
Task: $task_title | Phase: $phase_id | Implements: $fr_ids
Boundary: work only this task, using its Files, Acceptance Criteria, and Verification block as the scope.
${phase_skill_line:+$phase_skill_line
}Gate: do not run \`sdd task complete $feature_path $task_id\` until the verification command passes.
Pitfall: $pitfall_msg
Delegate: default to sdd-implementer for tasks touching multiple files or >30 lines; inline only for trivial deterministic edits — SubagentStart hook auto-injects the dispatch packet.
EOF
  if [ -n "$ref_line" ]; then
    printf '%s\n' "$ref_line"
  fi
  bash "$SCRIPT_DIR/sdd-status.sh" --json "$feature_path" >/dev/null 2>&1 || true
  sdd_summary_maybe "$feature_path"
}

cmd_scope_refresh() {
  validate_feature
  if [ -z "$task_id" ]; then sdd_usage_error "task" "sdd task scope-refresh <feature> <task-id>" "task ID required"; fi

  local file scope_file scope_path task_title phase_id fr_ids data_json guidance_json
  file="$(tasks_file)"
  require_task_status "$task_id" "$file" "in-progress"

  write_task_scope_file "$task_id" "$file"
  scope_file="$(task_scope_file)"
  if [ -f "$scope_file" ]; then
    scope_path=".features/$feature_path/task-scope.txt"
  else
    scope_path=""
  fi
  IFS=$'\t' read -r task_title phase_id fr_ids <<< "$(task_metadata_tsv "$task_id" "$file")"

  if sdd_is_json_mode; then
    data_json="$(jq -nc \
      --arg id "$task_id" \
      --arg title "$task_title" \
      --arg phase_id "$phase_id" \
      --arg implements "$fr_ids" \
      --arg status "in-progress" \
      --argjson scope_path "$(sdd_json_string_or_null "$scope_path")" \
      '{task:{id:$id,title:$title,phase:$phase_id,implements:$implements,status:$status}, task_scope:$scope_path}')"
    guidance_json="$(sdd_json_guidance "continue only with files covered by the refreshed task scope." "task-scope.txt is derived from the active task Files field; tasks.md remains the source of truth." "if the task needs more files, update tasks.md first, then rerun scope-refresh.")"
    sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement" "$data_json" "$guidance_json" '[]')"
    return 0
  fi

  if [ -n "$scope_path" ]; then
    echo "Task scope refreshed: $scope_path"
  else
    echo "Task scope refreshed: no Files entries; task-scope.txt removed"
  fi
}

# Extract verification content for a specific task into a temp file.
# Echoes "inline" for > Verification: <cmd> and "block" for fenced code blocks.
extract_verification() {
  local tid="$1"
  local file="$2"
  local out_file="$3"
  local inline command

  : > "$out_file"

  inline="$(sdd_task_field_value "$file" "$tid" "Verification" || true)"
  if [ -n "$inline" ]; then
    printf '%s\n' "$inline" > "$out_file"
    echo "inline"
    return 0
  fi

  command="$(sdd_task_verification_command "$file" "$tid" || true)"
  if [ -n "$command" ]; then
    printf '%s\n' "$command" > "$out_file"
    echo "block"
    return 0
  fi

  rm -f "$out_file"
  return 1
}

verification_record_path() {
  local tid="$1"
  local wp record_id
  wp="$(_active_wp)"
  if [ -n "$wp" ]; then
    record_id="${wp}-${tid}"
  else
    record_id="$tid"
  fi
  printf '%s/verification/%s.json\n' "$feature_dir" "$record_id"
}

write_verification_record() {
  local tid="$1"
  local mode="$2"
  local command="$3"
  local exit_code="$4"
  local stdout_text="$5"
  local stderr_text="$6"

  local result status captured_at path wp task_title phase_id fr_ids record_json
  if [ "$exit_code" -eq 0 ]; then
    result="pass"
  else
    result="fail"
  fi

  path="$(verification_record_path "$tid")"
  wp="$(_active_wp)"
  captured_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  IFS=$'\t' read -r task_title phase_id fr_ids <<< "$(task_metadata_tsv "$tid" "$(tasks_file)")"

  record_json="$(jq -nc \
    --argjson schema_version 1 \
    --arg feature "$feature" \
    --arg work_package "$wp" \
    --arg task_id "$tid" \
    --arg task_title "$task_title" \
    --arg task_phase "$phase_id" \
    --arg task_implements "$fr_ids" \
    --arg tasks_file "$(tasks_file)" \
    --arg captured_at "$captured_at" \
    --arg mode "$mode" \
    --arg command "$command" \
    --arg result "$result" \
    --arg stdout "$stdout_text" \
    --arg stderr "$stderr_text" \
    --argjson exit_code "$exit_code" \
    '{
      schema_version: $schema_version,
      feature: $feature,
      work_package: (if $work_package == "" then null else $work_package end),
      task: {
        id: $task_id,
        title: $task_title,
        phase: $task_phase,
        implements: $task_implements,
        tasks_file: $tasks_file
      },
      captured_at: $captured_at,
      verification: {
        mode: $mode,
        command: $command,
        result: $result,
        exit_code: $exit_code,
        stdout: $stdout,
        stderr: $stderr
      }
    }')"

  sdd_write_file_atomic "$path" "$record_json"
  printf '%s\n' "$path"
}

# Complete task (also checks all ACs in that task section)
cmd_complete() {
  validate_feature
  if [ -z "$task_id" ]; then sdd_usage_error "task" "sdd task complete <feature> <task-id>" "task ID required"; fi

  local file
  local ref_line
  local verification_details="{}"
  file="$(tasks_file)"
  require_task_status "$task_id" "$file" "in-progress"
  ref_line="$(sdd_phase_reference_line "implement")"

  # Extract and run verification command (if present)
  local verify_cmd=""
  local verify_mode=""
  local verify_script=""
  local verification_record=""
  verify_script="$(mktemp "${TMPDIR:-/tmp}/sdd-verify.XXXXXX")"
  sdd_cleanup_push "$verify_script"

  if verify_mode="$(extract_verification "$task_id" "$file" "$verify_script")"; then
    verify_cmd="$(cat "$verify_script")"
  else
    sdd_cleanup_file "$verify_script"
    verify_script=""
  fi

  if [ -n "$verify_cmd" ]; then
    if ! sdd_is_json_mode; then
      echo "Running verification:"
      printf '%s\n' "$verify_cmd"
    else
      echo "Running verification:" >&2
      printf '%s\n' "$verify_cmd" >&2
    fi
    local verify_output verify_exit verify_stdout verify_stderr
    local stdout_file stderr_file
    stdout_file="$(mktemp "${TMPDIR:-/tmp}/sdd-verify-stdout.XXXXXX")"
    stderr_file="$(mktemp "${TMPDIR:-/tmp}/sdd-verify-stderr.XXXXXX")"
    sdd_cleanup_push "$stdout_file"
    sdd_cleanup_push "$stderr_file"
    # Portable timeout: prefer timeout/gtimeout, fall back to plain bash
    local timeout_cmd=""
    if command -v timeout >/dev/null 2>&1; then
      timeout_cmd="timeout 30"
    elif command -v gtimeout >/dev/null 2>&1; then
      timeout_cmd="gtimeout 30"
    fi
    if [ -n "$timeout_cmd" ]; then
      $timeout_cmd bash "$verify_script" >"$stdout_file" 2>"$stderr_file" && verify_exit=0 || verify_exit=$?
    else
      bash "$verify_script" >"$stdout_file" 2>"$stderr_file" && verify_exit=0 || verify_exit=$?
    fi
    sdd_cleanup_file "$verify_script"
    verify_script=""

    verify_stdout="$(cat "$stdout_file")"
    verify_stderr="$(cat "$stderr_file")"
    sdd_cleanup_file "$stdout_file"
    sdd_cleanup_file "$stderr_file"

    verify_output="$verify_stdout"
    if [ -n "$verify_stderr" ]; then
      if [ -n "$verify_output" ]; then
        verify_output="${verify_output}"$'\n'
      fi
      verify_output="${verify_output}${verify_stderr}"
    fi

    verification_record="$(write_verification_record "$task_id" "$verify_mode" "$verify_cmd" "$verify_exit" "$verify_stdout" "$verify_stderr")"
    verification_details="$(jq -nc \
      --arg mode "$verify_mode" \
      --arg command "$verify_cmd" \
      --arg output "$verify_output" \
      --arg stdout "$verify_stdout" \
      --arg stderr "$verify_stderr" \
      --arg record_path "$verification_record" \
      --arg result "$( [ "$verify_exit" -eq 0 ] && printf 'pass' || printf 'fail' )" \
      --argjson exit_code "$verify_exit" \
      '{mode:$mode, command:$command, result:$result, output:$output, stdout:$stdout, stderr:$stderr, exit_code:$exit_code, record_path:$record_path}')"

    if [ "$verify_exit" -ne 0 ]; then
      # Append failure to scratchpad.md
      local scratchpad="$feature_dir/scratchpad.md"
      if [ -f "$scratchpad" ]; then
        local ts
        ts="$(date +%Y-%m-%dT%H:%M:%S)"
        printf '\n- [%s] Verification FAILED for %s (exit %d). Evidence captured at %s.\n' \
          "$ts" "$task_id" "$verify_exit" "$verification_record" >> "$scratchpad"
      fi
      if sdd_is_json_mode; then
        echo "Verification FAILED (exit code $verify_exit):" >&2
        printf '%s\n' "$verify_output" >&2
        echo "Verification record: $verification_record" >&2
        echo "" >&2
        echo "$task_id remains in-progress. Fix the issue and try again." >&2
        sdd_fail "task" "internal" "verification failed for $task_id" "{\"task_id\":\"$task_id\",\"verification\":$verification_details}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement"
      fi
      echo "Verification FAILED (exit code $verify_exit):"
      echo "$verify_output"
      echo "Verification record: $verification_record"
      echo ""
      echo "$task_id remains in-progress. Fix the issue and try again."
      exit "$SDD_EXIT_INTERNAL"
    fi
    if ! sdd_is_json_mode; then
      echo "Verification passed."
      echo "Verification record: $verification_record"
    else
      echo "Verification passed." >&2
      echo "Verification record: $verification_record" >&2
    fi
  fi

  # Check all acceptance criteria boxes in the task section using awk
  rewrite_file_with_awk "$file" -v tid="$task_id" '
    index($0, "## " tid ":") == 1 { in_task = 1; in_ac = 0; print; next }
    /^## / { in_task = 0; in_ac = 0 }
    in_task && /^### Acceptance Criteria/ { in_ac = 1; print; next }
    in_task && /^### / { in_ac = 0 }
    in_task && in_ac && /^- \[ \]/ { sub(/^- \[ \]/, "- [x]") }
    { print }
  ' || sdd_fail "task" "internal" "failed to update acceptance criteria for $task_id" "{\"task_id\":\"$task_id\",\"tasks_file\":\"$file\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

  set_status "$task_id" "completed"
  remove_task_scope_file
  bash "$SCRIPT_DIR/sdd-status.sh" --json "$feature_path" >/dev/null 2>&1 || true
  sdd_summary_maybe "$feature_path"

  local complete_pitfall_msg
  if [ "$(sdd_profile "$feature_dir")" = "lite" ]; then
    complete_pitfall_msg="if you touched unexpected files or learned new patterns, update spec.md and tasks.md before moving on."
  else
    complete_pitfall_msg="if you touched unexpected files or learned new patterns, update research.md and tasks.md before moving on."
  fi
  local phase_skill_line
  phase_skill_line="$(sdd_phase_skill_cli_hint implement)"

  if sdd_is_json_mode; then
    local task_title phase_id fr_ids data_json guidance_json
    IFS=$'\t' read -r task_title phase_id fr_ids <<< "$(task_metadata_tsv "$task_id" "$file")"
    data_json="$(jq -nc \
      --arg id "$task_id" \
      --arg title "$task_title" \
      --arg phase_id "$phase_id" \
      --arg implements "$fr_ids" \
      --argjson verification "$verification_details" \
      '{task:{id:$id,title:$title,phase:$phase_id,implements:$implements,status:"completed"}, verification:$verification}')"
    guidance_json="$(sdd_json_guidance "record discoveries in scratchpad.md, then pick the next task deliberately." "task completion means its Acceptance Criteria were checked and the Verification block passed when one existed." "$complete_pitfall_msg")"
    sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement" "$data_json" "$guidance_json" '[]')"
    cat >&2 <<EOF
Gate: task completion means its Acceptance Criteria were checked and the Verification block passed when one existed.
Next: record discoveries in scratchpad.md, then pick the next task deliberately with \`sdd task next $feature_path\`.
${phase_skill_line:+$phase_skill_line
}Pitfall: $complete_pitfall_msg
EOF
    if [ -n "$ref_line" ]; then
      printf '%s\n' "$ref_line" >&2
    fi
    return 0
  fi

  cat <<EOF
Gate: task completion means its Acceptance Criteria were checked and the Verification block passed when one existed.
Next: record discoveries in scratchpad.md, then pick the next task deliberately with \`sdd task next $feature_path\`.
${phase_skill_line:+$phase_skill_line
}Pitfall: $complete_pitfall_msg
EOF
  if [ -n "$ref_line" ]; then
    printf '%s\n' "$ref_line"
  fi
}

# Block task
cmd_block() {
  validate_feature
  if [ -z "$task_id" ]; then sdd_usage_error "task" "sdd task block <feature> <task-id> [reason]" "task ID required"; fi
  local file
  file="$(tasks_file)"
  require_task_status "$task_id" "$file" "pending" "in-progress"
  set_status "$task_id" "blocked"
  bash "$SCRIPT_DIR/sdd-status.sh" --json "$feature_path" >/dev/null 2>&1 || true
  sdd_summary_maybe "$feature_path"
  local reason
  reason="$(task_arg_rest 1)"
  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc --arg id "$task_id" --arg reason "$reason" '{task:{id:$id,status:"blocked"},reason:(if $reason == "" then null else $reason end)}')"
    sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement" "$DATA_JSON" '{}' '[]')"
  elif [ -n "$reason" ]; then
    echo "Reason: $reason"
  fi
}

# Reset task to pending
cmd_reset() {
  validate_feature
  if [ -z "$task_id" ]; then sdd_usage_error "task" "sdd task reset <feature> <task-id>" "task ID required"; fi
  local file
  file="$(tasks_file)"
  require_task_status "$task_id" "$file" "in-progress" "blocked" "completed" "pending"
  set_status "$task_id" "pending"
  remove_task_scope_file
  bash "$SCRIPT_DIR/sdd-status.sh" --json "$feature_path" >/dev/null 2>&1 || true
  sdd_summary_maybe "$feature_path"
  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc --arg id "$task_id" '{task:{id:$id,status:"pending"}}')"
    sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement" "$DATA_JSON" '{}' '[]')"
  fi
}

# Add new task
cmd_add() {
  validate_feature
  local phase fr_ids title canonical_implements
  phase="$(task_arg 0)"
  fr_ids="$(task_arg 1)"
  title="$(task_arg_rest 2)"

  if [ -z "$phase" ] || [ -z "$fr_ids" ] || [ -z "$title" ]; then
    sdd_usage_error "task" "sdd task add <feature> <phase> <fr-ids> <title>" "phase, FR IDs, and title are required"
  fi

  canonical_implements="$(sdd_parse_id_list "$fr_ids" | jq -c '.')"

  local file
  file="$(tasks_file)"

  # Find next task number
  local last_num
  last_num=$(grep -oE '^## T-[0-9]+' "$file" | grep -oE '[0-9]+' | sort -n | tail -1 || echo "0")
  local next_num=$((last_num + 1))
  local new_id
  new_id="$(printf 'T-%03d' "$next_num")"

  local today
  today="$(date +%Y-%m-%d)"

  # Append before the legacy Progress section (if present), or at end of file.
  local task_block
  task_block=$(cat << EOF

***

## $new_id: $title

> Status: pending
> Phase: $phase
> Implements: $canonical_implements

### Description

[TODO: describe the atomic outcome]

### Steps

1. [TODO]

### Acceptance Criteria

- [ ] [TODO: testable criterion]

### Verification

\`\`\`bash
[TODO: verification command]
\`\`\`
EOF
)

  local tmp inserted
  tmp="$(sdd_tmp_for_target "$file")" || sdd_fail "task" "internal" "failed to create temp file for task insertion" "{\"tasks_file\":\"$file\",\"task_id\":\"$new_id\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  sdd_cleanup_push "$tmp"
  inserted=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$inserted" -eq 0 ] && [ "$line" = "## Progress" ]; then
      printf '%s\n\n' "$task_block" >> "$tmp" || {
        sdd_cleanup_file "$tmp"
        sdd_fail "task" "internal" "failed to write task block into temp file" "{\"tasks_file\":\"$file\",\"task_id\":\"$new_id\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
      }
      inserted=1
    fi
    printf '%s\n' "$line" >> "$tmp" || {
      sdd_cleanup_file "$tmp"
      sdd_fail "task" "internal" "failed to copy tasks.md during task insertion" "{\"tasks_file\":\"$file\",\"task_id\":\"$new_id\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
    }
  done < "$file"
  if [ "$inserted" -eq 0 ]; then
    printf '%s\n' "$task_block" >> "$tmp" || {
      sdd_cleanup_file "$tmp"
      sdd_fail "task" "internal" "failed to append task block into temp file" "{\"tasks_file\":\"$file\",\"task_id\":\"$new_id\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
    }
  fi
  sdd_atomic_replace "$tmp" "$file" || {
    sdd_cleanup_file "$tmp"
    sdd_fail "task" "internal" "failed to replace tasks.md atomically after task insertion" "{\"tasks_file\":\"$file\",\"task_id\":\"$new_id\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  }

  # Update frontmatter date
  sdd_portable_sed "$file" -e "s/^updated: .*/updated: $today/" || sdd_fail "task" "internal" "failed to refresh tasks.md updated date" "{\"tasks_file\":\"$file\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

  bash "$SCRIPT_DIR/sdd-status.sh" --json "$feature_path" >/dev/null 2>&1 || true
  sdd_summary_maybe "$feature_path"

  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc --arg id "$new_id" --arg title "$title" --arg phase_id "$phase" --arg implements "$canonical_implements" '{task:{id:$id,title:$title,phase:$phase_id,implements:$implements,status:"pending"}}')"
    GUIDANCE_JSON="$(sdd_json_guidance "fill in the Description, Acceptance Criteria, Files, and Verification sections before implementation." "implement is ready when each task has Status, Implements, and a runnable Verification block." "avoid vague tasks that are really whole phases in disguise.")"
    sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "plan-tasks" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
    echo "Added: $new_id: $title (Phase: $phase, Implements: $canonical_implements)" >&2
    return 0
  fi

  echo "Added: $new_id: $title (Phase: $phase, Implements: $canonical_implements)"
}

cmd_graph() {
  validate_feature
  local file graph_json
  file="$(tasks_file)"
  graph_json="$(sdd_task_graph_json "$file")"

  if sdd_is_json_mode; then
    local data_json
    data_json="$(jq -nc --arg feature "$feature" --arg tasks_file "$file" --argjson graph "$graph_json" '{feature:$feature, tasks_file:$tasks_file, graph:$graph}')"
    sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement" "$data_json" '{}' '[]')"
    return 0
  fi

  printf '%s\n' "$graph_json" | jq .
}

render_lint_findings_text() {
  local lint_json="$1" severity_filter="${2:-}"
  if [ -n "$severity_filter" ]; then
    printf '%s\n' "$lint_json" | jq -r --arg severity "$severity_filter" '
      .findings[]
      | select(.severity == $severity)
      | "  - \(.task) \(.rule) [\(.severity)]: \(.message)\n    Suggestion: \(.suggestion)"
    '
  else
    printf '%s\n' "$lint_json" | jq -r '
      .findings[]
      | "  - \(.task) \(.rule) [\(.severity)]: \(.message)\n    Suggestion: \(.suggestion)"
    '
  fi
}

cmd_lint() {
  validate_feature
  local file lint_json error_count warning_count checked_count data_json
  file="$(tasks_file)"
  lint_json="$(sdd_task_verification_lint_json "$file" "$feature")"
  error_count="$(printf '%s\n' "$lint_json" | jq -r '.error_count')"
  warning_count="$(printf '%s\n' "$lint_json" | jq -r '.warning_count')"
  checked_count="$(printf '%s\n' "$lint_json" | jq -r '.checked_tasks')"

  data_json="$(jq -nc \
    --arg feature "$feature" \
    --arg tasks_file "$file" \
    --argjson lint "$lint_json" \
    '{feature:$feature, tasks_file:$tasks_file, lint:$lint}')"

  if sdd_is_json_mode; then
    if [ "$error_count" -gt 0 ]; then
      sdd_json_error "task" "precondition" "task verification lint failed" "$data_json" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement"
      exit "$SDD_EXIT_PRECONDITION"
    fi
    sdd_emit_json_selection "$(sdd_json_success "task" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "implement" "$data_json" '{}' '[]')"
    exit 0
  fi

  if [ "$error_count" -gt 0 ]; then
    printf 'Task Verification lint: FAILED (%s task(s) checked, %s error(s), %s warning(s))\n' "$checked_count" "$error_count" "$warning_count"
    render_lint_findings_text "$lint_json"
    exit "$SDD_EXIT_PRECONDITION"
  fi

  printf 'Task Verification lint: OK (%s task(s) checked, %s error(s), %s warning(s))\n' "$checked_count" "$error_count" "$warning_count"
  if [ "$warning_count" -gt 0 ]; then
    printf 'Warnings:\n'
    render_lint_findings_text "$lint_json" "warning"
  fi
}

# Help
cmd_help() {
  show_help
}

# Dispatch
case "$cmd" in
  list)     cmd_list ;;
  next)     cmd_next ;;
  start)    cmd_start ;;
  complete) cmd_complete ;;
  block)    cmd_block ;;
  reset)    cmd_reset ;;
  scope-refresh) cmd_scope_refresh ;;
  add)      cmd_add ;;
  lint)     cmd_lint ;;
  graph)    cmd_graph ;;
  help|*)   cmd_help ;;
esac
