#!/usr/bin/env bash
# sdd-reopen.sh — Reopen a closed feature for additional work
# Usage: sdd reopen <feature>
#
# Validates the feature is in "close" phase (verdict: pass), then:
#   1. Changes review.md verdict from "pass" to "reopened"
#   2. Re-selects the feature as active

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FEATURE_ROOT=".features"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "reopen" "sdd reopen <feature>" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "reopen" \
      "Reopen a closed feature for additional work." \
      "sdd reopen <feature> [--feature <id|auto>] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd reopen 0001-user-auth",
        "sdd reopen --json --feature auto"
      ]'
    return 0
  fi

  echo "Usage: sdd reopen <feature>"
  echo ""
  echo "Reopen a closed feature for additional work."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }
sdd_install_cleanup_trap

FEATURE="${SDD_FEATURE_OVERRIDE:-${SDD_ARGS[0]:-}}"
sdd_resolve_feature_target "$FEATURE" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
  case "$SDD_RESOLUTION_STATUS" in
    not_found)
      sdd_fail "reopen" "not_found" "feature '$FEATURE' not found" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "arg"
      ;;
    ambiguous)
      sdd_fail "reopen" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
      ;;
    none)
      sdd_usage_error "reopen" "sdd reopen <feature>" "feature is required"
      ;;
  esac
}
FEATURE="$SDD_RESOLVED_FEATURE"

FEATURE_DIR="$FEATURE_ROOT/$FEATURE"

if [ ! -d "$FEATURE_DIR" ]; then
  sdd_fail "reopen" "not_found" "feature directory '$FEATURE_DIR' not found" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

REVIEW_FILE="$FEATURE_DIR/review.md"

if [ ! -f "$REVIEW_FILE" ]; then
  sdd_fail "reopen" "precondition" "no review.md found — feature is not closed" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

VERDICT="$(sdd_frontmatter_value "$REVIEW_FILE" verdict || true)"

if [ "$VERDICT" = "reopened" ]; then
  sdd_fail "reopen" "precondition" "feature is already reopened (verdict: reopened)" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

if [ "$VERDICT" != "pass" ]; then
  sdd_fail "reopen" "precondition" "feature is not closed (verdict: '${VERDICT:-missing}', expected 'pass')" "{\"feature\":\"$FEATURE\",\"verdict\":\"${VERDICT:-missing}\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

# --- Update review.md: verdict → reopened, updated → today ---

TODAY="$(date +%Y-%m-%d)"
tmp="$(sdd_tmp_for_target "$REVIEW_FILE")" || sdd_fail "reopen" "internal" "unable to create temp file for review update" "{\"path\":\"$REVIEW_FILE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
sdd_cleanup_push "$tmp"
awk -v today="$TODAY" '
  BEGIN { in_frontmatter=0; started=0 }
  $0 == "---" {
    if (!started) { started=1; in_frontmatter=1; print; next }
    if (in_frontmatter) { in_frontmatter=0; print; next }
  }
  in_frontmatter && /^verdict:/ {
    print "verdict: reopened"
    next
  }
  in_frontmatter && /^updated:/ {
    print "updated: " today
    next
  }
  { print }
' "$REVIEW_FILE" > "$tmp" || {
  sdd_cleanup_file "$tmp"
  sdd_fail "reopen" "internal" "failed to rewrite review.md" "{\"path\":\"$REVIEW_FILE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
}
sdd_atomic_replace "$tmp" "$REVIEW_FILE" || {
  sdd_cleanup_file "$tmp"
  sdd_fail "reopen" "internal" "failed to replace review.md atomically" "{\"path\":\"$REVIEW_FILE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
}
bash "$SCRIPT_DIR/sdd-status.sh" --json "$FEATURE" >/dev/null 2>&1 || true
sdd_set_session_flag "self_reviewed_at" "null" || true

# --- Re-select feature as active ---

ACTIVE_FILE="$FEATURE_ROOT/.active"
sdd_write_file_atomic "$ACTIVE_FILE" "$FEATURE" || sdd_fail "reopen" "internal" "failed to update active feature selection" "{\"path\":\"$ACTIVE_FILE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"

# INDEX.md is rebuilt lazily by `sdd index` on next read; no eager rebuild here.

# --- Output ---

if sdd_is_json_mode; then
  DATA_JSON="$(jq -nc --arg action "reopen" --arg feature "$FEATURE" '{action:$action, feature:$feature, phase:"implement"}')"
  GUIDANCE_JSON="$(sdd_json_guidance "add new tasks with \`sdd task add $FEATURE <phase> <fr-ids> <title>\`." "reopen is valid only from a closed feature with review verdict pass." "do not resume implementation without explicitly reopening the feature first.")"
  sdd_emit_json_selection "$(sdd_json_success "reopen" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}" "implement" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
  echo "Reopened: $FEATURE" >&2
  echo "Phase is now: implement" >&2
  echo "Add new tasks with: sdd task add $FEATURE <phase> <fr-ids> <title>" >&2
  exit 0
fi

echo "Reopened: $FEATURE"
echo "Phase is now: implement"
echo "Add new tasks with: sdd task add $FEATURE <phase> <fr-ids> <title>"
