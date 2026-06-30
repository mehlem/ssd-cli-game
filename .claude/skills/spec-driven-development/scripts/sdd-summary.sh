#!/usr/bin/env bash
# sdd-summary.sh — Generate summary.md and summary-compact.md for a feature
# Usage: sdd-summary.sh [feature-id]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "summary" "sdd summary [feature-id]" "invalid shared CLI flags"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

# Singleton guard — only one summary generation runs at a time per project
sdd_lock_or_exit "summary"

FEATURE_ROOT=".features"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "summary" \
      "Generate summary.md and summary-compact.md for an SDD feature." \
      "sdd summary [feature-id] [--feature <id|auto>] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd summary 0001-user-auth",
        "sdd summary --feature auto --json",
        "sdd summary --json --field data.current_task"
      ]'
    return 0
  fi

  echo "Usage: sdd summary [feature-id]"
  echo ""
  echo "Generate summary.md and summary-compact.md for an SDD feature."
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

first_reasoning_row() {
  local rows="$1"
  printf '%s\n' "$rows" | awk 'NF { print; exit }'
}

compact_reasoning_state() {
  local assumptions="$1" ambiguity="$2" blocker="$3" verification="$4" scope_boundary="$5"
  local pieces=()
  local first=""

  first="$(first_reasoning_row "$assumptions")"
  [ -n "$first" ] && pieces+=("assumptions: $first")
  first="$(first_reasoning_row "$ambiguity")"
  [ -n "$first" ] && pieces+=("ambiguity: $first")
  first="$(first_reasoning_row "$blocker")"
  [ -n "$first" ] && pieces+=("blocker: $first")
  first="$(first_reasoning_row "$verification")"
  [ -n "$first" ] && pieces+=("verify: $first")
  first="$(first_reasoning_row "$scope_boundary")"
  [ -n "$first" ] && pieces+=("scope: $first")

  if [ "${#pieces[@]}" -gt 0 ]; then
    local joined=""
    local piece
    for piece in "${pieces[@]}"; do
      if [ -n "$joined" ]; then
        joined="$joined | $piece"
      else
        joined="$piece"
      fi
    done
    printf '%s' "$joined"
  fi
}

print_reasoning_block() {
  local label="$1"
  local rows="$2"
  printf -- "- %s:\n" "$label"
  if [ -n "$rows" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && printf '  %s\n' "$line"
    done <<< "$rows"
  else
    printf '  (none)\n'
  fi
}

feature_input="${SDD_FEATURE_OVERRIDE:-${SDD_ARGS[0]:-}}"
sdd_resolve_feature_target "$feature_input" 0 || {
  case "$SDD_RESOLUTION_STATUS" in
    not_found)
      sdd_fail "summary" "not_found" "feature '$feature_input' not found" "{\"feature\":\"$feature_input\"}" "$feature_input" "arg"
      ;;
    none)
      sdd_fail "summary" "not_found" "no active feature found" '{"feature":"auto"}' "" "none"
      ;;
    ambiguous)
      sdd_fail "summary" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc '{candidates: split("\n") | map(select(length > 0))}')" "" "auto"
      ;;
  esac
}

FEATURE="$SDD_RESOLVED_FEATURE"
FEATURE_PATH="${SDD_RESOLVED_FEATURE_PATH:-$FEATURE}"
FEATURE_DIR="${SDD_RESOLVED_FEATURE_DIR:-$FEATURE_ROOT/$FEATURE_PATH}"
[ -d "$FEATURE_DIR" ] || sdd_fail "summary" "not_found" "feature directory '$FEATURE_DIR' not found" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"

