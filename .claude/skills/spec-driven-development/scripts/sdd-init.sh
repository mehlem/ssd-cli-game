#!/usr/bin/env bash
# sdd-init.sh — Initialize a new feature folder
# Usage: sdd-init.sh <feature-name> [--group <path>] [--mode lite|full|normal|default|deep] [description]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "init" "sdd init <feature-name> [--group <path>] [--mode lite|full|normal|default|deep] [description]" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "init" \
      "Create a new SDD feature directory and seed the core working artifacts." \
      "sdd init <feature-name> [--group <path>] [--mode lite|full|normal|default|deep] [description] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd init user-authentication \"Add OAuth login\"",
        "sdd init login-redirect --mode lite \"Fix redirect after login\"",
        "sdd init search-index --group platform/search \"Add search index\"",
        "sdd init reporting-pipeline --json",
        "sdd init api-cleanup --json --field data.feature_id"
      ]'
    return 0
  fi

  echo "Usage: sdd init <feature-name> [--group <path>] [--mode lite|full|normal|default|deep] [description]"
  echo "Example: sdd init user-authentication \"Add OAuth-based login\""
  echo "Example: sdd init search-index --group platform/search \"Add search index\""
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

MODE="full"
GROUP_PATH=""
INIT_POSITIONAL=()
idx=0
while [ "$idx" -lt "${#SDD_ARGS[@]}" ]; do
  arg="${SDD_ARGS[$idx]}"
  case "$arg" in
    --mode)
      idx=$((idx + 1))
      [ "$idx" -lt "${#SDD_ARGS[@]}" ] || sdd_usage_error "init" "sdd init <feature-name> [--mode lite|full|normal|default|deep] [description]" "--mode requires one of: lite, full, normal, default, deep"
      MODE="${SDD_ARGS[$idx]}"
      ;;
    --mode=*)
      MODE="${arg#--mode=}"
      ;;
    --group)
      idx=$((idx + 1))
      [ "$idx" -lt "${#SDD_ARGS[@]}" ] || sdd_usage_error "init" "sdd init <feature-name> --group <path>" "--group requires a relative group path"
      GROUP_PATH="${SDD_ARGS[$idx]}"
      ;;
    --group=*)
      GROUP_PATH="${arg#--group=}"
      ;;
    --*)
      sdd_usage_error "init" "sdd init <feature-name> [--group <path>] [--mode lite|full|normal|default|deep] [description]" "unknown init flag '$arg'"
      ;;
    *)
      INIT_POSITIONAL+=("$arg")
      ;;
  esac
  idx=$((idx + 1))
done

MODE="$(sdd_normalize_mode_input "$MODE")" || sdd_usage_error "init" "sdd init <feature-name> [--group <path>] [--mode lite|full|normal|default|deep] [description]" "--mode must be lite or full (aliases: normal, default, deep)"

FEATURE_NAME="${INIT_POSITIONAL[0]:-}"
DESCRIPTION="${INIT_POSITIONAL[1]:-}"

[ -n "$FEATURE_NAME" ] || sdd_usage_error "init" "sdd init <feature-name> [--group <path>] [--mode lite|full|normal|default|deep] [description]" "feature name is required"

if ! echo "$FEATURE_NAME" | grep -qE '^[a-z][a-z0-9-]*$'; then
  sdd_usage_error "init" "sdd init <feature-name> [--group <path>] [--mode lite|full|normal|default|deep] [description]" "feature name must be kebab-case (lowercase, hyphens, starts with letter)"
fi

if [ -n "$GROUP_PATH" ]; then
  sdd_feature_ref_is_safe "$GROUP_PATH" || sdd_usage_error "init" "sdd init <feature-name> --group <path>" "group must be a safe relative path under .features"
  sdd_feature_path_has_wp_segment "$GROUP_PATH" && sdd_usage_error "init" "sdd init <feature-name> --group <path>" "group path must not contain wp-* segments"
  IFS='/' read -r -a GROUP_SEGMENTS <<< "$GROUP_PATH"
  for GROUP_SEGMENT in "${GROUP_SEGMENTS[@]}"; do
    case "$GROUP_SEGMENT" in
      -*)
        sdd_usage_error "init" "sdd init <feature-name> --group <path>" "group path segments must not start with '-'"
        ;;
      [0-9][0-9][0-9][0-9]-*)
        sdd_usage_error "init" "sdd init <feature-name> --group <path>" "group path segments must not look like feature IDs"
        ;;
    esac
  done
