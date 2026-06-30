#!/usr/bin/env bash
# sdd-archive.sh — Generate README.md and DOCS.md for a closed feature
# Usage:
#   sdd-archive.sh <feature>           — validate and emit dispatch guidance
#   sdd-archive.sh --force <feature>   — skip overwrite confirmation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FEATURE_ROOT=".features"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "archive" "sdd archive [--force] <feature>" "invalid shared CLI flags"
set -- "${SDD_ARGS[@]+"${SDD_ARGS[@]}"}"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "archive" \
      "Generate README.md and DOCS.md for a closed SDD feature via the sdd-archivist subagent." \
      "sdd archive [--force] <feature> [--feature <id|auto>] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd archive 0001-user-auth",
        "sdd archive --force 0001-user-auth",
        "sdd archive --json --feature auto"
      ]'
    return 0
  fi

  echo "Usage: sdd archive [--force] <feature>"
  echo ""
  echo "Generate README.md and DOCS.md for a closed SDD feature."
  echo "Dispatches the sdd-archivist subagent to synthesize documentation"
  echo "from canonical artifacts (brief, spec, research, plan, tasks, review, etc.)."
  echo ""
  echo "Options:"
  echo "  --force    Overwrite existing README.md/DOCS.md without confirmation"
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
      sdd_usage_error "archive" "sdd archive [--force] <feature>" "unknown option '$1'"
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
      sdd_fail "archive" "not_found" "feature '$FEATURE' not found" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "arg"
      ;;
    ambiguous)
      sdd_fail "archive" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
      ;;
    none)
      sdd_usage_error "archive" "sdd archive [--force] <feature>" "feature is required"
      ;;
  esac
}
FEATURE="$SDD_RESOLVED_FEATURE"

FEATURE_DIR="$FEATURE_ROOT/$FEATURE"

if [ ! -d "$FEATURE_DIR" ]; then
  sdd_fail "archive" "not_found" "feature directory '$FEATURE_DIR' not found" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

if [ "$(sdd_profile "$FEATURE")" = "lite" ]; then
  sdd_fail "archive" "precondition" "archive not applicable in lite mode; lite features close without archive output" "{\"feature\":\"$FEATURE\",\"profile\":\"lite\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

# --- Validate feature is closed ---

REQUIRED_ARTIFACTS="$(sdd_required_artifacts "$FEATURE")"
WARNINGS=()

missing=""
for artifact in $REQUIRED_ARTIFACTS; do
  file="$FEATURE_DIR/${artifact}.md"
  if [ ! -f "$file" ]; then
    missing="${missing}  - ${artifact}.md is missing\n"
  fi
done

if [ -n "$missing" ]; then
  sdd_fail "archive" "precondition" "feature is not closed — missing required artifacts" "$(printf "%b" "$missing" | jq -Rsc '{missing: split("\n") | map(select(length > 0))}')" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

# Check review verdict
review_file="$FEATURE_DIR/review.md"
verdict="$(sdd_frontmatter_value "$review_file" verdict || true)"
if [ "$verdict" != "pass" ]; then
  sdd_fail "archive" "precondition" "feature is not closed — review.md verdict is '${verdict:-missing}', must be 'pass'." "{\"feature\":\"$FEATURE\",\"verdict\":\"${verdict:-missing}\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

# Check artifacts have status: completed
not_completed=""
for artifact in $REQUIRED_ARTIFACTS; do
  file="$FEATURE_DIR/${artifact}.md"
  status="$(sdd_frontmatter_value "$file" status || true)"
  if [ "$status" != "completed" ]; then
    not_completed="${not_completed}  - ${artifact}.md status is '${status:-missing}'\n"
  fi
done

if [ -n "$not_completed" ]; then
  sdd_fail "archive" "precondition" "feature is not closed — some artifacts are not completed" "$(printf "%b" "$not_completed" | jq -Rsc '{not_completed: split("\n") | map(select(length > 0))}')" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

# --- Detect force-closed stubs ---

force_closed_stubs=""
for artifact in $REQUIRED_ARTIFACTS; do
  file="$FEATURE_DIR/${artifact}.md"
  if grep -q "closed with --force" "$file" 2>/dev/null; then
    force_closed_stubs="${force_closed_stubs}${artifact}.md "
  fi
done

if [ -n "$force_closed_stubs" ]; then
  WARNINGS+=("Feature was force-closed; stub artifacts detected (${force_closed_stubs% }). Generated docs may be thin.")
fi

# --- Check for existing docs ---

existing_docs=""
[ -f "$FEATURE_DIR/README.md" ] && existing_docs="${existing_docs}README.md "
[ -f "$FEATURE_DIR/DOCS.md" ] && existing_docs="${existing_docs}DOCS.md "

if [ -n "$existing_docs" ] && [ "$FORCE" -eq 0 ]; then
  if sdd_is_json_mode; then
    sdd_fail "archive" "confirmation_required" "existing docs found (${existing_docs% }); re-run with --force to overwrite" "$(jq -nc --arg existing "${existing_docs% }" --arg feature "$FEATURE" '{feature:$feature, existing_docs:$existing}')" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi
  echo "WARNING: ${existing_docs% } already exist in $FEATURE_DIR"
  echo "Re-run with --force to overwrite: sdd archive --force $FEATURE"
  exit 1
fi

if [ -n "$existing_docs" ] && [ "$FORCE" -eq 1 ]; then
  WARNINGS+=("Overwriting existing docs: ${existing_docs% }")
fi

# --- Build artifact inventory ---

ARTIFACT_INVENTORY=""
OPTIONAL_ARTIFACTS="scratchpad continuity knowledge"

