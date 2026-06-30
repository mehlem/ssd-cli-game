#!/usr/bin/env bash
# sdd-worker.sh — Provider-aware worker dispatch/result ledger commands.
# Usage:
#   sdd worker dispatch <feature> --provider codex --role research-scout --task-text "..."
#   sdd worker status <feature>
#   sdd worker import-result <feature> ...

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/sdd-lib.sh"

sdd_parse_common_args "$@" || sdd_usage_error "worker" "sdd worker {dispatch|status|import-result} <feature> [args]" "invalid shared CLI flags"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "worker" \
      "Manage provider-aware SDD worker dispatch and result ledger records." \
      "sdd worker {dispatch|status|import-result} <feature> [--provider codex] [--role <role>] [--task-text <text>]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd worker dispatch 0085-sdd-codex-delegation --provider codex --role research-scout --task-text \"Inspect prompt flow\"",
        "sdd worker status 0085-sdd-codex-delegation"
      ]'
    return 0
  fi

  cat <<'EOF'
sdd worker — Provider-aware worker ledger commands

Commands:
  dispatch <feature> --provider codex --role <role> [--task-text <text>]
      Create a provider-aware dispatch record without executing the provider.
  status <feature>
      Show worker ledger state for a feature.
  import-result <feature> --provider codex --file <path>
      Import a provider result after SDD machine-result validation.

Dispatch options:
  --provider <name>          Provider name. Currently: codex
  --role <role>              implementer | spec-reviewer | quality-reviewer | research-scout | plan-drafter
  --dispatch-id <id>         Stable dispatch id. Defaults to a generated id.
  --permission-mode <mode>   Permission mode recorded in dispatch metadata.
  --task-text <text>         Custom operator task text to carry into prompt metadata.
  --template <name>          Prompt template name to record before rendering exists.
  --runtime-mode <mode>      record-only | preflight. Defaults to record-only.
  --preflight                Alias for --runtime-mode preflight.

Import options:
  --provider <name>          Provider name. Currently: codex
  --dispatch-id <id>         Expected dispatch id. Defaults from the result payload.
  --file <path>              Raw Codex output file. Use '-' to read stdin.
EOF
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

resolve_worker_feature() {
  local feature_input="$1" strict="${2:-0}"
  sdd_resolve_feature_target "$feature_input" "$strict" || {
    case "$SDD_RESOLUTION_STATUS" in
      not_found)
        sdd_fail "worker" "not_found" "feature '$feature_input' not found" "{\"feature\":\"$feature_input\"}" "$feature_input" "arg"
        ;;
      ambiguous)
        sdd_fail "worker" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
        ;;
      none)
        sdd_usage_error "worker" "sdd worker {dispatch|status|import-result} <feature> [args]" "feature ID required"
        ;;
    esac
  }
}

generated_dispatch_id() {
  printf 'worker-%s-%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$$"
}

cmd="${SDD_ARGS[0]:-help}"

