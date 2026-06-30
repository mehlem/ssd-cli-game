#!/usr/bin/env bash
# sdd-trace.sh — Generate and inspect per-feature trace.json sidecars.
# Usage: sdd trace {refresh|ensure|doctor|coverage|acknowledge} <feature-id>

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 1

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_install_cleanup_trap
sdd_parse_common_args "$@" || sdd_usage_error "trace" "sdd trace {refresh|ensure|doctor|coverage|acknowledge} <feature-id>" "invalid shared CLI flags"

SUBCOMMAND="${SDD_ARGS[0]:-help}"
FEATURE_INPUT="${SDD_FEATURE_OVERRIDE:-${SDD_ARGS[1]:-}}"

show_help() {
  if sdd_is_json_mode; then
    local commands_json examples_json data_json result_json
    commands_json='[
      {"command":"refresh","summary":"Rebuild trace.json from artifact files"},
      {"command":"ensure","summary":"Rebuild only when trace.json is missing or stale"},
      {"command":"doctor","summary":"Print human-readable trace problems"},
      {"command":"coverage","summary":"Evaluate trace coverage rules and report gaps"},
      {"command":"acknowledge","summary":"Restamp based_on for suspect artifacts after operator verification"}
    ]'
    examples_json='[
      "sdd trace refresh 0026-sdd-task-dependency-graph",
      "sdd trace ensure --feature auto",
      "sdd trace doctor 0030-sdd-trace-graph",
      "sdd trace coverage 0026-sdd-task-dependency-graph --json",
      "sdd trace acknowledge 0043-sdd-trace-acknowledge --confirmed --reason \"verified downstream updates\""
    ]'
    data_json="$(jq -nc \
      --arg summary "Generate or inspect a feature trace graph sidecar." \
      --arg usage "sdd trace {refresh|ensure|doctor|coverage|acknowledge} <feature-id> [--feature <id|auto>] [--format text|json]" \
      --argjson flags "$(sdd_common_flags_json)" \
      --argjson commands "$commands_json" \
      --argjson examples "$examples_json" \
      --argjson exit_codes '{
        "0": "success",
        "2": "usage / parse error",
        "3": "target not found",
        "4": "precondition / readiness / gate failure",
        "5": "conflict / would-prompt / overwrite-policy failure",
        "6": "blocked / manual decision required",
        "7": "internal failure / verification failure / unexpected runtime failure"
      }' \
      '{
        summary: $summary,
        usage: $usage,
        output_formats: ["text", "json"],
        flags: $flags,
        commands: $commands,
        examples: $examples,
        exit_codes: $exit_codes
      }')"
    result_json="$(sdd_json_success "trace" "" "none" "" "$data_json" '{}' '[]')"
    sdd_emit_json_selection "$(printf '%s\n' "$result_json" | jq -c '. + {commands: .data.commands}')"
    return 0
  fi

  echo "Usage: sdd trace {refresh|ensure|doctor|coverage|acknowledge} <feature-id>"
  echo "       sdd trace acknowledge <feature-id> [ARTIFACT-ID...] --confirmed [--reason <text>]"
  echo ""
  echo "refresh     Rebuild trace.json from artifact files"
  echo "ensure      Rebuild only when trace.json is missing or stale"
  echo "doctor      Print human-readable trace problems"
  echo "coverage    Evaluate trace coverage rules and report gaps"
  echo "acknowledge Restamp based_on for suspect artifacts after operator verification"
}

show_acknowledge_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "trace" \
      "Restamp based_on for suspect artifacts after operator verification." \
      "sdd trace acknowledge <feature-id> [ARTIFACT-ID...] --confirmed [--reason <text>]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd trace acknowledge 0043-sdd-trace-acknowledge --confirmed",
        "sdd trace acknowledge 0043-sdd-trace-acknowledge PLAN-0043 --confirmed",
        "sdd trace acknowledge --feature auto --confirmed --reason \"verified downstream updates\""
      ]'
    return 0
  fi

  echo "Usage: sdd trace acknowledge <feature-id> [ARTIFACT-ID...] --confirmed [--reason <text>]"
  echo ""
  echo "All-suspect mode: with no ARTIFACT-ID values, restamps every currently suspect artifact."
  echo "Explicit-ID mode: with ARTIFACT-ID values, restamps only those currently suspect artifacts."
  echo "--confirmed is required before any based_on frontmatter is written."
  echo "--reason <text> records optional rationale in changes.log."
}

