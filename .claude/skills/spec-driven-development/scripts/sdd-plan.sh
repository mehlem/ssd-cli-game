#!/usr/bin/env bash
# sdd-plan.sh — Scaffold plan.md and/or tasks.md from templates
# Usage:
#   sdd-plan.sh plan  <feature-id>   — create plan.md from template
#   sdd-plan.sh tasks <feature-id>   — create tasks.md from template
#   sdd-plan.sh both  <feature-id>   — create both

set -euo pipefail

FEATURE_ROOT=".features"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$SKILL_DIR/templates"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "plan" "sdd plan {plan|create|tasks|create-tasks|both|create-all} <feature-id>" "invalid shared CLI flags"

PLAN_NEXT_PLAN_INTERACTIVE="turn research.md into AD-xxx decisions and PH-xx vertical slices that can be demoed independently."
PLAN_NEXT_TASKS_INTERACTIVE="derive atomic T-xxx tasks from the PH-xx slices in plan.md."
PLAN_NEXT_PLAN_AUTONOMOUS_TEMPLATE="Advance autonomously to sdd plan create-tasks %s once AD-xxx decisions and PH-xx slices are coherent; halt only on listed blockers."
PLAN_NEXT_TASKS_AUTONOMOUS="Advance autonomously to implementation once tasks are atomic, scoped, and verifiable; halt only on listed blockers."
PLAN_TASKS_SUSPECT_REMINDER='Note: editing plan.md after this point will flip tasks.md suspect; run `sdd trace acknowledge` before handing off.'

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "plan" \
      "Scaffold plan.md and tasks.md for a feature. The combined both/create-all path is disabled; run create and create-tasks as separate phase boundaries." \
      "sdd plan {plan|create|tasks|create-tasks|both|create-all} <feature-id> [--feature <id|auto>] [--format text|json] [--non-interactive] [--on-exists fail|overwrite|skip]" \
      "$(sdd_common_flags_json)" \
      '[
        {"name":"create","maps_to":"plan"},
        {"name":"create-tasks","maps_to":"tasks"},
        {"name":"create-all","maps_to":"both"}
      ]' \
      '[
        "sdd plan create 0001-user-auth",
        "sdd plan create-tasks --feature auto"
      ]'
    return 0
  fi

  echo "sdd-plan.sh — Scaffold plan and task artifacts from templates"
  echo ""
  echo "Usage: sdd plan {plan|create|tasks|create-tasks|both|create-all} <feature-id>"
  echo ""
  echo "Note: both/create-all is disabled; run create and create-tasks as separate phase boundaries."
  echo "Run 'sdd plan create <feature>' and then 'sdd plan create-tasks <feature>' as separate boundaries."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

cmd="${SDD_ARGS[0]:-help}"
case "$cmd" in
  create) cmd="plan" ;;
  create-tasks) cmd="tasks" ;;
  create-all) cmd="both" ;;
esac
feature_input="${SDD_FEATURE_OVERRIDE:-${SDD_ARGS[1]:-}}"
feature="$feature_input"

# --- Validate ---

if [ "$cmd" != "help" ]; then
  sdd_resolve_feature_target "$feature_input" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
    case "$SDD_RESOLUTION_STATUS" in
      not_found)
        sdd_fail "plan" "not_found" "feature '$feature_input' not found" "{\"feature\":\"$feature_input\"}" "$feature_input" "arg"
        ;;
      ambiguous)
        sdd_fail "plan" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
        ;;
      none)
        sdd_usage_error "plan" "sdd plan {plan|create|tasks|create-tasks|both|create-all} <feature-id>" "feature ID required"
        ;;
    esac
  }
  feature="$SDD_RESOLVED_FEATURE"
fi

FEATURE_DIR="$FEATURE_ROOT/$feature"

validate() {
  if [ ! -d "$FEATURE_DIR" ]; then
    sdd_fail "plan" "not_found" "feature directory '$FEATURE_DIR' not found" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
  if [ "$(sdd_profile "$feature")" = "lite" ]; then
    sdd_fail "plan" "precondition" "sdd plan is not applicable in lite mode; planning is captured in tasks.md Approach" "{\"feature\":\"$feature\",\"profile\":\"lite\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
}

# --- Extract metadata from existing spec.md frontmatter ---

get_meta() {
  local key="$1"
  local file="$FEATURE_DIR/spec.md"
  grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}: *//" | tr -d '"' || true
}

# --- Process template with placeholder replacement ---

