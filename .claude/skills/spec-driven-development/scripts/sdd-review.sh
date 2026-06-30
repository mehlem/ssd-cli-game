#!/usr/bin/env bash
# sdd-review.sh — Scaffold review.md from template, auto-populate ACs from spec.md
# Usage:
#   sdd-review.sh <feature-id>                      — feature-level review
#   sdd-review.sh --wp <wp-id> <feature-id>         — WP-scoped review

set -euo pipefail

FEATURE_ROOT=".features"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$SKILL_DIR/templates"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "review" "sdd review [--wp <wp-id>] <feature-id>" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "review" \
      "Scaffold review.md, or assemble and merge typed review adjudication." \
      "sdd review [adjudicate] [--wp <id>] <feature-id> [--feature <id|auto>] [--format text|json] [--non-interactive] [--on-exists fail|overwrite|skip]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd review 0001-user-auth",
        "sdd review adjudicate 0001-user-auth",
        "sdd review --wp wp-01-auth 0002-feature",
        "sdd review --json --feature auto"
      ]'
    return 0
  fi

  echo "Usage: sdd review [adjudicate] [--wp <wp-id>] <feature-id>"
  echo ""
  echo "Scaffold review.md for a feature or work package, or adjudicate typed review evidence."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

build_forwarded_args() {
  FORWARDED_ARGS=()
  [ "$SDD_HELP" = "1" ] && FORWARDED_ARGS+=("--help")
  case "$SDD_OUTPUT_FORMAT" in
    json) FORWARDED_ARGS+=("--json") ;;
    text) ;;
  esac
  [ -n "$SDD_FEATURE_OVERRIDE" ] && FORWARDED_ARGS+=("--feature" "$SDD_FEATURE_OVERRIDE")
  [ "$SDD_NON_INTERACTIVE" = "1" ] && FORWARDED_ARGS+=("--non-interactive")
  [ -n "$SDD_ON_EXISTS" ] && FORWARDED_ARGS+=("--on-exists" "$SDD_ON_EXISTS")
  [ -n "$SDD_FIELD" ] && FORWARDED_ARGS+=("--field" "$SDD_FIELD")
  [ -n "$SDD_JQ_EXPR" ] && FORWARDED_ARGS+=("--jq" "$SDD_JQ_EXPR")
  return 0
}

if [ "${SDD_ARGS[0]:-}" = "adjudicate" ]; then
  build_forwarded_args
  if [ "${#SDD_ARGS[@]}" -gt 1 ]; then
    FORWARDED_ARGS+=("${SDD_ARGS[@]:1}")
  fi
  exec bash "$SCRIPT_DIR/sdd-review-adjudicate.sh" "${FORWARDED_ARGS[@]}"
fi

# --- Parse --wp flag ---

WP_ID=""
if [ "${#SDD_ARGS[@]}" -gt 0 ]; then
  set -- "${SDD_ARGS[@]}"
else
  set --
fi
if [ "${1:-}" = "--wp" ]; then
  WP_ID="${2:-}"
  if [ -z "$WP_ID" ]; then
    sdd_usage_error "review" "sdd review [--wp <wp-id>] <feature-id>" "--wp requires a WP ID (e.g. wp-01-auth-layer)"
  fi
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
feature_path="${SDD_RESOLVED_FEATURE_PATH:-$feature}"
feature_dir="${SDD_RESOLVED_FEATURE_DIR:-$FEATURE_ROOT/$feature_path}"

FEATURE_DIR="$feature_dir"
spec="$FEATURE_DIR/spec.md"

if [ ! -d "$FEATURE_DIR" ]; then
  sdd_fail "review" "not_found" "feature directory '$FEATURE_DIR' not found" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

if [ ! -f "$spec" ]; then
  sdd_fail "review" "precondition" "spec.md not found — cannot generate review without acceptance criteria" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

# Cleanup temp files on exit
trap 'rm -f "${ac_tmp:-}" "${tmp:-}" "${scope_tmp:-}" "${scope_rows_tmp:-}" "${coverage_tmp:-}"' EXIT

