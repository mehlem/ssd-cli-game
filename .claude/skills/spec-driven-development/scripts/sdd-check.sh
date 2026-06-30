#!/usr/bin/env bash
# sdd-check.sh — Artifact readiness checks for phase transitions
# Usage: sdd-check.sh {brief|spec|research|plan|tasks|review|all} <feature-id>
# Exit: 0 = all checks pass (ready), 1 = one or more checks failed (gaps found)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FEATURE_ROOT=".features"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "check" "sdd check {brief|spec|research|plan|tasks|review|all} <feature-id>" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "check" \
      "Run readiness checks for one SDD artifact or for all artifacts in a feature." \
      "sdd check {brief|spec|research|plan|tasks|review|all} <feature-id> [--feature <id|auto>] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd check spec 0001-user-auth",
        "sdd check all --feature auto --json",
        "sdd check tasks --feature auto --field data.ready"
      ]'
    return 0
  fi

  echo "Usage: sdd check {brief|spec|research|plan|tasks|review|all} <feature-id>"
  echo ""
  echo "Run readiness checks for one SDD artifact or for all artifacts in a feature."
  echo "Structural checks remain authoritative; rubric documents in references/rubrics/*.md provide additive behavioral guidance."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

# --- Output helpers ---
USE_COLOR=1
sdd_is_json_mode && USE_COLOR=0

ok() {
  if [ "$USE_COLOR" = "1" ]; then
    printf "\033[32m✓\033[0m %s\n" "$1"
  else
    printf "OK %s\n" "$1"
  fi
}

fail_msg() {
  if [ "$USE_COLOR" = "1" ]; then
    printf "\033[31m✗\033[0m %s\n" "$1"
  else
    printf "FAIL %s\n" "$1"
  fi
}

gap() {
  printf "  - %s\n" "$1"
}

render_task_lint_warnings() {
  local lint_json="$1" warning_count
  warning_count="$(printf '%s\n' "$lint_json" | jq -r '.warning_count // 0')"
  [ "$warning_count" -gt 0 ] || return 0

  printf 'Warning: task Verification lint warnings:\n'
  printf '%s\n' "$lint_json" | jq -r '
    .findings[]
    | select(.severity == "warning")
    | "  * \(.task) \(.rule) [\(.severity)]: \(.message)\n    Suggestion: \(.suggestion)"
  '
}

sdd_bold_prefix_count() {
  local kind="$1" file="$2"
  [ -f "$file" ] || { echo 0; return 0; }

  awk -v kind="$kind" '
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    {
      line = $0
      if (kind == "AC") {
        if (line !~ /^- \[[ xX]\] \*\*AC-[0-9]+/) next
        sub(/^- \[[ xX]\] /, "", line)
      } else {
        if (line !~ "^- \\*\\*" kind "-[0-9]+") next
        sub(/^- /, "", line)
      }

      bold_after_re = "^\\*\\*" kind "-[0-9]+([[:space:]]+\\[[^]]+\\])?\\*\\*:"
      bold_inside_re = "^\\*\\*" kind "-[0-9]+([[:space:]]+\\[[^]]+\\])?:[^*]*\\*\\*"
      if (line ~ bold_after_re || line ~ bold_inside_re) {
        count++
      }
    }
    END { print count + 0 }
  ' "$file"
}

emit_bold_prefix_advisory() {
  local file="$1" kind="$2" canonical="$3" count
  count="$(sdd_bold_prefix_count "$kind" "$file")"
  [ "$count" -gt 0 ] || return 0
  printf 'Warning: advisory: %s uses %s bold-prefix %s identifier(s); canonical plain form is `%s`.\n' \
    "$(basename "$file")" "$count" "$kind" "$canonical" >&2
}

# --- Per-artifact check functions ---

check_brief() {
  local feature="$1"
  local file="$FEATURE_ROOT/$feature/brief.md"
  local gaps=()

  if [ ! -f "$file" ]; then
    fail_msg "brief: file not found ($file)"
    return 1
  fi

  # Check Motivation section has non-comment content
  if ! sdd_markdown_section_has_content "$file" "Motivation"; then
    gaps+=("Motivation section has no non-comment content")
  fi

  # Check Vision section has non-comment content
  if ! sdd_markdown_section_has_content "$file" "Vision"; then
    gaps+=("Vision section has no non-comment content")
  fi

  if [ "${#gaps[@]}" -eq 0 ]; then
    ok "brief: Ready for Design"
    return 0
  else
    fail_msg "brief: NOT ready for Design"
    local g
    for g in "${gaps[@]}"; do gap "$g"; done
    return 1
  fi
}

