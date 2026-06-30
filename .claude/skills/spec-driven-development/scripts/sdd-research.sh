#!/usr/bin/env bash
# sdd-research.sh — Scaffold research.md from template (Design → Research transition)
# Usage: sdd-research.sh <feature-id>

set -euo pipefail

FEATURE_ROOT=".features"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$SKILL_DIR/templates"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "research" "sdd research <feature-id> [--feature <id|auto>]" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "research" \
      "Scaffold research.md and scope.txt for a feature after the spec is ready." \
      "sdd research <feature-id> [--feature <id|auto>] [--format text|json] [--non-interactive] [--on-exists fail|overwrite|skip]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd research 0001-user-auth",
        "sdd research --json --feature auto",
        "sdd research --non-interactive --on-exists overwrite --feature 0001-user-auth"
      ]'
    return 0
  fi

  echo "Usage: sdd research <feature-id> [--feature <id|auto>]"
  echo ""
  echo "Scaffold research.md and scope.txt for a feature after the spec is ready."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }
sdd_install_cleanup_trap

feature="${SDD_FEATURE_OVERRIDE:-${SDD_ARGS[0]:-}}"
sdd_resolve_feature_target "$feature" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
  case "$SDD_RESOLUTION_STATUS" in
    not_found)
      sdd_fail "research" "not_found" "feature '$feature' not found" "{\"feature\":\"$feature\"}" "$feature" "arg"
      ;;
    ambiguous)
      sdd_fail "research" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
      ;;
    none)
      sdd_fail "research" "not_found" "no active feature found" '{"feature":"auto"}' "" "none"
      ;;
  esac
}
feature="$SDD_RESOLVED_FEATURE"

FEATURE_DIR="$FEATURE_ROOT/$feature"

if [ "$(sdd_profile "$feature")" = "lite" ]; then
  sdd_fail "research" "precondition" "sdd research is not applicable in lite mode; research notes are captured inline in spec.md" "{\"feature\":\"$feature\",\"profile\":\"lite\"}" "$feature" "$SDD_RESOLUTION_SOURCE"
fi

if [ ! -f "$FEATURE_DIR/spec.md" ]; then
  sdd_fail "research" "precondition" "spec.md must exist before creating research.md (complete Design phase first)" "{\"feature\":\"$feature\"}" "$feature" "$SDD_RESOLUTION_SOURCE"
fi

EXISTING_ACTION="$(sdd_existing_path_action "$FEATURE_DIR/research.md" "$FEATURE_DIR/research.md" 2>/dev/null)" || {
  sdd_fail "research" "conflict" "research.md already exists" "{\"path\":\"$FEATURE_DIR/research.md\",\"policy\":\"$(sdd_effective_on_exists)\"}" "$feature" "$SDD_RESOLUTION_SOURCE"
}

