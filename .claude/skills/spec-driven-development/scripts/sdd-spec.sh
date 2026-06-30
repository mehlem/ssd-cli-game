#!/usr/bin/env bash
# sdd-spec.sh — Scaffold spec.md from template (Brief → Design transition)
# Usage: sdd-spec.sh <feature-id>

set -euo pipefail

FEATURE_ROOT=".features"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$SKILL_DIR/templates"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "spec" "sdd spec <feature-id> [--feature <id|auto>]" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "spec" \
      "Scaffold spec.md for a feature after the brief is ready." \
      "sdd spec <feature-id> [--feature <id|auto>] [--format text|json] [--non-interactive] [--on-exists fail|overwrite|skip]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd spec 0001-user-auth",
        "sdd spec --json --feature auto",
        "sdd spec --non-interactive --on-exists overwrite --feature 0001-user-auth"
      ]'
    return 0
  fi

  echo "Usage: sdd spec <feature-id> [--feature <id|auto>]"
  echo ""
  echo "Scaffold spec.md for a feature after the brief is ready."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

feature="${SDD_FEATURE_OVERRIDE:-${SDD_ARGS[0]:-}}"
sdd_resolve_feature_target "$feature" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
  case "$SDD_RESOLUTION_STATUS" in
    not_found)
      sdd_fail "spec" "not_found" "feature '$feature' not found" "{\"feature\":\"$feature\"}" "$feature" "arg"
      ;;
    ambiguous)
      sdd_fail "spec" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
      ;;
    none)
      sdd_fail "spec" "not_found" "no active feature found" '{"feature":"auto"}' "" "none"
      ;;
  esac
}
feature="$SDD_RESOLVED_FEATURE"
FEATURE_DIR="$FEATURE_ROOT/$feature"

if [ "$(sdd_profile "$feature")" = "lite" ]; then
  sdd_fail "spec" "precondition" "sdd spec is not applicable in lite mode; lite uses a single combined spec.md scaffolded by sdd init and tasks.md Approach for planning" "{\"feature\":\"$feature\",\"profile\":\"lite\"}" "$feature" "$SDD_RESOLUTION_SOURCE"
fi

if [ ! -f "$FEATURE_DIR/brief.md" ]; then
  sdd_fail "spec" "precondition" "brief.md must exist before creating spec.md (complete Brief phase first)" "{\"feature\":\"$feature\"}" "$feature" "$SDD_RESOLUTION_SOURCE"
fi

EXISTING_ACTION="$(sdd_existing_path_action "$FEATURE_DIR/spec.md" "$FEATURE_DIR/spec.md" 2>/dev/null)" || {
  sdd_fail "spec" "conflict" "spec.md already exists" "{\"path\":\"$FEATURE_DIR/spec.md\",\"policy\":\"$(sdd_effective_on_exists)\"}" "$feature" "$SDD_RESOLUTION_SOURCE"
}

