#!/usr/bin/env bash
# sdd-scope.sh — Manage scope.txt sidecar
# Usage:
#   sdd-scope.sh refresh <feature>   — regenerate scope.txt from research.md

set -euo pipefail

FEATURE_ROOT=".features"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "scope" "sdd scope refresh <feature>" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "scope" \
      "Regenerate scope.txt from research.md for a feature." \
      "sdd scope refresh <feature> [--feature <id|auto>] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd scope refresh 0001-user-auth",
        "sdd scope refresh --feature auto --json"
      ]'
    return 0
  fi

  echo "sdd-scope.sh — Manage scope.txt sidecar"
  echo ""
  echo "Commands:"
  echo "  refresh <feature>   Regenerate scope.txt from research.md"
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }
sdd_install_cleanup_trap

generate_scope_txt() {
  local fdir="$1"
  local research_file="$fdir/research.md"
  local scope_file="$fdir/scope.txt"
  local tmp

  SCOPE_WARNING=""
  SCOPE_COUNT=0

  if [ ! -f "$research_file" ]; then
    tmp="$(sdd_tmp_for_target "$scope_file")" || return 1
    sdd_cleanup_push "$tmp"
    : > "$tmp" || {
      sdd_cleanup_file "$tmp"
      return 1
    }
    sdd_atomic_replace "$tmp" "$scope_file" || {
      sdd_cleanup_file "$tmp"
      return 1
    }
    SCOPE_WARNING="research.md not found — created empty scope.txt"
    return 0
  fi

  tmp="$(sdd_tmp_for_target "$scope_file")" || return 1
  sdd_cleanup_push "$tmp"
  sdd_affected_files_paths "$research_file" > "$tmp"

  sdd_atomic_replace "$tmp" "$scope_file" || {
    sdd_cleanup_file "$tmp"
    return 1
  }
  SCOPE_COUNT="$(wc -l < "$scope_file" | tr -d ' ')"
}

cmd="${SDD_ARGS[0]:-help}"
feature_input="${SDD_FEATURE_OVERRIDE:-${SDD_ARGS[1]:-}}"

case "$cmd" in
  refresh)
    sdd_resolve_feature_target "$feature_input" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
      case "$SDD_RESOLUTION_STATUS" in
        not_found)
          sdd_fail "scope" "not_found" "feature '$feature_input' not found" "{\"feature\":\"$feature_input\"}" "$feature_input" "arg"
          ;;
        ambiguous)
          sdd_fail "scope" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc '{candidates: split("\n") | map(select(length > 0))}')" "" "auto"
          ;;
        none)
          sdd_usage_error "scope" "sdd scope refresh <feature>" "feature ID required"
          ;;
      esac
    }

    feature="$SDD_RESOLVED_FEATURE"
    fdir="$FEATURE_ROOT/$feature"
    [ -d "$fdir" ] || sdd_fail "scope" "not_found" "feature directory '$fdir' not found" "{\"feature\":\"$feature\"}" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}"

    generate_scope_txt "$fdir"
    scope_file="$fdir/scope.txt"

    if sdd_is_json_mode; then
      warnings_json='[]'
      if [ -n "$SCOPE_WARNING" ]; then
        warnings_json="$(jq -nc --arg warning "$SCOPE_WARNING" '[ $warning ]')"
      fi
      data_json="$(jq -nc --arg scope_file "$scope_file" --argjson path_count "$SCOPE_COUNT" '{scope_file:$scope_file, path_count:$path_count}')"
      sdd_emit_json_selection "$(sdd_json_success "scope" "$feature" "${SDD_RESOLUTION_SOURCE:-arg}" "$(sdd_feature_phase "$feature")" "$data_json" '{}' "$warnings_json")"
      if [ -n "$SCOPE_WARNING" ]; then
        echo "Warning: $SCOPE_WARNING" >&2
      fi
      echo "Generated: $scope_file ($SCOPE_COUNT paths)" >&2
      exit 0
    fi

    if [ -n "$SCOPE_WARNING" ]; then
      echo "Warning: $SCOPE_WARNING"
    fi
    echo "Generated: $scope_file ($SCOPE_COUNT paths)"
    ;;
  help|"")
    show_help
    ;;
  *)
    sdd_usage_error "scope" "sdd scope refresh <feature>" "unknown subcommand '$cmd'"
    ;;
esac
