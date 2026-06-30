#!/usr/bin/env bash
# sdd-stop-gate.sh — Stop hook that blocks premature stopping during SDD work.
#
# During implement phase: blocks if tasks are in-progress or pending.
# During review phase: blocks if review.md is missing or verdict != pass.
# All other phases: allows stop (advisory phases, don't gate).
# WP mode: checks aggregate WP task and review readiness before feature review.
# Respects stop_hook_active to prevent infinite loops.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
INPUT="$(cat)"
EXPLICIT_FEATURE="${1:-}"

MAINT_REMINDER=" Before stopping: ensure scratchpad.md, continuity.md, and knowledge.md reflect current session state."

stop_gate_guidance() {
  local uncertain="$1" inspect="$2" next="$3" avoid="$4"
  printf 'Uncertain: %s Inspect: %s Next: %s Avoid: %s' "$uncertain" "$inspect" "$next" "$avoid"
}

continuity_block_if_needed() {
  local completed_count="${1:-0}"
  local continuity_state="filled"

  case "$PHASE" in
    implement|review) ;;
    *) return 0 ;;
  esac

  [ "$completed_count" -ge 1 ] || return 0
  continuity_state="$(sdd_continuity_state "$CONTINUITY_FILE" 2>/dev/null || printf 'filled')"
  [ "$continuity_state" = "empty" ] || return 0

  REASON="Feature $FEATURE: continuity.md is placeholder but $completed_count task(s) have completed. Populate .features/$FEATURE/continuity.md (Goal, Decisions, Reasoning State) before ending the session.$MAINT_REMINDER"
  jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
  exit 0
}

# Prevent infinite loops — allow stop on second attempt
STOP_ACTIVE="$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" || true
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

# Detect feature and phase. Normally close-phase features are inactive for hook
# silence, but a selected close feature still needs the reviewer-dispatch gate.
if [ -n "$EXPLICIT_FEATURE" ] && [ -d "$SDD_FEATURE_ROOT/$EXPLICIT_FEATURE" ]; then
  FEATURE_CONTEXT="$(printf '%s\tclose\targ\tnone\tnone\t0\t0\t0\t0\n' "$EXPLICIT_FEATURE")"
elif sdd_has_active_feature; then
  FEATURE_CONTEXT="$(sdd_feature_context_tsv || true)"
else
  SELECTED_CLOSE_FEATURE=""
  if [ -f "$SDD_FEATURE_ROOT/.active" ]; then
    read -r SELECTED_CLOSE_FEATURE < "$SDD_FEATURE_ROOT/.active" 2>/dev/null || true
  fi
  if [ -n "$SELECTED_CLOSE_FEATURE" ] \
    && [ -d "$SDD_FEATURE_ROOT/$SELECTED_CLOSE_FEATURE" ] \
    && [ "$(sdd_feature_phase "$SELECTED_CLOSE_FEATURE")" = "close" ]; then
    FEATURE_CONTEXT="$(printf '%s\tclose\tselected\tnone\tnone\t0\t0\t0\t0\n' "$SELECTED_CLOSE_FEATURE")"
  else
    exit 0
  fi
fi
IFS=$'\t' read -r FEATURE PHASE _SOURCE WP_ID _WP_PHASE WP_COUNT WP_DONE _WP_ACTIVE _WP_PENDING <<EOF
$FEATURE_CONTEXT
EOF

# No active feature — allow stop
[ -z "$FEATURE" ] || [ "$FEATURE" = "none" ] && exit 0

FEATURE_DIR="$SDD_FEATURE_ROOT/$FEATURE"
TASKS_FILE="$FEATURE_DIR/tasks.md"
REVIEW_FILE="$FEATURE_DIR/review.md"
CONTINUITY_FILE="$FEATURE_DIR/continuity.md"
RAW_PHASE="$PHASE"
if sdd_feature_has_work_packages "$FEATURE_DIR"; then
  PHASE="$(sdd_feature_effective_phase "$FEATURE" 2>/dev/null || printf '%s\n' "$RAW_PHASE")"