check_spec() {
  local feature="$1"
  local file="$FEATURE_ROOT/$feature/spec.md"
  local gaps=()

  if [ ! -f "$file" ]; then
    fail_msg "spec: file not found ($file)"
    return 1
  fi

  # Count FR-NNN lines outside fences
  local fr_count
  fr_count="$(sdd_count_id_lines FR "$file" headings)"
  emit_bold_prefix_advisory "$file" "FR" "- FR-NNN:"

  [ "$fr_count" -eq 0 ] && gaps+=("No FR-NNN lines found (need ≥1)")

  # Count AC-NNN lines outside fences
  local ac_count
  ac_count="$(sdd_count_id_lines AC "$file" headings)"
  emit_bold_prefix_advisory "$file" "AC" "- [ ] AC-NNN:"

  [ "$ac_count" -eq 0 ] && gaps+=("No AC-NNN lines found (need ≥1)")

  # Check Problem section has non-comment content
  local has_problem
  has_problem="$(awk '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^## Problem/ { in_section = 1; next }
    in_section && /^## / { in_section = 0; next }
    in_section && /^[[:space:]]*<!--/ { next }
    in_section && /^[[:space:]]*-->/ { next }
    in_section && /^[[:space:]]*$/ { next }
    in_section && /^[^<]/ { found = 1; exit }
    END { print found + 0 }
  ' "$file")"

  [ "$has_problem" = "0" ] && gaps+=("Problem section has no non-comment content")

  local next_phase_label="Research"
  if [ "$(sdd_profile "$feature")" = "lite" ]; then
    next_phase_label="Implement"
  fi
  if [ "${#gaps[@]}" -eq 0 ]; then
    ok "spec: Ready for $next_phase_label ($fr_count FRs, $ac_count ACs found)"
    return 0
  else
    fail_msg "spec: NOT ready for $next_phase_label"
    local g
    for g in "${gaps[@]}"; do gap "$g"; done
    return 1
  fi
}