if [ "$EXISTING_ACTION" = "skip" ]; then
  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc --arg file "$FEATURE_DIR/research.md" --arg artifact_id "RESEARCH-$(echo "$feature" | grep -oE '^[0-9]+')" '{action:"skip", file:$file, artifact_id:$artifact_id}')"
    GUIDANCE_JSON="$(sdd_json_guidance "capture codebase facts that constrain implementation, not architecture decisions." "\`sdd plan create $feature\` is valid when Affected Files has at least 1 valid row and Confidence ends with GO or HOLD." "do not start production edits during research, even if the correct change feels obvious.")"
    sdd_emit_json_selection "$(sdd_json_success "research" "$feature" "$SDD_RESOLUTION_SOURCE" "research" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
    echo "Skipped." >&2
  else
    echo "Skipped."
  fi
  exit 0
fi

# Extract metadata
FEATURE_NUM=$(echo "$feature" | grep -oE '^[0-9]+')
FEATURE_NAME="${feature#*-}"
TODAY="$(date +%Y-%m-%d)"

# Get title from spec.md
FEATURE_TITLE=$(grep '^title:' "$FEATURE_DIR/spec.md" 2>/dev/null | head -1 | sed 's/^title: *//' | tr -d '"')
if [ -z "$FEATURE_TITLE" ]; then
  FEATURE_TITLE=$(echo "$FEATURE_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
fi

# Get FR count from spec for reference
FR_COUNT="$(sdd_count_id_lines FR "$FEATURE_DIR/spec.md" headings)"

# Mark spec as completed (phase transition: Design to Research)
STATUS_UPDATES_JSON="$(sdd_complete_predecessor_status "$FEATURE_DIR/spec.md" "Design to Research transition")" || \
  sdd_fail "research" "internal" "failed to mark spec.md completed" "{\"path\":\"$FEATURE_DIR/spec.md\"}" "$feature" "$SDD_RESOLUTION_SOURCE"

# Process template
cp "$TEMPLATE_DIR/research.md" "$FEATURE_DIR/research.md"

sdd_portable_sed "$FEATURE_DIR/research.md" \
  -e "s/{{FEATURE_ID}}/$feature/g" \
  -e "s/{{FEATURE_NUM}}/$FEATURE_NUM/g" \
  -e "s/{{FEATURE_NAME}}/$FEATURE_NAME/g" \
  -e "s/{{FEATURE_TITLE}}/$FEATURE_TITLE/g" \
  -e "s/{{DATE}}/$TODAY/g"
sdd_stamp_based_on "$FEATURE_DIR/research.md" "SPEC-$FEATURE_NUM"

# Create empty scope.txt — will be populated when research.md is filled in
# (don't generate from template placeholders; auto-refresh on research.md edit handles it)
scope_tmp="$(sdd_tmp_for_target "$FEATURE_DIR/scope.txt")" || sdd_fail "research" "internal" "failed to create temp file for scope.txt" "{\"path\":\"$FEATURE_DIR/scope.txt\"}" "$feature" "$SDD_RESOLUTION_SOURCE"
sdd_cleanup_push "$scope_tmp"
: > "$scope_tmp" || {
  sdd_cleanup_file "$scope_tmp"
  sdd_fail "research" "internal" "failed to initialize scope.txt" "{\"path\":\"$FEATURE_DIR/scope.txt\"}" "$feature" "$SDD_RESOLUTION_SOURCE"
}
sdd_atomic_replace "$scope_tmp" "$FEATURE_DIR/scope.txt" || {
  sdd_cleanup_file "$scope_tmp"
  sdd_fail "research" "internal" "failed to replace scope.txt atomically" "{\"path\":\"$FEATURE_DIR/scope.txt\"}" "$feature" "$SDD_RESOLUTION_SOURCE"
}
REF_LINE="$(sdd_phase_reference_line "research")"
NEXT_LINE="capture codebase facts that constrain implementation, not architecture decisions."
DELEGATE_LINE="default to sdd-research-scout for context-heavy exploration; inline only for narrow lookups."
PHASE_SKILL_LINE="$(sdd_phase_skill_cli_hint research)"
if sdd_autonomy_is_on "$feature"; then
  NEXT_LINE="Advance autonomously to sdd plan create $feature once affected files and confidence are complete; halt only on listed blockers."
fi

if sdd_is_json_mode; then
  DATA_JSON="$(jq -nc \
    --arg action "$EXISTING_ACTION" \
    --arg file "$FEATURE_DIR/research.md" \
    --arg scope_file "$FEATURE_DIR/scope.txt" \
    --arg artifact_id "RESEARCH-$FEATURE_NUM" \
    --argjson fr_count "$FR_COUNT" \
    --argjson status_updates "$STATUS_UPDATES_JSON" \
    '{action:$action, file:$file, scope_file:$scope_file, artifact_id:$artifact_id, fr_count:$fr_count, status_updates:$status_updates}')"
  GUIDANCE_JSON="$(jq -nc \
    --arg next "$NEXT_LINE" \
    --arg worker "$DELEGATE_LINE" \
    --arg gate "\`sdd plan create $feature\` is valid when Affected Files has at least 1 valid row and Confidence ends with GO or HOLD." \
    '{"next":$next,"gate":$gate,"pitfall":"do not start production edits during research, even if the correct change feels obvious.","worker":$worker}')"
  sdd_emit_json_selection "$(sdd_json_success "research" "$feature" "$SDD_RESOLUTION_SOURCE" "research" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
  cat >&2 <<EOF
Created: $FEATURE_DIR/research.md (RESEARCH-$FEATURE_NUM)
$(sdd_status_updates_text "$STATUS_UPDATES_JSON")
Generated: $FEATURE_DIR/scope.txt (starts empty; it fills as Affected Files becomes concrete)
Spec scope: $FR_COUNT FRs to map across files, entry points, dependencies, and tests.
Next: $NEXT_LINE
${PHASE_SKILL_LINE:+$PHASE_SKILL_LINE
}Gate: \`sdd plan create $feature\` is valid when Affected Files has at least 1 valid row and Confidence ends with GO or HOLD.
Delegate: $DELEGATE_LINE
Pitfall: do not start production edits during research, even if the correct change feels obvious.
EOF
  if [ -n "$REF_LINE" ]; then
    printf '%s\n' "$REF_LINE" >&2
  fi
  exit 0
fi

cat <<EOF
Created: $FEATURE_DIR/research.md (RESEARCH-$FEATURE_NUM)
$(sdd_status_updates_text "$STATUS_UPDATES_JSON")
Generated: $FEATURE_DIR/scope.txt (starts empty; it fills as Affected Files becomes concrete)
Spec scope: $FR_COUNT FRs to map across files, entry points, dependencies, and tests.
Next: $NEXT_LINE
${PHASE_SKILL_LINE:+$PHASE_SKILL_LINE
}Gate: \`sdd plan create $feature\` is valid when Affected Files has at least 1 valid row and Confidence ends with GO or HOLD.
Delegate: $DELEGATE_LINE
Pitfall: do not start production edits during research, even if the correct change feels obvious.
EOF
if [ -n "$REF_LINE" ]; then
  printf '%s\n' "$REF_LINE"
fi