if [ "$EXISTING_ACTION" = "skip" ]; then
  if sdd_is_json_mode; then
    DATA_JSON="$(jq -nc --arg file "$FEATURE_DIR/spec.md" --arg artifact_id "SPEC-$(echo "$feature" | grep -oE '^[0-9]+')" '{action:"skip", file:$file, artifact_id:$artifact_id}')"
    GUIDANCE_JSON="$(sdd_json_guidance "translate brief.md into spec.md: problem, solution, user stories, FRs, and testable ACs." "\`sdd research $feature\` is valid when Problem is substantive and spec.md has at least 1 FR and 1 AC; keep architecture and tasks out of this file." "do not turn spec.md into plan.md or start coding from partial requirements.")"
    sdd_emit_json_selection "$(sdd_json_success "spec" "$feature" "$SDD_RESOLUTION_SOURCE" "design" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
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

# Get title from brief.md
FEATURE_TITLE=$(grep '^title:' "$FEATURE_DIR/brief.md" 2>/dev/null | head -1 | sed 's/^title: *//' | tr -d '"')
if [ -z "$FEATURE_TITLE" ]; then
  FEATURE_TITLE=$(echo "$FEATURE_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
fi

# Mark brief as completed (phase transition: Brief to Design)
STATUS_UPDATES_JSON="$(sdd_complete_predecessor_status "$FEATURE_DIR/brief.md" "Brief to Design transition")" || \
  sdd_fail "spec" "internal" "failed to mark brief.md completed" "{\"path\":\"$FEATURE_DIR/brief.md\"}" "$feature" "$SDD_RESOLUTION_SOURCE"

# Process template
cp "$TEMPLATE_DIR/spec.md" "$FEATURE_DIR/spec.md"

sdd_portable_sed "$FEATURE_DIR/spec.md" \
  -e "s/{{FEATURE_ID}}/$feature/g" \
  -e "s/{{FEATURE_NUM}}/$FEATURE_NUM/g" \
  -e "s/{{FEATURE_NAME}}/$FEATURE_NAME/g" \
  -e "s/{{FEATURE_TITLE}}/$FEATURE_TITLE/g" \
  -e "s/{{DATE}}/$TODAY/g"
sdd_stamp_based_on "$FEATURE_DIR/spec.md" "BRIEF-$FEATURE_NUM"

REF_LINE="$(sdd_phase_reference_line "design")"
PHASE_SKILL_LINE="$(sdd_phase_skill_cli_hint design)"
NEXT_LINE="translate brief.md into spec.md: problem, solution, user stories, FRs, and testable ACs."
if sdd_autonomy_is_on "$feature"; then
  NEXT_LINE="Advance autonomously to sdd research $feature once spec.md has Problem, FRs, and ACs; halt only on listed blockers."
fi

if sdd_is_json_mode; then
  DATA_JSON="$(jq -nc --arg action "$EXISTING_ACTION" --arg file "$FEATURE_DIR/spec.md" --arg artifact_id "SPEC-$FEATURE_NUM" --argjson status_updates "$STATUS_UPDATES_JSON" '{action:$action, file:$file, artifact_id:$artifact_id, status_updates:$status_updates}')"
  GUIDANCE_JSON="$(sdd_json_guidance "$NEXT_LINE" "\`sdd research $feature\` is valid when Problem is substantive and spec.md has at least 1 FR and 1 AC; keep architecture and tasks out of this file." "do not turn spec.md into plan.md or start coding from partial requirements.")"
  sdd_emit_json_selection "$(sdd_json_success "spec" "$feature" "$SDD_RESOLUTION_SOURCE" "design" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
  cat >&2 <<EOF
Created: $FEATURE_DIR/spec.md (SPEC-$FEATURE_NUM)
$(sdd_status_updates_text "$STATUS_UPDATES_JSON")
Next: $NEXT_LINE
${PHASE_SKILL_LINE:+$PHASE_SKILL_LINE
}Gate: \`sdd research $feature\` is valid when Problem is substantive and spec.md has at least 1 FR and 1 AC; keep architecture and tasks out of this file.
Pitfall: do not turn spec.md into plan.md or start coding from partial requirements.
EOF
  if [ -n "$REF_LINE" ]; then
    printf '%s\n' "$REF_LINE" >&2
  fi
  exit 0
fi

cat <<EOF
Created: $FEATURE_DIR/spec.md (SPEC-$FEATURE_NUM)
$(sdd_status_updates_text "$STATUS_UPDATES_JSON")
Next: $NEXT_LINE
${PHASE_SKILL_LINE:+$PHASE_SKILL_LINE
}Gate: \`sdd research $feature\` is valid when Problem is substantive and spec.md has at least 1 FR and 1 AC; keep architecture and tasks out of this file.
Pitfall: do not turn spec.md into plan.md or start coding from partial requirements.
EOF
if [ -n "$REF_LINE" ]; then
  printf '%s\n' "$REF_LINE"
fi
