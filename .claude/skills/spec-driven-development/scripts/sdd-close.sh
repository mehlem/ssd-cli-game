#!/usr/bin/env bash
# sdd-close.sh — Close a feature, optionally force-closing with stub artifacts
# Usage:
#   sdd-close.sh <feature>           — close normally (verify all artifacts, verdict: pass required)
#   sdd-close.sh --force <feature>   — create stub artifacts and set verdict: pass

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FEATURE_ROOT=".features"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "close" "sdd close [--force] <feature>" "invalid shared CLI flags"
set -- "${SDD_ARGS[@]+"${SDD_ARGS[@]}"}"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "close" \
      "Close a feature normally or force-close it with stub artifacts." \
      "sdd close [--force] <feature> [--feature <id|auto>] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd close 0001-user-auth",
        "sdd close --force 0001-user-auth",
        "sdd close --json --feature auto"
      ]'
    return 0
  fi

  echo "Usage: sdd close [--force] <feature>"
  echo ""
  echo "Close a feature normally or force-close it with stub artifacts."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }
sdd_install_cleanup_trap

# --- Argument parsing ---

FORCE=0
FEATURE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    -*)
      sdd_usage_error "close" "sdd close [--force] <feature>" "unknown option '$1'"
      ;;
    *)
      FEATURE="$1"
      shift
      ;;
  esac
done

FEATURE="${SDD_FEATURE_OVERRIDE:-$FEATURE}"
sdd_resolve_feature_target "$FEATURE" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
  case "$SDD_RESOLUTION_STATUS" in
    not_found)
      sdd_fail "close" "not_found" "feature '$FEATURE' not found" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "arg"
      ;;
    ambiguous)
      sdd_fail "close" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
      ;;
    none)
      sdd_usage_error "close" "sdd close [--force] <feature>" "feature is required"
      ;;
  esac
}
FEATURE="$SDD_RESOLVED_FEATURE"
FEATURE_PATH="${SDD_RESOLVED_FEATURE_PATH:-$FEATURE}"

FEATURE_DIR="${SDD_RESOLVED_FEATURE_DIR:-$FEATURE_ROOT/$FEATURE_PATH}"

if [ ! -d "$FEATURE_DIR" ]; then
  sdd_fail "close" "not_found" "feature directory '$FEATURE_DIR' not found" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

# Metadata for stub generation
sdd_extract_metadata "$FEATURE"
TODAY="$SDD_TODAY"
FEATURE_NUM="$SDD_FEATURE_NUM"
FEATURE_TITLE="$SDD_FEATURE_TITLE"

REQUIRED_ARTIFACTS="$(sdd_required_artifacts "$FEATURE_PATH")"

# --- Helpers ---

write_stub() {
  local artifact_type="$1"
  local file="$2"
  local artifact_id artifact_title content
  artifact_id="$(echo "$artifact_type" | tr '[:lower:]' '[:upper:]')-${FEATURE_NUM}"
  artifact_title="$(echo "$artifact_type" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"

  content="$(cat <<EOF
---
id: ${artifact_id}
feature: "${FEATURE}"
title: "${FEATURE_TITLE}"
type: ${artifact_type}
status: completed
created: ${TODAY}
updated: ${TODAY}
---

# ${artifact_title}: ${FEATURE_TITLE}

Stub artifact — feature closed with --force
EOF
)"

  sdd_write_file_atomic "$file" "$content"
}

write_review_stub() {
  local file="$1"
  local content
  content="$(cat <<EOF
---
id: REVIEW-${FEATURE_NUM}
feature: "${FEATURE}"
title: "${FEATURE_TITLE}"
type: review
status: completed
phase: review
created: ${TODAY}
updated: ${TODAY}
verdict: pass
---

# Review: ${FEATURE_TITLE}

Stub artifact — feature closed with --force
EOF
)"
  sdd_write_file_atomic "$file" "$content"
}

update_artifact_status() {
  local file="$1"
  [ -f "$file" ] || return 0
  local tmp
  tmp="$(sdd_tmp_for_target "$file")" || return 1
  sdd_cleanup_push "$tmp"
  awk '
    BEGIN { in_frontmatter=0; started=0; done=0 }
    $0 == "---" {
      if (!started) { started=1; in_frontmatter=1; print; next }
      if (in_frontmatter) { in_frontmatter=0; print; next }
    }
    in_frontmatter && /^status:/ && !done {
      print "status: completed"
      done=1
      next
    }
    { print }
  ' "$file" > "$tmp" || {
    sdd_cleanup_file "$tmp"
    return 1
  }
  sdd_atomic_replace "$tmp" "$file" || {
    sdd_cleanup_file "$tmp"
    return 1
  }
}

