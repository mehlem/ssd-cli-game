#!/usr/bin/env bash
# sdd-hook.sh — Hook adapter for spec-driven-development progress context
# Injects SDD state (feature, phase, current task, counts) into Claude's context.
#
# Reads hook_event_name from JSON stdin to decide behavior:
#   SessionStart / UserPromptSubmit → emit JSON with additionalContext
#   PostToolUse                     → refresh local cache only (no stdout)
#
# Registered in .claude/settings.json for SessionStart, UserPromptSubmit, PostToolUse.

set -euo pipefail

# Graceful degradation if jq is missing
command -v jq >/dev/null 2>&1 || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
STATE_CACHE_FILE="$(sdd_state_cache_path)"

# Read JSON from stdin
INPUT="$(cat)"
SESSION_ID="$(printf '%s\n' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"

HOOK_EVENT="${1:-}"
if [ -z "$HOOK_EVENT" ]; then
  HOOK_EVENT="$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)" || true
fi

# --- Detect active feature, phase, and WP fields ---

FEATURE_CONTEXT="$(sdd_feature_context_tsv || true)"
IFS=$'\t' read -r FEATURE PHASE SELECTION_SOURCE WP_ID WP_PHASE WP_COUNT WP_DONE WP_ACTIVE_COUNT WP_PENDING_COUNT <<EOF
$FEATURE_CONTEXT
EOF

FEATURE="${FEATURE:-none}"
PHASE="${PHASE:-brief}"
RAW_PHASE="$PHASE"
SELECTION_SOURCE="${SELECTION_SOURCE:-none}"
WP_ID="${WP_ID:-none}"
WP_PHASE="${WP_PHASE:-none}"
WP_COUNT="${WP_COUNT:-0}"
WP_DONE="${WP_DONE:-0}"
WP_ACTIVE_COUNT="${WP_ACTIVE_COUNT:-0}"
WP_PENDING_COUNT="${WP_PENDING_COUNT:-0}"
if [ "$FEATURE" != "none" ] && [ "${WP_COUNT:-0}" != "0" ]; then
  PHASE="$(sdd_feature_effective_phase "$FEATURE")"
fi
TRACE_SUMMARY_JSON="$(sdd_trace_suspect_summary_json "$FEATURE")"
TRACE_SUMMARY_FIELDS="$(printf '%s\n' "$TRACE_SUMMARY_JSON" | jq -r '[.suspect_artifacts // 0, ((.suspect_ids // [])[0:5] | join(", "))] | @tsv' 2>/dev/null || printf '0\t')"
IFS=$'\t' read -r TRACE_SUSPECT_COUNT TRACE_SUSPECT_IDS <<EOF
$TRACE_SUMMARY_FIELDS
EOF
TRACE_SUSPECT_COUNT="${TRACE_SUSPECT_COUNT:-0}"
TRACE_SUSPECT_IDS="${TRACE_SUSPECT_IDS:-}"
export SDD_ACTIVE_FEATURE="$FEATURE"
export SDD_ACTIVE_PHASE="$PHASE"

task_summary_json_for_feature() {
  local feature="$1"
  local feature_dir=".features/$feature"
  if [ "$(sdd_feature_task_source "$feature_dir")" = "work_packages" ]; then
    sdd_feature_task_summary_json "$feature_dir"
  else
    sdd_task_summary_cheap "$feature_dir/tasks.md"
  fi
}