# --- Scope Conformance pre-fill ---
# populate_scope_conformance <review_file> <feature_dir>
#   Reads expected files from <feature_dir>/research.md Affected Files table
#   Reads actual changes from <feature_dir>/changes.log (if present)
#   Replaces the [scope-from-research] placeholder row with real rows
populate_scope_conformance() {
  local review_file="$1"
  local feature_dir="$2"
  local wp_tasks_file="${3:-}"
  local research_file="$feature_dir/research.md"
  local changes_file="$feature_dir/changes.log"

  scope_rows_tmp="$(mktemp)"

  # Extract expected files from research.md Affected Files section
  local expected_files=""
  if [ -n "$wp_tasks_file" ] && [ -f "$wp_tasks_file" ]; then
    expected_files="$(sdd_review_wp_task_files "$wp_tasks_file" || true)"
  elif [ -f "$research_file" ]; then
    expected_files="$(sdd_affected_files_paths "$research_file" || true)"
  fi

  # Extract unique actual change paths from changes.log, normalized to relative paths
  local changed_files=""
  if [ -f "$changes_file" ]; then
    local project_dir
    project_dir="$(cd "${CLAUDE_PROJECT_DIR:-.}" && pwd)"
    changed_files="$(awk -F' \\| ' '{gsub(/^ +| +$/,"",$3); if ($3 != "") print $3}' "$changes_file" 2>/dev/null | sed "s|^${project_dir}/||" | while IFS= read -r changed_path; do
      [ -n "$changed_path" ] || continue
      if [ -n "$wp_tasks_file" ] && sdd_review_is_workflow_artifact_path "$feature_dir" "$changed_path"; then
        continue
      fi
      printf '%s\n' "$changed_path"
    done | sort -u || true)"
  fi

  # Graceful degradation: neither source available
  if [ -z "$expected_files" ] && [ -z "$changed_files" ]; then
    if [ ! -f "$research_file" ]; then
      echo "| (no research.md found) | — | — | — | — |" > "$scope_rows_tmp"
    else
      echo "| (no affected files in research.md) | — | — | — | — |" > "$scope_rows_tmp"
    fi
    _apply_scope_rows "$review_file" "$scope_rows_tmp"
    return
  fi

  # Build rows: iterate expected files, check against changed set
  local all_expected_processed=""
  while IFS= read -r efile; do
    [ -z "$efile" ] && continue
    local was_changed="—"
    if [ -n "$changed_files" ] && echo "$changed_files" | grep -qxF "$efile"; then
      was_changed="yes"
    fi
    if [ "$was_changed" = "yes" ]; then
      printf '| %s | yes | yes | expected | |\n' "$efile" >> "$scope_rows_tmp"
    else
      printf '| %s | yes | — | expected | |\n' "$efile" >> "$scope_rows_tmp"
    fi
    all_expected_processed="${all_expected_processed}${efile}"$'\n'
  done <<< "$expected_files"

  # For each actually changed file not in expected: mark as unexpected
  if [ -n "$changed_files" ]; then
    while IFS= read -r cfile; do
      [ -z "$cfile" ] && continue
      if ! echo "$all_expected_processed" | grep -qxF "$cfile"; then
        printf '| %s | — | yes | unexpected | |\n' "$cfile" >> "$scope_rows_tmp"
      fi
    done <<< "$changed_files"
  fi

  # If scope_rows_tmp is empty (edge case: both sources had content but no rows), add comment
  if [ ! -s "$scope_rows_tmp" ]; then
    echo "| (no affected files in research.md) | — | — | — | — |" > "$scope_rows_tmp"
  fi

  _apply_scope_rows "$review_file" "$scope_rows_tmp"
}

# _apply_scope_rows <review_file> <rows_tmp>
#   Replaces the [scope-from-research] placeholder row with contents of rows_tmp
_apply_scope_rows() {
  local review_file="$1"
  local rows_tmp="$2"
  scope_tmp="$(sdd_tmp_for_target "$review_file")"
  while IFS= read -r line; do
    if echo "$line" | grep -q '\[scope-from-research\]'; then
      cat "$rows_tmp"
    else
      echo "$line"
    fi
  done < "$review_file" > "$scope_tmp"
  sdd_atomic_replace "$scope_tmp" "$review_file"
}

sdd_review_unique_lines() {
  awk 'NF && !seen[$0]++'
}

sdd_review_join_lines() {
  awk 'NF { if (seen) printf ", "; printf "%s", $0; seen = 1 }'
}

sdd_review_plan_acceptance_for_phase() {
  local plan_file="$1" phase="$2"
  [ -f "$plan_file" ] || return 0

  while IFS= read -r raw_ids; do
    [ -n "$raw_ids" ] || continue
    sdd_parse_id_list "$raw_ids" | jq -r '.[]?'
  done < <(
    awk -v wanted="$phase" '
      /^```/ { in_fence = !in_fence; next }
      in_fence { next }
      /^### PH-[0-9]+:/ {
        current = $0
        sub(/^### /, "", current)
        sub(/:.*/, "", current)
        next
      }
      current == wanted && /^> Acceptance: / {
        print substr($0, 15)
        next
      }
      current == wanted && /^> Addresses: / {
        payload = substr($0, 14)
        marker_pos = index(payload, "Acceptance:")
        if (marker_pos > 0) print substr(payload, marker_pos + length("Acceptance:"))
      }
    ' "$plan_file"
  ) | sdd_review_unique_lines
}

sdd_review_plan_acceptance_all() {
  local plan_file="$1"
  [ -f "$plan_file" ] || return 0

  while IFS= read -r raw_ids; do
    [ -n "$raw_ids" ] || continue
    sdd_parse_id_list "$raw_ids" | jq -r '.[]?'
  done < <(
    awk '
      /^```/ { in_fence = !in_fence; next }
      in_fence { next }
      /^> Acceptance: / {
        print substr($0, 15)
        next
      }
      /^> Addresses: / {
        payload = substr($0, 14)
        marker_pos = index(payload, "Acceptance:")
        if (marker_pos > 0) print substr(payload, marker_pos + length("Acceptance:"))
      }
    ' "$plan_file"
  ) | sdd_review_unique_lines
}