process_template() {
  local src="$1"
  local dst="$2"

  if [ ! -f "$src" ]; then
    sdd_fail "plan" "internal" "template '$src' not found" "{\"template\":\"$src\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi

  # Extract feature number from feature ID (first 4 digits)
  local FEATURE_NUM
  FEATURE_NUM=$(echo "$feature" | grep -oE '^[0-9]+')

  # Extract title from spec.md or derive from feature name
  local FEATURE_TITLE
  FEATURE_TITLE=$(get_meta "title")
  if [ -z "$FEATURE_TITLE" ]; then
    local name_part="${feature#*-}"
    FEATURE_TITLE=$(echo "$name_part" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
  fi

  local TODAY
  TODAY="$(date +%Y-%m-%d)"

  cp "$src" "$dst"

  sdd_portable_sed "$dst" \
    -e "s/{{FEATURE_ID}}/$feature/g" \
    -e "s/{{FEATURE_NUM}}/$FEATURE_NUM/g" \
    -e "s/{{FEATURE_NAME}}/${feature#*-}/g" \
    -e "s/{{FEATURE_TITLE}}/$FEATURE_TITLE/g" \
    -e "s/{{DATE}}/$TODAY/g"
}

preflight_target() {
  local path="$1"
  local action
  action="$(sdd_existing_path_action "$path" "$path" 2>/dev/null)" || {
    sdd_fail "plan" "conflict" "$(basename "$path") already exists" "{\"path\":\"$path\",\"policy\":\"$(sdd_effective_on_exists)\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  }
  printf '%s\n' "$action"
}

plan_next_line() {
  local mode="$1" interactive="" autonomous=""

  case "$mode" in
    plan)
      interactive="$PLAN_NEXT_PLAN_INTERACTIVE"
      autonomous="$(printf "$PLAN_NEXT_PLAN_AUTONOMOUS_TEMPLATE" "$feature")"
      ;;
    tasks)
      interactive="$PLAN_NEXT_TASKS_INTERACTIVE"
      autonomous="$PLAN_NEXT_TASKS_AUTONOMOUS"
      ;;
  esac

  if sdd_autonomy_is_on "$feature"; then
    printf '%s\n' "$autonomous"
  else
    printf '%s\n' "$interactive"
  fi
}

emit_plan_success() {
  local mode="$1"
  local feature_num="$2"
  local ref_line=""
  local next_line=""
  local delegate_line="default to sdd-plan-drafter for non-trivial plan strategy; inline only when the plan fits in one screen."
  local phase_skill_line
  local status_update_lines
  phase_skill_line="$(sdd_phase_skill_cli_hint plan)"
  status_update_lines="$(sdd_status_updates_text "${STATUS_UPDATES_JSON:-[]}")"

  case "$mode" in
    plan)
      ref_line="$(sdd_phase_reference_line "plan")"
      next_line="$(plan_next_line plan)"
      cat <<EOF