current_task_from_summary() {
  local task_summary_json="$1"
  printf '%s\n' "$task_summary_json" | jq -r '
    .current_task as $task
    | if ($task.id // null) == null then
        "none"
      elif ($task.display_ref // null) != null and ($task.display_ref != ($task.id // "")) and ($task.heading // null) != null then
        "\($task.display_ref): \($task.heading)"
      else
        ($task.heading // $task.id // "none")
      end
  ' 2>/dev/null
}

epic_state_line() {
  local epic_file=".features/EPIC.md" feature_dir=".features/$FEATURE"
  local epic_entry_id epic_id entry_title

  [ -f "$epic_file" ] || return 0
  [ -d "$feature_dir" ] || return 0
  epic_entry_id="$(sdd_feature_epic_entry_from_dir "$feature_dir" 2>/dev/null || true)"
  [ -n "$epic_entry_id" ] || return 0
  epic_id="$(sdd_frontmatter_value "$epic_file" id 2>/dev/null || true)"
  [ -n "$epic_id" ] || return 0
  entry_title="$(awk -v entry_id="$epic_entry_id" '
    /^```/ {
      in_fence = !in_fence
      next
    }
    in_fence { next }
    /^### E-[0-9][0-9]+:/ {
      current = substr($0, 5)
      id = current
      sub(/:.*/, "", id)
      if (id == entry_id) {
        sub(/^[^:]+:[ \t]*/, "", current)
        print current
        exit
      }
    }
  ' "$epic_file")"
  [ -n "$entry_title" ] || return 0
  printf 'Epic: %s / %s (%s)\n' "$epic_id" "$epic_entry_id" "$entry_title"
}

# --- Phase rules and next-move guidance ---
# Thin wrappers around shared functions in sdd-lib.sh

phase_rules() { sdd_phase_rules "$@"; }
next_move() { sdd_next_move "$@"; }
behavioral_focus() {
  case "$1" in
    brief) sdd_steering_core_rule_line ambiguity ;;
    *)     sdd_steering_core_phase_focus_compact "$1" ;;
  esac
}

autonomous_directives() {
  local feature="$1" event="${2:-SessionStart}" session_flags="${3:-}" last_tool_failure_json="${4:-null}"
  local output="" halt_line="" suspect_ids="${TRACE_SUSPECT_IDS:-}" include_full=0
  local autonomy_on="false" pending="false" last_on="false" last_suspect_count=0 current_suspect_count=0

  current_suspect_count="${TRACE_SUSPECT_COUNT:-0}"
  if sdd_autonomy_is_on "$feature"; then
    autonomy_on="true"
  fi

  if [ "$event" = "UserPromptSubmit" ]; then
    [ -n "$session_flags" ] || session_flags="$(sdd_read_session_flags)"
    pending="$(printf '%s' "$session_flags" | jq -r '.autonomy_block_pending // false' 2>/dev/null)" || pending="false"
    last_on="$(printf '%s' "$session_flags" | jq -r '.autonomy_last_on // false' 2>/dev/null)" || last_on="false"
    last_suspect_count="$(printf '%s' "$session_flags" | jq -r '.autonomy_last_suspect_count // 0' 2>/dev/null)" || last_suspect_count=0

    if [ "$autonomy_on" != "true" ]; then
      sdd_set_session_flag "autonomy_block_pending" "false" || true
      sdd_set_session_flag "autonomy_last_on" "false" || true
      sdd_set_session_flag "autonomy_last_suspect_count" "$current_suspect_count" || true
      return 0
    fi

    if [ "$pending" = "true" ] || [ "$last_on" != "true" ]; then
      include_full=1
    fi
    if [ "${last_suspect_count:-0}" -le 0 ] && [ "$current_suspect_count" -gt 0 ]; then
      include_full=1
    fi
    if [ "$last_tool_failure_json" != "null" ]; then
      include_full=1
    fi

    sdd_set_session_flag "autonomy_block_pending" "false" || true
    sdd_set_session_flag "autonomy_last_on" "true" || true
    sdd_set_session_flag "autonomy_last_suspect_count" "$current_suspect_count" || true
  else
    [ "$autonomy_on" = "true" ] || return 0
    include_full=1
  fi

  if [ "$include_full" -eq 1 ]; then
    output="$(sdd_autonomy_halt_block "$feature")"
  else
    output="$(sdd_autonomy_halt_pointer)"
  fi

  if [ "$current_suspect_count" -gt 0 ]; then
    halt_line="$(sdd_autonomous_halt \
      "suspect artifacts are present" \
      "${current_suspect_count} suspect artifact(s) may be stale${suspect_ids:+: $suspect_ids}" \
      ".features/$feature/trace.json and the listed upstream artifacts" \
      "run sdd trace acknowledge $feature --confirmed after verifying downstream artifacts are current" \
      "continuing from stale spec, research, plan, or task artifacts")"
    output="${output:+$output

}$halt_line"
  fi

  printf '%s\n' "$output"
}

build_context_payload() {
  local state="$1" directives="${2:-}" recovery="${3:-}" customization="${4:-}" epic_context="${5:-}" context=""

  context="$(sdd_tagged_block "sdd_state" "$state")"
  if [ -n "$directives" ]; then
    context="$context
$(sdd_tagged_block "sdd_directives" "$directives")"
  fi
  if [ -n "$recovery" ]; then
    context="$context
$(sdd_tagged_block "sdd_recovery" "$recovery")"
  fi
  if [ -n "$customization" ]; then
    context="$context
$customization"
  fi
  if [ -n "$epic_context" ]; then
    context="$context
$epic_context"
  fi

  printf '%s\n' "$context"
}

# --- Build summary ---

build_summary() {
  local feature="$1" phase="$2" task_summary_json="$3" format="${4:-full}"
  local completed in_progress pending blocked current
  local profile profile_display summary_fields

  if [ "${FEATURE:-}" = "$feature" ] && [ -n "${PROFILE:-}" ]; then
    profile="$PROFILE"
  else
    profile="$(sdd_profile "$feature")"
  fi
  profile_display="$(sdd_profile_display "$profile")"
  summary_fields="$(printf '%s\n' "$task_summary_json" | jq -r '
    .current_task as $task
    | [
        .completed // 0,
        .in_progress // 0,
        .pending // 0,
        .blocked // 0,
        (
          if ($task.id // null) == null then
            "none"
          elif ($task.display_ref // null) != null and ($task.display_ref != ($task.id // "")) and ($task.heading // null) != null then
            "\($task.display_ref): \($task.heading)"
          else
            ($task.heading // $task.id // "none")
          end
        )
      ] | @tsv
  ' 2>/dev/null || printf '0\t0\t0\t0\tnone')"
  IFS=$'\t' read -r completed in_progress pending blocked current <<EOF
$summary_fields
EOF
  completed="${completed:-0}"
  in_progress="${in_progress:-0}"
  pending="${pending:-0}"
  blocked="${blocked:-0}"
  current="${current:-none}"

  # Build WP summary segment (empty when no WPs)
  local wp_segment=""
  if [ -n "$WP_COUNT" ] && [ "$WP_COUNT" != "0" ]; then
    local wp_done_sym="${WP_DONE:-0}"
    local wp_active_sym="${WP_ACTIVE_COUNT:-0}"
    local wp_pending_sym="${WP_PENDING_COUNT:-0}"
    wp_segment=" | ${WP_COUNT} WPs (${wp_done_sym}✓ ${wp_active_sym}▶ ${wp_pending_sym}◻) | active: ${WP_ID}"
  fi

  local selected_tag=""
  if [ "$SELECTION_SOURCE" = "selected" ]; then
    selected_tag=" [selected]"
  fi

  if [ "$format" = "compact" ]; then
    echo "SDD: ${feature}${selected_tag} | profile: $profile_display | phase: $phase | task: $current | $completed done, $in_progress active, $pending pending, $blocked blocked${wp_segment}"
  else
    if [ -n "$wp_segment" ]; then
      cat <<EOF
SDD status:
- feature: ${feature}${selected_tag}
- profile: $profile_display
- phase: $phase
- current_task: $current
- completed: $completed | in_progress: $in_progress | pending: $pending | blocked: $blocked
- work_packages: ${WP_COUNT} total (${WP_DONE:-0} done, ${WP_ACTIVE_COUNT:-0} active, ${WP_PENDING_COUNT:-0} pending) | active: ${WP_ID} | wp_phase: ${WP_PHASE}
Consult .features/$feature/ artifacts for details.
EOF
    else
      cat <<EOF
SDD status:
- feature: ${feature}${selected_tag}
- profile: $profile_display
- phase: $phase
- current_task: $current
- completed: $completed | in_progress: $in_progress | pending: $pending | blocked: $blocked
Consult .features/$feature/ artifacts for details.
EOF
    fi
  fi
}

# --- Main ---

# No active feature — emit hint for UserPromptSubmit, stay silent otherwise
if [ "$FEATURE" = "none" ]; then
  if [ "$HOOK_EVENT" = "UserPromptSubmit" ]; then
    NO_FEATURE_CTX="$(build_context_payload "No active SDD feature. If this work should be tracked, run sdd init <name>.")"
    jq -n --arg ctx "$NO_FEATURE_CTX" --arg evt "$HOOK_EVENT" \
      '{hookSpecificOutput: {hookEventName: $evt, additionalContext: $ctx}}'
  fi
  exit 0
fi

PROFILE="$(sdd_profile "$FEATURE")"
PROFILE_DISPLAY="$(sdd_profile_display "$PROFILE")"
GUIDE_PHASE="$PHASE"
if [ "$PROFILE" = "lite" ]; then
  GUIDE_PHASE="lite"
fi

case "$HOOK_EVENT" in
  SessionStart)
    # Fallback chain: summary-compact.md > continuity.md > build_summary
    SUMMARY_COMPACT=".features/$FEATURE/summary-compact.md"
    CONTINUITY_FILE=".features/$FEATURE/continuity.md"
    CONTINUITY_STATE="filled"
    if [ -f "$SUMMARY_COMPACT" ] && [ -s "$SUMMARY_COMPACT" ]; then
      STATE_CONTEXT="$(cat "$SUMMARY_COMPACT")"
    elif [ -f "$CONTINUITY_FILE" ] && [ "$(sdd_continuity_state "$CONTINUITY_FILE")" != "empty" ]; then
      CONTINUITY_CONTENT="$(cat "$CONTINUITY_FILE")"
      STATE_CONTEXT="Feature context from continuity.md:
$CONTINUITY_CONTENT"
    else
      TASK_SUMMARY_JSON="$(task_summary_json_for_feature "$FEATURE")"
      STATE_CONTEXT="$(build_summary "$FEATURE" "$PHASE" "$TASK_SUMMARY_JSON" full)"
      if [ -f "$CONTINUITY_FILE" ] && [ "$(sdd_continuity_state "$CONTINUITY_FILE")" = "empty" ]; then
        STATE_CONTEXT="$STATE_CONTEXT
continuity.md is placeholder — populate Goal/Constraints/Decisions before treating as authoritative state."
      fi
    fi
    case "$STATE_CONTEXT" in
      *"profile:"*|*"Profile:"*) ;;
      *) STATE_CONTEXT="$STATE_CONTEXT
profile: $PROFILE_DISPLAY" ;;
    esac

    # Resolve current task for next_move
    TASK_SUMMARY_JSON="${TASK_SUMMARY_JSON:-$(task_summary_json_for_feature "$FEATURE")}"
    local_current="$(current_task_from_summary "$TASK_SUMMARY_JSON")"

    # Append prescriptive steering
    RULES="$(phase_rules "$PHASE")"
    FOCUS="$(behavioral_focus "$PHASE")"
    NEXT="$(next_move "$PHASE" "$FEATURE" "$local_current")"
    PHASE_SKILL="$(sdd_phase_skill_directive "$PHASE" "$PROFILE" "$FEATURE" "$SESSION_ID")"
    DIRECTIVES=""
    if [ -n "$RULES" ]; then
      DIRECTIVES="$RULES"
    fi
    if [ -n "$FOCUS" ]; then
      DIRECTIVES="${DIRECTIVES:+$DIRECTIVES
}Steering: $FOCUS"
    fi
    if [ -n "$PHASE_SKILL" ]; then
      DIRECTIVES="${DIRECTIVES:+$DIRECTIVES
}$PHASE_SKILL"
    fi
    if [ -n "$NEXT" ]; then
      DIRECTIVES="${DIRECTIVES:+$DIRECTIVES
}$NEXT"
    fi

    # Append mode-appropriate phase methodology guide
    PHASE_GUIDE="$(sdd_phase_guide "$GUIDE_PHASE" "$FEATURE")"
    if [ -n "$PHASE_GUIDE" ]; then
      DIRECTIVES="${DIRECTIVES:+$DIRECTIVES
}$PHASE_GUIDE"
    fi

    # Brief-phase interview steering
    if [ "$PHASE" = "brief" ]; then
      BRIEF_INTERVIEW="$(sdd_brief_interview_hint "$FEATURE" full)"
      if [ -n "$BRIEF_INTERVIEW" ]; then
        DIRECTIVES="${DIRECTIVES:+$DIRECTIVES
}$BRIEF_INTERVIEW"
      fi
    fi

    HINTS="$(sdd_maintenance_hints "$PHASE" "$PROFILE")"
    if [ -n "$HINTS" ]; then
      DIRECTIVES="${DIRECTIVES:+$DIRECTIVES
}$HINTS"
    fi

    AUTONOMOUS_DIRECTIVES="$(autonomous_directives "$FEATURE" "$HOOK_EVENT")"
    if [ -n "$AUTONOMOUS_DIRECTIVES" ]; then
      DIRECTIVES="${DIRECTIVES:+$DIRECTIVES
}$AUTONOMOUS_DIRECTIVES"
    fi

    if [ "${TRACE_SUSPECT_COUNT:-0}" -gt 0 ]; then
      STATE_CONTEXT="$STATE_CONTEXT
Suspect artifacts: $TRACE_SUSPECT_COUNT"
      if [ -n "$TRACE_SUSPECT_IDS" ]; then
        STATE_CONTEXT="$STATE_CONTEXT ($TRACE_SUSPECT_IDS)"
      fi
    fi
    EPIC_STATE_LINE="$(epic_state_line)"
    if [ -n "$EPIC_STATE_LINE" ]; then
      STATE_CONTEXT="$STATE_CONTEXT
$EPIC_STATE_LINE"
    fi

    PROJECT_CUSTOMIZATION_FILE=".sdd/customization.yaml"
    FEATURE_CUSTOMIZATION_FILE=".features/$FEATURE/customization.yaml"
    CUSTOMIZATION_CONTEXT="$(sdd_emit_customization_block "$PROJECT_CUSTOMIZATION_FILE" "$FEATURE_CUSTOMIZATION_FILE" "$PHASE" "")"
    EPIC_ENTRY_ID="$(sdd_feature_epic_entry_from_dir ".features/$FEATURE" 2>/dev/null || true)"
    EPIC_CONTEXT="$(sdd_emit_epic_block ".features/EPIC.md" "$PHASE" "" "$EPIC_ENTRY_ID")"

    CONTEXT_PAYLOAD="$(build_context_payload "$STATE_CONTEXT" "$DIRECTIVES" "" "$CUSTOMIZATION_CONTEXT" "$EPIC_CONTEXT")"
    jq -n --arg ctx "$CONTEXT_PAYLOAD" --arg evt "$HOOK_EVENT" \
      '{hookSpecificOutput: {hookEventName: $evt, additionalContext: $ctx}}'
    ;;
  UserPromptSubmit)
    # Always emit the compact heartbeat; verbose context is delta-driven.
    TASK_SUMMARY_JSON="$(task_summary_json_for_feature "$FEATURE")"
    STATE_CONTEXT="$(build_summary "$FEATURE" "$PHASE" "$TASK_SUMMARY_JSON" compact)"

    # Brief-phase compact interview cue
    DIRECTIVES=""
    if [ "$PHASE" = "brief" ]; then
      BRIEF_CUE="$(sdd_brief_interview_hint "$FEATURE" compact)"
      if [ -n "$BRIEF_CUE" ]; then
        DIRECTIVES="$BRIEF_CUE"
      fi
    elif [ "$PHASE" = "review" ]; then
      REVIEW_CUE="$(sdd_review_dispatch_hint "$FEATURE" compact)"
      if [ -n "$REVIEW_CUE" ]; then
        DIRECTIVES="$REVIEW_CUE"
      fi
    fi

    if [ "${TRACE_SUSPECT_COUNT:-0}" -gt 0 ]; then
      STATE_CONTEXT="$STATE_CONTEXT | suspect: $TRACE_SUSPECT_COUNT"
    fi
    EPIC_STATE_LINE="$(epic_state_line)"
    if [ -n "$EPIC_STATE_LINE" ]; then
      STATE_CONTEXT="$STATE_CONTEXT
$EPIC_STATE_LINE"
    fi
    TASK_CURRENT_FIELDS="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '
      .current_task as $task
      | [
          (
            if ($task.id // null) == null then
              "none"
            elif ($task.display_ref // null) != null and ($task.display_ref != ($task.id // "")) and ($task.heading // null) != null then
              "\($task.display_ref): \($task.heading)"
            else
              ($task.heading // $task.id // "none")
            end
          ),
          ($task.display_ref // $task.id // "none")
        ] | @tsv
    ' 2>/dev/null || printf 'none\tnone')"
    IFS=$'\t' read -r CURRENT_TASK CURRENT_TASK_ID <<EOF
$TASK_CURRENT_FIELDS
EOF
    CURRENT_TASK="${CURRENT_TASK:-none}"
    CURRENT_TASK_ID="${CURRENT_TASK_ID:-none}"

    SESSION_FLAGS="$(sdd_read_session_flags)"
    POST_COMPACT_PENDING="$(printf '%s' "$SESSION_FLAGS" | jq -r '.post_compact_pending // false' 2>/dev/null)" || POST_COMPACT_PENDING="false"
    INSTRUCTIONS_RELOADED="$(printf '%s' "$SESSION_FLAGS" | jq -r '.instructions_reloaded // false' 2>/dev/null)" || INSTRUCTIONS_RELOADED="false"
    LAST_TOOL_FAILURE_JSON="$(printf '%s' "$SESSION_FLAGS" | jq -c '.last_tool_failure // null' 2>/dev/null)" || LAST_TOOL_FAILURE_JSON="null"
    RULES="$(phase_rules "$PHASE")"
    RULES_CLEAN="${RULES#Rules: }"
    RECOVERY_FOCUS="$(sdd_steering_core_phase_focus_compact recovery)"
    PHASE_FOCUS="$(behavioral_focus "$PHASE")"
    PHASE_SKILL="$(sdd_phase_skill_directive "$PHASE" "$PROFILE" "$FEATURE" "$SESSION_ID")"
    if [ -n "$PHASE_FOCUS" ]; then
      DIRECTIVES="${DIRECTIVES:+$DIRECTIVES
}Steering focus: $PHASE_FOCUS"
    fi
    if [ -n "$PHASE_SKILL" ]; then
      DIRECTIVES="${DIRECTIVES:+$DIRECTIVES
}$PHASE_SKILL"
    fi
    DELTAS=""
    CUSTOMIZATION_CONTEXT=""
    EPIC_CONTEXT=""

    if [ "$POST_COMPACT_PENDING" = "true" ]; then
      DELTA="Context compacted. Current state: feature=$FEATURE, profile=$PROFILE_DISPLAY, phase=$PHASE, task=$CURRENT_TASK. Read phase guide in references/phases/$GUIDE_PHASE.md for methodology. Phase rules: $RULES_CLEAN"
      if [ -n "$PHASE_FOCUS" ]; then
        DELTA="$DELTA Steering focus: $PHASE_FOCUS."
      fi
      DELTA="$DELTA Recovery focus: $RECOVERY_FOCUS Update continuity.md with current session state."
      DELTAS="${DELTAS:+$DELTAS
}$DELTA"
      sdd_set_session_flag "post_compact_pending" "false" || true
    fi

    if [ "$INSTRUCTIONS_RELOADED" = "true" ]; then
      DELTA="Instructions reloaded (reason: compact). Phase rules: $RULES_CLEAN"
      if [ -n "$PHASE_FOCUS" ]; then
        DELTA="$DELTA Steering focus: $PHASE_FOCUS."
      fi
      DELTAS="${DELTAS:+$DELTAS
}$DELTA"
      sdd_set_session_flag "instructions_reloaded" "false" || true
    fi

    if [ "$LAST_TOOL_FAILURE_JSON" != "null" ]; then
      FAILURE_TOOL="$(printf '%s' "$LAST_TOOL_FAILURE_JSON" | jq -r '.tool // "unknown"' 2>/dev/null)" || FAILURE_TOOL="unknown"
      FAILURE_ERROR="$(printf '%s' "$LAST_TOOL_FAILURE_JSON" | jq -r '.error // "unknown error"' 2>/dev/null)" || FAILURE_ERROR="unknown error"
      FAILURE_IS_VERIFICATION="$(printf '%s' "$LAST_TOOL_FAILURE_JSON" | jq -r '.is_verification // false' 2>/dev/null)" || FAILURE_IS_VERIFICATION="false"
      DELTA="Previous tool failure: $FAILURE_TOOL — $FAILURE_ERROR."
      if [ "$FAILURE_IS_VERIFICATION" = "true" ]; then
        DELTA="$DELTA This was a verification command — investigate root cause before retrying."
      fi
      DELTA="$DELTA Recovery focus: $RECOVERY_FOCUS Record failure context in scratchpad.md observations."
      DELTAS="${DELTAS:+$DELTAS
}$DELTA"
      sdd_set_session_flag "last_tool_failure" "null" || true
    fi

    # Event-aware nudge: detect meaningful state changes
    NUDGE=""

    if [ -f "$STATE_CACHE_FILE" ]; then
      CACHE_FIELDS="$(jq -r '[.last_phase // "", .last_task // "", .last_task_status // "", .tool_calls_since_scratchpad // 0, .tool_calls_since_continuity // 0, .tool_calls_since_knowledge // 0] | @tsv' "$STATE_CACHE_FILE" 2>/dev/null || printf '\t\t\t0\t0\t0')"
      IFS=$'\t' read -r CACHED_PHASE CACHED_TASK CACHED_STATUS TOOL_CALLS CONTINUITY_CALLS KNOWLEDGE_CALLS <<EOF
$CACHE_FIELDS
EOF
      CONTINUITY_FILE=".features/$FEATURE/continuity.md"
      KNOWLEDGE_FILE=".features/$FEATURE/knowledge.md"
      CONTINUITY_STATE="$(sdd_continuity_state "$CONTINUITY_FILE")"
      KNOWLEDGE_STATE="$(sdd_knowledge_state "$KNOWLEDGE_FILE")"

      # Priority 1: Phase transition detected
      if [ -n "$CACHED_PHASE" ] && [ "$CACHED_PHASE" != "$PHASE" ]; then
        NUDGE="Nudge: Phase changed to $PHASE. Read phase guide for methodology."
        EPIC_ENTRY_ID="$(sdd_feature_epic_entry_from_dir ".features/$FEATURE" 2>/dev/null || true)"
        EPIC_CONTEXT="$(SDD_EPIC_INCLUDE_GOAL=0 SDD_EPIC_INCLUDE_DEPS_NEIGHBORS=0 sdd_emit_epic_block ".features/EPIC.md" "$PHASE" "" "$EPIC_ENTRY_ID")"
        PROJECT_CUSTOMIZATION_FILE=".sdd/customization.yaml"
        FEATURE_CUSTOMIZATION_FILE=".features/$FEATURE/customization.yaml"
        CUSTOMIZATION_CONTEXT="$(SDD_CUSTOMIZATION_INCLUDE_GLOBAL=0 SDD_CUSTOMIZATION_INCLUDE_LEARNED=0 sdd_emit_customization_block "$PROJECT_CUSTOMIZATION_FILE" "$FEATURE_CUSTOMIZATION_FILE" "$PHASE" "")"
      # Priority 2: Task completion detected (task changed AND old status was in-progress)
      elif [ -n "$CACHED_TASK" ] && [ "$CACHED_TASK" != "none" ] && [ "$CACHED_STATUS" = "in-progress" ]; then
        if [ "${CURRENT_TASK_ID:-none}" != "$CACHED_TASK" ]; then
          NUDGE="Nudge: Task $CACHED_TASK completed. Update scratchpad.md with findings; graduate discoveries to knowledge.md."
          if [ "$KNOWLEDGE_STATE" = "empty" ]; then
            NUDGE="$NUDGE Add a K-entry to .features/$FEATURE/knowledge.md for any non-obvious discovery from the completed task."
          fi
        fi
      # Priority 3: Continuity placeholder state (post-planning phases)
      elif { [ "$PHASE" = "implement" ] || [ "$PHASE" = "review" ] || [ "$PHASE" = "close" ]; } && [ "$CONTINUITY_STATE" = "empty" ]; then
        NUDGE="Nudge: HIGH priority — continuity.md is placeholder-only. Populate .features/$FEATURE/continuity.md with Goal, Decisions, and Reasoning State before treating this feature state as recoverable."
      # Priority 4: Continuity staleness (partial sooner, filled later)
      elif { [ "$CONTINUITY_STATE" = "partial" ] && [ "${CONTINUITY_CALLS:-0}" -ge 5 ]; } || { [ "$CONTINUITY_STATE" = "filled" ] && [ "${CONTINUITY_CALLS:-0}" -ge 15 ]; }; then
        NUDGE="Nudge: ${CONTINUITY_CALLS} tool calls since continuity.md updated. Update .features/$FEATURE/continuity.md with current state (done/now/next, decisions, working set)."
      # Priority 4: Scratchpad staleness (5+ tool calls)
      elif [ "${TOOL_CALLS:-0}" -ge 5 ]; then
        NUDGE="Nudge: ${TOOL_CALLS} tool calls since last scratchpad update. Capture observations in .features/$FEATURE/scratchpad.md"
      # Priority 5: Empty knowledge is visible at close.
      elif [ "$PHASE" = "close" ] && [ "$KNOWLEDGE_STATE" = "empty" ]; then
        NUDGE="Nudge: HIGH priority — knowledge.md has no K-entries. Before close, add K-entries for non-obvious discoveries or document the empty-knowledge opt-out."
      fi
    fi

    if [ -n "$NUDGE" ]; then
      DIRECTIVES="${DIRECTIVES:+$DIRECTIVES
}$NUDGE"
    fi

    AUTONOMOUS_DIRECTIVES="$(autonomous_directives "$FEATURE" "$HOOK_EVENT" "$SESSION_FLAGS" "$LAST_TOOL_FAILURE_JSON")"
    if [ -n "$AUTONOMOUS_DIRECTIVES" ]; then
      DIRECTIVES="${DIRECTIVES:+$DIRECTIVES
}$AUTONOMOUS_DIRECTIVES"
    fi

    CUSTOMIZATION_RECOVERY_FILE=".claude/tmp/sdd-customization-learned-recovery-$FEATURE.txt"
    if [ -s "$CUSTOMIZATION_RECOVERY_FILE" ]; then
      RECOVERED_CUSTOMIZATION="$(cat "$CUSTOMIZATION_RECOVERY_FILE")"
      if [ -n "$RECOVERED_CUSTOMIZATION" ]; then
        RECOVERED_CUSTOMIZATION_BLOCK="$(sdd_tagged_block "project_customization" "$RECOVERED_CUSTOMIZATION")"
        CUSTOMIZATION_CONTEXT="${CUSTOMIZATION_CONTEXT:+$CUSTOMIZATION_CONTEXT
}$RECOVERED_CUSTOMIZATION_BLOCK"
      fi
      rm -f "$CUSTOMIZATION_RECOVERY_FILE" 2>/dev/null || true
    fi

    CONTEXT_PAYLOAD="$(build_context_payload "$STATE_CONTEXT" "$DIRECTIVES" "$DELTAS" "$CUSTOMIZATION_CONTEXT" "$EPIC_CONTEXT")"
    jq -n --arg ctx "$CONTEXT_PAYLOAD" --arg evt "$HOOK_EVENT" \
      '{hookSpecificOutput: {hookEventName: $evt, additionalContext: $ctx}}'
    ;;
  PostToolUse)
    # Moved to async sdd-cache-refresh.sh — no-op fallback
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
