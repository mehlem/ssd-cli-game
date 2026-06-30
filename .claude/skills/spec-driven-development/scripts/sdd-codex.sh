#!/usr/bin/env bash
# sdd-codex.sh - Codex provider adapter helpers for SDD worker prompts.
# Usage:
#   sdd-codex.sh render <feature> --role research-scout --task-text "..."
#   sdd-codex.sh preflight

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/sdd-lib.sh"

sdd_parse_common_args "$@" || sdd_usage_error "codex" "sdd-codex.sh render <feature> [args]" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "codex" \
      "Render SDD-owned Codex provider prompts without executing Codex." \
      "sdd-codex.sh {render|preflight} <feature> [args]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd-codex.sh render 0085-sdd-codex-delegation --role research-scout --task-text \"Inspect prompt flow\"",
        "sdd-codex.sh render --json 0085-sdd-codex-delegation --role implementer --template implement"
      ]'
    return 0
  fi

  cat <<'EOF'
sdd-codex.sh - Codex provider adapter helpers

Commands:
  render <feature> [--role <role>] [--task-text <text>] [--template <name>]
      Render an SDD-owned Codex prompt. This command does not execute Codex.
  preflight
      Check whether Codex tooling is available. Test with SDD_CODEX_FAKE_PREFLIGHT.

Render options:
  --role <role>              implementer | spec-reviewer | quality-reviewer | research-scout | plan-drafter
  --dispatch-id <id>         Stable dispatch id. Defaults to a generated id.
  --permission-mode <mode>   Permission mode recorded in prompt metadata.
  --task-text <text>         Custom operator task text inserted into the prompt template.
  --template <name>          research | plan | implement | review. Defaults from role.
EOF
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

resolve_codex_feature() {
  local feature_input="$1" strict="${2:-0}"
  sdd_resolve_feature_target "$feature_input" "$strict" || {
    case "$SDD_RESOLUTION_STATUS" in
      not_found)
        sdd_fail "codex" "not_found" "feature '$feature_input' not found" "{\"feature\":\"$feature_input\"}" "$feature_input" "arg"
        ;;
      ambiguous)
        sdd_fail "codex" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
        ;;
      none)
        sdd_usage_error "codex" "sdd-codex.sh render <feature> [args]" "feature ID required"
        ;;
    esac
  }
}

generated_codex_dispatch_id() {
  printf 'codex-%s-%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$$"
}

cmd="${SDD_ARGS[0]:-help}"

