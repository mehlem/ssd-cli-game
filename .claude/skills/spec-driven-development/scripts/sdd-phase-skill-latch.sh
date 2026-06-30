#!/usr/bin/env bash
# sdd-phase-skill-latch.sh — Hook adapter for phase-skill invocation state.
# Records observed direct slash or Skill-tool invocation for the active phase.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

INPUT="$(cat)"

HOOK_EVENT="${1:-}"
if [ -z "$HOOK_EVENT" ]; then
  HOOK_EVENT="$(printf '%s\n' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)" || true
fi

if [ -z "$HOOK_EVENT" ]; then
  exit 0
fi

sdd_phase_skill_normalize_name() {
  local raw="${1:-}" normalized
  normalized="${raw#/}"
  normalized="${normalized##*:}"
  printf '%s\n' "$normalized"
}

sdd_phase_skill_observed_name() {
  local event="$1" input="$2"
  case "$event" in
    UserPromptExpansion)
      printf '%s\n' "$input" | jq -r '.command_name // .command // .name // empty' 2>/dev/null
      ;;
    PreToolUse)
      printf '%s\n' "$input" | jq -r '
        if (.tool_name // "") != "Skill" then
          empty
        else
          .tool_input.skill
          // .tool_input.name
          // .tool_input.skill_name
          // .tool_input.command
          // .tool_input.id
          // empty
        end
      ' 2>/dev/null
      ;;
    *)
      return 0
      ;;
  esac
}

sdd_phase_skill_boundary_action() {
  local event="$1" input="$2"
  [ "$event" = "PreToolUse" ] || return 0

  local tool_name cmd sdd_args sub sub2
  IFS=$'\t' read -r tool_name cmd <<< "$(
    printf '%s\n' "$input" | jq -r '[.tool_name // "", .tool_input.command // ""] | @tsv' 2>/dev/null
  )"

  [ "$tool_name" = "Bash" ] || return 0
  [ -n "$cmd" ] || return 0

  sdd_args="$(printf '%s' "$cmd" | sed -n 's|.*sdd[[:space:]]\{1,\}\([a-z].*\)|\1|p')"
  [ -n "$sdd_args" ] || return 0

  sub="$(printf '%s' "$sdd_args" | awk '{print $1}')"
  sub2="$(printf '%s' "$sdd_args" | awk '{print $2}')"

  case "$sub" in
    spec|research|review|close)
      printf '%s\n' "$sub"
      ;;
    plan)
      case "$sub2" in
        create|tasks|create-tasks)
          printf '%s\n' "$sub $sub2"
          ;;
        *)
          return 0
          ;;
      esac
      ;;
    task)
      case "$sub2" in
        # task complete is advisory-only, matching task start.
        start|complete)
          printf '%s\n' "$sub $sub2"
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

sdd_phase_skill_emit_missing_context() {
  local feature="$1" phase="$2" skill="$3" action="$4" status source
  status="$(sdd_phase_skill_invocation_status "$feature" "$phase" "$skill")"
  if [ "$(printf '%s\n' "$status" | jq -r '.observed')" = "true" ]; then
    return 0
  fi

  source="$(printf '%s\n' "$status" | jq -r '.source // empty')"
  [ -n "$source" ] || source="not_observed"

  local context
  context="SDD phase skill not observed: feature $feature is in $phase and action 'sdd $action' requires /$skill first. Invoke /$skill before continuing this phase. This is a routing check, not artifact validation; existing SDD gates still validate correctness. If this host cannot expose skill invocation telemetry, treat this as an advisory reminder."

  jq -n --arg ctx "$context" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
}

FEATURE_PHASE="$(sdd_detect_feature_phase 2>/dev/null || true)"
IFS='|' read -r FEATURE PHASE <<EOF
$FEATURE_PHASE
EOF

[ -n "${FEATURE:-}" ] && [ "$FEATURE" != "none" ] || exit 0
if sdd_feature_has_work_packages "$SDD_FEATURE_ROOT/$FEATURE"; then
  PHASE="$(sdd_feature_effective_phase "$FEATURE")"
fi

PROFILE="$(sdd_profile "$FEATURE")"
REQUIRED_SKILL="$(sdd_required_phase_skill "$PHASE" "$PROFILE")"
[ -n "$REQUIRED_SKILL" ] || exit 0

BOUNDARY_ACTION="$(sdd_phase_skill_boundary_action "$HOOK_EVENT" "$INPUT")"
if [ -n "$BOUNDARY_ACTION" ]; then
  sdd_phase_skill_emit_missing_context "$FEATURE" "$PHASE" "$REQUIRED_SKILL" "$BOUNDARY_ACTION"
  exit 0
fi

OBSERVED_RAW="$(sdd_phase_skill_observed_name "$HOOK_EVENT" "$INPUT")"
OBSERVED_SKILL="$(sdd_phase_skill_normalize_name "$OBSERVED_RAW")"
[ -n "$OBSERVED_SKILL" ] || exit 0
sdd_phase_skill_is_known_skill "$OBSERVED_SKILL" || exit 0

SESSION_ID="$(printf '%s\n' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
case "$HOOK_EVENT" in
  UserPromptExpansion) SOURCE="user_prompt_expansion" ;;
  PreToolUse) SOURCE="skill_tool" ;;
  *) SOURCE="$HOOK_EVENT" ;;
esac

sdd_record_phase_skill_latest_invocation "$FEATURE" "$PHASE" "$OBSERVED_SKILL" "$SOURCE" "$SESSION_ID" || true

[ "$OBSERVED_SKILL" = "$REQUIRED_SKILL" ] || exit 0

sdd_record_phase_skill_invocation "$FEATURE" "$PHASE" "$REQUIRED_SKILL" "$SOURCE" "$SESSION_ID" || true

exit 0
