#!/usr/bin/env bash
# sdd-autonomy.sh — Toggle per-feature autonomous mode
# Usage:
#   sdd autonomy on <feature>      Enable autonomous steering
#   sdd autonomy off <feature>     Disable autonomous steering
#   sdd autonomy status <feature>  Print true, false, or null
#   sdd autonomy --self-reviewed <feature>        Accept deliberate self-review for this session
#   sdd autonomy --clear-self-reviewed <feature>  Clear the self-review session override

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/sdd-lib.sh"

sdd_parse_common_args "$@" || sdd_usage_error "autonomy" "sdd autonomy {on|off|status|--self-reviewed|--clear-self-reviewed} <feature>" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "autonomy" \
      "Toggle per-feature autonomous steering mode." \
      "sdd autonomy {on|off|status|--self-reviewed|--clear-self-reviewed} <feature> [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd autonomy on 0047-sdd-autonomous-mode",
        "sdd autonomy off 0047-sdd-autonomous-mode",
        "sdd autonomy status 0047-sdd-autonomous-mode",
        "sdd autonomy --self-reviewed 0047-sdd-autonomous-mode"
      ]'
    return 0
  fi

  echo "Usage: sdd autonomy {on|off|status|--self-reviewed|--clear-self-reviewed} <feature>"
  echo "Toggle per-feature autonomous steering mode."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

resolve_autonomy_feature() {
  local requested="$1"
  local matches=() feature_dir

  [ -n "$requested" ] || sdd_usage_error "autonomy" "sdd autonomy {on|off|status|--self-reviewed|--clear-self-reviewed} <feature>" "feature is required"

  if [ -d "$SDD_FEATURE_ROOT/$requested" ]; then
    printf '%s\n' "$requested"
    return 0
  fi

  for feature_dir in "$SDD_FEATURE_ROOT"/*-"$requested"; do
    [ -d "$feature_dir" ] || continue
    matches+=("$(basename "$feature_dir")")
  done

  case "${#matches[@]}" in
    1)
      printf '%s\n' "${matches[0]}"
      ;;
    0)
      sdd_fail "autonomy" "not_found" "feature '$requested' not found" "{\"feature\":\"$requested\"}" "$requested" "arg"
      ;;
    *)
      sdd_fail "autonomy" "blocked" "'$requested' matches multiple features" "{\"feature\":\"$requested\"}" "$requested" "arg"
      ;;
  esac
}

ensure_state_file() {
  local feature="$1"
  local state_file="$SDD_FEATURE_ROOT/$feature/state.json"

  if [ ! -f "$state_file" ] || ! jq -e . "$state_file" >/dev/null 2>&1; then
    bash "$SCRIPT_DIR/sdd-status.sh" --json "$feature" >/dev/null
  fi
}

autonomy_value() {
  local feature="$1"
  local state_file="$SDD_FEATURE_ROOT/$feature/state.json"

  ensure_state_file "$feature"
  jq -r 'if .autonomous == true then "true" elif .autonomous == false then "false" else "null" end' "$state_file"
}

set_autonomy() {
  local feature="$1" value="$2"
  local state_file="$SDD_FEATURE_ROOT/$feature/state.json"
  local next_json

  ensure_state_file "$feature"
  next_json="$(jq --argjson autonomous "$value" '.autonomous = $autonomous' "$state_file")"
  sdd_write_file_atomic "$state_file" "$next_json"
}

cmd="${SDD_ARGS[0]:-}"
feature_arg="${SDD_ARGS[1]:-}"
[ -n "$cmd" ] || sdd_usage_error "autonomy" "sdd autonomy {on|off|status|--self-reviewed|--clear-self-reviewed} <feature>" "subcommand is required"

feature="$(resolve_autonomy_feature "$feature_arg")"

case "$cmd" in
  on)
    set_autonomy "$feature" true
    sdd_set_session_flag "autonomy_block_pending" "true" || true
    echo "Autonomous mode enabled: $feature"
    ;;
  off)
    set_autonomy "$feature" false
    echo "Autonomous mode disabled: $feature"
    ;;
  status)
    autonomy_value "$feature"
    ;;
  --self-reviewed)
    timestamp="$(date -u +%FT%TZ)"
    sdd_set_session_flag "self_reviewed_at" "$timestamp"
    echo "Self-review accepted for $feature at $timestamp. Stop-gate will allow close."
    ;;
  --clear-self-reviewed)
    sdd_set_session_flag "self_reviewed_at" "null"
    echo "Self-review override cleared for $feature."
    ;;
  *)
    sdd_usage_error "autonomy" "sdd autonomy {on|off|status|--self-reviewed|--clear-self-reviewed} <feature>" "unknown autonomy subcommand '$cmd'"
    ;;
esac
