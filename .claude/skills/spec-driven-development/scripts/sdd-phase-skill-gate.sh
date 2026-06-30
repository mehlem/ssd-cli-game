#!/usr/bin/env bash
# sdd-phase-skill-gate.sh — PreToolUse gate for required phase-skill invocation.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

INPUT="$(cat)"

HOOK_EVENT="$(printf '%s\n' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
[ "${HOOK_EVENT:-}" = "PreToolUse" ] || exit 0

sdd_phase_skill_gate_message() {
  local feature="$1" phase="$2" skill="$3" action="$4" status="${5:-}" message latest_skill latest_source latest_session mismatch_reason
  message="$(printf "SDD phase skill not observed: feature %s is in %s and protected action '%s' requires /%s first. Invoke /%s before retrying this tool call. This is a routing latch, not artifact validation; existing SDD gates still validate correctness." "$feature" "$phase" "$action" "$skill" "$skill")"

  if [ -n "$status" ] && printf '%s\n' "$status" | jq -e . >/dev/null 2>&1; then
    latest_skill="$(printf '%s\n' "$status" | jq -r '.latest_skill // empty' 2>/dev/null || true)"
    latest_source="$(printf '%s\n' "$status" | jq -r '.latest_source // empty' 2>/dev/null || true)"
    latest_session="$(printf '%s\n' "$status" | jq -r '.latest_session_id // empty' 2>/dev/null || true)"
    mismatch_reason="$(printf '%s\n' "$status" | jq -r '.mismatch_reason // empty' 2>/dev/null || true)"
    if [ -n "$latest_skill" ]; then
      message="$message Latest observed phase skill: /$latest_skill"
      if [ -n "$latest_source" ] || [ -n "$latest_session" ] || [ -n "$mismatch_reason" ]; then
        message="$message (source: ${latest_source:-unknown}, session: ${latest_session:-unknown}, reason: ${mismatch_reason:-unknown})"
      fi
      message="$message."
    elif [ -n "$mismatch_reason" ]; then
      message="$message Observation status: $mismatch_reason."
    fi
  fi

  printf "%s If this host cannot expose skill invocation telemetry, set SDD_PHASE_SKILL_GATE=warn or off explicitly." "$message"
}

sdd_phase_skill_gate_emit_missing() {
  local mode="$1" message="$2"

  case "$mode" in
    off)
      return 0
      ;;
    warn)
      jq -n --arg ctx "$message" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
      ;;
    block|*)
      jq -n --arg msg "$message" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny"}, systemMessage: $msg}'
      ;;
  esac
}

sdd_phase_skill_gate_target_path() {
  local input="$1"
  printf '%s\n' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true
}

sdd_phase_skill_gate_protected_edit_action() {
  local event="$1" input="$2" feature="$3" phase="$4" project_dir="$5"
  [ "$event" = "PreToolUse" ] || return 0

  local tool_name file_path rel_path protected=""
  IFS=$'\t' read -r tool_name file_path <<EOF
$(printf '%s\n' "$input" | jq -r '[.tool_name // "", .tool_input.file_path // ""] | @tsv' 2>/dev/null)
EOF

  case "$tool_name" in
    Edit|Write) ;;
    *) return 0 ;;
  esac
  [ -n "$file_path" ] || return 0

  rel_path="$(sdd_project_relative_path "$file_path" "$project_dir")"

  case "$phase" in
    brief)
      protected=".features/$feature/brief.md"
      ;;
    design|spec)
      protected=".features/$feature/spec.md"
      ;;
    research)
      protected=".features/$feature/research.md"
      ;;
    plan)
      protected=".features/$feature/plan.md"
      ;;
    plan-tasks)
      protected=".features/$feature/tasks.md"
      ;;
    implement)
      protected=".features/$feature/tasks.md"
      case "$rel_path" in
        .features/"$feature"/wp-*/tasks.md)
          printf '%s %s' "$tool_name" "$rel_path"
          return 0
          ;;
      esac
      ;;
    review)
      protected=".features/$feature/review.md"
      case "$rel_path" in
        .features/"$feature"/wp-*/review.md)
          printf '%s %s' "$tool_name" "$rel_path"
          return 0
          ;;
      esac
      ;;
    *)
      return 0
      ;;
  esac

  [ "$rel_path" = "$protected" ] || return 0
  printf '%s %s' "$tool_name" "$rel_path"
}

