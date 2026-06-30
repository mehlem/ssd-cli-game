#!/usr/bin/env bash
# sdd-review-adjudicate.sh — Assemble typed review evidence and merge adjudication into review.md
# Usage:
#   sdd-review-adjudicate.sh [--wp <wp-id>] <feature-id>

set -euo pipefail

FEATURE_ROOT=".features"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "review" "sdd review adjudicate [--wp <wp-id>] <feature-id>" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "review" \
      "Assemble review evidence and merge typed adjudication state into review.md." \
      "sdd review adjudicate [--wp <id>] <feature-id> [--feature <id|auto>] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd review adjudicate 0025-sdd-review-adjudication",
        "sdd review adjudicate --wp wp-01-api 0025-sdd-review-adjudication",
        "sdd review adjudicate --json --feature auto"
      ]'
    return 0
  fi

  echo "Usage: sdd review adjudicate [--wp <wp-id>] <feature-id>"
  echo ""
  echo "Assemble persisted verification evidence and typed reviewer results, then merge adjudication state into review.md."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

WP_ID=""
if [ "${#SDD_ARGS[@]}" -gt 0 ]; then
  set -- "${SDD_ARGS[@]}"
else
  set --
fi
if [ "${1:-}" = "--wp" ]; then
  WP_ID="${2:-}"
  [ -n "$WP_ID" ] || sdd_usage_error "review" "sdd review adjudicate [--wp <wp-id>] <feature-id>" "--wp requires a work package id"
  shift 2
fi

feature="${SDD_FEATURE_OVERRIDE:-${1:-}}"
sdd_resolve_feature_target "$feature" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
  case "$SDD_RESOLUTION_STATUS" in
    not_found)
      sdd_fail "review" "not_found" "feature '$feature' not found" "{\"feature\":\"$feature\"}" "$feature" "arg"
      ;;
    ambiguous)
      sdd_fail "review" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
      ;;
    none)
      sdd_fail "review" "not_found" "no active feature found" '{"feature":"auto"}' "" "none"
      ;;
  esac
}
feature="$SDD_RESOLVED_FEATURE"
FEATURE_DIR="$FEATURE_ROOT/$feature"
[ -d "$FEATURE_DIR" ] || sdd_fail "review" "not_found" "feature directory '$FEATURE_DIR' not found" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

review_path() {
  if [ -n "$WP_ID" ]; then
    printf '%s/%s/review.md\n' "$FEATURE_DIR" "$WP_ID"
  else
    printf '%s/review.md\n' "$FEATURE_DIR"
  fi
}

review_rel_path() {
  if [ -n "$WP_ID" ]; then
    printf '%s/%s/review.md\n' "$FEATURE_DIR" "$WP_ID"
  else
    printf '%s/review.md\n' "$FEATURE_DIR"
  fi
}

adjudication_dir() {
  if [ -n "$WP_ID" ]; then
    printf '%s/review-adjudication/%s\n' "$FEATURE_DIR" "$WP_ID"
  else
    printf '%s/review-adjudication\n' "$FEATURE_DIR"
  fi
}

adjudication_rel_dir() {
  if [ -n "$WP_ID" ]; then
    printf '%s/review-adjudication/%s\n' "$FEATURE_DIR" "$WP_ID"
  else
    printf '%s/review-adjudication\n' "$FEATURE_DIR"
  fi
}

normalize_work_package() {
  local wp="${1:-}"
  case "$wp" in
    ""|null|none)
      printf '\n'
      ;;
    *)
      printf '%s\n' "$wp"
      ;;
  esac
}

reviewer_result_matches_scope() {
  local dispatch_wp="$1" result_scope="$2"
  dispatch_wp="$(normalize_work_package "$dispatch_wp")"

  if [ -n "$WP_ID" ]; then
    if [ -n "$dispatch_wp" ] && [ "$dispatch_wp" != "$WP_ID" ]; then
      return 1
    fi
    case "$result_scope" in
      wp:*)
        [ "$result_scope" = "wp:$WP_ID" ] || return 1
        ;;
      feature:*)
        return 1
        ;;
      "")
        [ -n "$dispatch_wp" ] || return 1
        ;;
    esac
    return 0
  fi

  if [ -n "$dispatch_wp" ]; then
    return 1
  fi
  case "$result_scope" in
    wp:*)
      return 1
      ;;
    feature:*)
      [ "$result_scope" = "feature:$feature" ] || return 1
      ;;
  esac
  return 0
}