check_research() {
  local feature="$1"
  local file="$FEATURE_ROOT/$feature/research.md"
  local gaps=()

  if [ ! -f "$file" ]; then
    fail_msg "research: file not found ($file)"
    return 1
  fi

  # Count valid Affected Files table rows outside fences, scoped to ## Affected Files section.
  # Valid rows have an explicit Action enum in column 2.
  local affected_counts row_count pipe_row_count
  affected_counts="$(awk '
    function trim(s) {
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      return s
    }
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^## Affected Files/ { in_section = 1; next }
    in_section && /^## / { in_section = 0; next }
    in_fence { next }
    in_section && /^\|/ {
      if ($0 ~ /^\|[[:space:]]*:?-+:?[[:space:]]*\|/) next
      split($0, cols, "|")
      first = trim(cols[2])
      action = trim(cols[3])
      if (first == "File" && action == "Action") next
      pipe_rows++
      if (action ~ /^(create|modify|delete|review)$/) count++
    }
    END { print count + 0, pipe_rows + 0 }
  ' "$file")"
  row_count="${affected_counts%% *}"
  pipe_row_count="${affected_counts##* }"

  if [ "$row_count" -eq 0 ]; then
    if [ "$pipe_row_count" -gt 0 ]; then
      gaps+=("Affected Files table has no valid Action column rows. Expected schema: | File | Action | Module | Impact | Relates To |")
    else
      gaps+=("Affected Files table has 0 valid rows (need ≥1 with create|modify|delete|review action)")
    fi
  fi

  # Check for Confidence section with verdict
  local has_confidence_section verdict_line
  has_confidence_section="$(awk '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^## Confidence/ { found = 1; exit }
    END { print found + 0 }
  ' "$file")"

  if [ "$has_confidence_section" = "0" ]; then
    gaps+=("No Confidence section found")
  else
    # Check for non-empty verdict line
    verdict_line="$(awk '
      /^```/ { in_fence = !in_fence; next }
      !in_fence && /^## Confidence/ { in_section = 1; next }
      in_section && /^## / { in_section = 0; next }
      in_section && /^\- ([*][*])?Verdict([*][*])?:/ {
        if ($0 ~ /(GO|HOLD)/) {
          found = 1
        }
        exit
      }
      END { print found + 0 }
    ' "$file")"
    [ "$verdict_line" = "0" ] && gaps+=("Confidence section has no verdict (need GO or HOLD)")
  fi

  if [ "$(sdd_profile "$feature")" = "deep" ]; then
    local research_depth_text parallel_scout_text
    research_depth_text="$(sdd_markdown_section_text "$file" "Research Depth")"
    parallel_scout_text="$(sdd_markdown_section_text "$file" "Parallel Scout Summary")"

    [ -z "$research_depth_text" ] && gaps+=("FR-010: Deep research requires substantive ## Research Depth section")
    if [ -n "$research_depth_text" ] && ! printf '%s\n' "$research_depth_text" | grep -qE '(^|[^[:alnum:]_])research_depth:[[:space:]]*deep([^[:alnum:]_]|$)'; then
      gaps+=("FR-010: ## Research Depth must include research_depth: deep marker")
    fi
    [ -z "$parallel_scout_text" ] && gaps+=("FR-010: Deep research requires substantive ## Parallel Scout Summary section")
  fi

  if [ "${#gaps[@]}" -eq 0 ]; then
    ok "research: Ready for Plan ($row_count Affected Files rows found)"
    return 0
  else
    fail_msg "research: NOT ready for Plan"
    local g
    for g in "${gaps[@]}"; do gap "$g"; done
    return 1
  fi
}

check_plan() {
  local feature="$1"
  local file="$FEATURE_ROOT/$feature/plan.md"
  local gaps=()

  if [ ! -f "$file" ]; then
    fail_msg "plan: file not found ($file)"
    return 1
  fi

  # Count PH-NN phase headings outside fences
  local ph_count
  ph_count="$(awk '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^### PH-[0-9]+:/ { count++ }
    END { print count + 0 }
  ' "$file")"

  [ "$ph_count" -eq 0 ] && gaps+=("No PH-NN phase headings found (need ≥1)")

  # Count AD-NNN lines outside fences
  local ad_count
  ad_count="$(sdd_count_id_lines AD "$file" headings)"
  emit_bold_prefix_advisory "$file" "AD" "- AD-NNN:"

  [ "$ad_count" -eq 0 ] && gaps+=("No AD-NNN architectural decision lines found (need ≥1)")

  if [ "$(sdd_profile "$feature")" = "deep" ]; then
    local must_haves_text
    must_haves_text="$(sdd_markdown_section_text "$file" "Must-haves")"
    [ -z "$must_haves_text" ] && gaps+=("FR-011: Deep plan requires substantive ## Must-haves section")
    [ "$ad_count" -eq 0 ] && gaps+=("FR-011: Deep plan requires at least one AD-NNN architectural decision")
  fi

  if [ "${#gaps[@]}" -eq 0 ]; then
    ok "plan: Ready for Tasks ($ph_count phases, $ad_count ADs found)"
    return 0
  else
    fail_msg "plan: NOT ready for Tasks"
    local g
    for g in "${gaps[@]}"; do gap "$g"; done
    return 1
  fi
}

check_tasks() {
  local feature="$1"
  local file="$FEATURE_ROOT/$feature/tasks.md"
  local profile
  local gaps=()

  if [ ! -f "$file" ]; then
    if sdd_feature_has_work_packages "$FEATURE_ROOT/$feature"; then
      check_wp_tasks "$feature"
      return $?
    fi
    fail_msg "tasks: file not found ($file)"
    return 1
  fi

  profile="$(sdd_profile "$feature")"
  if [ "$profile" = "lite" ] && ! sdd_tasks_file_has_approach_content "$file"; then
    gaps+=("Approach section has no non-comment bullet content")
  fi

  # Find all T-NNN task headings and check each has Status, Implements, and Verification
  local missing_status=0 missing_implements=0 missing_verification=0

  # Collect task heading line numbers
  local task_lines
  task_lines="$(awk '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^## T-[0-9]+:/ { print NR }
  ' "$file")"

  if [ -z "$task_lines" ]; then
    gaps+=("No task headings (## T-NNN:) found")
  else
    # For each task heading, check within the task's block
    local total_lines
    total_lines="$(awk 'END { print NR }' "$file")"

    while IFS= read -r task_line; do
      local next_task_line="$total_lines"
      # Find the next task boundary
      local found_next
      found_next="$(awk -v start="$task_line" '
        /^```/ { in_fence = !in_fence; next }
        !in_fence && NR > start && /^## T-[0-9]+:/ { print NR; exit }
        !in_fence && NR > start && /^\*\*\*/ { print NR; exit }
      ' "$file")"
      [ -n "$found_next" ] && next_task_line="$found_next"

      # Check for > Status: line
      local has_status
      has_status="$(awk -v start="$task_line" -v end="$next_task_line" '
        NR > start && NR < end && /^> Status:/ { found = 1; exit }
        END { print found + 0 }
      ' "$file")"
      [ "$has_status" = "0" ] && missing_status=$((missing_status + 1))

      # Check for > Implements: line
      local has_implements
      has_implements="$(awk -v start="$task_line" -v end="$next_task_line" '
        NR > start && NR < end && /^> Implements:/ { found = 1; exit }
        END { print found + 0 }
      ' "$file")"
      [ "$has_implements" = "0" ] && missing_implements=$((missing_implements + 1))

      # Check for ### Verification heading
      local has_verification
      has_verification="$(awk -v start="$task_line" -v end="$next_task_line" '
        NR > start && NR < end && /^### Verification/ { found = 1; exit }
        END { print found + 0 }
      ' "$file")"
      [ "$has_verification" = "0" ] && missing_verification=$((missing_verification + 1))

      if [ "$profile" = "deep" ]; then
        local task_id worker_strategy files_in_scope
        task_id="$(awk -v start="$task_line" 'NR == start { sub(/^## /, ""); sub(/:.*/, ""); print; exit }' "$file")"
        worker_strategy="$(awk -v start="$task_line" -v end="$next_task_line" '
          NR > start && NR < end && /^> Worker-strategy:/ {
            sub(/^> Worker-strategy:[[:space:]]*/, "")
            print
            exit
          }
        ' "$file")"
        files_in_scope="$(awk -v start="$task_line" -v end="$next_task_line" '
          NR > start && NR < end && /^> Files-in-scope:/ {
            sub(/^> Files-in-scope:[[:space:]]*/, "")
            print
            exit
          }
        ' "$file")"

        case "$worker_strategy" in
          inline|worker|parallel|sequential) ;;
          "") gaps+=("FR-012: ${task_id:-task} missing > Worker-strategy: inline | worker | parallel | sequential") ;;
          *) gaps+=("FR-012: ${task_id:-task} has invalid Worker-strategy '$worker_strategy' (expected inline | worker | parallel | sequential)") ;;
        esac

        case "$files_in_scope" in
          ""|"[]"|"[ ]") gaps+=("FR-012: ${task_id:-task} missing > Files-in-scope: with at least one path") ;;
        esac
      fi
    done <<< "$task_lines"

    [ "$missing_status" -gt 0 ] && gaps+=("$missing_status task(s) missing > Status: line")
    [ "$missing_implements" -gt 0 ] && gaps+=("$missing_implements task(s) missing > Implements: line")
    [ "$missing_verification" -gt 0 ] && gaps+=("$missing_verification task(s) missing ### Verification section")

    local graph_json dependency_problem=""
    graph_json="$(sdd_task_graph_json "$file")"
    while IFS= read -r dependency_problem; do
      [ -n "$dependency_problem" ] || continue
      gaps+=("$dependency_problem")
    done < <(printf '%s\n' "$graph_json" | jq -r '.problems[]?.message')
  fi

  local lint_json lint_warning_count lint_gap
  lint_json="$(sdd_task_verification_lint_json "$file" "$feature")"
  while IFS= read -r lint_gap; do
    [ -n "$lint_gap" ] || continue
    gaps+=("$lint_gap")
  done < <(printf '%s\n' "$lint_json" | jq -r '
    .findings[]
    | select(.severity == "error")
    | "\(.task) \(.rule) [\(.severity)]: \(.message) Suggestion: \(.suggestion)"
  ')
  lint_warning_count="$(printf '%s\n' "$lint_json" | jq -r '.warning_count // 0')"

  if [ "${#gaps[@]}" -eq 0 ]; then
    local task_count
    task_count="$(echo "$task_lines" | wc -l | tr -d ' ')"
    ok "tasks: Ready for Implement ($task_count tasks with complete metadata)"
    [ "$lint_warning_count" -gt 0 ] && render_task_lint_warnings "$lint_json"
    return 0
  else
    fail_msg "tasks: NOT ready for Implement"
    local g
    for g in "${gaps[@]}"; do gap "$g"; done
    [ "$lint_warning_count" -gt 0 ] && render_task_lint_warnings "$lint_json"
    return 1
  fi
}