sdd_review_wp_task_phase_ids() {
  local tasks_file="$1"
  sdd_task_rows_json "$tasks_file" | jq -r '.[] | .phase // empty' | sdd_review_unique_lines
}

sdd_review_wp_task_implements_ids() {
  local tasks_file="$1" raw_ids
  while IFS= read -r raw_ids; do
    [ -n "$raw_ids" ] || continue
    sdd_parse_id_list "$raw_ids" | jq -r '.[]?'
  done < <(sdd_task_rows_json "$tasks_file" | jq -r '.[] | .implements_raw // empty') | sdd_review_unique_lines
}

sdd_review_clean_file_ref() {
  sed -E 's/^[[:space:]]+|[[:space:]]+$//g; s/`//g; s|^\./||; s/[[:space:]]+\((create|modify|delete|review)\)[[:space:]]*$//'
}

sdd_review_wp_task_files() {
  local tasks_file="$1" raw_files
  while IFS= read -r raw_files; do
    [ -n "$raw_files" ] || continue
    sdd_parse_id_list "$raw_files" | jq -r '.[]?'
  done < <(sdd_task_rows_json "$tasks_file" | jq -r '.[] | .files_raw // empty') | sdd_review_clean_file_ref | sdd_review_unique_lines
}

sdd_review_is_workflow_artifact_path() {
  local feature_dir="$1" path="$2"
  local normalized="${path#./}"
  case "$normalized" in
    "$feature_dir"/brief.md|"$feature_dir"/spec.md|"$feature_dir"/research.md|"$feature_dir"/plan.md|"$feature_dir"/tasks.md|"$feature_dir"/review.md|"$feature_dir"/scratchpad.md|"$feature_dir"/continuity.md|"$feature_dir"/knowledge.md|"$feature_dir"/state.json|"$feature_dir"/summary.md|"$feature_dir"/handoff.md|"$feature_dir"/trace.json|"$feature_dir"/scope.txt|"$feature_dir"/changes.log)
      return 0
      ;;
    "$feature_dir"/wp-*/tasks.md|"$feature_dir"/wp-*/review.md|"$feature_dir"/wp-*/scratchpad.md|"$feature_dir"/wp-*/continuity.md)
      return 0
      ;;
  esac
  return 1
}

sdd_review_spec_ac_row() {
  local spec_file="$1" wanted="$2"
  sdd_parse_id_rows_tsv AC "$spec_file" headings | awk -F '\t' -v wanted="$wanted" '$1 == wanted { print; exit }'
}

sdd_review_insert_wp_scope_context() {
  local review_file="$1" phases="$2" fr_ids="$3"
  tmp="$(sdd_tmp_for_target "$review_file")"
  while IFS= read -r line; do
    if [ "$line" = "## Acceptance Criteria Validation" ]; then
      printf '## Work Package Scope Context\n\n'
      printf '| Field | Values |\n'
      printf '|:------|:-------|\n'
      printf '| Task phases | %s |\n' "${phases:-—}"
      printf '| Implements | %s |\n\n' "${fr_ids:-—}"
    fi
    echo "$line"
  done < "$review_file" > "$tmp"
  sdd_atomic_replace "$tmp" "$review_file"
}