Created: $FEATURE_DIR/plan.md (PLAN-$feature_num)
${status_update_lines:+$status_update_lines
}Next: $next_line
${phase_skill_line:+$phase_skill_line
}Gate: \`sdd plan tasks $feature\` is valid when plan.md has at least 1 AD-xxx and 1 PH-xx; make each phase an end-to-end slice mapped to FRs and ACs.
Delegate: $delegate_line
Pitfall: do not jump straight into tasks until the slice boundaries are coherent enough for user review.
EOF
      ;;
    tasks)
      ref_line="$(sdd_phase_reference_line "plan-tasks")"
      next_line="$(plan_next_line tasks)"
      cat <<EOF
Created: $FEATURE_DIR/tasks.md (TASKS-$feature_num)
${status_update_lines:+$status_update_lines
}Next: $next_line
${phase_skill_line:+$phase_skill_line
}Gate: implement is ready when each T-xxx has Status, Implements, and a Verification block; keep Phase explicit for routing clarity.
Quality bar: keep Files concrete and write a command Claude can actually run to verify completion.
Pitfall: avoid vague "do the phase" tasks or verification written as prose instead of commands.
$PLAN_TASKS_SUSPECT_REMINDER
EOF
      ;;
  esac

  if [ -n "$ref_line" ]; then
    printf '%s\n' "$ref_line"
  fi
}

# --- Commands ---

cmd_plan() {
  local feature_num
  local action
  validate
  if [ ! -f "$FEATURE_DIR/spec.md" ]; then
    sdd_fail "plan" "precondition" "spec.md must exist before creating plan.md (complete Design phase first)" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
  action="$(preflight_target "$FEATURE_DIR/plan.md")"
  if [ "$action" = "skip" ]; then
    if sdd_is_json_mode; then
      DATA_JSON="$(jq -nc --arg action "$action" --arg file "$FEATURE_DIR/plan.md" '{plan:{action:$action,file:$file}}')"
      GUIDANCE_JSON="$(sdd_json_guidance "turn research.md into AD-xxx decisions and PH-xx vertical slices that can be demoed independently." "\`sdd plan tasks $feature\` is valid when plan.md has at least 1 AD-xxx and 1 PH-xx; make each phase an end-to-end slice mapped to FRs and ACs." "do not jump straight into tasks until the slice boundaries are coherent enough for user review.")"
      sdd_emit_json_selection "$(sdd_json_success "plan" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "plan" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
      echo "Skipped plan.md" >&2
    else
      echo "Skipped plan.md"
    fi
    exit 0
  fi
  if [ "$(sdd_profile "$feature")" = "deep" ]; then
    local check_out check_rc
    check_out="$(bash "$SCRIPT_DIR/sdd-check.sh" research "$feature" 2>&1)" && check_rc=0 || check_rc=$?
    if [ "$check_rc" -ne 0 ]; then
      printf '%s\n' "$check_out" >&2
      exit "$SDD_EXIT_PRECONDITION"
    fi
  fi
  feature_num="$(echo "$feature" | grep -oE '^[0-9]+')"
  # Mark research as completed (phase transition: Research to Plan)
  STATUS_UPDATES_JSON="$(sdd_complete_predecessor_status "$FEATURE_DIR/research.md" "Research to Plan transition")" || \
    sdd_fail "plan" "internal" "failed to mark research.md completed" "{\"path\":\"$FEATURE_DIR/research.md\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  process_template "$TEMPLATE_DIR/plan.md" "$FEATURE_DIR/plan.md"
  sdd_stamp_based_on "$FEATURE_DIR/plan.md" "SPEC-$feature_num" "RESEARCH-$feature_num"
  local next_line delegate_line phase_skill_line
  next_line="$(plan_next_line plan)"
  delegate_line="default to sdd-plan-drafter for non-trivial plan strategy; inline only when the plan fits in one screen."
  phase_skill_line="$(sdd_phase_skill_cli_hint plan)"
  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc --arg action "$action" --arg file "$FEATURE_DIR/plan.md" --arg artifact_id "PLAN-$feature_num" --argjson status_updates "$STATUS_UPDATES_JSON" '{plan:{action:$action,file:$file,artifact_id:$artifact_id}, status_updates:$status_updates}')"
    GUIDANCE_JSON="$(jq -nc \
      --arg next "$next_line" \
      --arg worker "$delegate_line" \
      '{"next":$next,"gate":"`sdd plan tasks` is valid when plan.md has at least 1 AD-xxx and 1 PH-xx; make each phase an end-to-end slice mapped to FRs and ACs.","pitfall":"do not jump straight into tasks until the slice boundaries are coherent enough for user review.","worker":$worker}')"
    sdd_emit_json_selection "$(sdd_json_success "plan" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "plan" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
    local _ref_line
    _ref_line="$(sdd_phase_reference_line "plan")"
    cat >&2 <<EOF
Created: $FEATURE_DIR/plan.md (PLAN-$feature_num)
$(sdd_status_updates_text "$STATUS_UPDATES_JSON")
Next: $next_line
${phase_skill_line:+$phase_skill_line
}Gate: \`sdd plan tasks $feature\` is valid when plan.md has at least 1 AD-xxx and 1 PH-xx; make each phase an end-to-end slice mapped to FRs and ACs.
Delegate: $delegate_line
Pitfall: do not jump straight into tasks until the slice boundaries are coherent enough for user review.
EOF
    if [ -n "$_ref_line" ]; then printf '%s\n' "$_ref_line" >&2; fi
  else
    emit_plan_success "plan" "$feature_num"
  fi
}

cmd_tasks() {
  local feature_num
  local action
  validate
  if [ ! -f "$FEATURE_DIR/plan.md" ]; then
    sdd_fail "plan" "precondition" "plan.md must exist before creating tasks.md (complete Plan strategy first)" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
  action="$(preflight_target "$FEATURE_DIR/tasks.md")"
  if [ "$action" = "skip" ]; then
    if sdd_is_json_mode; then
      DATA_JSON="$(jq -nc --arg action "$action" --arg file "$FEATURE_DIR/tasks.md" '{tasks:{action:$action,file:$file}}')"
      GUIDANCE_JSON="$(sdd_json_guidance "derive atomic T-xxx tasks from the PH-xx slices in plan.md." "implement is ready when each T-xxx has Status, Implements, and a Verification block; keep Phase explicit for routing clarity." "avoid vague \"do the phase\" tasks or verification written as prose instead of commands.")"
      sdd_emit_json_selection "$(sdd_json_success "plan" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "plan-tasks" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
      echo "Skipped tasks.md" >&2
    else
      echo "Skipped tasks.md"
    fi
    exit 0
  fi
  if [ "$(sdd_profile "$feature")" = "deep" ]; then
    local check_out check_rc
    check_out="$(bash "$SCRIPT_DIR/sdd-check.sh" plan "$feature" 2>&1)" && check_rc=0 || check_rc=$?
    if [ "$check_rc" -ne 0 ]; then
      printf '%s\n' "$check_out" >&2
      exit "$SDD_EXIT_PRECONDITION"
    fi
  fi
  feature_num="$(echo "$feature" | grep -oE '^[0-9]+')"
  # Mark plan as completed (phase transition: Plan to Plan-Tasks)
  STATUS_UPDATES_JSON="$(sdd_complete_predecessor_status "$FEATURE_DIR/plan.md" "Plan to Tasks transition")" || \
    sdd_fail "plan" "internal" "failed to mark plan.md completed" "{\"path\":\"$FEATURE_DIR/plan.md\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  process_template "$TEMPLATE_DIR/tasks.md" "$FEATURE_DIR/tasks.md"
  sdd_stamp_based_on "$FEATURE_DIR/tasks.md" "PLAN-$feature_num"
  local next_line phase_skill_line
  next_line="$(plan_next_line tasks)"
  phase_skill_line="$(sdd_phase_skill_cli_hint plan)"
  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc --arg action "$action" --arg file "$FEATURE_DIR/tasks.md" --arg artifact_id "TASKS-$feature_num" --argjson status_updates "$STATUS_UPDATES_JSON" '{tasks:{action:$action,file:$file,artifact_id:$artifact_id}, status_updates:$status_updates}')"
    GUIDANCE_JSON="$(sdd_json_guidance "$next_line" "implement is ready when each T-xxx has Status, Implements, and a Verification block; keep Phase explicit for routing clarity." "avoid vague \"do the phase\" tasks or verification written as prose instead of commands.")"
    WARNINGS_JSON="$(jq -nc --arg reminder "$PLAN_TASKS_SUSPECT_REMINDER" '[$reminder]')"
    sdd_emit_json_selection "$(sdd_json_success "plan" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "plan-tasks" "$DATA_JSON" "$GUIDANCE_JSON" "$WARNINGS_JSON")"
    local _ref_line
    _ref_line="$(sdd_phase_reference_line "plan-tasks")"
    cat >&2 <<EOF
Created: $FEATURE_DIR/tasks.md (TASKS-$feature_num)
$(sdd_status_updates_text "$STATUS_UPDATES_JSON")
Next: $next_line
${phase_skill_line:+$phase_skill_line
}Gate: implement is ready when each T-xxx has Status, Implements, and a Verification block; keep Phase explicit for routing clarity.
Quality bar: keep Files concrete and write a command Claude can actually run to verify completion.
Pitfall: avoid vague "do the phase" tasks or verification written as prose instead of commands.
$PLAN_TASKS_SUSPECT_REMINDER
EOF
    if [ -n "$_ref_line" ]; then printf '%s\n' "$_ref_line" >&2; fi
  else
    emit_plan_success "tasks" "$feature_num"
  fi
}

cmd_both() {
  local feature_num
  validate
  feature_num="$(echo "$feature" | grep -oE '^[0-9]+')"
  sdd_fail "plan" "precondition" "'sdd plan both/create-all' is disabled; run 'sdd plan create $feature' and then 'sdd plan create-tasks $feature' as separate phase boundaries." "{\"feature\":\"$feature\",\"subcommand\":\"both\",\"blocked_aliases\":[\"both\",\"create-all\"],\"next_commands\":[\"sdd plan create $feature\",\"sdd plan create-tasks $feature\"]}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
}

cmd_help() {
  show_help
}

# --- Dispatch ---

case "$cmd" in
  plan)  cmd_plan ;;
  tasks) cmd_tasks ;;
  both)  cmd_both ;;
  help|*) cmd_help ;;
esac
