#!/usr/bin/env bash
# sdd-select.sh — Manage explicit feature selection
# Usage:
#   sdd select <feature>   Pin a feature as active
#   sdd select --clear     Remove explicit selection (revert to auto-detect)
#   sdd select             Show current selection status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

ACTIVE_FILE="$SDD_FEATURE_ROOT/.active"
sdd_parse_common_args "$@" || sdd_usage_error "select" "sdd select [<feature>|--clear|--feature <id|auto>]" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "select" \
      "Manage the explicit active SDD feature selection." \
      "sdd select [<feature>|--clear|--feature <id|auto>] [--format text|json] [--field <path>] [--jq <expr>]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd select 0006",
        "sdd select --clear",
        "sdd select --feature auto",
        "sdd select --json"
      ]'
    return 0
  fi

  echo "Usage:"
  echo "  sdd select <feature>           Pin a feature as active"
  echo "  sdd select --clear             Remove explicit selection"
  echo "  sdd select --feature auto      Alias for --clear"
  echo "  sdd select                     Show current selection status"
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }
sdd_install_cleanup_trap

# Show current selection status
show_status() {
  local selected=""
  if [ -f "$ACTIVE_FILE" ]; then
    read -r selected < "$ACTIVE_FILE" 2>/dev/null || true
  fi

  # Get auto-detect result by temporarily hiding .active
  local auto_feature="none"
  if [ -f "$ACTIVE_FILE" ]; then
    local tmp_backup
    tmp_backup="$(sdd_tmp_for_target "$ACTIVE_FILE")" || return 1
    sdd_cleanup_push "$tmp_backup"
    cp "$ACTIVE_FILE" "$tmp_backup" || {
      sdd_cleanup_file "$tmp_backup"
      return 1
    }
    rm -f "$ACTIVE_FILE"
    auto_feature="$(bash "$SCRIPT_DIR/sdd-phase.sh" 2>/dev/null | grep '^feature:' | cut -d' ' -f2 || true)"
    sdd_atomic_replace "$tmp_backup" "$ACTIVE_FILE" || {
      sdd_cleanup_file "$tmp_backup"
      return 1
    }
  else
    auto_feature="$(bash "$SCRIPT_DIR/sdd-phase.sh" 2>/dev/null | grep '^feature:' | cut -d' ' -f2 || true)"
  fi
  auto_feature="${auto_feature:-none}"

  if [ -n "$selected" ]; then
    echo "Selected: $selected"
    echo "Auto-detect: $auto_feature"
  else
    echo "Selected: (none)"
    echo "Auto-detect: $auto_feature"
  fi
}

# Main
cmd="${SDD_ARGS[0]:-}"
if [ -n "$SDD_FEATURE_OVERRIDE" ]; then
  cmd="$SDD_FEATURE_OVERRIDE"
fi