case "$cmd" in
  preflight)
    if preflight_json="$(sdd_codex_preflight_json)"; then
      if sdd_is_json_mode; then
        data_json="$(printf '%s\n' "$preflight_json" | jq -c '.')"
        sdd_emit_json_selection "$(sdd_json_success "codex" "" "none" "" "$data_json" '{}' '[]')"
      else
        printf 'Codex provider available: %s\n' "$(printf '%s\n' "$preflight_json" | jq -r '.bin // "codex"')"
      fi
    else
      sdd_fail \
        "codex" \
        "provider_unavailable" \
        "$(printf '%s\n' "$preflight_json" | jq -r '.error.message // "Codex provider is unavailable"')" \
        "$(printf '%s\n' "$preflight_json" | jq -c '.error.details // {}')"
    fi
    ;;
  render)
    feature_input="${SDD_FEATURE_OVERRIDE:-}"
    role="research-scout"
    dispatch_id=""
    permission_mode=""
    custom_task_text=""
    custom_task_source="none"
    prompt_template=""
    args=("${SDD_ARGS[@]:1}")
    idx=0
    while [ "$idx" -lt "${#args[@]}" ]; do
      arg="${args[$idx]}"
      case "$arg" in
        --role)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "codex" "sdd-codex.sh render <feature> --role <role>" "missing value for --role"
          role="${args[$idx]}"
          ;;
        --dispatch-id)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "codex" "sdd-codex.sh render <feature> --dispatch-id <id>" "missing value for --dispatch-id"
          dispatch_id="${args[$idx]}"
          ;;
        --permission-mode|--permission)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "codex" "sdd-codex.sh render <feature> --permission-mode <mode>" "missing value for --permission-mode"
          permission_mode="${args[$idx]}"
          ;;
        --task-text|--custom-task|--prompt)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "codex" "sdd-codex.sh render <feature> --task-text <text>" "missing value for --task-text"
          custom_task_text="${args[$idx]}"
          custom_task_source="inline"
          ;;
        --template)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "codex" "sdd-codex.sh render <feature> --template <name>" "missing value for --template"
          prompt_template="${args[$idx]}"
          ;;
        --provider)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "codex" "sdd-codex.sh render <feature> --provider codex" "missing value for --provider"
          [ "${args[$idx]}" = "codex" ] || sdd_fail "codex" "precondition" "unsupported codex adapter provider '${args[$idx]}'" "{\"provider\":\"${args[$idx]}\"}" "$feature_input" "arg"
          ;;
        --*)
          sdd_usage_error "codex" "sdd-codex.sh render <feature> [--role <role>] [--task-text <text>]" "unknown render option '$arg'"
          ;;
        *)
          if [ -z "$feature_input" ]; then
            feature_input="$arg"
          else
            sdd_usage_error "codex" "sdd-codex.sh render <feature> [args]" "unexpected argument '$arg'"
          fi
          ;;
      esac
      idx=$((idx + 1))
    done

    role="$(sdd_normalize_agent_role "$role")"
    sdd_worker_role_is_supported "$role" || \
      sdd_fail "codex" "precondition" "unsupported worker role '$role'" "{\"role\":\"$role\"}" "$feature_input" "arg"

    [ -n "$dispatch_id" ] || dispatch_id="$(generated_codex_dispatch_id)"
    sdd_worker_dispatch_id_is_safe "$dispatch_id" || \
      sdd_fail "codex" "precondition" "dispatch id contains unsupported characters" "{\"dispatch_id\":\"$dispatch_id\"}" "$feature_input" "arg"

    if [ -z "$prompt_template" ]; then
      prompt_template="$(sdd_codex_template_for_role "$role")" || \
        sdd_fail "codex" "precondition" "no default Codex template for role '$role'" "{\"role\":\"$role\"}" "$feature_input" "arg"
    fi

    case "$prompt_template" in
      research|plan|implement|review) ;;
      *) sdd_fail "codex" "precondition" "unsupported Codex template '$prompt_template'" "{\"template\":\"$prompt_template\",\"supported\":[\"research\",\"plan\",\"implement\",\"review\"]}" "$feature_input" "arg" ;;
    esac

    resolve_codex_feature "$feature_input" "$(sdd_is_machine_mode && echo 1 || echo 0)"
    feature="$SDD_RESOLVED_FEATURE_PATH"
    feature_id="$SDD_RESOLVED_FEATURE"
    phase="$(sdd_feature_phase "$feature")"
    [ -n "$permission_mode" ] || permission_mode="$(sdd_worker_default_permission_mode "codex" "$phase")"

    template_file="$SDD_TEMPLATE_DIR/codex/$prompt_template.md"
    [ -f "$template_file" ] || \
      sdd_fail "codex" "precondition" "Codex prompt template '$prompt_template' is missing" "{\"template\":\"$prompt_template\",\"path\":\"$template_file\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"

    dispatch_packet="$(sdd_build_dispatch_packet "$role" "$feature" "$phase" "" "$dispatch_id" "0")"
    dispatch_json="$(printf '%s\n' "$dispatch_packet" | sdd_extract_machine_dispatch_record)"
    [ -n "$dispatch_json" ] || \
      sdd_fail "codex" "internal" "failed to build dispatch record" "{\"feature\":\"$feature\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"

    rendered_prompt="$(sdd_codex_render_template "$template_file" "$dispatch_packet" "$custom_task_text" "$feature" "$phase" "$role" "$dispatch_id" "$permission_mode")"
    prompt_hash="sha256:$(sdd_string_sha256 "$rendered_prompt")"
    dispatch_json="$(sdd_worker_enrich_dispatch_record "$dispatch_json" "codex" "$permission_mode" "$prompt_template" "$template_file" "$prompt_hash" "$custom_task_source" "$custom_task_text" "render-only" "rendered")"

    if sdd_is_json_mode; then
      data_json="$(jq -nc \
        --arg action "render" \
        --arg provider "codex" \
        --arg role "$role" \
        --arg phase "$phase" \
        --arg dispatch_id "$dispatch_id" \
        --arg permission_mode "$permission_mode" \
        --arg template "$prompt_template" \
        --arg prompt_path "$template_file" \
        --arg content_hash "$prompt_hash" \
        --arg prompt "$rendered_prompt" \
        --argjson dispatch "$dispatch_json" \
        '{
          action: $action,
          provider: $provider,
          role: $role,
          phase: $phase,
          dispatch_id: $dispatch_id,
          permission_mode: $permission_mode,
          template: $template,
          prompt_path: $prompt_path,
          content_hash: $content_hash,
          prompt: $prompt,
          dispatch: $dispatch
        }')"
      sdd_emit_json_selection "$(sdd_json_success "codex" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase" "$data_json" '{}' '[]')"
    else
      printf '%s\n' "$rendered_prompt"
    fi
    ;;
  help|"")
    show_help
    ;;
  *)
    sdd_usage_error "codex" "sdd-codex.sh {render} <feature> [args]" "unknown codex subcommand '$cmd'"
    ;;
esac