for artifact in $REQUIRED_ARTIFACTS $OPTIONAL_ARTIFACTS; do
  file="$FEATURE_DIR/${artifact}.md"
  if [ -f "$file" ]; then
    ARTIFACT_INVENTORY="${ARTIFACT_INVENTORY}${artifact}.md "
  fi
done

# Check for non-.md optional files
[ -f "$FEATURE_DIR/changes.log" ] && ARTIFACT_INVENTORY="${ARTIFACT_INVENTORY}changes.log "
[ -f "$FEATURE_DIR/scope.txt" ] && ARTIFACT_INVENTORY="${ARTIFACT_INVENTORY}scope.txt "
[ -f "$FEATURE_DIR/summary.md" ] && ARTIFACT_INVENTORY="${ARTIFACT_INVENTORY}summary.md "

# --- Resolve description ---

DESC_JSON="$(sdd_feature_description_json "$FEATURE" 2>/dev/null || echo '{"short":"","long":null,"short_source":"feature.id","long_source":null}')"
DESC_SHORT="$(printf '%s\n' "$DESC_JSON" | jq -r '.short // empty')"
DESC_LONG="$(printf '%s\n' "$DESC_JSON" | jq -r '.long // empty')"

# --- Build warnings JSON ---

WARNINGS_JSON="$(printf '%s\n' "${WARNINGS[@]+"${WARNINGS[@]}"}" | jq -Rsc 'split("\n") | map(select(length > 0))')"

# --- Emit output ---

REF_LINE="$(sdd_phase_reference_line "close")"

if sdd_is_json_mode; then
  DATA_JSON="$(jq -nc \
    --arg action "archive" \
    --arg feature "$FEATURE" \
    --arg feature_dir "$FEATURE_DIR" \
    --arg artifact_inventory "${ARTIFACT_INVENTORY% }" \
    --arg force_closed_stubs "${force_closed_stubs% }" \
    --argjson force "$FORCE" \
    --arg description_short "$DESC_SHORT" \
    --arg description_long "$DESC_LONG" \
    '{
      action: $action,
      feature: $feature,
      feature_dir: $feature_dir,
      description_short: $description_short,
      description_long: (if $description_long == "" then null else $description_long end),
      artifact_inventory: ($artifact_inventory | split(" ") | map(select(length > 0))),
      force_closed_stubs: (if $force_closed_stubs == "" then [] else ($force_closed_stubs | split(" ") | map(select(length > 0))) end),
      force: ($force == 1),
      dispatch: {
        agent: "sdd-archivist",
        model: "inherit",
        effort: "high",
        run_in_background: true,
        prompt_context: {
          feature: $feature,
          feature_dir: $feature_dir,
          description_short: $description_short,
          description_long: (if $description_long == "" then null else $description_long end),
          artifact_inventory: ($artifact_inventory | split(" ") | map(select(length > 0)))
        }
      }
    }')"
  GUIDANCE_JSON="$(sdd_json_guidance \
    "dispatch the sdd-archivist agent in the background with the feature path \`$FEATURE_DIR\` to generate README.md and DOCS.md." \
    "the archivist reads all canonical artifacts, keeps synthesis grounded in verified artifacts and review outcomes, and says limited information available when the source material is thin." \
    "do not hallucinate missing details, and do not attempt to write README.md or DOCS.md directly — delegate to the sdd-archivist agent.")"
  sdd_emit_json_selection "$(sdd_json_success "archive" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}" "close" "$DATA_JSON" "$GUIDANCE_JSON" "$WARNINGS_JSON")"
  echo "Feature ready for archiving: $FEATURE" >&2
  echo "Feature directory: $FEATURE_DIR" >&2
  echo "" >&2
  if [ ${#WARNINGS[@]} -gt 0 ]; then
    for w in "${WARNINGS[@]}"; do
      echo "WARNING: $w" >&2
    done
    echo "" >&2
  fi
  echo "Artifacts available: ${ARTIFACT_INVENTORY% }" >&2
  echo "" >&2
  cat >&2 <<EOF
Next: dispatch the sdd-archivist agent in the background to generate README.md and DOCS.md.
Gate: the archivist reads all canonical artifacts and synthesizes two documents: README.md (narrative overview) and DOCS.md (technical reference).
Grounding: keep the synthesis grounded in verified artifacts and review outcomes; if the record is thin, say "limited information available" instead of filling gaps.
Pitfall: do not hallucinate missing details, and do not attempt to write README.md or DOCS.md directly — delegate to the sdd-archivist agent.
EOF
  if [ -n "$REF_LINE" ]; then
    printf '%s\n' "$REF_LINE" >&2
  fi
  exit 0
fi

# --- Text output ---

echo "Feature ready for archiving: $FEATURE"
echo "Feature directory: $FEATURE_DIR"
echo ""
if [ ${#WARNINGS[@]} -gt 0 ]; then
  for w in "${WARNINGS[@]}"; do
    echo "WARNING: $w"
  done
  echo ""
fi
echo "Artifacts available: ${ARTIFACT_INVENTORY% }"
echo ""
cat <<EOF
Next: dispatch the sdd-archivist agent in the background to generate README.md and DOCS.md.
Gate: the archivist reads all canonical artifacts and synthesizes two documents: README.md (narrative overview) and DOCS.md (technical reference).
Pitfall: do not attempt to write README.md or DOCS.md directly — delegate to the sdd-archivist agent.
EOF
if [ -n "$REF_LINE" ]; then
  printf '%s\n' "$REF_LINE"
fi