case "$cmd" in
  --clear|--auto|auto)
    PREVIOUS_SELECTION=""
    if [ -f "$ACTIVE_FILE" ]; then
      read -r PREVIOUS_SELECTION < "$ACTIVE_FILE" 2>/dev/null || true
    fi
    if [ -f "$ACTIVE_FILE" ]; then
      rm -f "$ACTIVE_FILE"
      if sdd_is_json_mode; then
        AUTO_FEATURE="$(bash "$SCRIPT_DIR/sdd-phase.sh" 2>/dev/null | grep '^feature:' | cut -d' ' -f2 || true)"
        DATA_JSON="$(jq -nc \
          --arg previous "$PREVIOUS_SELECTION" \
          --arg auto_feature "${AUTO_FEATURE:-none}" \
          '{action:"clear", previous_selection:(if $previous == "" then null else $previous end), selected:null, auto_detected:$auto_feature}')"
        sdd_emit_json_selection "$(sdd_json_success "select" "" "none" "" "$DATA_JSON" '{}' '[]')"
      else
        echo "Selection cleared. Reverting to auto-detect."
      fi
    else
      if sdd_is_json_mode; then
        DATA_JSON='{"action":"clear","previous_selection":null,"selected":null,"auto_detected":"none"}'
        sdd_emit_json_selection "$(sdd_json_success "select" "" "none" "" "$DATA_JSON" '{}' '[]')"
      else
        echo "No active selection to clear."
      fi
    fi
    ;;
  "")
    if sdd_is_json_mode; then
      SELECTED_VALUE=""
      if [ -f "$ACTIVE_FILE" ]; then
        read -r SELECTED_VALUE < "$ACTIVE_FILE" 2>/dev/null || true
      fi
      AUTO_FEATURE="$(bash "$SCRIPT_DIR/sdd-phase.sh" 2>/dev/null | grep '^feature:' | cut -d' ' -f2 || true)"
      DATA_JSON="$(jq -nc \
        --arg selected "$SELECTED_VALUE" \
        --arg auto_feature "${AUTO_FEATURE:-none}" \
        '{
          selected: (if $selected == "" then null else $selected end),
          auto_detected: $auto_feature
        }')"
      RESOLUTION_SOURCE="none"
      [ -n "$SELECTED_VALUE" ] && RESOLUTION_SOURCE="selected"
      sdd_emit_json_selection "$(sdd_json_success "select" "$SELECTED_VALUE" "$RESOLUTION_SOURCE" "" "$DATA_JSON" '{}' '[]')"
    else
      show_status
    fi
    ;;
  *)
    set +e
    sdd_resolve_feature_target "$cmd" 0
    RESOLVE_EXIT=$?
    set -e
    if [ "$RESOLVE_EXIT" -ne 0 ]; then
      CANDIDATE_DETAILS="$(printf '%s\n' "${SDD_RESOLUTION_CANDIDATES:-}" | jq -Rsc --arg feature "$cmd" '{feature:$feature,candidates:(split("\n") | map(select(length > 0)))}')"
      case "$RESOLVE_EXIT" in
        *)
          case "$SDD_RESOLUTION_STATUS" in
            ambiguous)
              SELECT_RESOLVE_MESSAGE="'$cmd' matches multiple features. Be more specific."
              if [ -n "${SDD_RESOLUTION_CANDIDATES:-}" ]; then
                SELECT_RESOLVE_MESSAGE="$SELECT_RESOLVE_MESSAGE Candidates: $(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
              fi
              sdd_fail "select" "blocked" "$SELECT_RESOLVE_MESSAGE" "$CANDIDATE_DETAILS" "$cmd" "arg"
              ;;
            not_found)
              sdd_fail "select" "not_found" "feature '$cmd' not found" "$(jq -nc --arg feature "$cmd" '{feature:$feature}')" "$cmd" "arg"
              ;;
            *)
              sdd_fail "select" "internal" "feature selection failed unexpectedly" "$(jq -nc --arg feature "$cmd" '{feature:$feature}')" "$cmd" "arg"
              ;;
          esac
          ;;
      esac
    fi

    resolved="$SDD_RESOLVED_FEATURE"
    resolved_path="${SDD_RESOLVED_FEATURE_PATH:-$resolved}"
    resolved_dir="${SDD_RESOLVED_FEATURE_DIR:-$SDD_FEATURE_ROOT/$resolved_path}"
    resolved_group="${SDD_RESOLVED_FEATURE_GROUP:-}"

    sdd_write_file_atomic "$ACTIVE_FILE" "$resolved_path" || sdd_fail "select" "internal" "failed to persist active feature selection" "{\"path\":\"$ACTIVE_FILE\"}" "$resolved" "arg"

    if sdd_is_json_mode; then
      DATA_JSON="$(jq -nc \
        --arg selected "$resolved" \
        --arg selected_path "$resolved_path" \
        --arg feature_id "$resolved" \
        --arg feature_path "$resolved_path" \
        --arg feature_dir "$resolved_dir" \
        --arg feature_group "$resolved_group" \
        '{action:"select", selected:$selected, selected_path:$selected_path, feature_id:$feature_id, feature_path:$feature_path, feature_dir:$feature_dir, feature_group:(if $feature_group == "" then null else $feature_group end)}')"
      sdd_emit_json_selection "$(sdd_json_success "select" "$resolved" "arg" "$(sdd_feature_phase "$resolved_path")" "$DATA_JSON" '{}' '[]')"
      echo "Selected: $resolved_path" >&2
      # Show compact summary excerpt if available
      summary_compact="$resolved_dir/summary-compact.md"
      if [ -f "$summary_compact" ] && [ -s "$summary_compact" ]; then
        echo "" >&2
        head -8 "$summary_compact" | grep '^- ' >&2 || true
      fi
    else
      echo "Selected: $resolved_path"

      # Show compact summary excerpt if available
      summary_compact="$resolved_dir/summary-compact.md"
      if [ -f "$summary_compact" ] && [ -s "$summary_compact" ]; then
        echo ""
        head -8 "$summary_compact" | grep '^- ' || true
      fi
    fi
    ;;
esac