update_verdict_to_pass() {
  local file="$1"
  [ -f "$file" ] || return 0
  local tmp
  tmp="$(sdd_tmp_for_target "$file")" || return 1
  sdd_cleanup_push "$tmp"
  awk '
    BEGIN { in_frontmatter=0; started=0; done=0 }
    $0 == "---" {
      if (!started) { started=1; in_frontmatter=1; print; next }
      if (in_frontmatter) { in_frontmatter=0; print; next }
    }
    in_frontmatter && /^verdict:/ && !done {
      print "verdict: pass"
      done=1
      next
    }
    { print }
  ' "$file" > "$tmp" || {
    sdd_cleanup_file "$tmp"
    return 1
  }
  sdd_atomic_replace "$tmp" "$file" || {
    sdd_cleanup_file "$tmp"
    return 1
  }
}

# --- Clear .active if matching closed feature ---

clear_active_if_matching() {
  local active_file="$FEATURE_ROOT/.active"
  [ -f "$active_file" ] || return 0
  local current=""
  read -r current < "$active_file" 2>/dev/null || true
  if [ "$current" = "$FEATURE" ] || [ "$current" = "$FEATURE_PATH" ]; then
    rm -f "$active_file"
  fi
}

refresh_epic_state_after_close() {
  [ -f "$SCRIPT_DIR/sdd-epic-refresh.sh" ] || return 0
  bash "$SCRIPT_DIR/sdd-epic-refresh.sh" --current >/dev/null 2>&1 || true
}

# --- Force-close path ---