FEATURE_CONTEXT="$(sdd_feature_context_tsv "$FEATURE_PATH" || true)"
IFS=$'\t' read -r FEATURE_FROM_CONTEXT RAW_PHASE SOURCE WP_ID WP_PHASE WP_COUNT WP_DONE _WP_ACTIVE_COUNT _WP_PENDING_COUNT <<EOF
$FEATURE_CONTEXT
EOF
[ -n "${FEATURE_FROM_CONTEXT:-}" ] && FEATURE_PATH="$FEATURE_FROM_CONTEXT"
FEATURE="$FEATURE_PATH"
RAW_PHASE="${RAW_PHASE:-brief}"
PHASE="$(sdd_feature_effective_phase "$FEATURE")"
[ -n "$PHASE" ] || PHASE="$RAW_PHASE"
SOURCE="${SOURCE:-${SDD_RESOLUTION_SOURCE:-auto}}"
WP_ID="${WP_ID:-none}"
WP_PHASE="${WP_PHASE:-none}"
WP_COUNT="${WP_COUNT:-0}"
WP_DONE="${WP_DONE:-0}"

STATE_FILE="$FEATURE_DIR/state.json"
TASK_SUMMARY_JSON="$(sdd_feature_task_summary_json "$FEATURE_DIR")"
T_DONE="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.completed // 0' 2>/dev/null)" || T_DONE=0
T_ACTIVE="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.in_progress // 0' 2>/dev/null)" || T_ACTIVE=0
T_PENDING="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.pending // 0' 2>/dev/null)" || T_PENDING=0
T_BLOCKED="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.blocked // 0' 2>/dev/null)" || T_BLOCKED=0
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
TASK_SOURCE="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.source // "none"' 2>/dev/null)" || TASK_SOURCE="none"

GOAL=""
BRIEF_FILE="$FEATURE_DIR/brief.md"
if [ -f "$BRIEF_FILE" ]; then
  GOAL="$(awk '
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^## Motivation/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section {
      if ($0 ~ /^[[:space:]]*$/) next
      if ($0 ~ /^<!--/) next
      if ($0 ~ /-->$/) next
      if ($0 ~ /^\[.*\]$/) next
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if (length($0) > 0) { print; exit }
    }
  ' "$BRIEF_FILE")"
fi

if [ -z "$GOAL" ] && [ -f "$FEATURE_DIR/continuity.md" ]; then
  GOAL="$(awk '
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^## Goal/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section {
      if ($0 ~ /^[[:space:]]*$/) next
      if ($0 ~ /^<!--/) next
      if ($0 ~ /-->$/) next
      if ($0 ~ /^\[.*\]$/) next
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if (length($0) > 0) { print; exit }
    }
  ' "$FEATURE_DIR/continuity.md")"
fi
[ -n "$GOAL" ] || GOAL="(no goal extracted)"

SCOPE_LINES=""
RESEARCH_FILE="$FEATURE_DIR/research.md"
if [ -f "$RESEARCH_FILE" ]; then
  SCOPE_LINES="$(sdd_affected_files_paths "$RESEARCH_FILE" | head -8)"
fi

CHANGES=""
CHANGES_FILE="$FEATURE_DIR/changes.log"
if [ -f "$CHANGES_FILE" ]; then
  CHANGES="$(tail -5 "$CHANGES_FILE" 2>/dev/null)" || CHANGES=""
fi

RULES_TEXT="$(sdd_phase_rules "$PHASE")"
NEXT_TEXT="$(sdd_next_move "$PHASE" "$FEATURE" "$CURRENT_TASK")"
RULES_CLEAN="${RULES_TEXT#Rules: }"
NEXT_CLEAN="${NEXT_TEXT#Next: }"

SELECTED_TAG=""
SELECTED_MATCH=0
if [ -f "$FEATURE_ROOT/.active" ]; then
  ACTIVE_SELECTION="$(head -1 "$FEATURE_ROOT/.active" 2>/dev/null || true)"
  [ "$ACTIVE_SELECTION" = "$FEATURE" ] && SELECTED_MATCH=1
fi
[ "$SOURCE" = "selected" ] || [ "$SELECTED_MATCH" = "1" ] && SELECTED_TAG=" [selected]"

