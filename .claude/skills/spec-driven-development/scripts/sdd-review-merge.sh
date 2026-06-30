#!/usr/bin/env bash
# sdd-review-merge.sh — Deterministically merge adjudication state into review.md
# Usage:
#   sdd-review-merge.sh [--wp <wp-id>] <feature-id>

set -euo pipefail

FEATURE_ROOT=".features"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "review" "sdd review merge [--wp <wp-id>] <feature-id>" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "review" \
      "Merge review-adjudication sidecars into review.md." \
      "sdd review merge [--wp <id>] <feature-id> [--feature <id|auto>] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd review merge 0025-sdd-review-adjudication",
        "sdd review merge --wp wp-01-api 0025-sdd-review-adjudication"
      ]'
    return 0
  fi

  echo "Usage: sdd review merge [--wp <wp-id>] <feature-id>"
  echo ""
  echo "Merge assembled typed adjudication state into review.md."
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
  [ -n "$WP_ID" ] || sdd_usage_error "review" "sdd review merge [--wp <wp-id>] <feature-id>" "--wp requires a work package id"
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

adjudication_dir() {
  if [ -n "$WP_ID" ]; then
    printf '%s/review-adjudication/%s\n' "$FEATURE_DIR" "$WP_ID"
  else
    printf '%s/review-adjudication\n' "$FEATURE_DIR"
  fi
}