[ "$SDD_HELP" = "1" ] && {
  if [ "$SUBCOMMAND" = "acknowledge" ]; then
    show_acknowledge_help
  else
    show_help
  fi
  exit 0
}

resolve_feature() {
  sdd_resolve_feature_target "$FEATURE_INPUT" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
    case "$SDD_RESOLUTION_STATUS" in
      not_found)
        sdd_fail "trace" "not_found" "feature '$FEATURE_INPUT' not found" "{\"feature\":\"$FEATURE_INPUT\"}" "$FEATURE_INPUT" "arg"
        ;;
      ambiguous)
        sdd_fail "trace" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto"
        ;;
      none)
        sdd_usage_error "trace" "sdd trace {refresh|ensure|doctor|coverage|acknowledge} <feature-id>" "feature ID required"
        ;;
    esac
  }
  FEATURE="$SDD_RESOLVED_FEATURE"
  FEATURE_PATH="${SDD_RESOLVED_FEATURE_PATH:-$FEATURE}"
  FEATURE_DIR_REL="${SDD_RESOLVED_FEATURE_DIR:-.features/$FEATURE_PATH}"
  [ -d "$FEATURE_DIR_REL" ] || sdd_fail "trace" "not_found" "feature directory '$FEATURE_DIR_REL' not found" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  FEATURE_DIR="$(cd "$FEATURE_DIR_REL" && pwd)"
  TRACE_PATH_REL="$FEATURE_DIR_REL/trace.json"
  TRACE_PATH="$FEATURE_DIR/trace.json"
}

file_mtime() {
  local path="$1"
  if stat -f %m "$path" >/dev/null 2>&1; then
    stat -f %m "$path"
  else
    stat -c %Y "$path"
  fi
}

trace_needs_refresh() {
  local trace_file="$1" feature_dir="$2" trace_mtime artifact

  if [ ! -f "$trace_file" ] || ! jq -e . "$trace_file" >/dev/null 2>&1; then
    return 0
  fi

  trace_mtime="$(file_mtime "$trace_file")"
  while IFS= read -r artifact; do
    [ -f "$artifact" ] || continue
    if [ "$(file_mtime "$artifact")" -gt "$trace_mtime" ]; then
      return 0
    fi
  done < <(sdd_trace_feature_markdown_files "$feature_dir")

  return 1
}