case "$cmd" in
  dispatch)
    feature_input="${SDD_FEATURE_OVERRIDE:-}"
    provider="codex"
    role="research-scout"
    dispatch_id=""
    permission_mode=""
    custom_task_text=""
    custom_task_source="none"
    prompt_template=""
    runtime_mode="record-only"
    args=("${SDD_ARGS[@]:1}")
    idx=0
    while [ "$idx" -lt "${#args[@]}" ]; do
      arg="${args[$idx]}"
      case "$arg" in
        --provider)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "worker" "sdd worker dispatch <feature> --provider <name>" "missing value for --provider"
          provider="${args[$idx]}"
          ;;
        --role)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "worker" "sdd worker dispatch <feature> --role <role>" "missing value for --role"
          role="${args[$idx]}"
          ;;
        --dispatch-id)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "worker" "sdd worker dispatch <feature> --dispatch-id <id>" "missing value for --dispatch-id"
          dispatch_id="${args[$idx]}"
          ;;
        --permission-mode|--permission)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "worker" "sdd worker dispatch <feature> --permission-mode <mode>" "missing value for --permission-mode"
          permission_mode="${args[$idx]}"
          ;;
        --task-text|--custom-task|--prompt)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "worker" "sdd worker dispatch <feature> --task-text <text>" "missing value for --task-text"
          custom_task_text="${args[$idx]}"
          custom_task_source="inline"
          ;;
        --template)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "worker" "sdd worker dispatch <feature> --template <name>" "missing value for --template"
          prompt_template="${args[$idx]}"
          ;;
        --runtime-mode)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "worker" "sdd worker dispatch <feature> --runtime-mode <mode>" "missing value for --runtime-mode"
          runtime_mode="${args[$idx]}"
          ;;
        --preflight)
          runtime_mode="preflight"
          ;;
        --*)
          sdd_usage_error "worker" "sdd worker dispatch <feature> [--provider codex] [--role <role>] [--task-text <text>]" "unknown dispatch option '$arg'"
          ;;
        *)
          if [ -z "$feature_input" ]; then
            feature_input="$arg"
          else
            sdd_usage_error "worker" "sdd worker dispatch <feature> [--task-text <text>]" "unexpected argument '$arg'"
          fi
          ;;
      esac
      idx=$((idx + 1))
    done

    case "$provider" in
      codex) ;;
      *) sdd_fail "worker" "precondition" "unsupported worker provider '$provider'" "{\"provider\":\"$provider\",\"supported\":[\"codex\"]}" "$feature_input" "arg" ;;
    esac

    case "$runtime_mode" in
      record-only|preflight) ;;
      *) sdd_fail "worker" "precondition" "unsupported worker runtime mode '$runtime_mode'" "{\"runtime_mode\":\"$runtime_mode\",\"supported\":[\"record-only\",\"preflight\"]}" "$feature_input" "arg" ;;
    esac

    role="$(sdd_normalize_agent_role "$role")"
    sdd_worker_role_is_supported "$role" || \
      sdd_fail "worker" "precondition" "unsupported worker role '$role'" "{\"role\":\"$role\"}" "$feature_input" "arg"

    [ -n "$dispatch_id" ] || dispatch_id="$(generated_dispatch_id)"
    sdd_worker_dispatch_id_is_safe "$dispatch_id" || \
      sdd_fail "worker" "precondition" "dispatch id contains unsupported characters" "{\"dispatch_id\":\"$dispatch_id\"}" "$feature_input" "arg"

    resolve_worker_feature "$feature_input" "$(sdd_is_machine_mode && echo 1 || echo 0)"
    feature="$SDD_RESOLVED_FEATURE_PATH"
    feature_id="$SDD_RESOLVED_FEATURE"
    feature_dir="$SDD_RESOLVED_FEATURE_DIR"
    phase="$(sdd_feature_phase "$feature")"
    [ -n "$permission_mode" ] || permission_mode="$(sdd_worker_default_permission_mode "$provider" "$phase")"

    packet="$(sdd_build_dispatch_packet "$role" "$feature" "$phase" "" "$dispatch_id" "0")"
    dispatch_json="$(printf '%s\n' "$packet" | sdd_extract_machine_dispatch_record)"
    [ -n "$dispatch_json" ] || sdd_fail "worker" "internal" "failed to build dispatch record" "{\"feature\":\"$feature\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"
    policy_json="$(sdd_worker_dispatch_policy_json "$provider" "$phase" "$permission_mode" "$dispatch_json")"
    if [ "$(printf '%s\n' "$policy_json" | jq -r '.ok // false')" != "true" ]; then
      sdd_fail \
        "worker" \
        "$(printf '%s\n' "$policy_json" | jq -r '.error_type // "precondition"')" \
        "$(printf '%s\n' "$policy_json" | jq -r '.message // "worker dispatch policy refused the request"')" \
        "$(printf '%s\n' "$policy_json" | jq -c '.details // {}')" \
        "$feature_id" \
        "$SDD_RESOLUTION_SOURCE" \
        "$phase"
    fi
    dispatch_json="$(sdd_worker_apply_policy_metadata "$dispatch_json" "$policy_json")"

    preflight_json=""
    if [ "$provider" = "codex" ] && [ "$runtime_mode" = "preflight" ]; then
      if ! preflight_json="$(sdd_codex_preflight_json)"; then
        sdd_fail \
          "worker" \
          "provider_unavailable" \
          "$(printf '%s\n' "$preflight_json" | jq -r '.error.message // "Codex provider is unavailable"')" \
          "$(printf '%s\n' "$preflight_json" | jq -c '.error.details // {}')" \
          "$feature_id" \
          "$SDD_RESOLUTION_SOURCE" \
          "$phase"
      fi
    fi

    rendered_prompt=""
    prompt_hash=""
    template_file=""
    prompt_status="not_rendered"
    if [ "$provider" = "codex" ]; then
      if [ -z "$prompt_template" ]; then
        prompt_template="$(sdd_codex_template_for_role "$role")" || \
          sdd_fail "worker" "precondition" "no default Codex template for role '$role'" "{\"role\":\"$role\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"
      fi
      case "$prompt_template" in
        research|plan|implement|review) ;;
        *) sdd_fail "worker" "precondition" "unsupported Codex template '$prompt_template'" "{\"template\":\"$prompt_template\",\"supported\":[\"research\",\"plan\",\"implement\",\"review\"]}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase" ;;
      esac
      template_file="$SDD_TEMPLATE_DIR/codex/$prompt_template.md"
      [ -f "$template_file" ] || \
        sdd_fail "worker" "precondition" "Codex prompt template '$prompt_template' is missing" "{\"template\":\"$prompt_template\",\"path\":\"$template_file\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"
      rendered_prompt="$(sdd_codex_render_template "$template_file" "$packet" "$custom_task_text" "$feature" "$phase" "$role" "$dispatch_id" "$permission_mode")"
      prompt_hash="sha256:$(sdd_string_sha256 "$rendered_prompt")"
      prompt_status="rendered"
    fi

    dispatch_json="$(sdd_worker_enrich_dispatch_record "$dispatch_json" "$provider" "$permission_mode" "$prompt_template" "$template_file" "$prompt_hash" "$custom_task_source" "$custom_task_text" "$runtime_mode" "$prompt_status")"
    if [ -n "$preflight_json" ]; then
      dispatch_json="$(printf '%s\n' "$dispatch_json" | jq -c --argjson preflight "$preflight_json" '.runtime.preflight = $preflight')"
    fi

    dispatch_path="$(sdd_dispatch_record_path "$feature" "$dispatch_id")"
    sdd_write_file_atomic "$dispatch_path" "$dispatch_json" || \
      sdd_fail "worker" "internal" "failed to write dispatch record" "{\"path\":\"$dispatch_path\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"

    data_json="$(jq -nc \
      --arg dispatch_id "$dispatch_id" \
      --arg dispatch_path "$dispatch_path" \
      --arg provider "$provider" \
      --arg role "$role" \
      --arg phase "$phase" \
      --arg permission_mode "$permission_mode" \
      --argjson dispatch "$dispatch_json" \
      '{
        action: "dispatch",
        dispatch_id: $dispatch_id,
        dispatch_record_path: $dispatch_path,
        provider: $provider,
        role: $role,
        phase: $phase,
        permission_mode: $permission_mode,
        runtime_mode: ($dispatch.runtime.mode // null),
        dispatch: $dispatch
      }')"

    if sdd_is_json_mode; then
      sdd_emit_json_selection "$(sdd_json_success "worker" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase" "$data_json" '{}' '[]')"
    else
      printf 'Dispatch recorded: %s\n' "$dispatch_path"
      printf 'Provider: %s | Role: %s | Phase: %s | Permission: %s | Runtime: %s\n' "$provider" "$role" "$phase" "$permission_mode" "$runtime_mode"
    fi
    ;;
  status)
    feature_input="${SDD_FEATURE_OVERRIDE:-${SDD_ARGS[1]:-}}"
    resolve_worker_feature "$feature_input" "$(sdd_is_machine_mode && echo 1 || echo 0)"
    feature="$SDD_RESOLVED_FEATURE_PATH"
    feature_id="$SDD_RESOLVED_FEATURE"
    phase="$(sdd_feature_phase "$feature")"
    workers_json="$(sdd_worker_state_json "$feature")"
    data_json="$(jq -nc --argjson workers "$workers_json" '{workers:$workers}')"
    if sdd_is_json_mode; then
      sdd_emit_json_selection "$(sdd_json_success "worker" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase" "$data_json" '{}' '[]')"
    else
      printf '%s\n' "$workers_json"
    fi
    ;;
  import-result)
    feature_input="${SDD_FEATURE_OVERRIDE:-}"
    provider="codex"
    dispatch_id=""
    input_file=""
    args=("${SDD_ARGS[@]:1}")
    idx=0
    while [ "$idx" -lt "${#args[@]}" ]; do
      arg="${args[$idx]}"
      case "$arg" in
        --provider)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "worker" "sdd worker import-result <feature> --provider <name>" "missing value for --provider"
          provider="${args[$idx]}"
          ;;
        --dispatch-id)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "worker" "sdd worker import-result <feature> --dispatch-id <id>" "missing value for --dispatch-id"
          dispatch_id="${args[$idx]}"
          ;;
        --file|--raw-output)
          idx=$((idx + 1)); [ "$idx" -lt "${#args[@]}" ] || sdd_usage_error "worker" "sdd worker import-result <feature> --file <path>" "missing value for --file"
          input_file="${args[$idx]}"
          ;;
        --*)
          sdd_usage_error "worker" "sdd worker import-result <feature> --provider codex --file <path>" "unknown import option '$arg'"
          ;;
        *)
          if [ -z "$feature_input" ]; then
            feature_input="$arg"
          else
            sdd_usage_error "worker" "sdd worker import-result <feature> --file <path>" "unexpected argument '$arg'"
          fi
          ;;
      esac
      idx=$((idx + 1))
    done

    case "$provider" in
      codex) ;;
      *) sdd_fail "worker" "precondition" "unsupported worker provider '$provider'" "{\"provider\":\"$provider\",\"supported\":[\"codex\"]}" "$feature_input" "arg" ;;
    esac

    [ -n "$input_file" ] || sdd_usage_error "worker" "sdd worker import-result <feature> --file <path>" "--file is required"

    resolve_worker_feature "$feature_input" "$(sdd_is_machine_mode && echo 1 || echo 0)"
    feature="$SDD_RESOLVED_FEATURE_PATH"
    feature_id="$SDD_RESOLVED_FEATURE"
    phase="$(sdd_feature_phase "$feature")"

    if [ "$input_file" = "-" ]; then
      raw_output="$(cat)"
      raw_source="stdin"
    else
      [ -f "$input_file" ] || sdd_fail "worker" "not_found" "raw result file '$input_file' not found" "{\"file\":\"$input_file\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"
      raw_output="$(cat "$input_file")"
      raw_source="$input_file"
    fi

    result_json="$(printf '%s\n' "$raw_output" | sdd_extract_machine_result_record)"
    [ -n "$result_json" ] || \
      sdd_fail "worker" "validation" "raw Codex output does not contain a Machine Result Record JSON block" "{\"provider\":\"codex\",\"source\":\"$raw_source\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"
    printf '%s\n' "$result_json" | jq -e . >/dev/null 2>&1 || \
      sdd_fail "worker" "validation" "Machine Result Record must contain valid JSON" "{\"provider\":\"codex\",\"source\":\"$raw_source\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"

    result_dispatch_id="$(printf '%s\n' "$result_json" | jq -r '.dispatch_id // empty')"
    [ -n "$dispatch_id" ] || dispatch_id="$result_dispatch_id"
    [ -n "$dispatch_id" ] || \
      sdd_fail "worker" "validation" "Codex result is missing dispatch_id" "{\"provider\":\"codex\",\"source\":\"$raw_source\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"
    sdd_worker_dispatch_id_is_safe "$dispatch_id" || \
      sdd_fail "worker" "validation" "dispatch id contains unsupported characters" "{\"dispatch_id\":\"$dispatch_id\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"

    dispatch_path="$(sdd_dispatch_record_path "$feature" "$dispatch_id")"
    [ -f "$dispatch_path" ] || \
      sdd_fail "worker" "validation" "dispatch record not found for Codex result" "{\"provider\":\"codex\",\"dispatch_id\":\"$dispatch_id\",\"dispatch_record_path\":\"$dispatch_path\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"

    dispatch_json="$(cat "$dispatch_path")"
    validation_json="$(sdd_codex_result_validation_json "$result_json" "$dispatch_json")"
    if [ "$(printf '%s\n' "$validation_json" | jq -r '.ok // false')" != "true" ]; then
      sdd_fail \
        "worker" \
        "$(printf '%s\n' "$validation_json" | jq -r '.error_type // "validation"')" \
        "$(printf '%s\n' "$validation_json" | jq -r '.message // "Codex result validation failed"')" \
        "$(printf '%s\n' "$validation_json" | jq -c '.details // {}')" \
        "$feature_id" \
        "$SDD_RESOLUTION_SOURCE" \
        "$phase"
    fi

    support_only="$(printf '%s\n' "$validation_json" | jq -r '.support_only // false')"
    imported_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    result_path="$(sdd_result_record_path "$feature" "$dispatch_id")"
    final_json="$(printf '%s\n' "$result_json" | jq -c \
      --arg provider "codex" \
      --arg imported_at "$imported_at" \
      --arg source "$raw_source" \
      --arg dispatch_path "$dispatch_path" \
      --argjson support_only "$support_only" \
      '
        . + {
          provider: $provider,
          support_only: $support_only,
          support_category: (if $support_only then "review-support" else null end),
          import: {
            imported_at: $imported_at,
            source: $source,
            dispatch_record_path: $dispatch_path
          }
        }
      ')"
    sdd_write_file_atomic "$result_path" "$final_json" || \
      sdd_fail "worker" "internal" "failed to write result record" "{\"path\":\"$result_path\"}" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase"

    data_json="$(jq -nc \
      --arg action "import-result" \
      --arg dispatch_id "$dispatch_id" \
      --arg provider "codex" \
      --arg result_path "$result_path" \
      --arg dispatch_path "$dispatch_path" \
      --argjson support_only "$support_only" \
      --argjson result "$final_json" \
      '{
        action: $action,
        dispatch_id: $dispatch_id,
        provider: $provider,
        result_record_path: $result_path,
        dispatch_record_path: $dispatch_path,
        support_only: $support_only,
        result: $result
      }')"

    if sdd_is_json_mode; then
      sdd_emit_json_selection "$(sdd_json_success "worker" "$feature_id" "$SDD_RESOLUTION_SOURCE" "$phase" "$data_json" '{}' '[]')"
    else
      printf 'Result imported: %s\n' "$result_path"
      if [ "$support_only" = "true" ]; then
        printf 'Provider: codex | Dispatch: %s | Support-only review evidence\n' "$dispatch_id"
      else
        printf 'Provider: codex | Dispatch: %s\n' "$dispatch_id"
      fi
    fi
    ;;
  help|"")
    show_help
    ;;
  *)
    sdd_usage_error "worker" "sdd worker {dispatch|status|import-result} <feature> [args]" "unknown worker subcommand '$cmd'"
    ;;
esac