CONFIDENCE_SCORE=0
CONFIDENCE_VERDICT="pending"
if [ -f "$STATE_FILE" ]; then
  CONFIDENCE_SCORE="$(jq -r '.confidence.score // 0' "$STATE_FILE" 2>/dev/null)" || CONFIDENCE_SCORE=0
  CONFIDENCE_VERDICT="$(jq -r '.confidence.verdict // "pending"' "$STATE_FILE" 2>/dev/null)" || CONFIDENCE_VERDICT="pending"
elif [ -f "$FEATURE_DIR/research.md" ]; then
  CONFIDENCE_SCORE="$(awk '
    BEGIN { found = 0 }
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^## Confidence/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section && /^\- \*\*Total\*\*:/ {
      match($0, /[0-9]+/)
      if (RSTART > 0) {
        found = 1
        print substr($0, RSTART, RLENGTH)
      }
      exit
    }
    END { if (!found) print 0 }
  ' "$FEATURE_DIR/research.md")"
  CONFIDENCE_VERDICT="$(awk '
    BEGIN { found = 0 }
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^## Confidence/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section && /^\- \*\*Verdict\*\*:/ {
      if ($0 ~ /GO/) { found = 1; print "GO"; exit }
      if ($0 ~ /HOLD/) { found = 1; print "HOLD"; exit }
    }
    END { if (!found) print "pending" }
  ' "$FEATURE_DIR/research.md")"
fi

REVIEW_VERDICT="not yet created"
REVIEW_AC_PASS=0
REVIEW_AC_FAIL=0
REVIEW_VERDICT_SOURCE=""
REVIEW_EVIDENCE_STATUS=""
REVIEW_ADJUDICATED_AT=""
REVIEW_ADJUDICATION_JSON="null"
REVIEW_FILE="$FEATURE_DIR/review.md"
CONTINUITY_FILE="$FEATURE_DIR/continuity.md"
SCRATCHPAD_FILE="$FEATURE_DIR/scratchpad.md"
if [ -f "$REVIEW_FILE" ]; then
  REVIEW_VERDICT="$(sdd_frontmatter_value "$REVIEW_FILE" verdict || echo "pending")"
  [ -n "$REVIEW_VERDICT" ] || REVIEW_VERDICT="pending"
  REVIEW_VERDICT_SOURCE="$(sdd_frontmatter_value "$REVIEW_FILE" verdict_source || true)"
  REVIEW_EVIDENCE_STATUS="$(sdd_frontmatter_value "$REVIEW_FILE" evidence_status || true)"
  REVIEW_ADJUDICATED_AT="$(sdd_frontmatter_value "$REVIEW_FILE" adjudicated_at || true)"
  REVIEW_AC_PASS="$(awk '
    /^## Acceptance Criteria/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section && /^\|/ && /PASS/ { count++ }
    END { print count + 0 }
  ' "$REVIEW_FILE")"
  REVIEW_AC_FAIL="$(awk '
    /^## Acceptance Criteria/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section && /^\|/ && /FAIL/ { count++ }
    END { print count + 0 }
  ' "$REVIEW_FILE")"
fi
if [ -f "$FEATURE_DIR/review-adjudication/current.json" ]; then
  REVIEW_ADJUDICATION_JSON="$(cat "$FEATURE_DIR/review-adjudication/current.json" 2>/dev/null || printf 'null')"
fi