check_wp_tasks() {
  local feature="$1"
  local feature_dir="$FEATURE_ROOT/$feature"
  local gaps=()
  local wp_dir wp_id tasks_file task_count wp_count=0 total_tasks=0

  for wp_dir in "$feature_dir"/wp-*/; do
    [ -d "$wp_dir" ] || continue
    wp_count=$((wp_count + 1))
    wp_id="$(basename "$wp_dir")"
    tasks_file="$wp_dir/tasks.md"

    if [ ! -f "$tasks_file" ]; then
      gaps+=("$wp_id/tasks.md is missing")
      continue
    fi

    task_count="$(sdd_count_task_headings "$tasks_file")"
    total_tasks=$((total_tasks + task_count))
    [ "$task_count" -eq 0 ] && gaps+=("$wp_id/tasks.md has no task headings (need ≥1)")

    local metadata_counts missing_status missing_implements missing_verification dependency_problem graph_json lint_json lint_gap
    metadata_counts="$(awk '
      function flush_task() {
        if (!in_task) return
        if (!has_status) missing_status++
        if (!has_implements) missing_implements++
        if (!has_verification) missing_verification++
      }
      /^```/ { in_fence = !in_fence; next }
      in_fence { next }
      /^## T-[0-9]+:/ {
        flush_task()
        in_task = 1
        has_status = 0
        has_implements = 0
        has_verification = 0
        next
      }
      in_task && /^> Status:/ { has_status = 1; next }
      in_task && /^> Implements:/ { has_implements = 1; next }
      in_task && /^### Verification/ { has_verification = 1; next }
      END {
        flush_task()
        printf "%d\t%d\t%d\n", missing_status + 0, missing_implements + 0, missing_verification + 0
      }
    ' "$tasks_file")"
    IFS=$'\t' read -r missing_status missing_implements missing_verification <<EOF
$metadata_counts
EOF
    [ "$missing_status" -gt 0 ] && gaps+=("$wp_id: $missing_status task(s) missing > Status: line")
    [ "$missing_implements" -gt 0 ] && gaps+=("$wp_id: $missing_implements task(s) missing > Implements: line")
    [ "$missing_verification" -gt 0 ] && gaps+=("$wp_id: $missing_verification task(s) missing ### Verification section")

    graph_json="$(sdd_task_graph_json "$tasks_file")"
    while IFS= read -r dependency_problem; do
      [ -n "$dependency_problem" ] || continue
      gaps+=("$wp_id: $dependency_problem")
    done < <(printf '%s\n' "$graph_json" | jq -r '.problems[]?.message')

    lint_json="$(sdd_task_verification_lint_json "$tasks_file" "$feature")"
    while IFS= read -r lint_gap; do
      [ -n "$lint_gap" ] || continue
      gaps+=("$wp_id: $lint_gap")
    done < <(printf '%s\n' "$lint_json" | jq -r '
      .findings[]
      | select(.severity == "error")
      | "\(.task) \(.rule) [\(.severity)]: \(.message) Suggestion: \(.suggestion)"
    ')
  done

  [ "$wp_count" -eq 0 ] && gaps+=("No work package task files found")

  if [ "${#gaps[@]}" -eq 0 ]; then
    ok "tasks: Ready for Implement ($total_tasks tasks across $wp_count work package(s))"
    return 0
  else
    fail_msg "tasks: NOT ready for Implement"
    local g
    for g in "${gaps[@]}"; do gap "$g"; done
    return 1
  fi
}

check_review() {
  local feature="$1"
  local file="$FEATURE_ROOT/$feature/review.md"
  local gaps=()
  local reviewer_warning=""

  if [ ! -f "$file" ]; then
    fail_msg "review: file not found ($file)"
    return 1
  fi

  # Check verdict is not "pending"
  local verdict
  verdict="$(sdd_frontmatter_value "$file" "verdict" || true)"
  if [ -z "$verdict" ] || [ "$verdict" = "pending" ]; then
    gaps+=("Frontmatter verdict is '${verdict:-empty}' (must be set to pass or fail)")
  fi

  # Check AC validation table has ≥1 row with PASS or FAIL
  local ac_row_count
  ac_row_count="$(sdd_review_ac_validation_count "$file")"

  [ "$ac_row_count" -eq 0 ] && gaps+=("AC validation table has 0 rows with PASS/FAIL status (need ≥1)")

  if [ "$(sdd_profile "$feature")" = "deep" ] && [ "$verdict" = "pass" ]; then
    local plan_check_text
    plan_check_text="$(sdd_markdown_section_text "$file" "Plan Check Evidence")"
    if [ -z "$plan_check_text" ]; then
      gaps+=("FR-013: Deep review pass requires substantive ## Plan Check Evidence citing sdd-spec-reviewer and sdd-quality-reviewer")
    else
      printf '%s\n' "$plan_check_text" | grep -q 'sdd-spec-reviewer' || gaps+=("FR-013: ## Plan Check Evidence must cite sdd-spec-reviewer result")
      printf '%s\n' "$plan_check_text" | grep -q 'sdd-quality-reviewer' || gaps+=("FR-013: ## Plan Check Evidence must cite sdd-quality-reviewer result")
    fi
  fi

  if [ "$(sdd_profile "$feature")" != "lite" ]; then
    local spec_file="$FEATURE_ROOT/$feature/spec.md"
    local tasks_file="$FEATURE_ROOT/$feature/tasks.md"
    local spec_ac_count=0
    local task_count=0
    local autonomy_on=0

    if [ -f "$spec_file" ]; then
      spec_ac_count="$(sdd_count_id_lines AC "$spec_file" headings)"
    fi

    task_count="$(sdd_count_task_headings "$tasks_file")"
    if sdd_autonomy_is_on "$feature"; then
      autonomy_on=1
    fi

    if { [ "$spec_ac_count" -ge 3 ] || [ "$task_count" -ge 5 ] || [ "$autonomy_on" -eq 1 ]; } && ! sdd_reviewer_dispatch_present "$feature"; then
      reviewer_warning="self-review is the failure mode the review phase exists to prevent; dispatch sdd-spec-reviewer + sdd-quality-reviewer before close, or accept deliberate self-review with sdd autonomy --self-reviewed $feature"
    fi
  fi

  if [ "${#gaps[@]}" -eq 0 ]; then
    [ -n "$reviewer_warning" ] && printf 'Warning: %s\n' "$reviewer_warning"
    ok "review: Ready for Close (verdict=$verdict, $ac_row_count AC rows)"
    return 0
  else
    fail_msg "review: NOT ready for Close"
    [ -n "$reviewer_warning" ] && printf 'Warning: %s\n' "$reviewer_warning"
    local g
    for g in "${gaps[@]}"; do gap "$g"; done
    return 1
  fi
}

check_coverage() {
  local feature="$1"
  local feature_dir="$FEATURE_ROOT/$feature"
  local trace_file rules_file coverage_json status score failing_rules

  trace_file="$(sdd_trace_path "$feature")"
  [ -f "$trace_file" ] || return 0
  jq -e . "$trace_file" >/dev/null 2>&1 || return 0

  rules_file="$(sdd_trace_rules_path)"
  coverage_json="$(sdd_trace_coverage_evaluate "$feature_dir" "$rules_file")"
  [ "$(printf '%s\n' "$coverage_json" | jq -r '.present')" = "true" ] || return 0

  status="$(printf '%s\n' "$coverage_json" | jq -r '.status')"
  score="$(printf '%s\n' "$coverage_json" | jq -r '.score')"
  failing_rules="$(printf '%s\n' "$coverage_json" | jq -r '.summary.rules_failed')"

  if [ "$status" = "PASS" ]; then
    ok "coverage: Trace coverage score ${score}%"
    return 0
  fi

  if [ "$status" = "SKIP" ]; then
    return 0
  fi

  fail_msg "coverage: Trace coverage score ${score}% (${failing_rules} failing rule(s), informational only)"
  while IFS= read -r coverage_gap; do
    [ -n "$coverage_gap" ] || continue
    gap "$coverage_gap"
  done < <(
    printf '%s\n' "$coverage_json" | jq -r '
      .rules[]
      | select(.status == "FAIL")
      | .id as $rule_id
      | .gaps[]?
      | "\($rule_id): \(.)"
    '
  )

  return 0
}

check_work_packages() {
  local feature="$1"
  local feature_dir="$FEATURE_ROOT/$feature"
  local summary_json wp_count scaffold incomplete missing_review failing_review
  local gaps=()

  sdd_feature_has_work_packages "$feature_dir" || return 0

  summary_json="$(sdd_feature_wp_review_summary_json "$feature_dir")"
  wp_count="$(printf '%s\n' "$summary_json" | jq -r '.work_package_count // 0')"
  scaffold="$(printf '%s\n' "$summary_json" | jq -r '.scaffold // 0')"
  incomplete="$(printf '%s\n' "$summary_json" | jq -r '.incomplete_tasks // 0')"
  missing_review="$(printf '%s\n' "$summary_json" | jq -r '.missing_review // 0')"
  failing_review="$(printf '%s\n' "$summary_json" | jq -r '.failing_review // 0')"

  [ "$wp_count" -eq 0 ] && return 0
  [ "$scaffold" -gt 0 ] && gaps+=("$scaffold work package(s) missing tasks.md")
  [ "$incomplete" -gt 0 ] && gaps+=("$incomplete work package(s) have incomplete tasks")
  [ "$missing_review" -gt 0 ] && gaps+=("$missing_review work package review file(s) missing")
  [ "$failing_review" -gt 0 ] && gaps+=("$failing_review work package review file(s) failing or evidence-insufficient")

  if [ "${#gaps[@]}" -eq 0 ]; then
    ok "work-packages: Ready for feature review ($wp_count work package(s) complete)"
    return 0
  else
    fail_msg "work-packages: NOT ready for feature review"
    local g
    for g in "${gaps[@]}"; do gap "$g"; done
    return 1
  fi
}

check_all() {
  local feature="$1"
  local profile
  local overall=0
  local feature_dir="$FEATURE_ROOT/$feature"

  profile="$(sdd_profile "$feature")"

  if [ "$profile" = "lite" ]; then
    [ -f "$FEATURE_ROOT/$feature/spec.md" ] && { check_spec "$feature" || overall=1; }
    if [ -f "$FEATURE_ROOT/$feature/tasks.md" ] || sdd_feature_has_work_packages "$feature_dir"; then
      check_tasks "$feature" || overall=1
    fi
    if sdd_feature_has_work_packages "$feature_dir"; then
      check_work_packages "$feature" || overall=1
    fi
    [ -f "$FEATURE_ROOT/$feature/review.md" ] && { check_review "$feature" || overall=1; }
  else
    # Run checks for all artifacts that exist
    [ -f "$FEATURE_ROOT/$feature/brief.md" ] && { check_brief "$feature" || overall=1; }
    [ -f "$FEATURE_ROOT/$feature/spec.md" ] && { check_spec "$feature" || overall=1; }
    [ -f "$FEATURE_ROOT/$feature/research.md" ] && { check_research "$feature" || overall=1; }
    [ -f "$FEATURE_ROOT/$feature/plan.md" ] && { check_plan "$feature" || overall=1; }
    if [ -f "$FEATURE_ROOT/$feature/tasks.md" ] || sdd_feature_has_work_packages "$feature_dir"; then
      check_tasks "$feature" || overall=1
    fi
    if sdd_feature_has_work_packages "$feature_dir"; then
      check_work_packages "$feature" || overall=1
    fi
    [ -f "$FEATURE_ROOT/$feature/review.md" ] && { check_review "$feature" || overall=1; }
  fi
  check_coverage "$feature"

  return $overall
}

run_check_command() {
  local check_name="$1"
  local target_feature="$2"

  case "$check_name" in
    brief)    check_brief "$target_feature" ;;
    spec)     check_spec "$target_feature" ;;
    research) check_research "$target_feature" ;;
    plan)     check_plan "$target_feature" ;;
    tasks)    check_tasks "$target_feature" ;;
    review)   check_review "$target_feature" ;;
    all)      check_all "$target_feature" ;;
  esac
}

check_failure_guidance() {
  local check_name="$1"
  local target_feature="$2"
  local artifact_path

  case "$check_name" in
    all) artifact_path="$FEATURE_ROOT/$target_feature/" ;;
    *) artifact_path="$FEATURE_ROOT/$target_feature/$check_name.md" ;;
  esac

  case "$check_name" in
    brief)
      printf 'Rubric: references/rubrics/brief.md\n'
      printf 'Inspect: %s for missing Motivation/Vision substance.\n' "$artifact_path"
      printf 'Next: strengthen the brief until intent is explicit, then rerun `sdd check brief %s`.\n' "$target_feature"
      printf 'Avoid: placeholder answers or implicit assumptions standing in for user intent.\n'
      ;;
    spec)
      printf 'Rubric: references/rubrics/spec.md\n'
      printf 'Inspect: %s for missing Problem, FR, and AC substance.\n' "$artifact_path"
      printf 'Next: clarify the requirement gaps, then rerun `sdd check spec %s`.\n' "$target_feature"
      if [ "$(sdd_profile "$target_feature")" = "lite" ]; then
        printf 'Avoid: treating vague behavior, hidden HOW, or placeholder ACs as ready for implement.\n'
      else
        printf 'Avoid: treating vague behavior, hidden HOW, or placeholder ACs as ready for research.\n'
      fi
      ;;
    research)
      printf 'Rubric: references/rubrics/research.md\n'
      printf 'Inspect: %s for grounded Affected Files rows and a concrete Confidence verdict.\n' "$artifact_path"
      printf 'Next: add inspected-file evidence and rerun `sdd check research %s`.\n' "$target_feature"
      printf 'Avoid: inferring architecture from memory or marking research ready without file-backed evidence.\n'
      ;;
    plan)
      printf 'Rubric: references/rubrics/plan.md\n'
      printf 'Inspect: %s for explicit ADs and PH phases.\n' "$artifact_path"
      printf 'Next: add the smallest viable plan structure, then rerun `sdd check plan %s`.\n' "$target_feature"
      printf 'Avoid: jumping to implementation or relying on implied plan structure.\n'
      ;;
    tasks)
      printf 'Rubric: references/rubrics/tasks.md (advisory)\n'
      printf 'Inspect: %s for missing task metadata, verification blocks, or dependency problems.\n' "$artifact_path"
      printf 'Next: make each task executable and rerun `sdd check tasks %s`.\n' "$target_feature"
      printf 'Avoid: starting implementation from placeholder tasks, incomplete verification steps, or tasks with fuzzy scope boundaries.\n'
      ;;
    review)
      printf 'Rubric: references/rubrics/review.md (advisory)\n'
      printf 'Inspect: %s for missing verdicts or AC evidence rows.\n' "$artifact_path"
      printf 'Next: finish AC validation and rerun `sdd check review %s`.\n' "$target_feature"
      printf 'Avoid: treating unverified review notes, scope drift, or unrequested work as a passing close boundary.\n'
      ;;
    all)
      printf 'Inspect: the reported gaps in %s before advancing phases.\n' "$artifact_path"
      printf 'Next: resolve the failing artifact checks, then rerun `sdd check all %s`.\n' "$target_feature"
      printf 'Avoid: advancing because one artifact looks close enough while other readiness gaps remain.\n'
      ;;
  esac
}

# --- Dispatcher ---

cmd="${SDD_ARGS[0]:-}"
feature="${SDD_FEATURE_OVERRIDE:-${SDD_ARGS[1]:-}}"

if [ -z "$cmd" ]; then
  sdd_usage_error "check" "sdd check {brief|spec|research|plan|tasks|review|all} <feature-id>" "check type is required"
fi

sdd_resolve_feature_target "$feature" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
  case "$SDD_RESOLUTION_STATUS" in
    not_found)
      sdd_fail "check" "not_found" "feature '$feature' not found" "{\"feature\":\"$feature\"}" "$feature" "arg"
      ;;
    ambiguous)
      sdd_fail "check" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
      ;;
    none)
      sdd_fail "check" "not_found" "no active feature found" '{"feature":"auto"}' "" "none"
      ;;
  esac
}

CHECK_FEATURE="$SDD_RESOLVED_FEATURE"
CHECK_FEATURE_PATH="${SDD_RESOLVED_FEATURE_PATH:-$CHECK_FEATURE}"
CHECK_FEATURE_DIR="${SDD_RESOLVED_FEATURE_DIR:-$FEATURE_ROOT/$CHECK_FEATURE_PATH}"

case "$cmd" in
  brief|spec|research|plan|tasks|review|all) ;;
  *)
    sdd_fail "check" "usage" "unknown check type '$cmd'" "{\"valid\":[\"brief\",\"spec\",\"research\",\"plan\",\"tasks\",\"review\",\"all\"]}" "$CHECK_FEATURE" "$SDD_RESOLUTION_SOURCE"
    ;;
esac

set +e
OUTPUT="$(run_check_command "$cmd" "$CHECK_FEATURE_PATH")"
CHECK_EXIT=$?
set -e

if sdd_is_json_mode; then
  PHASE="$(sdd_feature_phase "$CHECK_FEATURE_PATH")"
  LINT_JSON="null"
  if { [ "$cmd" = "tasks" ] || [ "$cmd" = "all" ]; } &&
     [ -f "$CHECK_FEATURE_DIR/tasks.md" ]; then
    LINT_JSON="$(sdd_task_verification_lint_json "$CHECK_FEATURE_DIR/tasks.md" "$CHECK_FEATURE")"
  fi
  DATA_JSON="$(printf '%s\n' "$OUTPUT" | jq -Rsc \
    --arg check "$cmd" \
    --arg feature "$CHECK_FEATURE" \
    --arg feature_path "$CHECK_FEATURE_PATH" \
    --arg feature_dir "$CHECK_FEATURE_DIR" \
    --argjson ready "$( [ "$CHECK_EXIT" -eq 0 ] && echo true || echo false )" \
    --argjson lint "$LINT_JSON" \
    '{
      check: $check,
      feature: $feature,
      feature_id: $feature,
      feature_path: $feature_path,
      feature_dir: $feature_dir,
      ready: $ready,
      report: .,
      gaps: (split("\n") | map(select(startswith("  - "))) | map(sub("^  - "; "")))
    }
    + (if $lint == null then {} else {lint: $lint} end)')"

  if [ "$CHECK_EXIT" -eq 0 ]; then
    sdd_emit_json_selection "$(sdd_json_success "check" "$CHECK_FEATURE" "$SDD_RESOLUTION_SOURCE" "$PHASE" "$DATA_JSON" '{}' '[]')"
    exit 0
  fi

  printf '%s\n' "$(sdd_json_error "check" "precondition" "artifact readiness checks failed" "$DATA_JSON" "$CHECK_FEATURE" "$SDD_RESOLUTION_SOURCE" "$PHASE" '[]')"
  check_failure_guidance "$cmd" "$CHECK_FEATURE_PATH" >&2
  exit "$SDD_EXIT_PRECONDITION"
fi

printf '%s\n' "$OUTPUT"
if [ "$CHECK_EXIT" -eq 0 ]; then
  exit 0
fi

check_failure_guidance "$cmd" "$CHECK_FEATURE_PATH"
exit "$SDD_EXIT_PRECONDITION"
