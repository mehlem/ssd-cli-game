#!/usr/bin/env bash
set -euo pipefail
command -v jq >/dev/null 2>&1 || exit 0
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"
source "$SCRIPT_DIR/sdd-lib.sh"

INPUT="$(cat)"
AGENT_ID="$(printf '%s' "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null)" || AGENT_ID=""
AGENT_TYPE="$(printf '%s' "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null)" || AGENT_TYPE=""
TRANSCRIPT_PATH="$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // empty' 2>/dev/null)" || TRANSCRIPT_PATH=""
STOP_ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" || STOP_ACTIVE="false"
LAST_MESSAGE="$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)" || LAST_MESSAGE=""

ROLE="$(sdd_normalize_agent_role "$AGENT_TYPE")"
case "$ROLE" in
  implementer|spec-reviewer|quality-reviewer|research-scout|plan-drafter) ;;
  *) exit 0 ;;
esac

sdd_has_active_feature || exit 0

# --- Bounded retry counter (AD-002 / FR-008) ---
# Key: stop_attempt_<AGENT_ID>. Max 3 total attempts before relaxing to Tier 1 only.
ATTEMPT_KEY="stop_attempt_${AGENT_ID}"
CURRENT_FLAGS="$(sdd_read_session_flags)"
ATTEMPT="$(printf '%s' "$CURRENT_FLAGS" | jq -r --arg k "$ATTEMPT_KEY" '.[$k] // 0' 2>/dev/null)" || ATTEMPT=0
ATTEMPT=$((ATTEMPT + 1))
sdd_set_session_flag "$ATTEMPT_KEY" "$ATTEMPT" || true
DEGRADED_MODE=false
if [ "$ATTEMPT" -ge 3 ]; then
  DEGRADED_MODE=true
fi

# --- Markdown structure validation ---
check_pattern() {
  local pattern="$1"
  printf '%s\n' "$LAST_MESSAGE" | grep -Eiq "$pattern"
}

MISSING=""
append_missing() {
  if [ -n "$MISSING" ]; then
    MISSING="$MISSING, $1"
  else
    MISSING="$1"
  fi
}

check_pattern '^[[:space:]]*#{1,6}[[:space:]]*Worker[[:space:]]+Result[[:space:]]*$' || append_missing "Worker Result heading"
check_pattern '^[[:space:]]*#{1,6}[[:space:]]*Machine[[:space:]]+Result[[:space:]]+Record[[:space:]]*$' || append_missing "Machine Result Record section"
check_pattern '^```json[[:space:]]*$' || append_missing "Machine Result Record JSON block"

case "$ROLE" in
  implementer)
    check_pattern '\*{0,2}Status\*{0,2}:[[:space:]]*(DONE|DONE_WITH_CONCERNS|BLOCKED|NEEDS_CONTEXT)\b' || append_missing "Status field"
    check_pattern '^[[:space:]]*#{1,6}[[:space:]]*Files[[:space:]]+Changed[[:space:]]*$' || append_missing "Files Changed section"
    check_pattern '^[[:space:]]*#{1,6}[[:space:]]*Verification[[:space:]]*$' || append_missing "Verification section"
    ;;
  spec-reviewer|quality-reviewer)
    check_pattern '\*{0,2}Status\*{0,2}:[[:space:]]*(PASS|FAIL|NEEDS_CONTEXT)\b' || append_missing "Status field"
    check_pattern '^[[:space:]]*#{1,6}[[:space:]]*Findings[[:space:]]*$' || append_missing "Findings section"
    ;;
  research-scout)
    check_pattern '\*{0,2}Status\*{0,2}:[[:space:]]*(DONE|DONE_WITH_CONCERNS|BLOCKED|NEEDS_CONTEXT)\b' || append_missing "Status field"
    check_pattern '^[[:space:]]*#{1,6}[[:space:]]*Findings[[:space:]]*$' || append_missing "Findings section"
    check_pattern '^[[:space:]]*#{1,6}[[:space:]]*Confidence[[:space:]]+Score[[:space:]]*$' || append_missing "Confidence Score section"
    check_pattern '^[[:space:]]*#{1,6}[[:space:]]*Files[[:space:]]+Discovered[[:space:]]*$' || append_missing "Files Discovered section"
    ;;
  plan-drafter)
    check_pattern '\*{0,2}Status\*{0,2}:[[:space:]]*(DONE|DONE_WITH_CONCERNS|BLOCKED|NEEDS_CONTEXT)\b' || append_missing "Status field"
    check_pattern '^[[:space:]]*#{1,6}[[:space:]]*Proposed[[:space:]]+Architectural[[:space:]]+Decisions[[:space:]]*$' || append_missing "Proposed Architectural Decisions section"
    check_pattern '^[[:space:]]*#{1,6}[[:space:]]*Proposed[[:space:]]+Tasks[[:space:]]*$' || append_missing "Proposed Tasks section"
    ;;