sdd_review_replace_wp_ac_rows() {
  local review_file="$1" spec_file="$2" scoped_ids="$3" unmapped_ids="$4"
  local rows_tmp unmapped_tmp ac_id ac_row ac_desc scoped_count=0 unmapped_count=0

  rows_tmp="$(mktemp)"
  while IFS= read -r ac_id; do
    [ -n "$ac_id" ] || continue
    ac_row="$(sdd_review_spec_ac_row "$spec_file" "$ac_id")"
    [ -n "$ac_row" ] || continue
    ac_desc="$(printf '%s\n' "$ac_row" | awk -F '\t' '{ print $3 }')"
    printf '| %s | %s | — | — |\n' "$ac_id" "$ac_desc" >> "$rows_tmp"
    scoped_count=$((scoped_count + 1))
  done <<< "$scoped_ids"

  if [ "$scoped_count" -eq 0 ]; then
    printf '| (none scoped) | No ACs mapped to this work package task phases. | — | — |\n' > "$rows_tmp"
  fi

  tmp="$(sdd_tmp_for_target "$review_file")"
  while IFS= read -r line; do
    if echo "$line" | grep -q '| AC-001 | \[from spec.md\]'; then
      cat "$rows_tmp"
    else
      echo "$line"
    fi
  done < "$review_file" > "$tmp"
  sdd_atomic_replace "$tmp" "$review_file"
  rm -f "$rows_tmp"

  unmapped_tmp="$(mktemp)"
  while IFS= read -r ac_id; do
    [ -n "$ac_id" ] || continue
    ac_row="$(sdd_review_spec_ac_row "$spec_file" "$ac_id")"
    [ -n "$ac_row" ] || continue
    ac_desc="$(printf '%s\n' "$ac_row" | awk -F '\t' '{ print $3 }')"
    printf '| %s | %s | Not mapped to a plan phase. |\n' "$ac_id" "$ac_desc" >> "$unmapped_tmp"
    unmapped_count=$((unmapped_count + 1))
  done <<< "$unmapped_ids"

  if [ "$unmapped_count" -gt 0 ]; then
    tmp="$(sdd_tmp_for_target "$review_file")"
    while IFS= read -r line; do
      if [ "$line" = "## Code Quality" ]; then
        printf '## Unmapped Acceptance Criteria\n\n'
        printf '| AC | Description | Reason |\n'
        printf '|:---|:------------|:-------|\n'
        cat "$unmapped_tmp"
        printf '\n'
      fi
      echo "$line"
    done < "$review_file" > "$tmp"
    sdd_atomic_replace "$tmp" "$review_file"
  fi
  rm -f "$unmapped_tmp"

  printf '%s\n' "$scoped_count"
}

emit_review_success() {
  local review_path="$1"
  local review_id="$2"
  local ac_count="$3"
  local context_line="${4:-}"
  local ref_line
  local data_json guidance_json
  local next_line="validate each AC against actual code and tests; every PASS or FAIL needs concrete evidence."
  local delegate_line
  local phase_skill_line
  local status_update_lines
  local status_updates_json="${STATUS_UPDATES_JSON:-[]}"

  delegate_line="Delegate (required): $(sdd_reviewer_dispatch_phrase). Self-review defeats the purpose of independent verification."

  ref_line="$(sdd_phase_reference_line "review")"
  phase_skill_line="$(sdd_phase_skill_cli_hint review)"
  status_update_lines="$(sdd_status_updates_text "$status_updates_json")"
  if sdd_autonomy_is_on "$feature_path"; then
    next_line="Continue autonomously through AC validation, then run sdd close $feature_path on PASS; halt only on listed blockers."
  fi

  if sdd_is_json_mode; then
    data_json="$(jq -nc \
      --arg action "${REVIEW_ACTION:-create}" \
      --arg feature "$feature" \
      --arg feature_path "$feature_path" \
      --arg feature_dir "$FEATURE_DIR" \
      --arg review_path "$review_path" \
      --arg review_id "$review_id" \
      --arg context_line "$context_line" \
      --argjson ac_count "$ac_count" \
      --argjson status_updates "$status_updates_json" \
      '{
        action: $action,
        feature: $feature,
        feature_id: $feature,
        feature_path: $feature_path,
        feature_dir: $feature_dir,
        review_path: $review_path,
        review_id: $review_id,
        acceptance_criteria_count: $ac_count,
        context: (if $context_line == "" then null else $context_line end),
        status_updates: $status_updates
      }')"
    guidance_json="$(jq -nc --arg next "$next_line" --arg worker "$delegate_line" '{"worker":$worker,"next":$next,"gate":"`sdd close` is valid when verdict is not pending and the AC table has at least 1 PASS or FAIL row.","pitfall":"review is not silent implementation - record failures first, then return deliberately to implement."}')"
    sdd_emit_json_selection "$(sdd_json_success "review" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "review" "$data_json" "$guidance_json" '[]')"
    if [ "${REVIEW_ACTION:-}" = "skip" ]; then
      echo "Skipped." >&2
    else
      printf 'Created: %s (%s)\n' "$review_path" "$review_id" >&2
      if [ -n "$status_update_lines" ]; then
        printf '%s\n' "$status_update_lines" >&2
      fi
      if [ -n "$context_line" ]; then
        printf 'Imported: %s acceptance criteria from spec.md | %s\n' "$ac_count" "$context_line" >&2
      else
        printf 'Imported: %s acceptance criteria from spec.md\n' "$ac_count" >&2
      fi
      printf '%s\n' "$delegate_line" >&2
      printf 'Next: %s\n' "$next_line" >&2
      if [ -n "$phase_skill_line" ]; then
        printf '%s\n' "$phase_skill_line" >&2
      fi
      printf 'Gate: `sdd close %s` is valid when verdict is not pending and the AC table has at least 1 PASS or FAIL row.\n' "$feature_path" >&2
      printf 'Pitfall: review is not silent implementation - record failures first, then return deliberately to implement.\n' >&2
      if [ -n "$ref_line" ]; then
        printf '%s\n' "$ref_line" >&2
      fi
    fi
    return 0
  fi

  printf 'Created: %s (%s)\n' "$review_path" "$review_id"
  if [ -n "$status_update_lines" ]; then
    printf '%s\n' "$status_update_lines"
  fi
  if [ -n "$context_line" ]; then
    printf 'Imported: %s acceptance criteria from spec.md | %s\n' "$ac_count" "$context_line"
  else
    printf 'Imported: %s acceptance criteria from spec.md\n' "$ac_count"
  fi
  printf '%s\n' "$delegate_line"
  printf 'Next: %s\n' "$next_line"
  if [ -n "$phase_skill_line" ]; then
    printf '%s\n' "$phase_skill_line"
  fi
  printf 'Gate: `sdd close %s` is valid when verdict is not pending and the AC table has at least 1 PASS or FAIL row.\n' "$feature_path"
  printf 'Pitfall: review is not silent implementation - record failures first, then return deliberately to implement.\n'
  if [ -n "$ref_line" ]; then
    printf '%s\n' "$ref_line"
  fi
}

