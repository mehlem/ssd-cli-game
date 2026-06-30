#!/usr/bin/env bash
# sdd-wp.sh — Work Package management commands for SDD
# Usage: sdd-wp.sh <cmd> [args]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "wp" "sdd wp {init|list} <feature> [args]" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "wp" \
      "Manage work packages for an SDD feature." \
      "sdd wp {init|list} <feature> [args] [--feature <id|auto>] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd wp init 0002-sdd-work-packages auth-layer",
        "sdd wp list 0002-sdd-work-packages",
        "sdd wp list --feature auto --json"
      ]'
    return 0
  fi

  echo "sdd wp — Work Package management"
  echo ""
  echo "Commands:"
  echo "  init <feature> <name>   Create a new work package"
  echo "  list <feature>          List all work packages with status"
  echo ""
  echo "Examples:"
  echo "  sdd wp init 0002-sdd-work-packages auth-layer"
  echo "  sdd wp list 0002-sdd-work-packages"
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

subcmd="${SDD_ARGS[0]:-help}"
WP_ARGS=("${SDD_ARGS[@]:1}")

if [ -n "$SDD_FEATURE_OVERRIDE" ]; then
  feature="$SDD_FEATURE_OVERRIDE"
  WP_ARG_OFFSET=0
else
  feature="${WP_ARGS[0]:-}"
  WP_ARG_OFFSET=1
fi
feature_path="$feature"
feature_dir="$SDD_FEATURE_ROOT/$feature_path"

wp_arg() {
  local index="$1"
  printf '%s\n' "${WP_ARGS[$((WP_ARG_OFFSET + index))]:-}"
}

wp_plan_mentions_name() {
  local plan_file="$1" wp_name="$2"
  [ -f "$plan_file" ] || return 0

  awk -v slug="$wp_name" '
    function norm(value) {
      value = tolower(value)
      gsub(/[^a-z0-9]+/, "-", value)
      gsub(/^-+|-+$/, "", value)
      return value
    }
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^[[:space:]]*#/ ||
    /^[[:space:]]*[-*][[:space:]]+/ ||
    /^[[:space:]]*[0-9]+[.)][[:space:]]+/ ||
    /^[[:space:]]*>[[:space:]]*(Phase|Work Package|WP):/ {
      seen = 1
      if (index(norm($0), slug) > 0) found = 1
    }
    END {
      if (!seen || found) exit 0
      exit 1
    }
  ' "$plan_file"
}

resolve_wp_feature() {
  local strict_auto="$1"
  sdd_resolve_feature_target "$feature" "$strict_auto" || {
    case "$SDD_RESOLUTION_STATUS" in
      not_found)
        sdd_fail "wp" "not_found" "feature '$feature' not found" "{\"feature\":\"$feature\"}" "$feature" "arg"
        ;;
      ambiguous)
        sdd_fail "wp" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc '{candidates: split("\n") | map(select(length > 0))}')" "" "auto"
        ;;
      none)
        sdd_usage_error "wp" "sdd wp {init|list} <feature> [args]" "feature ID required"
        ;;
    esac
  }
  feature="$SDD_RESOLVED_FEATURE"
  feature_path="${SDD_RESOLVED_FEATURE_PATH:-$feature}"
  feature_dir="${SDD_RESOLVED_FEATURE_DIR:-$SDD_FEATURE_ROOT/$feature_path}"
}

refresh_wp_init_derived_state() {
  bash "$SCRIPT_DIR/sdd-status.sh" --json "$feature_path" >/dev/null 2>&1 || true
  bash "$SCRIPT_DIR/sdd-summary.sh" "$feature_path" >/dev/null 2>&1 || true
  bash "$SCRIPT_DIR/sdd-continuity-refresh.sh" "$feature_path" >/dev/null 2>&1 || true
}