esac

if [ -n "$MISSING" ]; then
  REASON="Missing structured result: $MISSING. Return the worker result using references/worker-results.md."
  jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
  exit 0
fi

# --- Extract and validate raw JSON ---
RESULT_JSON="$(printf '%s\n' "$LAST_MESSAGE" | sdd_extract_machine_result_record)"
if [ -z "$RESULT_JSON" ]; then
  REASON="Missing structured result: Machine Result Record JSON block. Return the worker result using references/worker-results.md."
  jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
  exit 0
fi

if ! printf '%s\n' "$RESULT_JSON" | jq -e . >/dev/null 2>&1; then
  REASON="Machine Result Record must contain valid JSON. Repair the dedicated json block under ## Machine Result Record."
  jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
  exit 0
fi

# --- Tier 1: blocking identity/correlation checks (AD-001 / FR-009) ---
TIER1_ERRORS="$(
  printf '%s\n' "$RESULT_JSON" | jq -r --arg role "$ROLE" --arg dispatch_id "$AGENT_ID" '
    [
      (if (.schema_version // "") != "sdd-result-v1" then "schema_version must be sdd-result-v1" else empty end),
      (if ($dispatch_id != "" and (.dispatch_id // "") != $dispatch_id) then "dispatch_id must match hook agent_id " + $dispatch_id else empty end),
      (if (.role // "") != $role then "role must be " + $role else empty end),
      (if (.status // "") == "" then "status is required" else empty end),
      (if ($role == "implementer" or $role == "research-scout" or $role == "plan-drafter") and ((.status // "") | test("^(DONE|DONE_WITH_CONCERNS|BLOCKED|NEEDS_CONTEXT)$") | not) then "status must be one of DONE, DONE_WITH_CONCERNS, BLOCKED, NEEDS_CONTEXT" else empty end),
      (if ($role == "spec-reviewer" or $role == "quality-reviewer") and ((.status // "") != "" and ((.status // "") | test("^(PASS|FAIL|NEEDS_CONTEXT)$") | not)) then "status must be one of PASS, FAIL, NEEDS_CONTEXT" else empty end)
    ] | join("; ")
  ' 2>/dev/null
)"

if [ -n "$TIER1_ERRORS" ]; then
  EXAMPLE="$(sdd_build_repair_example "$ROLE" "$AGENT_ID" "")"
  REASON="Fix all identity errors: $TIER1_ERRORS. Expected shape: $EXAMPLE"
  jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
  exit 0
fi

# --- Normalize before Tier 2 (AD-003 / FR-010) ---
NORMALIZED_JSON="$(sdd_normalize_result_deviations "$RESULT_JSON")"
NORM_WARNINGS="$(printf '%s\n' "$NORMALIZED_JSON" | jq -r '._normalization_warnings // [] | join("; ")' 2>/dev/null)" || NORM_WARNINGS=""
NORMALIZED_JSON="$(printf '%s\n' "$NORMALIZED_JSON" | jq 'del(._normalization_warnings)' 2>/dev/null)" || NORMALIZED_JSON="$RESULT_JSON"

# --- Tier 2: non-blocking structural checks (AD-001, AD-005 / FR-009, FR-011) ---
# In degraded mode (attempt >= 3), skip Tier 2 and persist whatever passed Tier 1.
TIER2_ERRORS=""
if [ "$DEGRADED_MODE" = "false" ]; then
  TIER2_ERRORS="$(
    printf '%s\n' "$NORMALIZED_JSON" | jq -r --arg role "$ROLE" '
      [
        (if $role == "implementer" and ((.task | type) != "object" or (.task.id // "") == "") then "task must be an object with id field" else empty end),
        (if $role == "implementer" and ((.files_changed | type) != "array") then "files_changed must be an array" else empty end),
        (if $role == "implementer" and ((.verification | type) != "object") then "verification must be an object" else empty end),
        (if ($role == "spec-reviewer" or $role == "quality-reviewer") and (.scope // "") == "" then "scope is required for reviewer results" else empty end),
        (if ($role == "spec-reviewer" or $role == "quality-reviewer") and ((.findings | type) != "array") then "findings must be an array" else empty end),
        (if ($role == "spec-reviewer" or $role == "quality-reviewer") and (.verdict // "") == "" then "verdict is required for reviewer results" else empty end),
        (if $role == "research-scout" and (.scope // "") == "" then "scope is required for research-scout results" else empty end),
        (if $role == "research-scout" and ((.findings | type) != "array") then "findings must be an array for research-scout results" else empty end),
        (if $role == "research-scout" and ((.confidence | type) != "object") then "confidence must be an object for research-scout results" else empty end),
        (if $role == "research-scout" and ((.files_discovered | type) != "array") then "files_discovered must be an array for research-scout results" else empty end),
        (if $role == "plan-drafter" and (.scope // "") == "" then "scope is required for plan-drafter results" else empty end),
        (if $role == "plan-drafter" and ((.proposed_decisions | type) != "array") then "proposed_decisions must be an array for plan-drafter results" else empty end),
        (if $role == "plan-drafter" and ((.proposed_tasks | type) != "array") then "proposed_tasks must be an array for plan-drafter results" else empty end)
      ] | join("; ")
    ' 2>/dev/null
  )"
fi

if [ -n "$TIER2_ERRORS" ]; then
  EXAMPLE="$(sdd_build_repair_example "$ROLE" "$AGENT_ID" "$(printf '%s\n' "$NORMALIZED_JSON" | jq -r '.task.id // ""' 2>/dev/null)")"
  REASON="Fix all structural errors: $TIER2_ERRORS. Expected shape: $EXAMPLE"
  jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
  exit 0
fi

# --- Resolve dispatch_id and feature ---
DISPATCH_ID="$AGENT_ID"
if [ -z "$DISPATCH_ID" ]; then
  DISPATCH_ID="$(printf '%s\n' "$NORMALIZED_JSON" | jq -r '.dispatch_id // empty' 2>/dev/null)" || DISPATCH_ID=""
fi

if [ -z "$DISPATCH_ID" ]; then
  REASON="Machine Result Record must include dispatch_id, and the hook input did not provide agent_id for correlation."
  jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
  exit 0
fi

RECOVERED_DISPATCH=false
DISPATCH_PATH="$(sdd_find_dispatch_record_path "$DISPATCH_ID" || true)"
if [ -z "$DISPATCH_PATH" ] || [ ! -f "$DISPATCH_PATH" ]; then
  case "$ROLE" in
    spec-reviewer|quality-reviewer)
      if [ -z "$AGENT_ID" ] || [ "$DISPATCH_ID" != "$AGENT_ID" ]; then
        REASON="No dispatch ledger entry was found for dispatch_id $DISPATCH_ID, and reviewer recovery requires dispatch_id to match hook agent_id."
        jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
        exit 0
      fi

      DETECTED_CONTEXT="$(sdd_detect_feature_phase 2>/dev/null || true)"
      IFS='|' read -r FEATURE PHASE <<< "$DETECTED_CONTEXT"
      if [ -z "$FEATURE" ] || [ "$FEATURE" = "none" ] || [ ! -d "$SDD_FEATURE_ROOT/$FEATURE" ]; then
        REASON="No dispatch ledger entry was found for dispatch_id $DISPATCH_ID, and reviewer recovery could not detect an active feature."
        jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
        exit 0
      fi

      RESULT_FEATURE="$(printf '%s\n' "$NORMALIZED_JSON" | jq -r '.feature // empty' 2>/dev/null)" || RESULT_FEATURE=""
      if [ -n "$RESULT_FEATURE" ] && [ "$RESULT_FEATURE" != "$FEATURE" ]; then
        REASON="No dispatch ledger entry was found for dispatch_id $DISPATCH_ID, and reviewer recovery refused feature mismatch: result feature $RESULT_FEATURE, active feature $FEATURE."
        jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
        exit 0
      fi

      PHASE="${PHASE:-review}"
      DISPATCH_PATH="$(sdd_dispatch_record_path "$FEATURE" "$DISPATCH_ID")"
      DISPATCH_JSON="$(jq -nc \
        --arg dispatch_id "$DISPATCH_ID" \
        --arg role "$ROLE" \
        --arg feature "$FEATURE" \
        --arg phase "$PHASE" \
        '{
          schema_version: "sdd-dispatch-v1",
          dispatch_id: $dispatch_id,
          dispatch_epoch: 0,
          role: $role,
          feature: $feature,
          phase: $phase,
          task: null,
          work_package: "none",
          objective: "Recovered foreground reviewer result from SubagentStop because no SubagentStart dispatch sidecar was present.",
          requirements: {fr: [], ac: []},
          files_in_scope: [],
          verification: null,
          authority: "RECOVERED: This dispatch record was synthesized by SubagentStop after a foreground reviewer returned a valid result without a start-created dispatch sidecar.",
          recovered_dispatch: true,
          recovery_source: "SubagentStop"
        }')"
      if ! sdd_write_file_atomic "$DISPATCH_PATH" "$DISPATCH_JSON"; then
        REASON="No dispatch ledger entry was found for dispatch_id $DISPATCH_ID, and reviewer recovery could not write $DISPATCH_PATH."
        jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
        exit 0
      fi
      RECOVERED_DISPATCH=true
      ;;
    *)
      REASON="No dispatch ledger entry was found for dispatch_id $DISPATCH_ID. Re-run the worker from a valid SDD dispatch packet before stopping."
      jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
      exit 0
      ;;
  esac
fi

FEATURE="$(sdd_feature_from_worker_record_path "$DISPATCH_PATH")"
if [ -z "$FEATURE" ] || [ ! -d "$SDD_FEATURE_ROOT/$FEATURE" ]; then
  REASON="Dispatch ledger entry $DISPATCH_PATH does not resolve to a valid feature directory."
  jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
  exit 0
fi
PHASE="$(sdd_feature_phase "$FEATURE")"
PHASE="${PHASE:-implement}"

# --- Build final result JSON with optional warnings ---
FINAL_JSON="$NORMALIZED_JSON"
PERSISTENCE_WARNINGS=()
if [ -n "$NORM_WARNINGS" ]; then
  PERSISTENCE_WARNINGS+=("normalization: $NORM_WARNINGS")
fi
if [ "$DEGRADED_MODE" = "true" ]; then
  PERSISTENCE_WARNINGS+=("degraded: persisted after $ATTEMPT attempts with Tier 1 checks only")
fi
if [ "$RECOVERED_DISPATCH" = "true" ]; then
  PERSISTENCE_WARNINGS+=("recovered_dispatch: dispatch sidecar synthesized by SubagentStop")
  FINAL_JSON="$(printf '%s\n' "$FINAL_JSON" | jq -c '. + {recovered_dispatch: true}' 2>/dev/null)" || FINAL_JSON="$NORMALIZED_JSON"
fi

if [ "${#PERSISTENCE_WARNINGS[@]}" -gt 0 ]; then
  WARNINGS_JSON="$(printf '%s\n' "${PERSISTENCE_WARNINGS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')"
  FINAL_JSON="$(printf '%s\n' "$FINAL_JSON" | jq -c --argjson w "$WARNINGS_JSON" '. + {warnings: $w}' 2>/dev/null)" || FINAL_JSON="$NORMALIZED_JSON"
fi

# --- Persist result and set session flag ---
RESULT_PATH="$(sdd_result_record_path "$FEATURE" "$DISPATCH_ID")"
sdd_write_file_atomic "$RESULT_PATH" "$FINAL_JSON" || exit 0

# Clear the retry counter on successful persistence
sdd_set_session_flag "$ATTEMPT_KEY" 0 || true

RESULT_STATUS="$(printf '%s\n' "$FINAL_JSON" | jq -r '.status // empty' 2>/dev/null)" || RESULT_STATUS=""

# Auto-complete the task in tasks.md for DONE results (closes the loop for background agents)
if [ "$ROLE" = "implementer" ] && { [ "$RESULT_STATUS" = "DONE" ] || [ "$RESULT_STATUS" = "DONE_WITH_CONCERNS" ]; }; then
  TASK_ID="$(printf '%s\n' "$FINAL_JSON" | jq -r '.task.id // empty' 2>/dev/null)" || TASK_ID=""
  if [ -n "$TASK_ID" ]; then
    bash "$SCRIPT_DIR/sdd.sh" task complete "$FEATURE" "$TASK_ID" >/dev/null 2>&1 || true
  fi
fi
HAS_WARNINGS=false
if [ "${#PERSISTENCE_WARNINGS[@]}" -gt 0 ]; then
  HAS_WARNINGS=true
fi

PENDING_JSON="$(jq -nc \
  --arg feature "$FEATURE" \
  --arg phase "$PHASE" \
  --arg role "$ROLE" \
  --arg dispatch_id "$DISPATCH_ID" \
  --arg status "$RESULT_STATUS" \
  --arg result_path "$RESULT_PATH" \
  --arg transcript_path "$TRANSCRIPT_PATH" \
  --argjson has_warnings "$HAS_WARNINGS" \
  '{
    feature: $feature,
    phase: $phase,
    role: $role,
    dispatch_id: $dispatch_id,
    status: $status,
    result_path: $result_path,
    transcript_path: (if $transcript_path == "" then null else $transcript_path end),
    has_warnings: $has_warnings
  }')"
sdd_set_session_flag "subagent_result_pending" "$PENDING_JSON" || true
exit 0