append_trace_coverage_section() {
  local review_file="$1"
  local feature_dir="$2"
  local coverage_json score summary_text

  [ -f "$feature_dir/trace.json" ] || return 0
  jq -e . "$feature_dir/trace.json" >/dev/null 2>&1 || return 0

  coverage_json="$(sdd_trace_coverage_evaluate "$feature_dir" "$(sdd_trace_rules_path)")"
  [ "$(printf '%s\n' "$coverage_json" | jq -r '.present')" = "true" ] || return 0

  coverage_tmp="$(mktemp)"
  score="$(printf '%s\n' "$coverage_json" | jq -r '.score')"
  summary_text="$(printf '%s\n' "$coverage_json" | jq -r '"\(.summary.rules_passed) passed / \(.summary.rules_failed) failed / \(.summary.rules_skipped) skipped rules"')"

  {
    echo "## Trace Coverage"
    echo ""
    echo "> Snapshot generated from \`trace.json\` at review scaffold time."
    echo "> Review validation coverage stays red until evidence is recorded in the AC table."
    echo ""
    echo "- **Trace score**: ${score}%"
    echo "- **Rule summary**: ${summary_text}"
    echo ""
    echo "| Rule | Status | Coverage | Gaps |"
    echo "|:-----|:-------|:---------|:-----|"
  } > "$coverage_tmp"

  while IFS=$'\t' read -r rule_id rule_status coverage_ratio rule_gaps; do
    [ -n "$rule_id" ] || continue
    printf '| %s | %s | %s | %s |\n' "$rule_id" "$rule_status" "$coverage_ratio" "$rule_gaps" >> "$coverage_tmp"
  done < <(
    printf '%s\n' "$coverage_json" | jq -r '
      .rules[]
      | [
          .id,
          .status,
          (if .applicable == 0 then "n/a" else ((.passed | tostring) + "/" + (.applicable | tostring)) end),
          (if (.gaps | length) > 0 then (.gaps | join("<br>")) elif (.note // "") != "" then .note else "—" end)
        ]
      | @tsv
    '
  )

  tmp="$(mktemp)"
  while IFS= read -r line; do
    if [ "$line" = "## Code Quality" ]; then
      cat "$coverage_tmp" >> "$tmp"
      echo "" >> "$tmp"
    fi
    echo "$line" >> "$tmp"
  done < "$review_file"
  mv "$tmp" "$review_file"
}

review_preflight_action() {
  local path="$1"
  local action
  action="$(sdd_existing_path_action "$path" "$path" 2>/dev/null)" || {
    sdd_fail "review" "conflict" "$(basename "$path") already exists" "{\"path\":\"$path\",\"policy\":\"$(sdd_effective_on_exists)\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  }
  printf '%s\n' "$action"
}

# --- Common metadata ---

FEATURE_NUM=$(echo "$feature" | grep -oE '^[0-9]+') || FEATURE_NUM=""
FEATURE_NAME="${feature#*-}"
TODAY="$(date +%Y-%m-%d)"

# Get title from spec.md
FEATURE_TITLE=$(grep '^title:' "$spec" 2>/dev/null | head -1 | sed 's/^title: *//' | tr -d '"' || true)
if [ -z "$FEATURE_TITLE" ]; then
  FEATURE_TITLE=$(echo "$FEATURE_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')
fi

# --- WP review path ---

if [ -n "$WP_ID" ]; then
  # Find the WP directory (exact match or prefix match)
  WP_DIR=""
  for candidate in "$FEATURE_DIR"/wp-*/; do
    [ -d "$candidate" ] || continue
    candidate_name="$(basename "$candidate")"
    if [ "$candidate_name" = "$WP_ID" ]; then
      WP_DIR="${candidate%/}"
      break
    fi
  done

  if [ -z "$WP_DIR" ]; then
    sdd_fail "review" "not_found" "WP directory '$WP_ID' not found in $FEATURE_DIR" "{\"wp\":\"$WP_ID\",\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi

  if [ ! -f "$WP_DIR/tasks.md" ]; then
    sdd_fail "review" "precondition" "tasks.md not found in $WP_DIR" "{\"wp\":\"$WP_ID\",\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi

  review="$WP_DIR/review.md"
  REVIEW_ACTION="$(review_preflight_action "$review")"
  if [ "$REVIEW_ACTION" = "skip" ]; then
    if sdd_is_json_mode; then
      emit_review_success "$review" "$(sdd_frontmatter_value "$review" id || echo "REVIEW-$FEATURE_NUM")" 0 "Scope: $(basename "$WP_DIR")"
    else
      echo "Skipped."
    fi
    exit 0
  fi

  # Derive WP name from directory name (strip wp-NN- prefix, title-case)
  WP_BASENAME="$(basename "$WP_DIR")"
  WP_NAME_RAW="${WP_BASENAME#wp-[0-9][0-9]-}"
  WP_NAME="$(echo "$WP_NAME_RAW" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')"

  # Mark WP tasks as completed (phase transition: Implement to Review)
  STATUS_UPDATES_JSON="$(sdd_complete_predecessor_status "$WP_DIR/tasks.md" "Implement to WP Review transition")" || \
    sdd_fail "review" "internal" "failed to mark WP tasks.md completed" "{\"path\":\"$WP_DIR/tasks.md\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

  # Scaffold from wp-review.md template
  cp "$TEMPLATE_DIR/wp-review.md" "$review"

  sdd_portable_sed "$review" \
    -e "s/{{FEATURE_ID}}/$feature/g" \
    -e "s/{{FEATURE_NUM}}/$FEATURE_NUM/g" \
    -e "s/{{WP_ID}}/$WP_BASENAME/g" \
    -e "s/{{WP_NAME}}/$WP_NAME/g" \
    -e "s/{{DATE}}/$TODAY/g"

  # Auto-populate scoped AC table from WP task phases and plan phase acceptance.
  WP_TASKS_FILE="$WP_DIR/tasks.md"
  WP_PHASE_IDS="$(sdd_review_wp_task_phase_ids "$WP_TASKS_FILE" || true)"
  WP_IMPLEMENT_IDS="$(sdd_review_wp_task_implements_ids "$WP_TASKS_FILE" || true)"
  WP_PHASE_CONTEXT="$(printf '%s\n' "$WP_PHASE_IDS" | sdd_review_join_lines)"
  WP_IMPLEMENT_CONTEXT="$(printf '%s\n' "$WP_IMPLEMENT_IDS" | sdd_review_join_lines)"
  sdd_review_insert_wp_scope_context "$review" "$WP_PHASE_CONTEXT" "$WP_IMPLEMENT_CONTEXT"

  scoped_ac_ids="$(
    while IFS= read -r phase_id; do
      [ -n "$phase_id" ] || continue
      sdd_review_plan_acceptance_for_phase "$FEATURE_DIR/plan.md" "$phase_id"
    done <<< "$WP_PHASE_IDS" | sdd_review_unique_lines
  )"
  mapped_ac_ids="$(sdd_review_plan_acceptance_all "$FEATURE_DIR/plan.md" || true)"
  unmapped_ac_ids="$(
    sdd_parse_id_rows_tsv AC "$spec" headings | awk -F '\t' '{ print $1 }' | while IFS= read -r ac_id; do
      [ -n "$ac_id" ] || continue
      if ! printf '%s\n' "$mapped_ac_ids" | grep -qxF "$ac_id"; then
        printf '%s\n' "$ac_id"
      fi
    done
  )"
  ac_count="$(sdd_review_replace_wp_ac_rows "$review" "$spec" "$scoped_ac_ids" "$unmapped_ac_ids")"

  # Populate Scope Conformance table from research.md and changes.log
  populate_scope_conformance "$review" "$FEATURE_DIR" "$WP_TASKS_FILE"

  REVIEW_ID="$(sdd_frontmatter_value "$review" id || true)"
  emit_review_success "$review" "${REVIEW_ID:-REVIEW-$FEATURE_NUM}" "$ac_count" "Scope: $WP_BASENAME"
  exit 0
fi

# --- Feature-level review (no --wp) ---

# Check if this is a WP-enabled feature
WP_DIRS="$(ls -d "$FEATURE_DIR"/wp-*/ 2>/dev/null | sort)" || true
if [ -n "$WP_DIRS" ]; then
  # WP mode: check all WP reviews before creating feature-level review
  all_pass=1
  REVIEW_ERRORS=""
  for wp_dir in $WP_DIRS; do
    wp_name="$(basename "$wp_dir")"
    wp_review="$wp_dir/review.md"
    if [ ! -f "$wp_review" ]; then
      REVIEW_ERRORS="${REVIEW_ERRORS}WP $wp_name has no review. Run: sdd review --wp $wp_name $feature_path"$'\n'
      all_pass=0
    else
      verdict="$(sdd_frontmatter_value "$wp_review" verdict || echo "pending")"
      if [ "$verdict" = "pass" ]; then
        continue
      fi
      REVIEW_ERRORS="${REVIEW_ERRORS}WP $wp_name review has verdict: $verdict. Fix the WP review before creating the feature-level review."$'\n'
      all_pass=0
    fi
  done

  if [ "$all_pass" -eq 0 ]; then
    sdd_fail "review" "precondition" "all WP reviews must have verdict: pass before the feature-level review can be created" "$(printf '%s' "$REVIEW_ERRORS" | jq -Rsc '{details: split("\n") | map(select(length > 0))}')" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi

  # All WPs passed — create feature-level review with rollup table
  review="$FEATURE_DIR/review.md"

  REVIEW_ACTION="$(review_preflight_action "$review")"
  if [ "$REVIEW_ACTION" = "skip" ]; then
    if sdd_is_json_mode; then
      emit_review_success "$review" "$(sdd_frontmatter_value "$review" id || echo "REVIEW-$FEATURE_NUM")" 0 "Rollup: $(echo "$WP_DIRS" | wc -l | tr -d ' ') passed WP reviews"
    else
      echo "Skipped."
    fi
    exit 0
  fi

  cp "$TEMPLATE_DIR/review.md" "$review"

  sdd_portable_sed "$review" \
    -e "s/{{FEATURE_ID}}/$feature/g" \
    -e "s/{{FEATURE_NUM}}/$FEATURE_NUM/g" \
    -e "s/{{FEATURE_NAME}}/$FEATURE_NAME/g" \
    -e "s/{{FEATURE_TITLE}}/$FEATURE_TITLE/g" \
    -e "s/{{DATE}}/$TODAY/g"

  # Build WP rollup section into a temp file
  rollup_tmp="$(mktemp)"
  printf '## Work Package Rollup\n\n' >> "$rollup_tmp"
  printf '| WP | Title | Verdict | Date |\n' >> "$rollup_tmp"
  printf '|:---|:------|:--------|:-----|\n' >> "$rollup_tmp"
  for wp_dir in $WP_DIRS; do
    wp_name="$(basename "$wp_dir")"
    wp_review_file="$wp_dir/review.md"
    wp_verdict="$(sdd_frontmatter_value "$wp_review_file" verdict || echo "pending")"
    wp_date="$(grep '^updated:' "$wp_review_file" 2>/dev/null | head -1 | cut -d' ' -f2)" || wp_date="$TODAY"
    wp_title_raw="${wp_name#wp-[0-9][0-9]-}"
    wp_title="$(echo "$wp_title_raw" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')"
    printf '| %s | %s | %s | %s |\n' "$wp_name" "$wp_title" "$wp_verdict" "$wp_date" >> "$rollup_tmp"
  done
  printf '\n## Integration Assessment\n\n' >> "$rollup_tmp"
  printf '| Check | Status | Notes |\n' >> "$rollup_tmp"
  printf '|:------|:-------|:------|\n' >> "$rollup_tmp"
  printf '| All WP interfaces compatible | — | |\n' >> "$rollup_tmp"
  printf '| End-to-end test suite passes | — | |\n' >> "$rollup_tmp"
  printf '| No cross-WP regressions | — | |\n' >> "$rollup_tmp"
  printf '\n' >> "$rollup_tmp"

  # Insert rollup section before the AC table using a line-by-line approach
  tmp="$(mktemp)"
  while IFS= read -r line; do
    if echo "$line" | grep -q '^## Acceptance Criteria'; then
      cat "$rollup_tmp"
    fi
    echo "$line"
  done < "$review" > "$tmp"
  mv "$tmp" "$review"
  rm -f "$rollup_tmp"

  # Auto-populate AC table
  ac_tmp="$(mktemp)"
  ac_count=0
  while IFS=$'\t' read -r ac_id _line ac_desc _checkbox; do
    [ -n "$ac_id" ] || continue
    ac_desc="$(sdd_markdown_table_cell_escape "$ac_desc")"
    echo "| ${ac_id} | ${ac_desc} | — | — |" >> "$ac_tmp"
    ac_count=$((ac_count + 1))
  done < <(sdd_parse_id_rows_tsv AC "$spec" headings)

  if [ "$ac_count" -gt 0 ]; then
    tmp="$(mktemp)"
    while IFS= read -r line; do
      if echo "$line" | grep -q '| AC-001 | \[from spec.md\]'; then
        cat "$ac_tmp"
      else
        echo "$line"
      fi
    done < "$review" > "$tmp"
    mv "$tmp" "$review"
  fi

  # Populate Scope Conformance table from research.md and changes.log
  populate_scope_conformance "$review" "$FEATURE_DIR"

  wp_count="$(echo "$WP_DIRS" | wc -l | tr -d ' ')"
  REVIEW_ID="$(sdd_frontmatter_value "$review" id || true)"
  emit_review_success "$review" "${REVIEW_ID:-REVIEW-$FEATURE_NUM}" "$ac_count" "Rollup: $wp_count passed WP reviews"
  exit 0
fi

# --- Standard (non-WP) feature review ---

review="$FEATURE_DIR/review.md"

if [ ! -f "$FEATURE_DIR/tasks.md" ]; then
  sdd_fail "review" "precondition" "tasks.md must exist before creating review.md" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
fi

REVIEW_ACTION="$(review_preflight_action "$review")"
if [ "$REVIEW_ACTION" = "skip" ]; then
  if sdd_is_json_mode; then
    emit_review_success "$review" "$(sdd_frontmatter_value "$review" id || echo "REVIEW-$FEATURE_NUM")" 0
  else
    echo "Skipped."
  fi
  exit 0
fi

# Mark tasks as completed (phase transition: Implement to Review)
STATUS_UPDATES_JSON="$(sdd_complete_predecessor_status "$FEATURE_DIR/tasks.md" "Implement to Review transition")" || \
  sdd_fail "review" "internal" "failed to mark tasks.md completed" "{\"path\":\"$FEATURE_DIR/tasks.md\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

# --- Scaffold from template ---

cp "$TEMPLATE_DIR/review.md" "$review"

sdd_portable_sed "$review" \
  -e "s/{{FEATURE_ID}}/$feature/g" \
  -e "s/{{FEATURE_NUM}}/$FEATURE_NUM/g" \
  -e "s/{{FEATURE_NAME}}/$FEATURE_NAME/g" \
  -e "s/{{FEATURE_TITLE}}/$FEATURE_TITLE/g" \
  -e "s/{{DATE}}/$TODAY/g"
sdd_stamp_based_on "$review" "SPEC-$FEATURE_NUM" "TASKS-$FEATURE_NUM"

# --- Auto-populate AC table from spec.md ---

# Build AC rows file from spec
ac_tmp="$(mktemp)"
ac_count=0
trace_present=0
if [ -f "$FEATURE_DIR/trace.json" ] && jq -e . "$FEATURE_DIR/trace.json" >/dev/null 2>&1; then
  trace_present=1
  while IFS=$'\t' read -r ac_id ac_desc; do
    [ -n "$ac_id" ] || continue
    ac_desc="$(sdd_markdown_table_cell_escape "$ac_desc")"
    echo "| ${ac_id} | ${ac_desc} | — | — |" >> "$ac_tmp"
    ac_count=$((ac_count + 1))
  done < <(
    jq -r '
      [.nodes | to_entries[] | select(.value.kind == "ac") | {id: .key, line: (.value.line // 0), title: (.value.title // .key)}]
      | sort_by(.line, .id)
      | .[]
      | [.id, .title]
      | @tsv
    ' "$FEATURE_DIR/trace.json"
  )
else
  while IFS=$'\t' read -r ac_id _line ac_desc _checkbox; do
    [ -n "$ac_id" ] || continue
    ac_desc="$(sdd_markdown_table_cell_escape "$ac_desc")"
    echo "| ${ac_id} | ${ac_desc} | — | — |" >> "$ac_tmp"
    ac_count=$((ac_count + 1))
  done < <(sdd_parse_id_rows_tsv AC "$spec" headings)
fi

# Replace the placeholder AC row with real ACs (line-by-line safe approach)
if [ "$ac_count" -gt 0 ]; then
  tmp="$(mktemp)"
  while IFS= read -r line; do
    if echo "$line" | grep -q '| AC-001 | \[from spec.md\]'; then
      cat "$ac_tmp"
    else
      echo "$line"
    fi
  done < "$review" > "$tmp"
  mv "$tmp" "$review"
fi

# Populate Scope Conformance table from research.md and changes.log
populate_scope_conformance "$review" "$FEATURE_DIR"

if [ "$trace_present" = "1" ]; then
  CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}" bash "$SCRIPT_DIR/sdd-trace.sh" refresh "$feature_path" >/dev/null 2>&1 || true
  append_trace_coverage_section "$review" "$FEATURE_DIR"
fi

REVIEW_ID="$(sdd_frontmatter_value "$review" id || true)"
emit_review_success "$review" "${REVIEW_ID:-REVIEW-$FEATURE_NUM}" "$ac_count"