cmd_init() {
  local wp_name next_num existing last_num wp_num wp_id wp_dir tmpl tasks_file scratchpad wp_title data_json guidance_json
  local alignment_warning="" warnings_json="[]"

  resolve_wp_feature 1
  wp_name="$(wp_arg 0)"
  [ -n "$wp_name" ] || sdd_usage_error "wp" "sdd wp init <feature> <name>" "work package name required"

  [ -d "$feature_dir" ] || sdd_fail "wp" "not_found" "feature directory '$feature_dir' not found" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

  if ! echo "$wp_name" | grep -qE '^[a-z][a-z0-9-]*$'; then
    sdd_usage_error "wp" "sdd wp init <feature> <name>" "WP name must be kebab-case (lowercase letters, digits, hyphens; start with letter)"
  fi

  next_num=1
  existing="$(ls -d "$feature_dir"/wp-*/ 2>/dev/null | sort)" || true
  if [ -n "$existing" ]; then
    last_num="$(echo "$existing" | sed 's|.*/wp-||' | grep -oE '^[0-9]+' | sort -n | tail -1)"
    next_num=$((last_num + 1))
  fi
  wp_num="$(printf '%02d' "$next_num")"
  wp_id="wp-${wp_num}-${wp_name}"
  wp_dir="$feature_dir/$wp_id"

  if [ -d "$wp_dir" ]; then
    case "$(sdd_effective_on_exists)" in
      skip)
        if sdd_is_json_mode; then
          data_json="$(jq -nc --arg action "skip" --arg feature "$feature" --arg feature_path "$feature_path" --arg feature_dir "$feature_dir" --arg wp_id "$wp_id" --arg wp_dir "$wp_dir" '{action:$action, feature:$feature, feature_id:$feature, feature_path:$feature_path, feature_dir:$feature_dir, work_package:{id:$wp_id, path:$wp_dir}}')"
          sdd_emit_json_selection "$(sdd_json_success "wp" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "$(sdd_feature_phase "$feature_path")" "$data_json" '{}' '[]')"
        else
          echo "Skipped."
        fi
        return 0
        ;;
      overwrite)
        sdd_fail "wp" "conflict" "work package directory '$wp_dir' already exists; overwrite is not supported" "{\"path\":\"$wp_dir\",\"policy\":\"overwrite\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
        ;;
      *)
        sdd_fail "wp" "conflict" "work package directory '$wp_dir' already exists" "{\"path\":\"$wp_dir\",\"policy\":\"$(sdd_effective_on_exists)\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"
        ;;
    esac
  fi

  if ! wp_plan_mentions_name "$feature_dir/plan.md" "$wp_name"; then
    alignment_warning="work package '$wp_name' was not found in plan.md phase/work-package decomposition; continuing because this warning is non-blocking."
    warnings_json="$(jq -nc --arg message "$alignment_warning" '[{type:"alignment_warning",message:$message}]')"
    sdd_warn "$alignment_warning"
  fi

  sdd_extract_metadata "$feature"
  mkdir -p "$wp_dir"

  tmpl="$SDD_TEMPLATE_DIR/wp-tasks.md"
  [ -f "$tmpl" ] || sdd_fail "wp" "internal" "template 'wp-tasks.md' not found at $tmpl" "{\"template\":\"$tmpl\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

  tasks_file="$wp_dir/tasks.md"
  cp "$tmpl" "$tasks_file"

  wp_title="$(echo "$wp_name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')"

  sdd_portable_sed "$tasks_file" \
    -e "s/{{FEATURE_ID}}/$feature/g" \
    -e "s/{{FEATURE_NUM}}/$SDD_FEATURE_NUM/g" \
    -e "s/{{WP_ID}}/$wp_id/g" \
    -e "s/{{WP_NAME}}/$wp_title/g" \
    -e "s/{{DATE}}/$SDD_TODAY/g"

  scratchpad="$wp_dir/scratchpad.md"
  cat > "$scratchpad" <<EOF
---
id: WP-SCRATCH-${SDD_FEATURE_NUM}-${wp_id}
feature: "${feature}"
work_package: "${wp_id}"
title: "${wp_title}"
type: scratchpad
status: active
created: ${SDD_TODAY}
updated: ${SDD_TODAY}
tags: []
---

# Scratchpad: ${wp_title}

## Observations

## Open Questions
EOF

  refresh_wp_init_derived_state

  if sdd_is_json_mode; then
    data_json="$(jq -nc \
      --arg action "create" \
      --arg feature "$feature" \
      --arg feature_path "$feature_path" \
      --arg feature_dir "$feature_dir" \
      --arg wp_id "$wp_id" \
      --arg wp_dir "$wp_dir" \
      --arg tasks_file "$tasks_file" \
      --arg scratchpad "$scratchpad" \
      '{action:$action, feature:$feature, feature_id:$feature, feature_path:$feature_path, feature_dir:$feature_dir, work_package:{id:$wp_id, path:$wp_dir, tasks_file:$tasks_file, scratchpad:$scratchpad}}')"
    guidance_json="$(sdd_json_guidance "add tasks to the new work package tasks.md file." "" "")"
    sdd_emit_json_selection "$(sdd_json_success "wp" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "$(sdd_feature_phase "$feature_path")" "$data_json" "$guidance_json" "$warnings_json")"
    echo "═══════════════════════════════════════════════" >&2
    echo "Work package initialized: $wp_id" >&2
    echo "═══════════════════════════════════════════════" >&2
    echo "" >&2
    echo "Feature:  $feature" >&2
    echo "WP:       $wp_id" >&2
    echo "Directory: $wp_dir/" >&2
    echo "" >&2
    echo "Artifacts created:" >&2
    echo "  tasks.md      WP-TASKS-${SDD_FEATURE_NUM}-${wp_id}" >&2
    echo "  scratchpad.md WP-SCRATCH-${SDD_FEATURE_NUM}-${wp_id}" >&2
    echo "" >&2
    echo "Next: Add tasks to $wp_dir/tasks.md" >&2
    return 0
  fi

  echo "═══════════════════════════════════════════════"
  echo "Work package initialized: $wp_id"
  echo "═══════════════════════════════════════════════"
  echo ""
  echo "Feature:  $feature"
  echo "WP:       $wp_id"
  echo "Directory: $wp_dir/"
  echo ""
  echo "Artifacts created:"
  echo "  tasks.md      WP-TASKS-${SDD_FEATURE_NUM}-${wp_id}"
  echo "  scratchpad.md WP-SCRATCH-${SDD_FEATURE_NUM}-${wp_id}"
  echo ""
  echo "Next: Add tasks to $wp_dir/tasks.md"
}