upsert_frontmatter_value() {
  local file="$1" key="$2" value="$3"
  local tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { started = 0; in_frontmatter = 0; inserted = 0 }
    $0 == "---" {
      if (!started) {
        started = 1
        in_frontmatter = 1
        print
        next
      }
      if (in_frontmatter) {
        if (!inserted) print key ": " value
        in_frontmatter = 0
        print
        next
      }
    }
    in_frontmatter && index($0, key ":") == 1 {
      print key ": " value
      inserted = 1
      next
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

md_cell() {
  printf '%s' "$1" | tr '\n' ' ' | sed 's/|/\\|/g'
}

replace_adjudication_block() {
  local review_file="$1" content_file="$2"
  local tmp
  tmp="$(mktemp)"

  if grep -q '^<!-- SDD-ADJUDICATION:START -->$' "$review_file"; then
    awk -v content="$content_file" '
      $0 == "<!-- SDD-ADJUDICATION:START -->" {
        print
        while ((getline line < content) > 0) print line
        in_block = 1
        next
      }
      $0 == "<!-- SDD-ADJUDICATION:END -->" {
        in_block = 0
        print
        next
      }
      in_block { next }
      { print }
    ' "$review_file" > "$tmp"
  else
    awk -v content="$content_file" '
      BEGIN { inserted = 0 }
      /^## Scope Conformance/ && !inserted {
        print "## Adjudication"
        print ""
        print "<!-- SDD-ADJUDICATION:START -->"
        while ((getline line < content) > 0) print line
        print "<!-- SDD-ADJUDICATION:END -->"
        print ""
        inserted = 1
      }
      { print }
      END {
        if (!inserted) {
          print ""
          print "## Adjudication"
          print ""
          print "<!-- SDD-ADJUDICATION:START -->"
          while ((getline line < content) > 0) print line
          print "<!-- SDD-ADJUDICATION:END -->"
        }
      }
    ' "$review_file" > "$tmp"
  fi

  mv "$tmp" "$review_file"
}

INPUT_PATH="$(adjudication_dir)/input.json"
CURRENT_PATH="$(adjudication_dir)/current.json"
REVIEW_FILE="$(review_path)"
[ -f "$INPUT_PATH" ] || sdd_fail "review" "precondition" "adjudication input not found at $INPUT_PATH" "{\"feature\":\"$feature\",\"input_path\":\"$INPUT_PATH\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
[ -f "$REVIEW_FILE" ] || sdd_fail "review" "precondition" "review.md not found at $REVIEW_FILE" "{\"feature\":\"$feature\",\"review_path\":\"$REVIEW_FILE\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

CURRENT_JSON="$(jq -nc \
  --arg input_path "$INPUT_PATH" \
  --arg current_path "$CURRENT_PATH" \
  --slurpfile input "$INPUT_PATH" '
  ($input[0]) as $in
  | ($in.reviewer_results | map({
      role: (.result.role // "unknown"),
      status: (.result.status // "unknown"),
      verdict: (.result.verdict // .result.status // "unknown"),
      dispatch_id: (.result.dispatch_id // ""),
      path: .path,
      summary: (.result.summary // ""),
      requirements_checked: (.result.requirements_checked // []),
      findings: (.result.findings // []),
      verified_clean: (.result.verified_clean // [])
    })) as $reviewers
  | (($in.support_results // []) | map({
      provider: (.result.provider // "unknown"),
      role: (.result.role // "unknown"),
      status: (.result.status // "unknown"),
      verdict: (.result.verdict // .result.status // "unknown"),
      dispatch_id: (.result.dispatch_id // ""),
      path: .path,
      summary: (.result.summary // ""),
      support_category: (.result.support_category // "support")
    })) as $support
  | ($reviewers | map(.role)) as $available_roles
  | ($in.required_roles - $available_roles) as $missing_roles
  | ($in.verification_records | length) as $verification_count
  | ($reviewers | length) as $reviewer_count
  | ($support | length) as $support_count
  | (if $verification_count > 0 and ($missing_roles | length) == 0 then "sufficient" else "insufficient" end) as $evidence_status
  | (if $evidence_status != "sufficient" then "pending"
     elif ($reviewers | map(select(.status == "FAIL" or .verdict == "FAIL")) | length) > 0 then "fail"
     elif ($reviewers | map(select(.status == "NEEDS_CONTEXT" or .verdict == "NEEDS_CONTEXT")) | length) > 0 then "pending"
     else "pass"
     end) as $overall_verdict
  | {
      schema_version: 1,
      feature: $in.feature,
      work_package: $in.work_package,
      review_path: $in.review_path,
      input_path: $input_path,
      current_path: $current_path,
      adjudicated_at: (now | todateiso8601),
      verdict_source: "adjudicated",
      evidence_status: $evidence_status,
      overall_verdict: $overall_verdict,
      required_roles: $in.required_roles,
      missing_roles: $missing_roles,
      verification_count: $verification_count,
      reviewer_count: $reviewer_count,
      support_count: $support_count,
      verification_records: $in.verification_records,
      reviewer_results: $reviewers,
      support_results: $support
    }')"

sdd_write_file_atomic "$CURRENT_PATH" "$CURRENT_JSON"

VERDICT="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.overall_verdict')"
EVIDENCE_STATUS="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.evidence_status')"
ADJUDICATED_AT="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.adjudicated_at')"
VERIFICATION_COUNT="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.verification_count')"
REVIEWER_COUNT="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.reviewer_count')"
SUPPORT_COUNT="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.support_count // 0')"
MISSING_ROLES="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.missing_roles | join(", ")')"

upsert_frontmatter_value "$REVIEW_FILE" "verdict" "$VERDICT"
upsert_frontmatter_value "$REVIEW_FILE" "verdict_source" "adjudicated"
upsert_frontmatter_value "$REVIEW_FILE" "evidence_status" "$EVIDENCE_STATUS"
upsert_frontmatter_value "$REVIEW_FILE" "adjudicated_at" "$ADJUDICATED_AT"

SECTION_FILE="$(mktemp)"
{
  echo "> AUTO-MERGED — DO NOT EDIT BY HAND"
  echo "> Refresh via: sdd review adjudicate ${WP_ID:+--wp $WP_ID }$feature"
  echo ""
  echo "| Signal | Value | Notes |"
  echo "|:-------|:------|:------|"
  printf '| Verdict Source | %s | typed reviewer results + persisted verification sidecars |\n' "$(md_cell "adjudicated")"
  printf '| Evidence Status | %s | %s verification record(s), %s reviewer result(s)%s |\n' \
    "$(md_cell "$EVIDENCE_STATUS")" \
    "$(md_cell "$VERIFICATION_COUNT")" \
    "$(md_cell "$REVIEWER_COUNT")" \
    "$( [ -n "$MISSING_ROLES" ] && printf '; missing roles: %s' "$(md_cell "$MISSING_ROLES")" )"
  printf '| Support Evidence | %s | provider-tagged support result(s); not counted as required reviewer roles |\n' "$(md_cell "$SUPPORT_COUNT")"
  printf '| Adjudicated At | %s | — |\n' "$(md_cell "$ADJUDICATED_AT")"
  printf '| Review Verdict | %s | canonical frontmatter updated by merge |\n' "$(md_cell "$VERDICT")"
  echo ""
  echo "### Reviewer Status"
  echo "| Role | Status | Verdict | Dispatch | Summary |"
  echo "|:-----|:-------|:--------|:---------|:--------|"
  REVIEWER_ROWS="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.reviewer_results[]? | [(.role // "—"), (.status // "—"), (.verdict // "—"), (.dispatch_id // "—"), (.summary // "—")] | @tsv')"
  if [ -n "$REVIEWER_ROWS" ]; then
    while IFS=$'\t' read -r role status verdict dispatch_id summary; do
      printf '| %s | %s | %s | %s | %s |\n' "$(md_cell "$role")" "$(md_cell "$status")" "$(md_cell "$verdict")" "$(md_cell "$dispatch_id")" "$(md_cell "$summary")"
    done <<< "$REVIEWER_ROWS"
  else
    echo "| (none) | — | — | — | No typed reviewer results available yet. |"
  fi
  echo ""
  echo "### Support Evidence"
  echo "| Provider | Role | Status | Dispatch | Category | Summary |"
  echo "|:---------|:-----|:-------|:---------|:---------|:--------|"
  SUPPORT_ROWS="$(printf '%s\n' "$CURRENT_JSON" | jq -r '.support_results[]? | [(.provider // "—"), (.role // "—"), (.status // "—"), (.dispatch_id // "—"), (.support_category // "support"), (.summary // "—")] | @tsv')"
  if [ -n "$SUPPORT_ROWS" ]; then
    while IFS=$'\t' read -r provider role status dispatch_id category summary; do
      printf '| %s | %s | %s | %s | %s | %s |\n' "$(md_cell "$provider")" "$(md_cell "$role")" "$(md_cell "$status")" "$(md_cell "$dispatch_id")" "$(md_cell "$category")" "$(md_cell "$summary")"
    done <<< "$SUPPORT_ROWS"
  else
    echo "| (none) | — | — | — | — | No provider support results available yet. |"
  fi
  echo ""
  echo "### Requirement Results"
  echo "| Reviewer | Requirement | Status | Evidence | Notes |"
  echo "|:---------|:------------|:-------|:---------|:------|"
  REQUIREMENT_ROWS="$(printf '%s\n' "$CURRENT_JSON" | jq -r '
    .reviewer_results[]
    | .role as $role
    | (.requirements_checked // [])[]
    | [ $role, (.id // .requirement // "—"), (.status // "—"), (.evidence // "—"), (.notes // "—") ]
    | @tsv
  ')"
  if [ -n "$REQUIREMENT_ROWS" ]; then
    while IFS=$'\t' read -r role req_id req_status evidence notes; do
      printf '| %s | %s | %s | %s | %s |\n' "$(md_cell "$role")" "$(md_cell "$req_id")" "$(md_cell "$req_status")" "$(md_cell "$evidence")" "$(md_cell "$notes")"
    done <<< "$REQUIREMENT_ROWS"
  else
    echo "| (none) | — | — | Reviewer machine results did not include requirement-level adjudication rows. | — |"
  fi
  echo ""
  echo "### Findings"
  echo "| Reviewer | Severity | Category | Location | Description | Evidence | Suggestion |"
  echo "|:---------|:---------|:---------|:---------|:------------|:---------|:-----------|"
  FINDING_ROWS="$(printf '%s\n' "$CURRENT_JSON" | jq -r '
    .reviewer_results[]
    | .role as $role
    | (.findings // [])[]
    | [
        $role,
        (.severity // "—"),
        (.category // "—"),
        (.location // "—"),
        (.description // "—"),
        (.evidence // "—"),
        (.suggestion // "—")
      ]
    | @tsv
  ')"
  if [ -n "$FINDING_ROWS" ]; then
    while IFS=$'\t' read -r role severity category location description evidence suggestion; do
      printf '| %s | %s | %s | %s | %s | %s | %s |\n' \
        "$(md_cell "$role")" \
        "$(md_cell "$severity")" \
        "$(md_cell "$category")" \
        "$(md_cell "$location")" \
        "$(md_cell "$description")" \
        "$(md_cell "$evidence")" \
        "$(md_cell "$suggestion")"
    done <<< "$FINDING_ROWS"
  else
    echo "| (none) | — | — | — | No reviewer findings were present. | — | — |"
  fi
  echo ""
  echo "### Verification Evidence"
  echo "| Task | Result | Exit | Captured At | Record |"
  echo "|:-----|:-------|:-----|:------------|:-------|"
  VERIFICATION_ROWS="$(printf '%s\n' "$CURRENT_JSON" | jq -r '
    .verification_records[]?
    | [
        (.task.id // "—"),
        (.verification.result // "—"),
        ((.verification.exit_code // "—") | tostring),
        (.captured_at // "—"),
        (.path // "—")
      ]
    | @tsv
  ')"
  if [ -n "$VERIFICATION_ROWS" ]; then
    while IFS=$'\t' read -r task_id result exit_code captured_at record_path; do
      printf '| %s | %s | %s | %s | %s |\n' "$(md_cell "$task_id")" "$(md_cell "$result")" "$(md_cell "$exit_code")" "$(md_cell "$captured_at")" "$(md_cell "$record_path")"
    done <<< "$VERIFICATION_ROWS"
  else
    echo "| (none) | — | — | — | No persisted verification records were found. |"
  fi
  echo ""
  echo "### Verified Clean"
  echo "| Reviewer | Area | Method | Result |"
  echo "|:---------|:-----|:-------|:-------|"
  CLEAN_ROWS="$(printf '%s\n' "$CURRENT_JSON" | jq -r '
    .reviewer_results[]
    | .role as $role
    | (.verified_clean // [])[]
    | [ $role, (.area // "—"), (.method // "—"), (.result // "—") ]
    | @tsv
  ')"
  if [ -n "$CLEAN_ROWS" ]; then
    while IFS=$'\t' read -r role area method result; do
      printf '| %s | %s | %s | %s |\n' "$(md_cell "$role")" "$(md_cell "$area")" "$(md_cell "$method")" "$(md_cell "$result")"
    done <<< "$CLEAN_ROWS"
  else
    echo "| (none) | — | — | No reviewer verified-clean rows were present. |"
  fi
} > "$SECTION_FILE"

replace_adjudication_block "$REVIEW_FILE" "$SECTION_FILE"
rm -f "$SECTION_FILE"

if sdd_is_json_mode; then
  DATA_JSON="$(jq -nc \
    --arg review_path "$REVIEW_FILE" \
    --arg current_path "$CURRENT_PATH" \
    --arg verdict "$VERDICT" \
    --arg evidence_status "$EVIDENCE_STATUS" \
    --arg adjudicated_at "$ADJUDICATED_AT" \
    --argjson reviewer_count "$REVIEWER_COUNT" \
    --argjson support_count "$SUPPORT_COUNT" \
    --argjson verification_count "$VERIFICATION_COUNT" \
    '{
      review_path: $review_path,
      current_path: $current_path,
      verdict: $verdict,
      evidence_status: $evidence_status,
      adjudicated_at: $adjudicated_at,
      reviewer_count: $reviewer_count,
      support_count: $support_count,
      verification_count: $verification_count
    }')"
  GUIDANCE_JSON="$(sdd_json_guidance "re-run adjudication whenever new reviewer results or verification records land." "frontmatter is now authoritative for adjudicated verdict_source and evidence_status." "legacy manual review sections may now diverge from the auto-merged adjudication block if edited by hand.")"
  sdd_emit_json_selection "$(sdd_json_success "review" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "review" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
  cat >&2 <<EOF
Merged adjudication into: $REVIEW_FILE
State sidecar: $CURRENT_PATH
Status: verdict=$VERDICT | evidence=$EVIDENCE_STATUS | verification=$VERIFICATION_COUNT | reviewers=$REVIEWER_COUNT | support=$SUPPORT_COUNT
Next: re-run adjudication whenever new reviewer results or verification records land.
Gate: frontmatter is now authoritative for adjudicated verdict_source and evidence_status.
Pitfall: legacy manual review sections may diverge from the auto-merged adjudication block if edited by hand.
EOF
  exit 0
fi

cat <<EOF
Merged adjudication into: $REVIEW_FILE
State sidecar: $CURRENT_PATH
Status: verdict=$VERDICT | evidence=$EVIDENCE_STATUS | verification=$VERIFICATION_COUNT | reviewers=$REVIEWER_COUNT | support=$SUPPORT_COUNT
Next: re-run adjudication whenever new reviewer results or verification records land.
Gate: frontmatter is now authoritative for adjudicated verdict_source and evidence_status.
Pitfall: legacy manual review sections may diverge from the auto-merged adjudication block if edited by hand.
EOF
