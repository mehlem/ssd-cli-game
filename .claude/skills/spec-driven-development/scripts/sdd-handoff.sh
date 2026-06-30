#!/usr/bin/env bash
# sdd-handoff.sh — Read-only CLI for structured SDD session handoff output.
# Usage: sdd-handoff.sh [feature-id]

set -euo pipefail

command -v jq >/dev/null 2>&1 || {
  printf 'Error [internal]: jq is required for sdd handoff\n' >&2
  exit 7
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

[ -f "$SCRIPT_DIR/sdd-lib.sh" ] || {
  printf 'Error [internal]: sdd-lib.sh not found\n' >&2
  exit 7
}
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "handoff" "sdd handoff [feature-id]" "invalid shared CLI flags"

QUALITY_GATE_SCOPE_LINE='Quality gate: delegated work uses `sdd-quality-gate-test.sh --since <branch-base>`; unscoped is the operator'\''s pre-merge check.'

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "handoff" \
      "Print a structured session handoff for an SDD feature. Runs suspect/check preflight by default; use --skip-preflight to bypass." \
      "sdd handoff [feature-id] [--skip-preflight] [--feature <id|auto>] [--format text|json]" \
      "$(jq -nc --argjson common "$(sdd_common_flags_json)" '$common + [{"name":"--skip-preflight","description":"Bypass suspect/check preflight and emit the handoff summary anyway"}]')" \
      '[]' \
      '[
        "sdd handoff 0001-user-auth",
        "sdd handoff 0001-user-auth --skip-preflight",
        "sdd handoff --feature auto --json",
        "sdd handoff --json --field data.resume_prompt"
      ]'
    return 0
  fi

  echo "Usage: sdd handoff [feature-id] [--skip-preflight]"
  echo ""
  echo "Print a structured session handoff for an SDD feature."
  echo "Runs suspect/check preflight by default; use --skip-preflight to bypass."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

markdown_section_rows() {
  local file="$1"
  local heading="$2"
  [ -f "$file" ] || return 0
  awk -v heading="$heading" '
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    $0 == heading { in_section = 1; next }
    in_section && /^## / { exit }
    in_section {
      if ($0 ~ /^[[:space:]]*$/) next
      if ($0 ~ /^[[:space:]]*<!--/) next
      if ($0 ~ /^[[:space:]]*-->/) next
      print
    }
  ' "$file"
}

reasoning_state_rows() {
  local file="$1"
  local heading="$2"
  [ -f "$file" ] || return 0
  awk -v heading="$heading" '
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    $0 == "## Reasoning State" { in_reasoning = 1; next }
    in_reasoning && /^## / { exit }
    in_reasoning && $0 == heading { in_section = 1; next }
    in_section && /^### / { exit }
    in_section {
      if ($0 ~ /^[[:space:]]*$/) next
      if ($0 ~ /^[[:space:]]*<!--/) next
      if ($0 ~ /^[[:space:]]*-->/) next
      print
    }
  ' "$file"
}

print_reasoning_rows() {
  local rows="$1"
  if [ -n "$rows" ]; then
    while IFS= read -r row; do
      [ -n "$row" ] && printf '%s\n' "$row"
    done <<< "$rows"
  else
    printf '(none)\n'
  fi
}

print_reasoning_state_section() {
  local assumptions="$1" ambiguity="$2" blocker="$3" verification="$4" scope_boundary="$5"
  printf '## Reasoning State\n\n'
  printf '### Active Assumptions\n\n'
  print_reasoning_rows "$assumptions"
  printf '\n### Open Ambiguity\n\n'
  print_reasoning_rows "$ambiguity"
  printf '\n### Current Blocker\n\n'
  print_reasoning_rows "$blocker"
  printf '\n### Next Verification Target\n\n'
  print_reasoning_rows "$verification"
  printf '\n### Active Scope Boundary\n\n'
  print_reasoning_rows "$scope_boundary"
  printf '\n'
}

find_current_task_heading() {
  local tasks_file="$1"
  local task_summary_json
  task_summary_json="$(sdd_task_summary_cheap "$tasks_file")"
  printf '%s\n' "$task_summary_json" | jq -r '.current_task.heading // "none"' 2>/dev/null
}