cmd_list() {
  local wp_dirs rows_json

  resolve_wp_feature 0
  [ -d "$feature_dir" ] || sdd_fail "wp" "not_found" "feature directory '$feature_dir' not found" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

  wp_dirs="$(ls -d "$feature_dir"/wp-*/ 2>/dev/null | sort)" || true

  if [ -z "$wp_dirs" ]; then
    if sdd_is_json_mode; then
      rows_json='[]'
      sdd_emit_json_selection "$(sdd_json_success "wp" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "$(sdd_feature_phase "$feature_path")" "$(jq -nc --arg feature "$feature" --arg feature_path "$feature_path" --arg feature_dir "$feature_dir" --argjson work_packages "$rows_json" '{feature:$feature, feature_id:$feature, feature_path:$feature_path, feature_dir:$feature_dir, work_packages:$work_packages}')" '{}' '[]')"
      echo "No work packages found for feature: $feature" >&2
      echo "Create one with: sdd wp init $feature_path <name>" >&2
    else
      echo "No work packages found for feature: $feature"
      echo "Create one with: sdd wp init $feature_path <name>"
    fi
    return 0
  fi

  rows_json="$(
    while IFS= read -r wp_path; do
      [ -d "$wp_path" ] || continue
      wp_name="$(basename "$wp_path")"
      tasks_file="$wp_path/tasks.md"
      review_file="$wp_path/review.md"

      if [ ! -f "$tasks_file" ]; then
        phase="scaffold"
        progress="0/0"
        status_label="no tasks.md"
      else
        pending="$(sdd_count_task_status "$tasks_file" pending)"
        in_progress="$(sdd_count_task_status "$tasks_file" in-progress)"
        completed="$(sdd_count_task_status "$tasks_file" completed)"
        blocked="$(sdd_count_task_status "$tasks_file" blocked)"
        total=$((pending + in_progress + completed + blocked))
        done=$((completed + blocked))

        if [ -f "$review_file" ] && [ "$(sdd_frontmatter_value "$review_file" verdict || true)" = "pass" ]; then
          phase="done"
          progress="${done}/${total}"
          status_label="review passed"
        elif [ -f "$review_file" ]; then
          phase="review"
          progress="${done}/${total}"
          status_label="in review"
        elif [ "$((pending + in_progress))" -eq 0 ] && [ "$total" -gt 0 ]; then
          phase="review"
          progress="${done}/${total}"
          status_label="ready for review"
        elif [ "$in_progress" -gt 0 ]; then
          phase="implement"
          progress="${done}/${total}"
          status_label="${in_progress} in-progress"
        elif [ "$pending" -gt 0 ]; then
          phase="implement"
          progress="${done}/${total}"
          status_label="${pending} pending"
        else
          phase="scaffold"
          progress="0/0"
          status_label="empty"
        fi
      fi

      jq -nc \
        --arg id "$wp_name" \
        --arg path "$wp_path" \
        --arg phase "$phase" \
        --arg progress "$progress" \
        --arg status "$status_label" \
        '{id:$id, path:$path, phase:$phase, progress:$progress, status:$status}'
    done <<< "$wp_dirs" | jq -sc '.'
  )"

  if sdd_is_json_mode; then
    sdd_emit_json_selection "$(sdd_json_success "wp" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "$(sdd_feature_phase "$feature_path")" "$(jq -nc --arg feature "$feature" --arg feature_path "$feature_path" --arg feature_dir "$feature_dir" --argjson work_packages "$rows_json" '{feature:$feature, feature_id:$feature, feature_path:$feature_path, feature_dir:$feature_dir, work_packages:$work_packages}')" '{}' '[]')"
    return 0
  fi

  printf "%-30s  %-12s  %-12s  %s\n" "Work Package" "Phase" "Progress" "Status"
  printf "%-30s  %-12s  %-12s  %s\n" "------------------------------" "------------" "------------" "------"

  while IFS= read -r row; do
    [ -n "$row" ] || continue
    printf "%-30s  %-12s  %-12s  %s\n" \
      "$(printf '%s\n' "$row" | jq -r '.id')" \
      "$(printf '%s\n' "$row" | jq -r '.phase')" \
      "$(printf '%s\n' "$row" | jq -r '.progress')" \
      "$(printf '%s\n' "$row" | jq -r '.status')"
  done <<< "$(printf '%s\n' "$rows_json" | jq -c '.[]')"
}

case "$subcmd" in
  init)
    cmd_init
    ;;
  list)
    cmd_list
    ;;
  help|"")
    show_help
    ;;
  *)
    sdd_usage_error "wp" "sdd wp {init|list} <feature> [args]" "unknown subcommand '$subcmd'"
    ;;
esac