fi

case "$PHASE" in
  implement)
    # WP mode: check aggregate WP tasks, not root tasks.md.
    if sdd_feature_has_work_packages "$FEATURE_DIR"; then
      WP_TASK_SUMMARY_JSON="$(sdd_feature_task_summary_json "$FEATURE_DIR")"
      COMPLETED="$(printf '%s\n' "$WP_TASK_SUMMARY_JSON" | jq -r '.completed // 0' 2>/dev/null)" || COMPLETED=0
      WP_IN_PROGRESS="$(printf '%s\n' "$WP_TASK_SUMMARY_JSON" | jq -r '.in_progress // 0' 2>/dev/null)" || WP_IN_PROGRESS=0
      WP_PENDING="$(printf '%s\n' "$WP_TASK_SUMMARY_JSON" | jq -r '.pending // 0' 2>/dev/null)" || WP_PENDING=0
      WP_CURRENT="$(printf '%s\n' "$WP_TASK_SUMMARY_JSON" | jq -r '.current_task.work_package // empty' 2>/dev/null)" || WP_CURRENT=""
      [ -n "$WP_CURRENT" ] || WP_CURRENT="work packages"

      continuity_block_if_needed "$COMPLETED"

      if [ "$WP_IN_PROGRESS" -gt 0 ] || [ "$WP_PENDING" -gt 0 ]; then
        if [ "$WP_PENDING" -eq 0 ]; then
          ACTIVE="$(sdd_active_dispatch_count "$FEATURE" 2>/dev/null || echo 0)"
          if [ "$ACTIVE" -gt 0 ]; then
            jq -n --arg msg "SDD: $ACTIVE background dispatch(es) active for $FEATURE/$WP_CURRENT — in-progress tasks are covered by running agents. $(stop_gate_guidance \
              "a running worker may still change the task state before you resume." \
              "the worker ledger and result files for $FEATURE, plus the current WP task verification block." \
              "resume, read the worker result, then verify before marking anything else complete." \
              "assuming the background run already finished successfully or skipping verification on resume.")$MAINT_REMINDER" \
              '{systemMessage: $msg}'
            exit 0
          fi
        fi
        REASON="SDD: $WP_IN_PROGRESS task(s) in-progress, $WP_PENDING pending in $WP_CURRENT. $(stop_gate_guidance \
          "stopping here would leave active work or unresolved defer/block decisions inside the work package lifecycle." \
          "$WP_CURRENT/tasks.md for the active task and verification block, plus scratchpad.md and continuity.md for the current blocker or verification target." \
          "complete the current WP task, explicitly defer it, or stop only after recording the exact state you expect to resume from." \
          "assuming pending work will be obvious later or treating in-progress work as implicitly deferred.")$MAINT_REMINDER"
        jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
        exit 0
      fi
    fi

    # Standard mode (no WPs): check feature-level tasks.md
    if [ -f "$TASKS_FILE" ]; then
      TASK_SUMMARY_JSON="$(sdd_task_summary_json "$TASKS_FILE")"
      COMPLETED="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.completed // 0' 2>/dev/null)" || COMPLETED=0
      IN_PROGRESS="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.in_progress // 0' 2>/dev/null)" || IN_PROGRESS=0
      PENDING="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.pending // 0' 2>/dev/null)" || PENDING=0

      # Pre-implementation: no work started yet → allow (natural boundary)
      if [ "$COMPLETED" -eq 0 ] && [ "$IN_PROGRESS" -eq 0 ]; then
        exit 0
      fi

      continuity_block_if_needed "$COMPLETED"

      if [ "$IN_PROGRESS" -gt 0 ] || [ "$PENDING" -gt 0 ]; then
        if [ "$PENDING" -eq 0 ]; then
          ACTIVE="$(sdd_active_dispatch_count "$FEATURE" 2>/dev/null || echo 0)"
          if [ "$ACTIVE" -gt 0 ]; then
            jq -n --arg msg "SDD: $ACTIVE background dispatch(es) active for $FEATURE — in-progress tasks are covered by running agents. $(stop_gate_guidance \
              "a running worker may still change task state after the controller stops." \
              "the worker ledger and result files for $FEATURE, plus the current task verification block." \
              "resume, read the worker result, then verify before marking anything complete." \
              "assuming background work succeeded silently or retrying around it without reading the result first.")$MAINT_REMINDER" \
              '{systemMessage: $msg}'
            exit 0
          fi
        fi
        REASON="SDD: $IN_PROGRESS task(s) in-progress, $PENDING pending in $FEATURE. $(stop_gate_guidance \
          "stopping now would leave active implement work or an unresolved defer/block decision." \
          "tasks.md for the current task and verification block, plus scratchpad.md and continuity.md for the latest blocker or verification target." \
          "complete the current task, run 'sdd task block $FEATURE <task-id>' to defer intentionally, or stop only after recording the exact resume state." \
          "guessing what future-you will remember, or treating in-progress work as automatically deferred.")$MAINT_REMINDER"
        jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
        exit 0
      fi
    fi

    if [ -f "$REVIEW_FILE" ]; then
      REVIEW_VERDICT="$(sdd_frontmatter_value "$REVIEW_FILE" verdict || echo "pending")"
      if [ "$REVIEW_VERDICT" = "fail" ]; then
        REASON="SDD: Review verdict is '$REVIEW_VERDICT' for $FEATURE. $(stop_gate_guidance \
          "review already found a problem that must be resolved before this feature is stable." \
          "review.md for the failing evidence and the linked AC rows, then inspect the affected implementation files." \
          "re-open implementation work, fix the recorded issue, and rerun review evidence before stopping." \
          "ignoring a failed review or treating it as a clean stopping boundary.")$MAINT_REMINDER"
        jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
        exit 0
      fi
    fi
    ;;
  review|close)
    # WP mode: require aggregate WP task completion and passing WP reviews before
    # treating feature-level review as the remaining gate.
    if sdd_feature_has_work_packages "$FEATURE_DIR"; then
      WP_TASK_SUMMARY_JSON="$(sdd_feature_task_summary_json "$FEATURE_DIR")"
      COMPLETED="$(printf '%s\n' "$WP_TASK_SUMMARY_JSON" | jq -r '.completed // 0' 2>/dev/null)" || COMPLETED=0
      WP_IN_PROGRESS="$(printf '%s\n' "$WP_TASK_SUMMARY_JSON" | jq -r '.in_progress // 0' 2>/dev/null)" || WP_IN_PROGRESS=0
      WP_PENDING="$(printf '%s\n' "$WP_TASK_SUMMARY_JSON" | jq -r '.pending // 0' 2>/dev/null)" || WP_PENDING=0
      WP_CURRENT="$(printf '%s\n' "$WP_TASK_SUMMARY_JSON" | jq -r '.current_task.work_package // empty' 2>/dev/null)" || WP_CURRENT=""
      [ -n "$WP_CURRENT" ] || WP_CURRENT="work packages"

      continuity_block_if_needed "$COMPLETED"

      if [ "$WP_IN_PROGRESS" -gt 0 ] || [ "$WP_PENDING" -gt 0 ]; then
        REASON="SDD: $WP_IN_PROGRESS task(s) in-progress, $WP_PENDING pending in $WP_CURRENT. $(stop_gate_guidance \
          "the work package lifecycle still has open work and no clean feature review boundary yet." \
          "$WP_CURRENT/tasks.md for the current task and verification block, plus scratchpad.md and continuity.md for the latest blocker or verification target." \
          "finish the active WP task, defer it explicitly, or stop only after capturing the exact resume state." \
          "treating WP progress as self-explanatory or leaving hidden blockers for the next session.")$MAINT_REMINDER"
        jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
        exit 0
      fi

      WP_REVIEW_SUMMARY_JSON="$(sdd_feature_wp_review_summary_json "$FEATURE_DIR")"
      WP_SCAFFOLD="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '.scaffold // 0' 2>/dev/null)" || WP_SCAFFOLD=0
      WP_INCOMPLETE="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '.incomplete_tasks // 0' 2>/dev/null)" || WP_INCOMPLETE=0
      WP_MISSING_REVIEW="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '.missing_review // 0' 2>/dev/null)" || WP_MISSING_REVIEW=0
      WP_FAILING_REVIEW="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '.failing_review // 0' 2>/dev/null)" || WP_FAILING_REVIEW=0
      WP_INCOMPLETE_LIST="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '[.work_packages[] | select(.phase != "done") | .id] | join(", ")' 2>/dev/null)" || WP_INCOMPLETE_LIST=""
      WP_MISSING_REVIEW_LIST="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '[.work_packages[] | select(.review_verdict == null) | .id] | join(", ")' 2>/dev/null)" || WP_MISSING_REVIEW_LIST=""
      WP_FAILING_REVIEW_LIST="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '[.work_packages[] | select(.review_verdict != null and .review_pass != true) | .id] | join(", ")' 2>/dev/null)" || WP_FAILING_REVIEW_LIST=""

      if [ "$WP_SCAFFOLD" -gt 0 ] || [ "$WP_INCOMPLETE" -gt 0 ]; then
        [ -n "$WP_INCOMPLETE_LIST" ] || WP_INCOMPLETE_LIST="work packages"
        REASON="SDD: work package tasks are incomplete for $FEATURE ($WP_INCOMPLETE_LIST). $(stop_gate_guidance \
          "feature review would hide unfinished WP execution state." \
          "the listed wp-*/tasks.md files and their verification blocks." \
          "complete or explicitly defer WP tasks before treating this as a review boundary." \
          "closing from root feature artifacts while WP tasks remain scaffolded or incomplete.")$MAINT_REMINDER"
        jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
        exit 0
      fi

      if [ "$WP_MISSING_REVIEW" -gt 0 ]; then
        [ -n "$WP_MISSING_REVIEW_LIST" ] || WP_MISSING_REVIEW_LIST="work packages"
        REASON="SDD: work package review is missing for $FEATURE ($WP_MISSING_REVIEW_LIST). $(stop_gate_guidance \
          "the feature-level review would lack verified WP-level evidence." \
          "the listed wp-*/review.md files and the completed WP task evidence." \
          "run WP review for each completed work package before feature review close-out." \
          "treating completed WP tasks as equivalent to a passing WP review.")$MAINT_REMINDER"
        jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
        exit 0
      fi

      if [ "$WP_FAILING_REVIEW" -gt 0 ]; then
        [ -n "$WP_FAILING_REVIEW_LIST" ] || WP_FAILING_REVIEW_LIST="work packages"
        REASON="SDD: work package review is failing or lacks sufficient evidence for $FEATURE ($WP_FAILING_REVIEW_LIST). $(stop_gate_guidance \
          "one or more WP reviews has not reached a trustworthy passing boundary." \
          "the listed wp-*/review.md files, their verdicts, and evidence_status fields." \
          "resolve failing WP review evidence before feature-level review close-out." \
          "rolling up a feature review while WP review failures remain unresolved.")$MAINT_REMINDER"
        jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
        exit 0
      fi
    fi

    if [ -f "$TASKS_FILE" ]; then
      TASK_SUMMARY_JSON="$(sdd_task_summary_json "$TASKS_FILE")"
      COMPLETED="$(printf '%s\n' "$TASK_SUMMARY_JSON" | jq -r '.completed // 0' 2>/dev/null)" || COMPLETED=0
      continuity_block_if_needed "$COMPLETED"
    fi

    if [ -n "$EXPLICIT_FEATURE" ] && [ "$(sdd_profile "$FEATURE")" = "deep" ] && ! sdd_reviewer_dispatch_present "$FEATURE"; then
      REASON="SDD: Reviewer dispatch missing for $FEATURE; deep mode requires recorded sdd-spec-reviewer and sdd-quality-reviewer results before close. $(stop_gate_guidance \
        "the feature is being checked at a close boundary without both reviewer results." \
        "the workers/result-*.json ledger for $FEATURE and review.md plan-check evidence." \
        "dispatch sdd-spec-reviewer and sdd-quality-reviewer, then integrate both results before close." \
        "using implementer self-review for a deep-mode feature.")$MAINT_REMINDER"
      jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
      exit 0
    fi

    if [ ! -f "$REVIEW_FILE" ]; then
      REASON="SDD: All tasks completed but review.md not yet created for $FEATURE. $(stop_gate_guidance \
        "acceptance criteria have not been validated yet, so completion is still unverified." \
        "spec.md for the AC set and the completed task verification evidence you already gathered." \
        "run 'sdd review $FEATURE' to scaffold the review, then validate ACs before stopping." \
        "treating completed tasks as equivalent to a finished review.")$MAINT_REMINDER"
      jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
      exit 0
    fi

    EVIDENCE_STATUS="$(sdd_frontmatter_value "$REVIEW_FILE" evidence_status || echo "")"
    if [ -n "$EVIDENCE_STATUS" ] && [ "$EVIDENCE_STATUS" != "sufficient" ]; then
      REASON="SDD: Review evidence_status is '$EVIDENCE_STATUS' for $FEATURE. $(stop_gate_guidance \
        "the current review does not yet have enough evidence to trust the verdict." \
        "review.md, adjudication output, and the missing verification evidence linked from the review rows." \
        "gather the missing evidence or rerun adjudication before treating review as complete." \
        "assuming a pass verdict is trustworthy when evidence_status is not sufficient.")$MAINT_REMINDER"
      jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
      exit 0
    fi

    VERDICT="$(sdd_frontmatter_value "$REVIEW_FILE" verdict || echo "pending")"
    if [ "$VERDICT" != "pass" ]; then
      REASON="SDD: Review verdict is '$VERDICT' for $FEATURE. $(stop_gate_guidance \
        "the feature has not yet reached a passing review boundary." \
        "review.md for unresolved AC rows and the evidence behind the current verdict." \
        "finish AC validation, resolve any failures, and set verdict to 'pass' before stopping." \
        "treating a pending or failing review as a safe close-out point.")$MAINT_REMINDER"
      jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
      exit 0
    fi

    SESSION_FLAGS="$(sdd_read_session_flags)"
    SELF_REVIEWED_AT="$(printf '%s\n' "$SESSION_FLAGS" | jq -r '.self_reviewed_at // empty' 2>/dev/null || true)"
    PROFILE="$(sdd_profile "$FEATURE")"
    if [ -z "$SELF_REVIEWED_AT" ] && [ "$PROFILE" != "lite" ] && { sdd_autonomy_is_on "$FEATURE" || [ "$PROFILE" = "deep" ]; } && ! sdd_reviewer_dispatch_present "$FEATURE"; then
      REASON="SDD: Reviewer dispatch missing for $FEATURE; self-review is the failure mode the review phase exists to prevent. $(stop_gate_guidance \
        "the passing review verdict was produced without recorded sdd-spec-reviewer and sdd-quality-reviewer results." \
        "the workers/result-*.json ledger for $FEATURE and review.md evidence rows." \
        "dispatch reviewers via Agent(\"sdd-spec-reviewer: validate ACs against code\") and Agent(\"sdd-quality-reviewer: run tests and check quality\"), then integrate results; or accept self-review with: sdd autonomy --self-reviewed $FEATURE." \
        "closing a non-trivial autonomous feature from implementer self-review without an explicit override.")$MAINT_REMINDER"
      jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
      exit 0
    fi
    ;;
esac

# All other phases or conditions met — allow stop
exit 0