feature_task_files() {
  local feature_dir="$1" root_tasks="$2"
  if sdd_feature_has_work_packages "$feature_dir"; then
    sdd_feature_wp_task_files "$feature_dir"
  elif [ -f "$root_tasks" ]; then
    sdd_task_normalize_file_path "$root_tasks"
  fi
}

task_headings_by_status() {
  local tasks_file="$1"
  local wanted_status="$2"
  sdd_task_headings_by_status "$tasks_file" "$wanted_status"
}

feature_task_headings_by_status() {
  local feature_dir="$1" root_tasks="$2" wanted_status="$3"
  local task_file work_package task_prefix row
  while IFS= read -r task_file; do
    [ -n "$task_file" ] || continue
    [ -f "$task_file" ] || continue
    work_package="$(sdd_task_work_package_from_tasks_file "$task_file")"
    task_prefix=""
    [ -n "$work_package" ] && task_prefix="$(sdd_task_wp_ref_prefix "$work_package")"
    while IFS= read -r row; do
      [ -n "$row" ] || continue
      if [ -n "$task_prefix" ]; then
        printf '%s/%s\n' "$task_prefix" "$row"
      else
        printf '%s\n' "$row"
      fi
    done <<EOF
$(sdd_task_headings_by_status "$task_file" "$wanted_status")
EOF
  done <<EOF
$(feature_task_files "$feature_dir" "$root_tasks")
EOF
}

print_task_section() {
  local title="$1"
  local tasks_file="$2"
  local status="$3"
  local feature_dir="${4:-}"
  local rows=""

  if [ -n "$feature_dir" ]; then
    rows="$(feature_task_headings_by_status "$feature_dir" "$tasks_file" "$status")"
  else
    rows="$(task_headings_by_status "$tasks_file" "$status")"
  fi

  printf '### %s\n\n' "$title"
  if [ -n "$rows" ]; then
    while IFS= read -r row; do
      [ -n "$row" ] && printf -- '- %s\n' "$row"
    done <<< "$rows"
  else
    printf '(none)\n'
  fi
  printf '\n'
}

print_recent_changes() {
  local changes_file="$1"
  local rows=""

  printf '## Recent Changes\n\n'
  if [ -f "$changes_file" ]; then
    rows="$(tail -10 "$changes_file" 2>/dev/null)" || rows=""
  fi

  if [ -n "$rows" ]; then
    while IFS= read -r row; do
      [ -n "$row" ] && printf -- '- %s\n' "$row"
    done <<< "$rows"
  else
    printf '(none)\n'
  fi
  printf '\n'
}

print_open_questions() {
  local scratchpad_file="$1"
  local rows=""

  printf '## Open Questions\n\n'
  if [ -f "$scratchpad_file" ]; then
    rows="$(awk '
      /^## Open Questions/ { in_section = 1; next }
      in_section && /^## / { exit }
      in_section {
        if ($0 ~ /^[[:space:]]*$/) next
        if ($0 ~ /^- ~~.*~~/) next
        print
      }
    ' "$scratchpad_file")" || rows=""
  fi

  if [ -n "$rows" ]; then
    while IFS= read -r row; do
      [ -n "$row" ] && printf '%s\n' "$row"
    done <<< "$rows"
  else
    printf '(none)\n'
  fi
  printf '\n'
}

handoff_preflight() {
  local feature="$1"
  local suspect_json suspect_count suspect_ids message details_json
  local check_output

  suspect_json="$(sdd_trace_suspect_summary_json "$feature")"
  suspect_count="$(printf '%s\n' "$suspect_json" | jq -r '.suspect_artifacts // 0')"
  if [ "$suspect_count" -gt 0 ]; then
    suspect_ids="$(printf '%s\n' "$suspect_json" | jq -r '.suspect_ids | join(", ")')"
    message="handoff preflight failed: suspect artifacts: $suspect_ids. Run sdd trace acknowledge $feature --confirmed --reason \"verified handoff readiness\" before handing off."
    details_json="$(jq -nc --argjson suspect "$suspect_json" '{preflight:"trace_suspect", suspect:$suspect}')"
    sdd_fail "handoff" "precondition" "$message" "$details_json" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "${PHASE:-}"
  fi

  if ! check_output="$(bash "$SCRIPT_DIR/sdd-check.sh" all "$feature" 2>&1)"; then
    if ! sdd_is_json_mode; then
      printf '%s\n' "$check_output" >&2
    fi
    details_json="$(jq -nc --arg output "$check_output" '{preflight:"sdd_check_all", command:"sdd check all", output:$output}')"
    sdd_fail "handoff" "precondition" "handoff preflight failed: sdd check all failed for $feature" "$details_json" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "${PHASE:-}"
  fi
}