if [ "$FORCE" -eq 1 ]; then
  created_count=0
  normalized_count=0

  for artifact in $REQUIRED_ARTIFACTS; do
    if [ "$artifact" = "review" ]; then
      file="$FEATURE_DIR/review.md"
      if [ ! -f "$file" ]; then
        write_review_stub "$file"
        created_count=$((created_count + 1))
      else
        current_verdict="$(sdd_frontmatter_value "$file" verdict || true)"
        if [ "$current_verdict" != "pass" ]; then
          update_verdict_to_pass "$file"
        fi
        update_artifact_status "$file"
        normalized_count=$((normalized_count + 1))
      fi
    else
      file="$FEATURE_DIR/${artifact}.md"
      if [ ! -f "$file" ]; then
        write_stub "$artifact" "$file"
        created_count=$((created_count + 1))
      else
        update_artifact_status "$file"
        normalized_count=$((normalized_count + 1))
      fi
    fi
  done

  if [ -f "$FEATURE_DIR/continuity.md" ]; then
    update_artifact_status "$FEATURE_DIR/continuity.md"
  fi

  REF_LINE="$(sdd_phase_reference_line "close")"
  bash "$SCRIPT_DIR/sdd-status.sh" --json "$FEATURE_PATH" >/dev/null 2>&1 || true
  refresh_epic_state_after_close
  sdd_summary_maybe "$FEATURE_PATH"
  clear_active_if_matching
  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc --arg action "force-close" --arg feature "$FEATURE" --arg feature_path "$FEATURE_PATH" --arg feature_dir "$FEATURE_DIR" --argjson created "$created_count" --argjson normalized "$normalized_count" --arg archive_command "sdd archive $FEATURE_PATH" --arg record_command "sdd record-close $FEATURE_PATH" '{action:$action, feature:$feature, feature_id:$feature, feature_path:$feature_path, feature_dir:$feature_dir, created:$created, normalized:$normalized, archive_command:$archive_command, record_command:$record_command}')"
    GUIDANCE_JSON="$(sdd_json_guidance "treat this as an administrative closure; use \`sdd reopen $FEATURE_PATH\` before more implementation or review work. After the user-approved close commit, run \`sdd record-close $FEATURE_PATH\`; optionally run \`sdd archive $FEATURE_PATH\` to generate README.md and DOCS.md (note: force-closed features may produce thin docs)." "\`sdd close --force $FEATURE_PATH\` bypasses the normal passed-review requirement and only normalizes lifecycle artifacts." "do not treat force-close as equivalent to a passed review.")"
    sdd_emit_json_selection "$(sdd_json_success "close" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}" "close" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
    cat >&2 <<EOF
Feature force-closed: $FEATURE
Status: stub artifacts were created or normalized ($created_count created, $normalized_count normalized); this does not imply review evidence existed.
Next: treat this as an administrative closure; use \`sdd reopen $FEATURE_PATH\` before more implementation or review work.
Record: after the user-approved close commit, run \`sdd record-close $FEATURE_PATH\`.
Archive: optionally run \`sdd archive $FEATURE_PATH\` to generate README.md and DOCS.md (note: force-closed features may produce thin docs).
Gate: \`sdd close --force $FEATURE_PATH\` bypasses the normal passed-review requirement and only normalizes lifecycle artifacts.
Pitfall: do not treat force-close as equivalent to a passed review.
EOF
    if [ -n "$REF_LINE" ]; then
      printf '%s\n' "$REF_LINE" >&2
    fi
    exit 0
  fi
  cat <<EOF
Feature force-closed: $FEATURE
Status: stub artifacts were created or normalized ($created_count created, $normalized_count normalized); this does not imply review evidence existed.
Next: treat this as an administrative closure; use \`sdd reopen $FEATURE_PATH\` before more implementation or review work.
Record: after the user-approved close commit, run \`sdd record-close $FEATURE_PATH\`.
Archive: optionally run \`sdd archive $FEATURE_PATH\` to generate README.md and DOCS.md (note: force-closed features may produce thin docs).
Gate: \`sdd close --force $FEATURE_PATH\` bypasses the normal passed-review requirement and only normalizes lifecycle artifacts.
Pitfall: do not treat force-close as equivalent to a passed review.
EOF
  if [ -n "$REF_LINE" ]; then
    printf '%s\n' "$REF_LINE"
  fi
  exit 0
fi

# --- Normal close path ---

NORMAL_REQUIRED_ARTIFACTS="$(sdd_required_artifacts_for_close "$FEATURE_PATH")"
missing=""
for artifact in $NORMAL_REQUIRED_ARTIFACTS; do
  file="$FEATURE_DIR/${artifact}.md"
  if [ ! -f "$file" ]; then
    missing="${missing}  - ${artifact}.md is missing\n"
  fi
done

if [ -n "$missing" ]; then
  MISSING_DETAIL="$(printf "%b" "$missing" | sed 's/^  - //' | awk 'NF { items = items (items ? "; " : "") $0 } END { print items }')"
  MISSING_MESSAGE="missing required artifacts"
  if [ -n "$MISSING_DETAIL" ]; then
    MISSING_MESSAGE="$MISSING_MESSAGE: $MISSING_DETAIL"
  fi
  sdd_fail "close" "precondition" "$MISSING_MESSAGE" "$(printf "%b" "$missing" | jq -Rsc '{missing: split("\n") | map(select(length > 0))}')" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

if sdd_feature_has_work_packages "$FEATURE_DIR"; then
  WP_REVIEW_SUMMARY_JSON="$(sdd_feature_wp_review_summary_json "$FEATURE_DIR")"
  WP_SCAFFOLD="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '.scaffold // 0')"
  WP_INCOMPLETE="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '.incomplete_tasks // 0')"
  WP_MISSING_REVIEW="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '.missing_review // 0')"
  WP_FAILING_REVIEW="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '.failing_review // 0')"
  WP_INCOMPLETE_LIST="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '[.work_packages[] | select(.phase != "done") | .id] | join(", ")')"
  WP_MISSING_REVIEW_LIST="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '[.work_packages[] | select(.review_verdict == null) | .id] | join(", ")')"
  WP_FAILING_REVIEW_LIST="$(printf '%s\n' "$WP_REVIEW_SUMMARY_JSON" | jq -r '[.work_packages[] | select(.review_verdict != null and .review_pass != true) | .id] | join(", ")')"

  if [ "$WP_SCAFFOLD" -gt 0 ] || [ "$WP_INCOMPLETE" -gt 0 ]; then
    [ -n "$WP_INCOMPLETE_LIST" ] || WP_INCOMPLETE_LIST="wp-*"
    sdd_fail "close" "precondition" "work package tasks are incomplete ($WP_INCOMPLETE_LIST); complete all wp-*/tasks.md files before closing." "$WP_REVIEW_SUMMARY_JSON" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
  if [ "$WP_MISSING_REVIEW" -gt 0 ]; then
    [ -n "$WP_MISSING_REVIEW_LIST" ] || WP_MISSING_REVIEW_LIST="wp-*"
    sdd_fail "close" "precondition" "work package review is missing ($WP_MISSING_REVIEW_LIST); run WP review for every work package before feature close." "$WP_REVIEW_SUMMARY_JSON" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
  if [ "$WP_FAILING_REVIEW" -gt 0 ]; then
    [ -n "$WP_FAILING_REVIEW_LIST" ] || WP_FAILING_REVIEW_LIST="wp-*"
    sdd_fail "close" "precondition" "work package review is failing or lacks sufficient evidence ($WP_FAILING_REVIEW_LIST); fix wp-*/review.md before feature close." "$WP_REVIEW_SUMMARY_JSON" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
fi

review_file="$FEATURE_DIR/review.md"
verdict="$(sdd_frontmatter_value "$review_file" verdict || true)"
evidence_status="$(sdd_frontmatter_value "$review_file" evidence_status || true)"
if [ -n "$evidence_status" ] && [ "$evidence_status" != "sufficient" ]; then
  sdd_fail "close" "precondition" "review.md evidence_status is '${evidence_status}', must be 'sufficient' to close." "{\"feature\":\"$FEATURE\",\"evidence_status\":\"$evidence_status\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi
if [ "$verdict" != "pass" ]; then
  sdd_fail "close" "precondition" "review.md verdict is '${verdict:-missing}', must be 'pass' to close." "{\"feature\":\"$FEATURE\",\"verdict\":\"${verdict:-missing}\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

set +e
CHECK_OUTPUT="$(bash "$SCRIPT_DIR/sdd-check.sh" all "$FEATURE_PATH" 2>&1)"
CHECK_EXIT=$?
set -e
if [ "$CHECK_EXIT" -ne 0 ]; then
  CHECK_DETAILS="$(jq -nc --arg feature "$FEATURE" --arg feature_path "$FEATURE_PATH" --arg check "all" --arg output "$CHECK_OUTPUT" '{feature:$feature, feature_id:$feature, feature_path:$feature_path, check:$check, output:$output}')"
  sdd_fail "close" "precondition" "artifact readiness checks failed; run \`sdd check all $FEATURE_PATH\` before closing." "$CHECK_DETAILS" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

for artifact in $NORMAL_REQUIRED_ARTIFACTS; do
  file="$FEATURE_DIR/${artifact}.md"
  update_artifact_status "$file"
done

if [ -f "$FEATURE_DIR/continuity.md" ]; then
  update_artifact_status "$FEATURE_DIR/continuity.md"
fi

bash "$SCRIPT_DIR/sdd-status.sh" --json "$FEATURE_PATH" >/dev/null 2>&1 || true
refresh_epic_state_after_close
sdd_summary_maybe "$FEATURE_PATH"
REF_LINE="$(sdd_phase_reference_line "close")"
PHASE_SKILL_LINE="$(sdd_phase_skill_cli_hint close)"
clear_active_if_matching

if sdd_is_json_mode; then
  DATA_JSON="$(jq -nc --arg action "close" --arg feature "$FEATURE" --arg feature_path "$FEATURE_PATH" --arg feature_dir "$FEATURE_DIR" --arg archive_command "sdd archive $FEATURE_PATH" --arg record_command "sdd record-close $FEATURE_PATH" '{action:$action, feature:$feature, feature_id:$feature, feature_path:$feature_path, feature_dir:$feature_dir, archive_command:$archive_command, record_command:$record_command}')"
  GUIDANCE_JSON="$(sdd_json_guidance "treat this feature as done; only additional scope should continue via \`sdd reopen $FEATURE_PATH\`. After the user-approved close commit, run \`sdd record-close $FEATURE_PATH\`; optionally run \`sdd archive $FEATURE_PATH\` to generate README.md and DOCS.md for future reference." "normal close requires review.md verdict pass and \`sdd check all $FEATURE_PATH\` readiness; closed means artifacts are final, not waiting for more silent edits." "do not resume implementation inside a closed feature without reopening it explicitly.")"
  sdd_emit_json_selection "$(sdd_json_success "close" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}" "close" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
  cat >&2 <<EOF
Feature closed: $FEATURE
Status: all required artifacts were verified and marked completed.
Next: treat this feature as done; only additional scope should continue via \`sdd reopen $FEATURE_PATH\`.
${PHASE_SKILL_LINE:+$PHASE_SKILL_LINE
}Record: after the user-approved close commit, run \`sdd record-close $FEATURE_PATH\`.
Archive: optionally run \`sdd archive $FEATURE_PATH\` to generate README.md and DOCS.md for future reference.
Gate: normal close requires review.md verdict pass and \`sdd check all $FEATURE_PATH\` readiness; closed means artifacts are final, not waiting for more silent edits.
Pitfall: do not resume implementation inside a closed feature without reopening it explicitly.
EOF
  if [ -n "$REF_LINE" ]; then
    printf '%s\n' "$REF_LINE" >&2
  fi
  exit 0
fi

cat <<EOF
Feature closed: $FEATURE
Status: all required artifacts were verified and marked completed.
Next: treat this feature as done; only additional scope should continue via \`sdd reopen $FEATURE_PATH\`.
${PHASE_SKILL_LINE:+$PHASE_SKILL_LINE
}Record: after the user-approved close commit, run \`sdd record-close $FEATURE_PATH\`.
Archive: optionally run \`sdd archive $FEATURE_PATH\` to generate README.md and DOCS.md for future reference.
Gate: normal close requires review.md verdict pass and \`sdd check all $FEATURE_PATH\` readiness; closed means artifacts are final, not waiting for more silent edits.
Pitfall: do not resume implementation inside a closed feature without reopening it explicitly.
EOF
if [ -n "$REF_LINE" ]; then
  printf '%s\n' "$REF_LINE"
fi