WORKERS_JSON="$(sdd_worker_state_json "$FEATURE")"
WORKER_DISPATCH_LINE=""
WORKER_RESULT_LINE=""
WORKER_PENDING_LINE=""
if [ "$WORKERS_JSON" != "null" ]; then
  WORKER_DISPATCH_LINE="$(printf '%s\n' "$WORKERS_JSON" | jq -r '
    .latest_dispatch
    | select(. != null)
    | "Latest dispatch: \(.role) \(.dispatch_id)" + (if .task.id then " \(.task.id)" + (if .task.heading != "" and .task.heading != null then ": \(.task.heading)" else "" end) else "" end) + " (epoch \(.dispatch_epoch))"
  ' 2>/dev/null)" || WORKER_DISPATCH_LINE=""
  WORKER_RESULT_LINE="$(printf '%s\n' "$WORKERS_JSON" | jq -r '
    .latest_result
    | select(. != null)
    | "Latest result: \(.role) \(.dispatch_id) -> \(.status)" + (if (.warnings // []) | length > 0 then " ⚠ \((.warnings | length)) warning(s)" else "" end)
  ' 2>/dev/null)" || WORKER_RESULT_LINE=""
  WORKER_PENDING_LINE="$(printf '%s\n' "$WORKERS_JSON" | jq -r '
    .pending_controller_action
    | select(. != null)
    | "Pending controller action: \(.role) \(.dispatch_id) -> \(.status)" + (if .has_warnings == true then " ⚠ warnings" else "" end)
  ' 2>/dev/null)" || WORKER_PENDING_LINE=""
fi

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
REASONING_COMPACT="$(compact_reasoning_state "$REASONING_ASSUMPTIONS" "$REASONING_AMBIGUITY" "$REASONING_BLOCKER" "$REASONING_VERIFICATION" "$REASONING_SCOPE_BOUNDARY")"
REASONING_PRESENT=0
[ -n "$REASONING_COMPACT" ] && REASONING_PRESENT=1

SUMMARY_FILE="$FEATURE_DIR/summary.md"
{
  echo "> AUTO-GENERATED — DO NOT EDIT"
  echo "> Refresh via: sdd summary $FEATURE"
  echo ""
  echo "# SDD Summary: $FEATURE"
  echo ""
  echo "## Goal"
  echo "$GOAL"
  echo ""
  echo "## Current State"
  printf -- "- Feature: %s%s\n" "$FEATURE" "$SELECTED_TAG"
  printf -- "- Phase: %s\n" "$PHASE"
  if [ "$RAW_PHASE" != "$PHASE" ]; then
    printf -- "- Raw phase: %s\n" "$RAW_PHASE"
  fi
  if [ -n "$WP_COUNT" ] && [ "$WP_COUNT" != "0" ]; then
    printf -- "- Active WP: %s\n" "${WP_ID:-none}"
    printf -- "- Task source: %s\n" "$TASK_SOURCE"
  fi
  printf -- "- Current task: %s\n" "$CURRENT_TASK"
  printf -- "- Progress: %s done / %s active / %s pending / %s blocked\n" "$T_DONE" "$T_ACTIVE" "$T_PENDING" "$T_BLOCKED"
  if [ "$PHASE" = "brief" ]; then
    BRIEF_STATE_JSON="$(sdd_brief_interview_state_json "$FEATURE" 2>/dev/null)" || BRIEF_STATE_JSON=""
    BRIEF_Q_COUNT="$(printf '%s\n' "$BRIEF_STATE_JSON" | jq -r '.question_count // 0' 2>/dev/null)" || BRIEF_Q_COUNT=0
    BRIEF_MISSING="$(printf '%s\n' "$BRIEF_STATE_JSON" | jq -r '.missing_sections // [] | join(", ")' 2>/dev/null)" || BRIEF_MISSING=""
    BRIEF_NEXT="$(printf '%s\n' "$BRIEF_STATE_JSON" | jq -r '.next_focus.label // "none"' 2>/dev/null)" || BRIEF_NEXT="none"
    echo ""
    echo "## Brief Interview State"
    printf -- "- Questions asked: %s\n" "$BRIEF_Q_COUNT"
    printf -- "- Missing sections: %s\n" "${BRIEF_MISSING:-(none)}"
    printf -- "- Next focus: %s\n" "$BRIEF_NEXT"
    echo "- Interview rule: ask one question at a time, recommend an answer, inspect code first"
  fi
  echo ""
  echo "## Rules"
  echo "$RULES_CLEAN"
  echo ""
  echo "## Next"
  echo "$NEXT_CLEAN"
  if [ "$REASONING_PRESENT" = "1" ]; then
    echo ""
    echo "## Reasoning State"
    print_reasoning_block "Active Assumptions" "$REASONING_ASSUMPTIONS"
    print_reasoning_block "Open Ambiguity" "$REASONING_AMBIGUITY"
    print_reasoning_block "Current Blocker" "$REASONING_BLOCKER"
    print_reasoning_block "Next Verification Target" "$REASONING_VERIFICATION"
    print_reasoning_block "Active Scope Boundary" "$REASONING_SCOPE_BOUNDARY"
  fi
  echo ""
  echo "## Scope Highlights"
  if [ -n "$SCOPE_LINES" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && printf -- "- %s\n" "$line"
    done <<< "$SCOPE_LINES"
  else
    echo "(no affected files found)"
  fi
  echo ""
  echo "## Recent Changes"
  if [ -n "$CHANGES" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] && printf -- "- %s\n" "$line"
    done <<< "$CHANGES"
  else
    echo "(no changes.log found)"
  fi
  echo ""
  echo "## Confidence"
  printf -- "- Score: %s/100\n" "$CONFIDENCE_SCORE"
  printf -- "- Verdict: %s\n" "$CONFIDENCE_VERDICT"
  echo ""
  echo "## Review State"
  printf -- "- Verdict: %s\n" "$REVIEW_VERDICT"
  if [ -n "$REVIEW_VERDICT_SOURCE" ]; then
    printf -- "- Verdict source: %s\n" "$REVIEW_VERDICT_SOURCE"
  fi
  if [ -n "$REVIEW_EVIDENCE_STATUS" ]; then
    printf -- "- Evidence: %s\n" "$REVIEW_EVIDENCE_STATUS"
  fi
  if [ -n "$REVIEW_ADJUDICATED_AT" ]; then
    printf -- "- Adjudicated at: %s\n" "$REVIEW_ADJUDICATED_AT"
  fi
  printf -- "- ACs: %s pass / %s fail\n" "$REVIEW_AC_PASS" "$REVIEW_AC_FAIL"
  if [ "$REVIEW_ADJUDICATION_JSON" != "null" ]; then
    REVIEWER_COUNT="$(printf '%s\n' "$REVIEW_ADJUDICATION_JSON" | jq -r '.reviewer_count // 0' 2>/dev/null)" || REVIEWER_COUNT=0
    VERIFICATION_COUNT="$(printf '%s\n' "$REVIEW_ADJUDICATION_JSON" | jq -r '.verification_count // 0' 2>/dev/null)" || VERIFICATION_COUNT=0
    MISSING_ROLES="$(printf '%s\n' "$REVIEW_ADJUDICATION_JSON" | jq -r '.missing_roles // [] | join(", ")' 2>/dev/null)" || MISSING_ROLES=""
    printf -- "- Evidence counts: %s verification / %s reviewer\n" "$VERIFICATION_COUNT" "$REVIEWER_COUNT"
    if [ -n "$MISSING_ROLES" ]; then
      printf -- "- Missing roles: %s\n" "$MISSING_ROLES"
    fi
  fi
  if [ "$WORKERS_JSON" != "null" ]; then
    echo ""
    echo "## Worker Status"
    [ -n "$WORKER_DISPATCH_LINE" ] && printf -- "- %s\n" "$WORKER_DISPATCH_LINE"
    [ -n "$WORKER_RESULT_LINE" ] && printf -- "- %s\n" "$WORKER_RESULT_LINE"
    [ -n "$WORKER_PENDING_LINE" ] && printf -- "- %s\n" "$WORKER_PENDING_LINE"
  fi
} > "$SUMMARY_FILE"

COMPACT_FILE="$FEATURE_DIR/summary-compact.md"
SCOPE_BASENAMES=""
if [ -n "$SCOPE_LINES" ]; then
  SCOPE_BASENAMES="$(echo "$SCOPE_LINES" | awk -F/ 'NR > 6 { exit } { print $NF }' | paste -sd ',' - | sed 's/,/, /g')"
fi
LAST_CHANGE=""
[ -n "$CHANGES" ] && LAST_CHANGE="$(echo "$CHANGES" | tail -1)"

{
  echo "> AUTO-GENERATED — DO NOT EDIT"
  echo ""
  echo "# SDD Summary: ${FEATURE}${SELECTED_TAG}"
  echo ""
  printf -- "- Goal: %s\n" "$GOAL"
  printf -- "- Phase: %s\n" "$PHASE"
  if [ "$RAW_PHASE" != "$PHASE" ]; then
    printf -- "- Raw phase: %s\n" "$RAW_PHASE"
  fi
  if [ -n "$WP_COUNT" ] && [ "$WP_COUNT" != "0" ]; then
    printf -- "- Active WP: %s\n" "${WP_ID:-none}"
    printf -- "- Task source: %s\n" "$TASK_SOURCE"
  fi
  printf -- "- Task: %s\n" "$CURRENT_TASK"
  printf -- "- Progress: %s done / %s active / %s pending / %s blocked\n" "$T_DONE" "$T_ACTIVE" "$T_PENDING" "$T_BLOCKED"
  printf -- "- Rules: %s\n" "$RULES_CLEAN"
  printf -- "- Process: see references/phases/%s.md for full methodology\n" "$PHASE"
  printf -- "- Next: %s\n" "$NEXT_CLEAN"
  if [ "$PHASE" = "brief" ]; then
    BRIEF_COMPACT_HINT="$(sdd_brief_interview_hint "$FEATURE" compact)"
    # Normalize compact brief guidance label for summary format.
    BRIEF_COMPACT_HINT="$(printf '%s' "$BRIEF_COMPACT_HINT" | sed -e 's/^interview:/Interview:/' -e 's/^brief:/Interview:/')"
    printf -- "- %s\n" "$BRIEF_COMPACT_HINT"
  fi
  printf -- "- Confidence: %s/100 %s\n" "$CONFIDENCE_SCORE" "$CONFIDENCE_VERDICT"
  if [ -n "$REVIEW_VERDICT_SOURCE" ] || [ -n "$REVIEW_EVIDENCE_STATUS" ]; then
    printf -- "- Review: %s (%s, %s)\n" "$REVIEW_VERDICT" "${REVIEW_VERDICT_SOURCE:-manual}" "${REVIEW_EVIDENCE_STATUS:-n/a}"
  else
    printf -- "- Review: %s\n" "$REVIEW_VERDICT"
  fi
  if [ "$WORKERS_JSON" != "null" ]; then
    WORKER_COMPACT_LINE="$(printf '%s\n' "$WORKERS_JSON" | jq -r '
      [
        (.latest_dispatch | select(. != null) | "dispatch " + .dispatch_id + " (" + .role + ")" + (if .task.id then " " + .task.id else "" end)),
        (.latest_result | select(. != null) | "result " + .status + (if (.warnings // []) | length > 0 then " ⚠" else "" end)),
        (.pending_controller_action | select(. != null) | "pending follow-up" + (if .has_warnings == true then " ⚠" else "" end))
      ]
      | map(select(. != null and . != ""))
      | if length == 0 then empty else join(" | ") end
    ' 2>/dev/null)" || WORKER_COMPACT_LINE=""
    [ -n "$WORKER_COMPACT_LINE" ] && printf -- "- Worker: %s\n" "$WORKER_COMPACT_LINE"
  fi
  [ -n "$REASONING_COMPACT" ] && printf -- "- Reasoning: %s\n" "$REASONING_COMPACT"
  printf -- "- Scope: %s\n" "${SCOPE_BASENAMES:-(none)}"
  printf -- "- Recent: %s\n" "${LAST_CHANGE:-(no recent changes)}"
} > "$COMPACT_FILE"

# Index rebuild removed from hot path — was causing process explosion (168+ concurrent
# sdd-index.sh rebuilds). INDEX.md is rebuilt on feature lifecycle events (init, close)
# or explicitly via: sdd index rebuild

if sdd_is_json_mode; then
  SCOPE_JSON="$(printf '%s\n' "$SCOPE_LINES" | jq -Rsc 'split("\n") | map(select(length > 0))')"
  CHANGES_JSON="$(printf '%s\n' "$CHANGES" | jq -Rsc 'split("\n") | map(select(length > 0))')"
  WP_JSON="$(jq -nc \
    --arg id "${WP_ID:-}" \
    --arg phase "${WP_PHASE:-}" \
    --arg count "${WP_COUNT:-}" \
    --arg wp_done "${WP_DONE:-}" \
    'if $count == "" or $count == "0" then null else {id:(if $id == "" then null else $id end), phase:(if $phase == "" then null else $phase end), count:($count|tonumber), done:($wp_done|tonumber)} end')"
  DATA_JSON="$(jq -nc \
    --arg feature "$FEATURE" \
    --arg feature_dir "$FEATURE_DIR" \
    --arg summary_file "$SUMMARY_FILE" \
    --arg summary_compact_file "$COMPACT_FILE" \
    --arg goal "$GOAL" \
    --arg current_task "$CURRENT_TASK" \
    --arg phase "$PHASE" \
    --arg raw_phase "$RAW_PHASE" \
    --arg task_source "$TASK_SOURCE" \
    --arg rules "$RULES_CLEAN" \
    --arg next_move "$NEXT_CLEAN" \
    --arg review_verdict "$REVIEW_VERDICT" \
    --arg review_verdict_source "$REVIEW_VERDICT_SOURCE" \
    --arg review_evidence_status "$REVIEW_EVIDENCE_STATUS" \
    --arg review_adjudicated_at "$REVIEW_ADJUDICATED_AT" \
    --argjson tasks "$(jq -nc --argjson completed "$T_DONE" --argjson active "$T_ACTIVE" --argjson pending "$T_PENDING" --argjson blocked "$T_BLOCKED" '{done:$completed, active:$active, pending:$pending, blocked:$blocked}')" \
    --argjson confidence "$(jq -nc --argjson score "$CONFIDENCE_SCORE" --arg verdict "$CONFIDENCE_VERDICT" '{score:$score, verdict:$verdict}')" \
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
    --argjson review "$(jq -nc --arg verdict "$REVIEW_VERDICT" --arg verdict_source "$REVIEW_VERDICT_SOURCE" --arg evidence_status "$REVIEW_EVIDENCE_STATUS" --arg adjudicated_at "$REVIEW_ADJUDICATED_AT" --argjson pass "$REVIEW_AC_PASS" --argjson fail "$REVIEW_AC_FAIL" '{verdict:$verdict, verdict_source:(if $verdict_source == "" then null else $verdict_source end), evidence_status:(if $evidence_status == "" then null else $evidence_status end), adjudicated_at:(if $adjudicated_at == "" then null else $adjudicated_at end), pass:$pass, fail:$fail}')" \
    --argjson review_adjudication "$REVIEW_ADJUDICATION_JSON" \
    --argjson workers "$WORKERS_JSON" \
    --argjson scope "$SCOPE_JSON" \
    --argjson recent_changes "$CHANGES_JSON" \
    --argjson work_package "$WP_JSON" \
    --arg selected "$SELECTED_TAG" \
    '{
      feature: $feature,
      feature_dir: $feature_dir,
      summary_file: $summary_file,
      summary_compact_file: $summary_compact_file,
      goal: $goal,
      current_task: $current_task,
      raw_phase: $raw_phase,
      phase: $phase,
      task_source: $task_source,
      tasks: $tasks,
      rules: $rules,
      next: $next_move,
      confidence: $confidence,
      reasoning_state: $reasoning_state,
      review: $review,
      review_adjudication: $review_adjudication,
      workers: $workers,
      scope_highlights: $scope,
      recent_changes: $recent_changes,
      work_package: $work_package,
      selected: ($selected != "")
    }')"
  GUIDANCE_JSON="$(sdd_json_guidance "$NEXT_CLEAN" "" "")"
  sdd_emit_json_selection "$(sdd_json_success "summary" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}" "$PHASE" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
  echo "Generated: $SUMMARY_FILE" >&2
  echo "Generated: $COMPACT_FILE" >&2
  exit 0
fi

echo "Generated: $SUMMARY_FILE"
echo "Generated: $COMPACT_FILE"