sdd_phase_skill_gate_boundary_action() {
  local event="$1" input="$2"
  [ "$event" = "PreToolUse" ] || return 0

  local tool_name cmd sdd_args sub sub2
  IFS=$'\t' read -r tool_name cmd <<EOF
$(printf '%s\n' "$input" | jq -r '[.tool_name // "", .tool_input.command // ""] | @tsv' 2>/dev/null)
EOF

  [ "$tool_name" = "Bash" ] || return 0
  [ -n "$cmd" ] || return 0

  sdd_args="$(printf '%s' "$cmd" | sed -n 's|.*sdd[[:space:]]\{1,\}\([a-z].*\)|\1|p')"
  [ -n "$sdd_args" ] || return 0

  sub="$(printf '%s' "$sdd_args" | awk '{print $1}')"
  sub2="$(printf '%s' "$sdd_args" | awk '{print $2}')"

  case "$sub" in
    spec|research|review|close)
      printf 'sdd %s\n' "$sub"
      ;;
    plan)
      case "$sub2" in
        create|tasks|create-tasks)
          printf 'sdd %s %s\n' "$sub" "$sub2"
          ;;
        *)
          return 0
          ;;
      esac
      ;;
    task)
      case "$sub2" in
        start|complete)
          printf 'sdd %s %s\n' "$sub" "$sub2"
          ;;
        *)
          return 0
          ;;
      esac
      ;;
    *)
      return 0
      ;;
  esac
}

FEATURE_PHASE="$(sdd_detect_feature_phase 2>/dev/null || true)"
IFS='|' read -r FEATURE PHASE <<EOF
$FEATURE_PHASE
EOF

[ -n "${FEATURE:-}" ] && [ "$FEATURE" != "none" ] || exit 0
if sdd_feature_has_work_packages "$SDD_FEATURE_ROOT/$FEATURE"; then
  PHASE="$(sdd_feature_effective_phase "$FEATURE")"
fi

ACTION="$(sdd_phase_skill_gate_protected_edit_action "$HOOK_EVENT" "$INPUT" "$FEATURE" "$PHASE" "$PROJECT_DIR")"
if [ -z "$ACTION" ]; then
  ACTION="$(sdd_phase_skill_gate_boundary_action "$HOOK_EVENT" "$INPUT")"
fi
[ -n "$ACTION" ] || exit 0

PROFILE="$(sdd_profile "$FEATURE")"
REQUIRED_PHASE="$(sdd_phase_skill_contract_phase "$PHASE")"
REQUIRED_SKILL="$(sdd_required_phase_skill "$REQUIRED_PHASE" "$PROFILE")"
[ -n "$REQUIRED_SKILL" ] || exit 0

MODE="$(sdd_phase_skill_gate_mode)"
[ "$MODE" = "off" ] && exit 0

SESSION_ID="$(printf '%s\n' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"

STATUS="$(sdd_phase_skill_invocation_status "$FEATURE" "$REQUIRED_PHASE" "$REQUIRED_SKILL" "$SESSION_ID")"
if [ "$(printf '%s\n' "$STATUS" | jq -r '.observed // false' 2>/dev/null)" = "true" ]; then
  exit 0
fi

MESSAGE="$(sdd_phase_skill_gate_message "$FEATURE" "$PHASE" "$REQUIRED_SKILL" "$ACTION" "$STATUS")"
sdd_phase_skill_gate_emit_missing "$MODE" "$MESSAGE"

exit 0