fi

NEXT_NUM=1
if [ -d "$SDD_FEATURE_ROOT" ]; then
  LAST_NUM="0"
  while IFS= read -r existing_feature_path; do
    [ -n "$existing_feature_path" ] || continue
    existing_feature="$(basename "$existing_feature_path")"
    case "$existing_feature" in
      [0-9][0-9][0-9][0-9]-*)
        existing_num="${existing_feature%%-*}"
        if [ "$existing_num" -gt "$LAST_NUM" ]; then
          LAST_NUM="$existing_num"
        fi
        ;;
    esac
  done <<EOF
$(sdd_iter_resolvable_feature_paths)
EOF
  NEXT_NUM=$((10#$LAST_NUM + 1))
fi

FEATURE_NUM="$(printf '%04d' "$NEXT_NUM")"
FEATURE_ID="${FEATURE_NUM}-${FEATURE_NAME}"
FEATURE_PATH="$FEATURE_ID"
[ -z "$GROUP_PATH" ] || FEATURE_PATH="$GROUP_PATH/$FEATURE_ID"
FEATURE_DIR="$SDD_FEATURE_ROOT/$FEATURE_PATH"
FEATURE_GROUP="$(sdd_feature_path_group "$FEATURE_PATH")"

sdd_extract_metadata "$FEATURE_ID"

if [ -d "$FEATURE_DIR" ]; then
  sdd_fail "init" "conflict" "feature '$FEATURE_ID' already exists" "{\"feature\":\"$FEATURE_ID\"}" "$FEATURE_ID" "arg"
fi

[ -d "$SDD_TEMPLATE_DIR" ] || sdd_fail "init" "internal" "templates directory not found at $SDD_TEMPLATE_DIR" "{\"templates\":\"$SDD_TEMPLATE_DIR\"}" "$FEATURE_ID" "arg"

if [ "$MODE" = "lite" ]; then
  required_templates="spec-lite.md tasks.md scratchpad.md continuity.md knowledge.md"
else
  required_templates="brief.md scratchpad.md continuity.md knowledge.md"
fi

for tmpl in $required_templates; do
  [ -f "$SDD_TEMPLATE_DIR/$tmpl" ] || sdd_fail "init" "internal" "template '$tmpl' not found in $SDD_TEMPLATE_DIR" "{\"template\":\"$tmpl\"}" "$FEATURE_ID" "arg"
done

mkdir -p "$FEATURE_DIR"
if [ "$MODE" = "lite" ]; then
  sdd_process_template "$SDD_TEMPLATE_DIR/spec-lite.md" "$FEATURE_DIR/spec.md" "$FEATURE_ID"
  sdd_process_template "$SDD_TEMPLATE_DIR/tasks.md" "$FEATURE_DIR/tasks.md" "$FEATURE_ID"
  sdd_portable_sed "$FEATURE_DIR/tasks.md" "s|^source: PLAN-|source: SPEC-|"
  sdd_portable_sed "$FEATURE_DIR/tasks.md" "s|\"derived_from\":\\[\"PLAN-|\"derived_from\":[\"SPEC-|"
  scope_tmp="$(sdd_tmp_for_target "$FEATURE_DIR/scope.txt")" || sdd_fail "init" "internal" "failed to create temp file for scope.txt" "{\"path\":\"$FEATURE_DIR/scope.txt\"}" "$FEATURE_ID" "arg"
  : > "$scope_tmp"
  sdd_atomic_replace "$scope_tmp" "$FEATURE_DIR/scope.txt" || sdd_fail "init" "internal" "failed to initialize scope.txt" "{\"path\":\"$FEATURE_DIR/scope.txt\"}" "$FEATURE_ID" "arg"
else
  sdd_process_template "$SDD_TEMPLATE_DIR/brief.md" "$FEATURE_DIR/brief.md" "$FEATURE_ID"
fi
sdd_process_template "$SDD_TEMPLATE_DIR/scratchpad.md" "$FEATURE_DIR/scratchpad.md" "$FEATURE_ID"
sdd_process_template "$SDD_TEMPLATE_DIR/continuity.md" "$FEATURE_DIR/continuity.md" "$FEATURE_ID"
sdd_process_template "$SDD_TEMPLATE_DIR/knowledge.md" "$FEATURE_DIR/knowledge.md" "$FEATURE_ID"

if [ -n "$DESCRIPTION" ]; then
  if [ "$MODE" = "lite" ]; then
    sdd_portable_sed "$FEATURE_DIR/spec.md" \
      "s|<!-- What problem is being solved, who feels it, and why this is worth doing now. -->|$DESCRIPTION|"
  else
    sdd_portable_sed "$FEATURE_DIR/brief.md" \
      "s|<!-- WHY does this need to exist? What's the driving force? What happens if we don't build this? -->|$DESCRIPTION|"
    sdd_portable_sed "$FEATURE_DIR/brief.md" \
      "s|<!-- One sentence reused by INDEX.md, status, handoff, and archive context. Prefer <= 200 chars. -->|$DESCRIPTION|"
  fi
  sdd_portable_sed "$FEATURE_DIR/continuity.md" \
    "s|<!-- What is this feature trying to achieve? One sentence. -->|$DESCRIPTION|"
fi

sdd_write_file_atomic "$FEATURE_DIR/state.json" "$(jq -nc --arg profile "$MODE" '{profile: $profile}')"

ACTIVE_FILE="$SDD_FEATURE_ROOT/.active"
PREV_SELECTION=""
if [ -f "$ACTIVE_FILE" ]; then
  read -r PREV_SELECTION < "$ACTIVE_FILE" 2>/dev/null || true
fi

ACTIVE_TMP="$(mktemp)"
printf '%s\n' "$FEATURE_PATH" > "$ACTIVE_TMP"
mv "$ACTIVE_TMP" "$ACTIVE_FILE"

# INDEX.md is rebuilt lazily by `sdd index` on next read; no eager rebuild here.
# Materialize feature-local derived state for tools that inspect state.json
# immediately after init.
bash "$SCRIPT_DIR/sdd-status.sh" --json "$FEATURE_PATH" >/dev/null

RESULT_LINE="Feature initialized and selected: $FEATURE_PATH"
if [ -n "$PREV_SELECTION" ] && [ "$PREV_SELECTION" != "$FEATURE_PATH" ]; then
  RESULT_LINE="$RESULT_LINE (previously $PREV_SELECTION)"
fi
if [ "$MODE" = "lite" ]; then
  INIT_PHASE="spec"
  CREATED_LINE="Created: $FEATURE_DIR/spec.md | $FEATURE_DIR/tasks.md | $FEATURE_DIR/scratchpad.md | $FEATURE_DIR/continuity.md | $FEATURE_DIR/knowledge.md | $FEATURE_DIR/scope.txt"
  IDS_LINE="IDs: SPEC-$FEATURE_NUM | TASKS-$FEATURE_NUM | REVIEW-$FEATURE_NUM"
  NEXT_LINE="Next: fill spec.md with FRs/ACs and tasks.md with Approach + concrete tasks."
  GATE_LINE="Gate: production code is valid only after spec.md and tasks.md are populated."
  PITFALL_LINE="Pitfall: do not create brief.md, research.md, plan.md, or trace.json for lite features."
  REF_LINE=""
  GUIDANCE_JSON="$(sdd_json_guidance "fill spec.md with the problem, FRs, ACs, constraints, and compact codebase notes; fill tasks.md with Approach and concrete T-xxx tasks." "implementation is valid only after spec.md and tasks.md are populated." "do not create full-mode brief/research/plan/trace artifacts for lite features.")"
else
  INIT_PHASE="brief"
  CREATED_LINE="Created: $FEATURE_DIR/brief.md | $FEATURE_DIR/scratchpad.md | $FEATURE_DIR/continuity.md | $FEATURE_DIR/knowledge.md"
  IDS_LINE="IDs: BRIEF-$FEATURE_NUM | SPEC-$FEATURE_NUM | RESEARCH-$FEATURE_NUM | PLAN-$FEATURE_NUM | TASKS-$FEATURE_NUM | REVIEW-$FEATURE_NUM"
  NEXT_LINE="Next: run Brief in lean intent-extraction mode — gather context first (CLAUDE.md, INDEX, scoped repo), propose ideas or draft inferable sections, then ask only intent-level questions (Motivation, Vision) with a soft cap of ~3."
  GATE_LINE="Gate: \`sdd spec $FEATURE_PATH\` is valid when all 5 sections (Motivation, Problem, Vision, Context, Constraints) have substantive non-comment content — Problem/Context/Constraints may be filled by interpretation labeled with source."
  PITFALL_LINE="Pitfall: do not ask code-logic, research-phase, or inspectable questions; do not pad the Q&A Record with one question per section."
  REF_LINE="$(sdd_phase_reference_line "brief")"
  GUIDANCE_JSON="$(sdd_json_guidance "run Brief in lean intent-extraction mode: gather context (CLAUDE.md, .features/INDEX.md, scoped repo files) before engaging; propose options or draft inferable sections (Problem, Context, Constraints) from inference and label with source; ask only intent-level questions; soft cap ~3 questions, each paired with a **Recommended**: line. Forbidden: research/plan-phase questions, code-logic questions, questions answerable by inspection." "\`sdd spec $FEATURE_PATH\` is valid when all 5 sections have substantive non-comment content (inferred content labeled <!-- inferred from <source> --> counts)." "do not ask code-logic or research-phase questions; do not ask one question per section; do not fabricate inferred content without a source label.")"
fi

if sdd_is_json_mode; then
  DATA_JSON="$(jq -nc \
    --arg feature_id "$FEATURE_ID" \
    --arg feature_path "$FEATURE_PATH" \
    --arg feature_dir "$FEATURE_DIR" \
    --arg feature_group "$FEATURE_GROUP" \
    --arg profile "$MODE" \
    --arg previous_selection "$PREV_SELECTION" \
    --arg brief "$FEATURE_DIR/brief.md" \
    --arg spec "$FEATURE_DIR/spec.md" \
    --arg tasks "$FEATURE_DIR/tasks.md" \
    --arg scratchpad "$FEATURE_DIR/scratchpad.md" \
    --arg continuity "$FEATURE_DIR/continuity.md" \
    --arg knowledge "$FEATURE_DIR/knowledge.md" \
    --arg scope "$FEATURE_DIR/scope.txt" \
    --arg feature_num "$FEATURE_NUM" \
    '{
      feature_id: $feature_id,
      feature_path: $feature_path,
      feature_dir: $feature_dir,
      feature_group: (if $feature_group == "" then null else $feature_group end),
      profile: $profile,
      previous_selection: (if $previous_selection == "" then null else $previous_selection end),
      files: (if $profile == "lite" then {
        spec: $spec,
        tasks: $tasks,
        scratchpad: $scratchpad,
        continuity: $continuity,
        knowledge: $knowledge,
        scope: $scope
      } else {
        brief: $brief,
        scratchpad: $scratchpad,
        continuity: $continuity,
        knowledge: $knowledge
      } end),
      ids: {
        brief: ("BRIEF-" + $feature_num),
        spec: ("SPEC-" + $feature_num),
        research: ("RESEARCH-" + $feature_num),
        plan: ("PLAN-" + $feature_num),
        tasks: ("TASKS-" + $feature_num),
        review: ("REVIEW-" + $feature_num)
      }
    }')"
  sdd_emit_json_selection "$(sdd_json_success "init" "$FEATURE_ID" "arg" "$INIT_PHASE" "$DATA_JSON" "$GUIDANCE_JSON" '[]')"
  cat >&2 <<EOF
$RESULT_LINE
$CREATED_LINE
$IDS_LINE
EOF
  cat >&2 <<EOF
$NEXT_LINE
$GATE_LINE
$PITFALL_LINE
EOF
  if [ -n "$REF_LINE" ]; then
    printf '%s\n' "$REF_LINE" >&2
  fi
  exit 0
fi

cat <<EOF
$RESULT_LINE
$CREATED_LINE
$IDS_LINE
$NEXT_LINE
$GATE_LINE
$PITFALL_LINE
EOF
if [ -n "$REF_LINE" ]; then
  printf '%s\n' "$REF_LINE"
fi