build_trace_json() {
  local feature="$1" feature_dir="$2"
  local artifact_nodes spec_nodes plan_nodes task_nodes file_nodes edges_json
  local task_file nodes_array nodes_map stub_nodes='[]' unresolved_problems='[]'
  local missing_refs task_graph_json basis_json next_basis_json nodes_with_basis indexes_json problems_json trace_json

  artifact_nodes="$(sdd_trace_extract_artifact_nodes "$feature_dir")"
  spec_nodes="$(sdd_trace_extract_spec_nodes "$feature_dir/spec.md")"
  plan_nodes="$(sdd_trace_extract_plan_nodes "$feature_dir/plan.md")"

  task_nodes='[]'
  while IFS= read -r task_file; do
    [ -f "$task_file" ] || continue
    task_nodes="$(printf '%s\n' "$task_nodes" | jq -c --argjson arr "$(sdd_trace_extract_task_nodes "$task_file")" '. + $arr')"
  done < <(sdd_task_feature_task_files "$feature_dir/tasks.md")

  file_nodes="$(sdd_trace_extract_file_nodes "$feature_dir/research.md" "$feature_dir/tasks.md")"
  edges_json="$(sdd_trace_extract_edges "$feature_dir")"

  nodes_array="$(jq -nc \
    --argjson artifact_nodes "$artifact_nodes" \
    --argjson spec_nodes "$spec_nodes" \
    --argjson plan_nodes "$plan_nodes" \
    --argjson task_nodes "$task_nodes" \
    --argjson file_nodes "$file_nodes" \
    '$artifact_nodes + $spec_nodes + $plan_nodes + $task_nodes + $file_nodes')"

  nodes_map="$(jq -nc --argjson nodes "$nodes_array" '$nodes | reduce .[] as $node ({}; .[$node.id] = $node)')"
  missing_refs="$(jq -nc --argjson nodes "$nodes_map" --argjson edges "$edges_json" '
    [ $edges[] | .from, .to ]
    | unique
    | map(select($nodes[.] == null))
  ')"

  while IFS= read -r missing_ref; do
    [ -n "$missing_ref" ] || continue
    stub_nodes="$(printf '%s\n' "$stub_nodes" | jq -c --argjson node "$(sdd_trace_stub_node_json "$missing_ref")" '. + [$node]')"
    unresolved_problems="$(printf '%s\n' "$unresolved_problems" | jq -c --arg ref "$missing_ref" --arg kind "$(sdd_trace_guess_kind "$missing_ref")" '
      . + [{
        type: "unresolved_ref",
        ref: $ref,
        kind: $kind,
        message: ("Unresolved reference: " + $ref)
      }]
    ')"
  done < <(printf '%s\n' "$missing_refs" | jq -r '.[]?')

  nodes_map="$(jq -nc --argjson base "$nodes_map" --argjson stubs "$stub_nodes" '
    $base + ($stubs | reduce .[] as $node ({}; .[$node.id] = $node))
  ')"

  task_graph_json="$(sdd_task_graph_json "$feature_dir/tasks.md")"
  basis_json="$(jq -nc --argjson nodes "$nodes_map" '
    reduce ($nodes | to_entries[] | select(.value.kind == "artifact")) as $entry ({};
      .[$entry.key] = (
        ($entry.value.based_on // {}) as $based_on
        | ($based_on | if type == "object" then . else {} end) as $basis_map
        | ($basis_map | to_entries | map(
            . as $stamp
            | ($nodes[$stamp.key] // null) as $upstream
            | if $upstream == null then
                {
                  type: "missing_upstream",
                  upstream: $stamp.key,
                  expected: $stamp.value,
                  current: null,
                  message: ($stamp.key + " is not present in trace nodes")
                }
              elif ($upstream.kind // "") != "artifact" then
                {
                  type: "invalid_upstream",
                  upstream: $stamp.key,
                  expected: $stamp.value,
                  current: ($upstream.rev // null),
                  message: ($stamp.key + " does not resolve to an artifact node")
                }
              elif ($upstream.rev // null) != $stamp.value then
                {
                  type: "changed_upstream",
                  upstream: $stamp.key,
                  expected: $stamp.value,
                  current: ($upstream.rev // null),
                  message: ($stamp.key + " changed since this artifact was generated")
                }
              else
                empty
              end
          )) as $reasons
        | {
            based_on: $basis_map,
            basis_state: (if ($basis_map | length) > 0 then "tracked" else "untracked" end),
            direct_suspect: (($basis_map | length) > 0 and ($reasons | length) > 0),
            suspect: (($basis_map | length) > 0 and ($reasons | length) > 0),
            reasons: $reasons
          }
      )
    )')"

  while :; do
    next_basis_json="$(jq -nc --argjson basis "$basis_json" --argjson edges "$edges_json" '
      reduce ($edges[] | select(.type == "derived_from")) as $edge ($basis;
        if (.[$edge.from] != null and (.[$edge.from].basis_state // "") == "tracked" and (.[$edge.from].suspect // false) == false and (.[$edge.to].suspect // false) == true) then
          .[$edge.from].suspect = true
          | .[$edge.from].reasons = ((.[$edge.to].reasons // []) + [{
              type: "propagated",
              via: $edge.to,
              message: ("Derived from suspect " + $edge.to)
            }])
        else
          .
        end
      )')"
    [ "$next_basis_json" = "$basis_json" ] && break
    basis_json="$next_basis_json"
  done

  nodes_with_basis="$(jq -nc --argjson nodes "$nodes_map" --argjson basis "$basis_json" '
    $nodes
    | with_entries(
        if .value.kind == "artifact" and ($basis[.key] != null) then
          .value += {
            suspect: ($basis[.key].suspect // false),
            basis_state: ($basis[.key].basis_state // null)
          }
        else
          .
        end
      )')"

  indexes_json="$(jq -nc --argjson nodes "$nodes_with_basis" --argjson edges "$edges_json" --argjson task_nodes "$task_nodes" '
    {
      incoming: (reduce $edges[] as $edge ({}; .[$edge.to] = ((.[$edge.to] // []) + [{from: $edge.from, type: $edge.type}]))),
      implemented_by: (reduce $edges[] as $edge ({}; if $edge.type == "implements" then .[$edge.to] = ((.[$edge.to] // []) + [$edge.from]) else . end)),
      ready_tasks: ([
        $task_nodes[]
        | .id as $task_id
        | select((.status // "") == "pending")
        | ([ $edges[] | select(.from == $task_id and .type == "depends_on") | .to ]) as $deps
        | select(all($deps[]?; (($nodes[.] // null) != null and ($nodes[.].kind // "") == "task" and (($nodes[.].status // "") == "completed"))))
        | $task_id
      ]),
      blocked_tasks: (
        [ $task_nodes[]
          | .id as $task_id
          | select((.status // "") == "pending")
          | ([ $edges[] | select(.from == $task_id and .type == "depends_on") | .to ]) as $deps
          | ([ $deps[] | select((($nodes[.] // null) == null) or (($nodes[.].kind // "") != "task") or (($nodes[.].status // "") != "completed")) ]) as $blockers
          | select(($blockers | length) > 0)
          | {key: $task_id, value: $blockers}
        ] | from_entries
      )
    }')"

  problems_json="$(jq -nc --argjson unresolved "$unresolved_problems" --argjson task_graph "$task_graph_json" '
    $unresolved + ($task_graph.problems // [])
  ')"

  trace_json="$(jq -nc \
    --argjson schema_version 1 \
    --arg feature "$feature" \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson nodes "$nodes_with_basis" \
    --argjson edges "$edges_json" \
    --argjson indexes "$indexes_json" \
    --argjson basis "$basis_json" \
    --argjson problems "$problems_json" \
    '{
      schema_version: $schema_version,
      feature: $feature,
      generated_at: $generated_at,
      nodes: $nodes,
      edges: $edges,
      indexes: $indexes,
      basis: $basis,
      problems: $problems
    }')"

  printf '%s\n' "$trace_json"
}

trace_stats_json() {
  local trace_json="$1"
  printf '%s\n' "$trace_json" | jq -c '
    {
      node_count: (.nodes | length),
      edge_count: (.edges | length),
      problem_count: (.problems | length),
      suspect_artifacts: (.basis | to_entries | map(select(.value.suspect == true)) | length)
    }'
}

write_trace_file() {
  local trace_json="$1"
  sdd_write_file_atomic "$TRACE_PATH" "$trace_json"
}

emit_trace_result() {
  local action="$1" refreshed="$2" trace_json="$3"
  local stats_json data_json phase problems_json

  stats_json="$(trace_stats_json "$trace_json")"
  problems_json="$(printf '%s\n' "$trace_json" | jq -c '.problems')"
  phase="$(sdd_feature_phase "$FEATURE")"

  if sdd_is_json_mode; then
    data_json="$(jq -nc \
      --arg action "$action" \
      --arg trace_path "$TRACE_PATH_REL" \
      --argjson refreshed "$refreshed" \
      --argjson stats "$stats_json" \
      --argjson problems "$problems_json" \
      '{
        action: $action,
        trace_path: $trace_path,
        refreshed: $refreshed,
        stats: $stats,
        problems: $problems
      }')"
    sdd_emit_json_selection "$(sdd_json_success "trace" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}" "$phase" "$data_json" '{}' '[]')"
    return 0
  fi

  printf '%s: %s (%s nodes, %s edges, %s suspect, %s problems)\n' \
    "$(printf '%s' "$action" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')" \
    "$TRACE_PATH_REL" \
    "$(printf '%s\n' "$stats_json" | jq -r '.node_count')" \
    "$(printf '%s\n' "$stats_json" | jq -r '.edge_count')" \
    "$(printf '%s\n' "$stats_json" | jq -r '.suspect_artifacts')" \
    "$(printf '%s\n' "$stats_json" | jq -r '.problem_count')"
}

ensure_trace_current() {
  local trace_json refreshed=false

  if trace_needs_refresh "$TRACE_PATH" "$FEATURE_DIR"; then
    trace_json="$(build_trace_json "$FEATURE" "$FEATURE_DIR")"
    write_trace_file "$trace_json"
    refreshed=true
  else
    trace_json="$(cat "$TRACE_PATH")"
  fi

  TRACE_JSON="$trace_json"
  TRACE_REFRESHED="$refreshed"
}

cmd_refresh() {
  local trace_json
  resolve_feature
  trace_json="$(build_trace_json "$FEATURE" "$FEATURE_DIR")"
  write_trace_file "$trace_json"
  emit_trace_result "refresh" true "$trace_json"
}

cmd_ensure() {
  resolve_feature
  ensure_trace_current
  emit_trace_result "ensure" "$TRACE_REFRESHED" "$TRACE_JSON"
}

cmd_doctor() {
  local problems
  resolve_feature
  ensure_trace_current

  if sdd_is_json_mode; then
    emit_trace_result "doctor" "$TRACE_REFRESHED" "$TRACE_JSON"
    problems="$(printf '%s\n' "$TRACE_JSON" | jq -r '
      .problems[]
      | "- " + (.message // (.type + ": " + (.ref // .task // .upstream // "problem")))
    ' 2>/dev/null || true)"
    if [ -z "$problems" ]; then
      printf 'No trace problems for %s\n' "$FEATURE" >&2
    else
      printf '%s\n' "$problems" >&2
    fi
    return 0
  fi

  problems="$(printf '%s\n' "$TRACE_JSON" | jq -r '
    .problems[]
    | "- " + (.message // (.type + ": " + (.ref // .task // .upstream // "problem")))
  ' 2>/dev/null || true)"

  if [ -z "$problems" ]; then
    printf 'No trace problems for %s\n' "$FEATURE"
  else
    printf '%s\n' "$problems"
  fi
}

cmd_coverage() {
  local coverage_json rules_path phase data_json

  resolve_feature
  ensure_trace_current
  rules_path="$(sdd_trace_rules_path)"
  coverage_json="$(sdd_trace_coverage_evaluate "$FEATURE_DIR" "$rules_path")"

  if sdd_is_json_mode; then
    phase="$(sdd_feature_phase "$FEATURE")"
    data_json="$(jq -nc \
      --arg action "coverage" \
      --arg trace_path "$TRACE_PATH_REL" \
      --arg rules_path "$rules_path" \
      --argjson refreshed "$TRACE_REFRESHED" \
      --argjson coverage "$coverage_json" \
      '{
        action: $action,
        trace_path: $trace_path,
        rules_path: $rules_path,
        refreshed: $refreshed,
        coverage: $coverage
      }')"
    sdd_emit_json_selection "$(sdd_json_success "trace" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}" "$phase" "$data_json" '{}' '[]')"
    return 0
  fi

  if [ "$(printf '%s\n' "$coverage_json" | jq -r '.present')" != "true" ]; then
    printf 'Trace coverage unavailable for %s: %s\n' "$FEATURE" "$(printf '%s\n' "$coverage_json" | jq -r '.note // "no trace data available"')"
    return 0
  fi

  printf 'Trace coverage for %s\n' "$FEATURE"
  printf 'score: %s%% (%s/%s checks, %s passed, %s failed, %s skipped rules)\n' \
    "$(printf '%s\n' "$coverage_json" | jq -r '.score')" \
    "$(printf '%s\n' "$coverage_json" | jq -r '.summary.checks_passed')" \
    "$(printf '%s\n' "$coverage_json" | jq -r '.summary.applicable_checks')" \
    "$(printf '%s\n' "$coverage_json" | jq -r '.summary.rules_passed')" \
    "$(printf '%s\n' "$coverage_json" | jq -r '.summary.rules_failed')" \
    "$(printf '%s\n' "$coverage_json" | jq -r '.summary.rules_skipped')"

  while IFS=$'\t' read -r rule_status rule_id applicable passed note; do
    [ -n "$rule_id" ] || continue
    case "$rule_status" in
      PASS) printf 'PASS %s (%s/%s)\n' "$rule_id" "$passed" "$applicable" ;;
      FAIL) printf 'FAIL %s (%s/%s)\n' "$rule_id" "$passed" "$applicable" ;;
      SKIP) printf 'SKIP %s (%s)\n' "$rule_id" "$note" ;;
      *) printf '%s %s (%s/%s)\n' "$rule_status" "$rule_id" "$passed" "$applicable" ;;
    esac
  done < <(
    printf '%s\n' "$coverage_json" | jq -r '
      .rules[]
      | [
          .status,
          .id,
          (if .applicable == 0 then "n/a" else (.applicable | tostring) end),
          (if .applicable == 0 then "n/a" else (.passed | tostring) end),
          (.note // "not applicable")
        ]
      | @tsv
    '
  )

  while IFS= read -r gap_line; do
    [ -n "$gap_line" ] || continue
    printf '  - %s\n' "$gap_line"
  done < <(
    printf '%s\n' "$coverage_json" | jq -r '
      .rules[]
      | select(.status == "FAIL")
      | .id as $rule_id
      | .gaps[]?
      | "\($rule_id): \(.)"
    '
  )
}

cmd_acknowledge() {
  local confirmed=0 reason="" parse_start=1 arg
  local target_id upstreams line upstream expected current artifact_path
  local timestamp acknowledged_json upstreams_json payload_json changes_log
  local pre_count post_count cleared refresh_output refresh_rc
  local upstream_args=()
  local upstream_ids=()
  local explicit_ids=()
  local target_ids=()
  local target_upstreams=()

  resolve_feature

  if [ -z "${SDD_FEATURE_OVERRIDE:-}" ]; then
    parse_start=2
  fi

  while [ "$parse_start" -lt "${#SDD_ARGS[@]}" ]; do
    arg="${SDD_ARGS[$parse_start]}"
    case "$arg" in
      --confirmed)
        confirmed=1
        ;;
      --reason)
        parse_start=$((parse_start + 1))
        [ "$parse_start" -lt "${#SDD_ARGS[@]}" ] || sdd_usage_error "trace" "sdd trace acknowledge <feature-id> [ARTIFACT-ID...] --confirmed [--reason <text>]" "--reason requires a value"
        reason="${SDD_ARGS[$parse_start]}"
        ;;
      *)
        explicit_ids+=("$arg")
        ;;
    esac
    parse_start=$((parse_start + 1))
  done

  ensure_trace_current

  if [ "${#explicit_ids[@]}" -eq 0 ]; then
    while IFS=$'\t' read -r target_id upstreams; do
      [ -n "$target_id" ] || continue
      target_ids+=("$target_id")
      target_upstreams+=("$upstreams")
    done < <(
      printf '%s\n' "$TRACE_JSON" | jq -r '
        .basis
        | to_entries
        | map(select(.value.suspect == true))
        | .[]
        | [.key, ((.value.based_on // {}) | keys | join(" "))]
        | @tsv
      '
    )
  else
    for arg in "${explicit_ids[@]}"; do
      artifact_path="$(sdd_feature_artifact_path_by_id "$FEATURE_DIR" "$arg" 2>/dev/null || true)"
      [ -n "$artifact_path" ] || sdd_usage_error "trace" "sdd trace acknowledge <feature-id> [ARTIFACT-ID...] --confirmed [--reason <text>]" "unknown artifact ID '$arg'"

      line="$(printf '%s\n' "$TRACE_JSON" | jq -er --arg id "$arg" '
        .basis[$id]
        | select(.suspect == true)
        | [$id, ((.based_on // {}) | keys | join(" "))]
        | @tsv
      ' 2>/dev/null || true)"

      if [ -z "$line" ]; then
        printf '%s is not currently suspect - skipping\n' "$arg" >&2
        continue
      fi

      IFS=$'\t' read -r target_id upstreams <<< "$line"
      target_ids+=("$target_id")
      target_upstreams+=("$upstreams")
    done
  fi

  if [ "${#target_ids[@]}" -eq 0 ]; then
    printf 'no suspect artifacts to acknowledge\n'
    return 0
  fi

  if [ "$confirmed" -ne 1 ]; then
    local i=0
    while [ "$i" -lt "${#target_ids[@]}" ]; do
      target_id="${target_ids[$i]}"
      upstreams="${target_upstreams[$i]}"
      if [ -z "$upstreams" ]; then
        printf 'Would restamp %s\n' "$target_id"
      else
        for upstream in $upstreams; do
          expected="$(printf '%s\n' "$TRACE_JSON" | jq -r --arg id "$target_id" --arg upstream "$upstream" '.basis[$id].based_on[$upstream] // "null"')"
          current="$(printf '%s\n' "$TRACE_JSON" | jq -r --arg upstream "$upstream" '.nodes[$upstream].rev // "null"')"
          printf 'Would restamp %s: based_on.%s %s -> %s\n' "$target_id" "$upstream" "$expected" "$current"
        done
      fi
      i=$((i + 1))
    done
    exit "$SDD_EXIT_PRECONDITION"
  fi

  pre_count="$(printf '%s\n' "$TRACE_JSON" | jq -r '.basis | to_entries | map(select(.value.suspect == true)) | length')"

  local i=0
  while [ "$i" -lt "${#target_ids[@]}" ]; do
    target_id="${target_ids[$i]}"
    upstreams="${target_upstreams[$i]}"
    artifact_path="$(sdd_feature_artifact_path_by_id "$FEATURE_DIR" "$target_id" 2>/dev/null || true)"
    [ -n "$artifact_path" ] || sdd_fail "trace" "internal" "acknowledge: failed to resolve $target_id" "{\"artifact\":\"$target_id\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"

    upstream_args=()
    for upstream in $upstreams; do
      upstream_args+=("$upstream")
    done

    if ! sdd_stamp_based_on "$artifact_path" "${upstream_args[@]}"; then
      sdd_fail "trace" "internal" "acknowledge: failed to restamp $target_id at $artifact_path" "{\"artifact\":\"$target_id\",\"path\":\"$artifact_path\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
    fi
    i=$((i + 1))
  done

  for upstreams in "${target_upstreams[@]}"; do
    for upstream in $upstreams; do
      upstream_ids+=("$upstream")
    done
  done

  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  acknowledged_json="$(printf '%s\n' "${target_ids[@]}" | jq -Rcs 'split("\n") | map(select(length > 0))')"
  upstreams_json="$(printf '%s\n' "${upstream_ids[@]}" | jq -Rcs 'split("\n") | map(select(length > 0)) | unique')"
  payload_json="$(jq -nc \
    --arg timestamp "$timestamp" \
    --arg event "trace_acknowledge" \
    --argjson acknowledged "$acknowledged_json" \
    --argjson upstreams "$upstreams_json" \
    --arg reason "$reason" \
    '{
      timestamp: $timestamp,
      event: $event,
      acknowledged: $acknowledged,
      upstreams: $upstreams,
      reason: (if $reason == "" then null else $reason end)
    }')"
  changes_log="$FEATURE_DIR/changes.log"
  printf '%s | trace_acknowledge | %s\n' "$timestamp" "$payload_json" >> "$changes_log"

  set +e
  refresh_output="$(cmd_refresh 2>&1)"
  refresh_rc=$?
  set -e

  post_count="$(jq -r '.basis | to_entries | map(select(.value.suspect == true)) | length' "$TRACE_PATH" 2>/dev/null || printf '%s\n' "$pre_count")"
  cleared=$((pre_count - post_count))
  printf 'refreshed trace.json: %d suspect nodes cleared (was %d, now %d)\n' "$cleared" "$pre_count" "$post_count"

  if [ "$refresh_rc" -ne 0 ]; then
    [ -n "$refresh_output" ] && printf '%s\n' "$refresh_output" >&2
    sdd_fail "trace" "internal" "acknowledge: restamped artifacts but trace refresh failed" "{\"feature\":\"$FEATURE\"}" "$FEATURE" "${SDD_RESOLUTION_SOURCE:-arg}"
  fi

  return 0
}

case "$SUBCOMMAND" in
  refresh) cmd_refresh ;;
  ensure) cmd_ensure ;;
  doctor) cmd_doctor ;;
  coverage) cmd_coverage ;;
  acknowledge) cmd_acknowledge ;;
  help|"") show_help ;;
  *)
    sdd_usage_error "trace" "sdd trace {refresh|ensure|doctor|coverage|acknowledge} <feature-id>" "unknown trace subcommand '$SUBCOMMAND'"
    ;;
esac