HANDOFF_SKIP_PREFLIGHT=0
HANDOFF_ARGS=()
if [ "${#SDD_ARGS[@]}" -gt 0 ]; then
  for arg in "${SDD_ARGS[@]}"; do
    case "$arg" in
      --skip-preflight)
        HANDOFF_SKIP_PREFLIGHT=1
        ;;
      *)
        HANDOFF_ARGS+=("$arg")
        ;;
    esac
  done
fi

feature_input="${SDD_FEATURE_OVERRIDE:-}"
if [ -z "$feature_input" ] && [ "${#HANDOFF_ARGS[@]}" -gt 0 ]; then
  feature_input="${HANDOFF_ARGS[0]}"
fi
sdd_resolve_feature_target "$feature_input" 0 || {
  case "$SDD_RESOLUTION_STATUS" in
    not_found)
      sdd_fail "handoff" "not_found" "feature '$feature_input' not found" "{\"feature\":\"$feature_input\"}" "$feature_input" "arg"
      ;;
    none)
      sdd_fail "handoff" "not_found" "no active feature found" '{"feature":"auto"}' "" "none"
      ;;
    ambiguous)
      sdd_fail "handoff" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc '{candidates: split("\n") | map(select(length > 0))}')" "" "auto"
      ;;
  esac
}

FEATURE="$SDD_RESOLVED_FEATURE"
FEATURE_DIR="$SDD_FEATURE_ROOT/$FEATURE"
[ -d "$FEATURE_DIR" ] || sdd_fail "handoff" "not_found" "feature directory '$FEATURE_DIR' not found" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"

RAW_PHASE="$(sdd_feature_phase "$FEATURE")"
PHASE="$(sdd_feature_effective_phase "$FEATURE")"
[ -n "$PHASE" ] || PHASE="$RAW_PHASE"
PROFILE="$(sdd_profile "$FEATURE")"
PROFILE_DISPLAY="$PROFILE"

if [ "$HANDOFF_SKIP_PREFLIGHT" -ne 1 ]; then
  handoff_preflight "$FEATURE"
fi

DESC_JSON="$(sdd_feature_description_json "$FEATURE" 2>/dev/null || echo '{"short":"","long":null,"short_source":"feature.id","long_source":null}')"
SHORT_DESC="$(printf '%s\n' "$DESC_JSON" | jq -r '.short // empty')"

STATE_FILE="$FEATURE_DIR/state.json"
TASKS_FILE="$FEATURE_DIR/tasks.md"
CHANGES_FILE="$FEATURE_DIR/changes.log"
SCRATCHPAD_FILE="$FEATURE_DIR/scratchpad.md"
REVIEW_FILE="$FEATURE_DIR/review.md"