collect_verification_records_json() {
  local verification_dir="$FEATURE_DIR/verification"
  local lines="" file wp rel obj

  [ -d "$verification_dir" ] || { printf '[]\n'; return 0; }

  for file in "$verification_dir"/*.json; do
    [ -f "$file" ] || continue
    if [ -n "$WP_ID" ]; then
      wp="$(jq -r '.work_package // empty' "$file" 2>/dev/null)" || wp=""
      [ "$wp" = "$WP_ID" ] || continue
    fi
    rel="$(printf '%s/verification/%s\n' "$FEATURE_DIR" "$(basename "$file")")"
    obj="$(jq -c --arg path "$rel" '. + {path:$path}' "$file" 2>/dev/null || true)"
    [ -n "$obj" ] || continue
    lines="${lines}${obj}"$'\n'
  done

  if [ -z "$lines" ]; then
    printf '[]\n'
  else
    printf '%s' "$lines" | jq -s '.'
  fi
}

collect_reviewer_results_json() {
  local ledger_dir="$FEATURE_DIR/workers"
  local spec_json="" quality_json="" file role dispatch_id dispatch_path dispatch_rel dispatch_json obj
  local dispatch_wp result_scope support_only

  [ -d "$ledger_dir" ] || { printf '[]\n'; return 0; }

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    support_only="$(jq -r '.support_only // false' "$file" 2>/dev/null)" || support_only="false"
    [ "$support_only" = "true" ] && continue
    role="$(jq -r '.role // empty' "$file" 2>/dev/null)" || role=""
    case "$role" in
      spec-reviewer)
        [ -z "$spec_json" ] || continue
        ;;
      quality-reviewer)
        [ -z "$quality_json" ] || continue
        ;;
      *)
        continue
        ;;
    esac

    dispatch_id="$(jq -r '.dispatch_id // empty' "$file" 2>/dev/null)" || dispatch_id=""
    dispatch_path="$(sdd_dispatch_record_path "$feature" "$dispatch_id")"
    dispatch_rel="$dispatch_path"
    if [ -n "$dispatch_id" ] && [ -f "$dispatch_path" ]; then
      dispatch_json="$(cat "$dispatch_path")"
    else
      dispatch_json='null'
      dispatch_rel=""
    fi

    dispatch_wp="$(printf '%s\n' "$dispatch_json" | jq -r '.work_package // empty' 2>/dev/null)" || dispatch_wp=""
    result_scope="$(jq -r '.scope // empty' "$file" 2>/dev/null)" || result_scope=""
    reviewer_result_matches_scope "$dispatch_wp" "$result_scope" || continue

    obj="$(jq -nc \
      --arg path "$file" \
      --arg dispatch_path "$dispatch_rel" \
      --argjson result "$(cat "$file")" \
      --argjson dispatch "$dispatch_json" \
      '{
        path: $path,
        dispatch_path: (if $dispatch_path == "" then null else $dispatch_path end),
        result: $result,
        dispatch: $dispatch
      }')"

    case "$role" in
      spec-reviewer) spec_json="$obj" ;;
      quality-reviewer) quality_json="$obj" ;;
    esac
  done < <(LC_ALL=C ls -1t "$ledger_dir"/result-*.json 2>/dev/null || true)

  jq -nc \
    --argjson spec "${spec_json:-null}" \
    --argjson quality "${quality_json:-null}" \
    '[ $spec, $quality ] | map(select(. != null))'
}

collect_support_results_json() {
  local ledger_dir="$FEATURE_DIR/workers"
  local lines="" file role dispatch_id dispatch_path dispatch_rel dispatch_json obj
  local dispatch_wp result_scope provider support_only

  [ -d "$ledger_dir" ] || { printf '[]\n'; return 0; }

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    provider="$(jq -r '.provider // empty' "$file" 2>/dev/null)" || provider=""
    support_only="$(jq -r '.support_only // false' "$file" 2>/dev/null)" || support_only="false"
    [ "$provider" = "codex" ] || continue
    [ "$support_only" = "true" ] || continue

    role="$(jq -r '.role // empty' "$file" 2>/dev/null)" || role=""
    case "$role" in
      spec-reviewer|quality-reviewer) ;;
      *) continue ;;
    esac

    dispatch_id="$(jq -r '.dispatch_id // empty' "$file" 2>/dev/null)" || dispatch_id=""
    dispatch_path="$(sdd_dispatch_record_path "$feature" "$dispatch_id")"
    dispatch_rel="$dispatch_path"
    if [ -n "$dispatch_id" ] && [ -f "$dispatch_path" ]; then
      dispatch_json="$(cat "$dispatch_path")"
    else
      dispatch_json='null'
      dispatch_rel=""
    fi

    dispatch_wp="$(printf '%s\n' "$dispatch_json" | jq -r '.work_package // empty' 2>/dev/null)" || dispatch_wp=""
    result_scope="$(jq -r '.scope // empty' "$file" 2>/dev/null)" || result_scope=""
    reviewer_result_matches_scope "$dispatch_wp" "$result_scope" || continue

    obj="$(jq -nc \
      --arg path "$file" \
      --arg dispatch_path "$dispatch_rel" \
      --argjson result "$(cat "$file")" \
      --argjson dispatch "$dispatch_json" \
      '{
        path: $path,
        dispatch_path: (if $dispatch_path == "" then null else $dispatch_path end),
        result: $result,
        dispatch: $dispatch
      }')"
    lines="${lines}${obj}"$'\n'
  done < <(LC_ALL=C ls -1t "$ledger_dir"/result-*.json 2>/dev/null || true)

  if [ -z "$lines" ]; then
    printf '[]\n'
  else
    printf '%s' "$lines" | jq -s '.'
  fi
}

REVIEW_FILE="$(review_path)"
[ -f "$REVIEW_FILE" ] || sdd_fail "review" "precondition" "review.md not found. Run 'sdd review ${WP_ID:+--wp $WP_ID }$feature' before adjudicating." "{\"feature\":\"$feature\",\"review_path\":\"$REVIEW_FILE\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

VERIFICATION_JSON="$(collect_verification_records_json)"
REVIEWERS_JSON="$(collect_reviewer_results_json)"
SUPPORT_JSON="$(collect_support_results_json)"
ADJ_DIR="$(adjudication_dir)"
ADJ_REL_DIR="$(adjudication_rel_dir)"
INPUT_PATH="$ADJ_DIR/input.json"
INPUT_REL_PATH="$ADJ_REL_DIR/input.json"
GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

INPUT_JSON="$(jq -nc \
  --argjson schema_version 1 \
  --arg feature "$feature" \
  --arg work_package "$WP_ID" \
  --arg review_path "$REVIEW_FILE" \
  --arg generated_at "$GENERATED_AT" \
  --argjson verification_records "$VERIFICATION_JSON" \
  --argjson reviewer_results "$REVIEWERS_JSON" \
  --argjson support_results "$SUPPORT_JSON" \
  '{
    schema_version: $schema_version,
    feature: $feature,
    work_package: (if $work_package == "" then null else $work_package end),
    review_path: $review_path,
    generated_at: $generated_at,
    required_roles: ["spec-reviewer", "quality-reviewer"],
    verification_records: $verification_records,
    reviewer_results: $reviewer_results,
    support_results: $support_results
  }')"

sdd_write_file_atomic "$INPUT_PATH" "$INPUT_JSON"

MERGE_ARGS=()
[ "$SDD_HELP" = "1" ] && MERGE_ARGS+=("--help")
case "$SDD_OUTPUT_FORMAT" in
  json) MERGE_ARGS+=("--json") ;;
  text) ;;
esac
[ -n "$SDD_FEATURE_OVERRIDE" ] && MERGE_ARGS+=("--feature" "$SDD_FEATURE_OVERRIDE")
[ "$SDD_NON_INTERACTIVE" = "1" ] && MERGE_ARGS+=("--non-interactive")
[ -n "$SDD_ON_EXISTS" ] && MERGE_ARGS+=("--on-exists" "$SDD_ON_EXISTS")
[ -n "$SDD_FIELD" ] && MERGE_ARGS+=("--field" "$SDD_FIELD")
[ -n "$SDD_JQ_EXPR" ] && MERGE_ARGS+=("--jq" "$SDD_JQ_EXPR")
[ -n "$WP_ID" ] && MERGE_ARGS+=("--wp" "$WP_ID")
MERGE_ARGS+=("$feature")

bash "$SCRIPT_DIR/sdd-review-merge.sh" "${MERGE_ARGS[@]}" >/dev/null

CURRENT_PATH="$ADJ_DIR/current.json"
CURRENT_REL_PATH="$ADJ_REL_DIR/current.json"
if [ -f "$CURRENT_PATH" ]; then
  CURRENT_JSON="$(cat "$CURRENT_PATH")"
  EVIDENCE_STATUS="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.evidence_status // "insufficient"' 2>/dev/null)" || EVIDENCE_STATUS="insufficient"
  OVERALL_VERDICT="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.overall_verdict // "pending"' 2>/dev/null)" || OVERALL_VERDICT="pending"
  REVIEWER_COUNT="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.reviewer_count // 0' 2>/dev/null)" || REVIEWER_COUNT=0
  SUPPORT_COUNT="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.support_count // 0' 2>/dev/null)" || SUPPORT_COUNT=0
  VERIFICATION_COUNT="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.verification_count // 0' 2>/dev/null)" || VERIFICATION_COUNT=0
else
  EVIDENCE_STATUS="insufficient"
  OVERALL_VERDICT="pending"
  REVIEWER_COUNT=0
  SUPPORT_COUNT=0
  VERIFICATION_COUNT=0
fi

if sdd_is_json_mode; then
  DATA_JSON="$(jq -nc \
    --arg input_path "$INPUT_REL_PATH" \
    --arg current_path "$CURRENT_REL_PATH" \
    --arg review_path "$(review_rel_path)" \
    --arg evidence_status "$EVIDENCE_STATUS" \
    --arg overall_verdict "$OVERALL_VERDICT" \
    --argjson reviewer_count "$REVIEWER_COUNT" \
    --argjson support_count "$SUPPORT_COUNT" \
    --argjson verification_count "$VERIFICATION_COUNT" \
    '{
      input_path: $input_path,
      current_path: $current_path,
      review_path: $review_path,
      evidence_status: $evidence_status,
      overall_verdict: $overall_verdict,
      reviewer_count: $reviewer_count,
      support_count: $support_count,
      verification_count: $verification_count
    }')"
  GUIDANCE_JSON="$(sdd_json_guidance "re-run adjudication after new reviewer results land, or proceed to status/summary if the evidence is already sufficient." "adjudication is merge-driven: review.md remains canonical, and sidecars are the audit trail." "if evidence is still insufficient, stop/close should stay blocked once adjudication fields exist.")"
  sdd_emit_json_selection "$(sdd_json_success "review" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "review" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
  cat >&2 <<EOF
Adjudication refreshed: $(review_rel_path)
Evidence bundle: $INPUT_REL_PATH
Adjudication state: $CURRENT_REL_PATH
Status: evidence=$EVIDENCE_STATUS | verdict=$OVERALL_VERDICT | verification=$VERIFICATION_COUNT | reviewers=$REVIEWER_COUNT | support=$SUPPORT_COUNT
Next: re-run adjudication after new reviewer results land, or proceed with status/summary if the evidence is already sufficient.
Gate: adjudication is merge-driven: review.md remains canonical, and sidecars are the audit trail.
Pitfall: if evidence is still insufficient, stop/close should stay blocked once adjudication fields exist.
EOF
  exit 0
fi

cat <<EOF
Adjudication refreshed: $(review_rel_path)
Evidence bundle: $INPUT_REL_PATH
Adjudication state: $CURRENT_REL_PATH
Status: evidence=$EVIDENCE_STATUS | verdict=$OVERALL_VERDICT | verification=$VERIFICATION_COUNT | reviewers=$REVIEWER_COUNT | support=$SUPPORT_COUNT
Next: re-run adjudication after new reviewer results land, or proceed with status/summary if the evidence is already sufficient.
Gate: adjudication is merge-driven: review.md remains canonical, and sidecars are the audit trail.
Pitfall: if evidence is still insufficient, stop/close should stay blocked once adjudication fields exist.
EOF