CURRENT_TASK="none"
COMPLETED=0
IN_PROGRESS=0
PENDING=0
BLOCKED=0
CONFIDENCE_SCORE=0
CONFIDENCE_VERDICT="pending"
REVIEW_VERDICT="pending"
TASK_SUMMARY_JSON="$(sdd_feature_task_summary_json "$FEATURE_DIR")"
CURRENT_TASK="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '
  .current_task as $task
  | if ($task.id // null) == null then
      "none"
    elif ($task.display_ref // null) != null and ($task.display_ref != ($task.id // "")) and ($task.heading // null) != null then
      "\($task.display_ref): \($task.heading)"
    elif ($task.heading // null) != null then
      $task.heading
    else
      $task.id
    end
' 2>/dev/null)" || CURRENT_TASK="none"
COMPLETED="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.completed // 0' 2>/dev/null)" || COMPLETED=0
IN_PROGRESS="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.in_progress // 0' 2>/dev/null)" || IN_PROGRESS=0
PENDING="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.pending // 0' 2>/dev/null)" || PENDING=0
BLOCKED="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.blocked // 0' 2>/dev/null)" || BLOCKED=0
TASK_SOURCE="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.source // "none"' 2>/dev/null)" || TASK_SOURCE="none"

if [ -f "$STATE_FILE" ]; then
  CONFIDENCE_SCORE="$(jq -r '.confidence.score // 0' "$STATE_FILE" 2>/dev/null)" || CONFIDENCE_SCORE=0
  CONFIDENCE_VERDICT="$(jq -r '.confidence.verdict // "pending"' "$STATE_FILE" 2>/dev/null)" || CONFIDENCE_VERDICT="pending"
  REVIEW_VERDICT="$(jq -r '.review.verdict // "pending"' "$STATE_FILE" 2>/dev/null)" || REVIEW_VERDICT="pending"
fi

if [ "$REVIEW_VERDICT" = "pending" ] && [ -f "$REVIEW_FILE" ]; then
  REVIEW_VERDICT="$(sdd_frontmatter_value "$REVIEW_FILE" verdict || echo "pending")"
fi

NEXT_MOVE="$(sdd_next_move "$PHASE" "$FEATURE" "$CURRENT_TASK")"
NEXT_CLEAN="${NEXT_MOVE#Next: }"
if [ -n "$SHORT_DESC" ]; then
  RESUME_PROMPT="Resume feature $FEATURE ($SHORT_DESC) in ${PHASE:-unknown} phase. Current task: $CURRENT_TASK. Next: ${NEXT_CLEAN:-review the feature state}."
else
  RESUME_PROMPT="Resume feature $FEATURE in ${PHASE:-unknown} phase. Current task: $CURRENT_TASK. Next: ${NEXT_CLEAN:-review the feature state}."
fi

COMPLETED_ROWS="$(feature_task_headings_by_status "$FEATURE_DIR" "$TASKS_FILE" "completed")"
IN_PROGRESS_ROWS="$(feature_task_headings_by_status "$FEATURE_DIR" "$TASKS_FILE" "in-progress")"
PENDING_ROWS="$(feature_task_headings_by_status "$FEATURE_DIR" "$TASKS_FILE" "pending")"
BLOCKED_ROWS="$(feature_task_headings_by_status "$FEATURE_DIR" "$TASKS_FILE" "blocked")"
RECENT_CHANGES_ROWS="$(tail -10 "$CHANGES_FILE" 2>/dev/null || true)"
OPEN_QUESTIONS_ROWS="$(awk '
  /^## Open Questions/ { in_section = 1; next }
  in_section && /^## / { exit }
  in_section {
    if ($0 ~ /^[[:space:]]*$/) next
    if ($0 ~ /^- ~~.*~~/) next
    print
  }
' "$SCRATCHPAD_FILE" 2>/dev/null || true)"

CONTINUITY_FILE="$FEATURE_DIR/continuity.md"
REASONING_ASSUMPTIONS="$(reasoning_state_rows "$CONTINUITY_FILE" "### Active Assumptions")"
[ -n "$REASONING_ASSUMPTIONS" ] || REASONING_ASSUMPTIONS="$(markdown_section_rows "$CONTINUITY_FILE" "## Constraints / Assumptions")"
REASONING_AMBIGUITY="$(reasoning_state_rows "$CONTINUITY_FILE" "### Open Ambiguity")"
[ -n "$REASONING_AMBIGUITY" ] || REASONING_AMBIGUITY="$(reasoning_state_rows "$SCRATCHPAD_FILE" "### Open Ambiguity")"
REASONING_BLOCKER="$(reasoning_state_rows "$CONTINUITY_FILE" "### Current Blocker")"
[ -n "$REASONING_BLOCKER" ] || REASONING_BLOCKER="$(reasoning_state_rows "$SCRATCHPAD_FILE" "### Current Blocker")"
REASONING_VERIFICATION="$(reasoning_state_rows "$CONTINUITY_FILE" "### Next Verification Target")"
[ -n "$REASONING_VERIFICATION" ] || REASONING_VERIFICATION="$(reasoning_state_rows "$SCRATCHPAD_FILE" "### Next Verification Target")"
REASONING_SCOPE_BOUNDARY="$(reasoning_state_rows "$CONTINUITY_FILE" "### Active Scope Boundary")"
[ -n "$REASONING_SCOPE_BOUNDARY" ] || REASONING_SCOPE_BOUNDARY="$(reasoning_state_rows "$SCRATCHPAD_FILE" "### Active Scope Boundary")"
REASONING_PRESENT=0
[ -n "$REASONING_ASSUMPTIONS$REASONING_AMBIGUITY$REASONING_BLOCKER$REASONING_VERIFICATION$REASONING_SCOPE_BOUNDARY" ] && REASONING_PRESENT=1

if sdd_is_json_mode; then
  DATA_JSON="$(jq -nc \
    --arg feature "$FEATURE" \
    --arg phase "${PHASE:-unknown}" \
    --arg profile "$PROFILE_DISPLAY" \
    --arg current_task "$CURRENT_TASK" \
    --arg raw_phase "$RAW_PHASE" \
    --arg task_source "$TASK_SOURCE" \
    --arg resume_prompt "$RESUME_PROMPT" \
    --argjson description "$DESC_JSON" \
    --argjson progress "$(jq -nc --argjson completed "$COMPLETED" --argjson in_progress "$IN_PROGRESS" --argjson pending "$PENDING" --argjson blocked "$BLOCKED" '{completed:$completed, in_progress:$in_progress, pending:$pending, blocked:$blocked}')" \
    --argjson confidence "$(jq -nc --argjson score "$CONFIDENCE_SCORE" --arg verdict "$CONFIDENCE_VERDICT" '{score:$score, verdict:$verdict}')" \
    --arg review_verdict "$REVIEW_VERDICT" \
    --argjson task_breakdown "$(jq -nc \
      --arg completed "$COMPLETED_ROWS" \
      --arg in_progress "$IN_PROGRESS_ROWS" \
      --arg pending "$PENDING_ROWS" \
      --arg blocked "$BLOCKED_ROWS" \
      '{
        completed: ($completed | split("\n") | map(select(length > 0))),
        in_progress: ($in_progress | split("\n") | map(select(length > 0))),
        pending: ($pending | split("\n") | map(select(length > 0))),
        blocked: ($blocked | split("\n") | map(select(length > 0)))
      }')" \
    --argjson recent_changes "$(printf '%s\n' "$RECENT_CHANGES_ROWS" | jq -Rsc 'split("\n") | map(select(length > 0))')" \
    --argjson open_questions "$(printf '%s\n' "$OPEN_QUESTIONS_ROWS" | jq -Rsc 'split("\n") | map(select(length > 0))')" \
    --argjson reasoning_state "$(jq -nc \
      --arg assumptions "$REASONING_ASSUMPTIONS" \
      --arg ambiguity "$REASONING_AMBIGUITY" \
      --arg blocker "$REASONING_BLOCKER" \
      --arg verification "$REASONING_VERIFICATION" \
      --arg scope_boundary "$REASONING_SCOPE_BOUNDARY" \
      '{
        assumptions: ($assumptions | split("\n") | map(select(length > 0))),
        open_ambiguity: ($ambiguity | split("\n") | map(select(length > 0))),
        current_blocker: ($blocker | split("\n") | map(select(length > 0))),
        next_verification_target: ($verification | split("\n") | map(select(length > 0))),
        scope_boundary: ($scope_boundary | split("\n") | map(select(length > 0)))
      }')" \
    '{
      feature: $feature,
      phase: $phase,
      raw_phase: $raw_phase,
      profile: $profile,
      current_task: $current_task,
      task_source: $task_source,
      description: $description,
      progress: $progress,
      confidence: $confidence,
      review_verdict: $review_verdict,
      task_breakdown: $task_breakdown,
      recent_changes: $recent_changes,
      open_questions: $open_questions,
      reasoning_state: $reasoning_state,
      resume_prompt: $resume_prompt
    }')"
  GUIDANCE_JSON="$(sdd_json_guidance "$NEXT_CLEAN" "" "")"
  sdd_emit_json_selection "$(sdd_json_success "handoff" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}" "$PHASE" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
  {
    printf '# SDD Handoff: %s\n\n' "$FEATURE"
    printf '## Status\n\n'
    printf -- '- Feature: %s\n' "$FEATURE"
    printf -- '- Phase: %s\n' "${PHASE:-unknown}"
    if [ "$RAW_PHASE" != "$PHASE" ]; then printf -- '- Raw phase: %s\n' "${RAW_PHASE:-unknown}"; fi
    printf -- '- profile: %s\n' "$PROFILE_DISPLAY"
    if [ -n "$SHORT_DESC" ]; then printf -- '- Description: %s\n' "${SHORT_DESC:0:120}"; fi
    printf -- '- Current task: %s\n' "$CURRENT_TASK"
    [ "$TASK_SOURCE" = "work_packages" ] && printf -- '- Task source: %s\n' "$TASK_SOURCE"
    printf -- '- Progress: %s completed, %s in-progress, %s pending, %s blocked\n' \
      "$COMPLETED" "$IN_PROGRESS" "$PENDING" "$BLOCKED"
    printf -- '- Confidence: %s/100 %s\n' "$CONFIDENCE_SCORE" "$CONFIDENCE_VERDICT"
    printf -- '- Review: %s\n\n' "$REVIEW_VERDICT"
    printf '## Task Breakdown\n\n'
    print_task_section "Completed" "$TASKS_FILE" "completed" "$FEATURE_DIR"
    print_task_section "In Progress" "$TASKS_FILE" "in-progress" "$FEATURE_DIR"
    print_task_section "Pending" "$TASKS_FILE" "pending" "$FEATURE_DIR"
    print_task_section "Blocked" "$TASKS_FILE" "blocked" "$FEATURE_DIR"
    print_recent_changes "$CHANGES_FILE"
    print_open_questions "$SCRATCHPAD_FILE"
    if [ "$REASONING_PRESENT" = "1" ]; then
      print_reasoning_state_section \
        "$REASONING_ASSUMPTIONS" \
        "$REASONING_AMBIGUITY" \
        "$REASONING_BLOCKER" \
        "$REASONING_VERIFICATION" \
        "$REASONING_SCOPE_BOUNDARY"
    fi
    printf '## Resume Prompt\n\n'
    printf '`%s`\n' "$RESUME_PROMPT"
    printf '\n%s\n' "$QUALITY_GATE_SCOPE_LINE"
  } >&2
  exit 0
fi

printf '# SDD Handoff: %s\n\n' "$FEATURE"

printf '## Status\n\n'
printf -- '- Feature: %s\n' "$FEATURE"
printf -- '- Phase: %s\n' "${PHASE:-unknown}"
if [ "$RAW_PHASE" != "$PHASE" ]; then printf -- '- Raw phase: %s\n' "${RAW_PHASE:-unknown}"; fi
printf -- '- profile: %s\n' "$PROFILE_DISPLAY"
[ -n "$SHORT_DESC" ] && printf -- '- Description: %s\n' "${SHORT_DESC:0:120}"
printf -- '- Current task: %s\n' "$CURRENT_TASK"
[ "$TASK_SOURCE" = "work_packages" ] && printf -- '- Task source: %s\n' "$TASK_SOURCE"
printf -- '- Progress: %s completed, %s in-progress, %s pending, %s blocked\n' \
  "$COMPLETED" "$IN_PROGRESS" "$PENDING" "$BLOCKED"
printf -- '- Confidence: %s/100 %s\n' "$CONFIDENCE_SCORE" "$CONFIDENCE_VERDICT"
printf -- '- Review: %s\n\n' "$REVIEW_VERDICT"

printf '## Task Breakdown\n\n'
print_task_section "Completed" "$TASKS_FILE" "completed" "$FEATURE_DIR"
print_task_section "In Progress" "$TASKS_FILE" "in-progress" "$FEATURE_DIR"
print_task_section "Pending" "$TASKS_FILE" "pending" "$FEATURE_DIR"
print_task_section "Blocked" "$TASKS_FILE" "blocked" "$FEATURE_DIR"

print_recent_changes "$CHANGES_FILE"
print_open_questions "$SCRATCHPAD_FILE"
if [ "$REASONING_PRESENT" = "1" ]; then
  print_reasoning_state_section \
    "$REASONING_ASSUMPTIONS" \
    "$REASONING_AMBIGUITY" \
    "$REASONING_BLOCKER" \
    "$REASONING_VERIFICATION" \
    "$REASONING_SCOPE_BOUNDARY"
fi

printf '## Resume Prompt\n\n'
printf '`%s`\n' "$RESUME_PROMPT"
printf '\n%s\n' "$QUALITY_GATE_SCOPE_LINE"
