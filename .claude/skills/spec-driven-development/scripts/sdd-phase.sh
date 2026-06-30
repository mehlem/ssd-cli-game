#!/usr/bin/env bash
# sdd-phase.sh — Detect the current phase for a feature (or auto-detect active feature)
# Usage: sdd-phase.sh [feature-id]
# Output: feature-id and phase name on stdout
#
# Phase detection (7 phases):
#   no brief.md                          → brief
#   brief.md, no spec.md                 → design
#   spec.md, no research.md              → research
#   research.md, no plan.md              → plan
#   plan.md, no tasks.md                 → plan-tasks
#   tasks.md with pending/in-progress    → implement
#   all tasks done, no review.md         → review
#   review.md verdict: pass (+ sufficient evidence when adjudicated) → close
#   review.md verdict: fail              → implement
#   review.md verdict: reopened          → implement

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
FEATURE_ROOT="$SDD_FEATURE_ROOT"
SCHEMA_VERSION=1
OUTPUT_FORMAT="text"
FEATURE_OVERRIDE=""
FIELD=""
JQ_EXPR=""
SHOW_HELP=0
POSITIONAL_ARGS=()

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --help|-h)
        SHOW_HELP=1
        ;;
      --json)
        OUTPUT_FORMAT="json"
        ;;
      --format)
        shift
        case "${1:-}" in
          text|json) OUTPUT_FORMAT="$1" ;;
          *) echo "Error [usage]: invalid --format value '${1:-}'" >&2; exit 2 ;;
        esac
        ;;
      --feature)
        shift
        [ -n "${1:-}" ] || { echo "Error [usage]: --feature requires a value" >&2; exit 2; }
        FEATURE_OVERRIDE="$1"
        ;;
      --field)
        shift
        [ -n "${1:-}" ] || { echo "Error [usage]: --field requires a value" >&2; exit 2; }
        FIELD="$1"
        OUTPUT_FORMAT="json"
        ;;
      --jq)
        shift
        [ -n "${1:-}" ] || { echo "Error [usage]: --jq requires a value" >&2; exit 2; }
        JQ_EXPR="$1"
        OUTPUT_FORMAT="json"
        ;;
      --)
        shift
        while [ $# -gt 0 ]; do
          POSITIONAL_ARGS+=("$1")
          shift
        done
        break
        ;;
      *)
        POSITIONAL_ARGS+=("$1")
        ;;
    esac
    shift
  done

  if [ -n "$FIELD" ] && [ -n "$JQ_EXPR" ]; then
    echo "Error [usage]: --field and --jq cannot be combined" >&2
    exit 2
  fi
}

selector_expr() {
  if [ -n "$JQ_EXPR" ]; then
    printf '%s\n' "$JQ_EXPR"
  elif [ -n "$FIELD" ]; then
    case "$FIELD" in
      .*) printf '%s\n' "$FIELD" ;;
      *)  printf '.%s\n' "$FIELD" ;;
    esac
  else
    printf '.\n'
  fi
}

emit_json_selection() {
  local json="$1"
  local expr

  if [ -z "$FIELD" ] && [ -z "$JQ_EXPR" ]; then
    printf '%s\n' "$json"
    return 0
  fi

  expr="$(selector_expr)"
  printf '%s\n' "$json" | jq -cr "
    ${expr} |
    if . == null then
      \"null\"
    elif (type == \"object\" or type == \"array\") then
      tojson
    else
      .
    end
  "
}

phase_help() {
  if [ "$OUTPUT_FORMAT" = "json" ]; then
    emit_json_selection "$(jq -nc \
      --argjson schema_version "$SCHEMA_VERSION" \
      --argjson flags '[
        {"name":"--help","description":"Show command help"},
        {"name":"--feature <id|auto>","description":"Explicit feature target override"},
        {"name":"--format text|json","description":"Select text or JSON output"},
        {"name":"--json","description":"Alias for --format json"},
        {"name":"--field <path>","description":"Select a field from the JSON response"},
        {"name":"--jq <expr>","description":"Apply a jq expression to the JSON response"}
      ]' \
      --argjson examples '[
        "sdd phase",
        "sdd phase --json",
        "sdd phase --feature 0001-user-auth",
        "sdd phase --field phase"
      ]' \
      '{
        ok: true,
        schema_version: $schema_version,
        command: "phase",
        resolved_feature: null,
        resolution_source: "none",
        phase: null,
        data: {
          summary: "Detect the current SDD phase for a feature or the auto-detected active feature.",
          usage: "sdd phase [feature-id] [--feature <id|auto>] [--format text|json] [--field <path>] [--jq <expr>]",
          output_formats: ["text", "json"],
          flags: $flags,
          aliases: [],
          examples: $examples,
          exit_codes: {
            "0": "success",
            "2": "usage / parse error",
            "3": "target not found",
            "7": "internal failure"
          }
        },
        guidance: {},
        warnings: []
      }')"
    return 0
  fi

  echo "Usage: sdd phase [feature-id] [--feature <id|auto>] [--format text|json] [--field <path>] [--jq <expr>]"
  echo ""
  echo "Detect the current SDD phase for a feature or the auto-detected active feature."
}

emit_wp_fields() {
  local feature_dir="$1"
  local wp_snapshot wp_id wp_phase wp_count wp_done wp_active wp_pending
  wp_snapshot="$(sdd_feature_wp_snapshot "$feature_dir" || true)"
  [ -n "$wp_snapshot" ] || return 0
  IFS=$'\t' read -r wp_id wp_phase wp_count wp_done wp_active wp_pending <<EOF
$wp_snapshot
EOF
  echo "wp: ${wp_id:-none}"
  echo "wp_phase: ${wp_phase:-none}"
  echo "wp_count: ${wp_count:-0}"
  echo "wp_done: ${wp_done:-0}"
  echo "wp_active: ${wp_active:-0}"
  echo "wp_pending: ${wp_pending:-0}"
}

# Main
parse_args "$@"
[ "$SHOW_HELP" = "1" ] && { phase_help; exit 0; }

SDD_OUTPUT_FORMAT="$OUTPUT_FORMAT"
SDD_FIELD="$FIELD"
SDD_JQ_EXPR="$JQ_EXPR"

FEATURE_REF="${FEATURE_OVERRIDE:-${POSITIONAL_ARGS[0]:-}}"

sdd_resolve_feature_target "$FEATURE_REF" 0 || {
  case "$SDD_RESOLUTION_STATUS" in
    not_found)
      if [ "$OUTPUT_FORMAT" = "json" ]; then
        emit_json_selection "$(jq -nc \
          --argjson schema_version "$SCHEMA_VERSION" \
          --arg feature "$FEATURE_REF" \
          '{
            ok: false,
            schema_version: $schema_version,
            command: "phase",
            resolved_feature: $feature,
            resolution_source: "arg",
            phase: null,
            error: {
              type: "not_found",
              message: ("feature directory \($feature) not found"),
              details: {feature: $feature}
            },
            warnings: []
          }')"
      else
        echo "Error [not_found]: feature directory '$FEATURE_REF' not found" >&2
      fi
      exit 3
      ;;
    ambiguous)
      if [ "$OUTPUT_FORMAT" = "json" ]; then
        emit_json_selection "$(jq -nc \
          --argjson schema_version "$SCHEMA_VERSION" \
          --arg feature "$FEATURE_REF" \
          --argjson candidates "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0))')" \
          '{
            ok: false,
            schema_version: $schema_version,
            command: "phase",
            resolved_feature: null,
            resolution_source: "arg",
            phase: null,
            error: {
              type: "blocked",
              message: ("feature \($feature) matches multiple features"),
              details: {feature: $feature, candidates: $candidates}
            },
            warnings: []
          }')"
      else
        echo "Error [blocked]: feature '$FEATURE_REF' matches multiple features. Be more specific." >&2
        printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | sed 's/^/  - /' >&2
      fi
      exit 6
      ;;
    none)
      FEATURE_ID="none"
      ;;
  esac
}

if [ "${FEATURE_ID:-}" != "none" ]; then
  FEATURE_ID="$SDD_RESOLVED_FEATURE"
  FEATURE_PATH="${SDD_RESOLVED_FEATURE_PATH:-$FEATURE_ID}"
  FEATURE_DIR="${SDD_RESOLVED_FEATURE_DIR:-$FEATURE_ROOT/$FEATURE_PATH}"
  FEATURE_GROUP="${SDD_RESOLVED_FEATURE_GROUP:-}"
  SOURCE="${SDD_RESOLUTION_SOURCE:-auto}"
fi

if [ "$FEATURE_ID" = "none" ]; then
  if [ "$OUTPUT_FORMAT" = "json" ]; then
    emit_json_selection "$(jq -nc \
      --argjson schema_version "$SCHEMA_VERSION" \
      '{
        ok: true,
        schema_version: $schema_version,
        command: "phase",
        resolved_feature: null,
        resolution_source: "none",
        phase: "brief",
        data: {
          feature: null,
          phase: "brief",
          source: "none",
          note: "no active feature found — run '\''sdd init <name>'\'' to start"
        },
        guidance: {},
        warnings: []
      }')"
    exit 0
  fi
  echo "feature: none"
  echo "phase: brief"
  echo "source: auto"
  echo "note: no active feature found — run 'sdd init <name>' to start"
  exit 0
fi

PHASE="$(sdd_feature_phase "$FEATURE_PATH")"
EFFECTIVE_PHASE="$(sdd_feature_effective_phase "$FEATURE_PATH")"

if [ "$OUTPUT_FORMAT" = "json" ]; then
  WP_JSON="$(emit_wp_fields "$FEATURE_DIR" | jq -Rn '
    [inputs] |
    reduce .[] as $line (
      {};
      if ($line | length) == 0 then
        .
      else
        ($line | capture("^(?<key>[^:]+): (?<value>.*)$")) as $parsed
        | . + {($parsed.key): $parsed.value}
      end
    )
  ' 2>/dev/null || echo '{}')"
  emit_json_selection "$(jq -nc \
    --argjson schema_version "$SCHEMA_VERSION" \
    --arg feature "$FEATURE_ID" \
    --arg feature_path "$FEATURE_PATH" \
    --arg feature_dir "$FEATURE_DIR" \
    --arg feature_group "$FEATURE_GROUP" \
    --arg resolution_source "$SOURCE" \
    --arg phase "$PHASE" \
    --arg effective_phase "$EFFECTIVE_PHASE" \
    --argjson wp "$WP_JSON" \
    '{
      ok: true,
      schema_version: $schema_version,
      command: "phase",
      resolved_feature: $feature,
      resolved_feature_path: $feature_path,
      resolution_source: $resolution_source,
      phase: $phase,
      effective_phase: $effective_phase,
      execution_phase: $effective_phase,
      raw_phase: $phase,
      data: (
        {
          feature: $feature,
          feature_id: $feature,
          feature_path: $feature_path,
          feature_dir: $feature_dir,
          feature_group: (if $feature_group == "" then null else $feature_group end),
          phase: $phase,
          raw_phase: $phase,
          effective_phase: $effective_phase,
          execution_phase: $effective_phase,
          source: $resolution_source
        } + $wp
      ),
      guidance: {},
      warnings: []
    }')"
  exit 0
fi

echo "feature: $FEATURE_ID"
echo "feature_path: $FEATURE_PATH"
[ -n "$FEATURE_GROUP" ] && echo "feature_group: $FEATURE_GROUP"
echo "phase: $PHASE"
echo "raw_phase: $PHASE"
echo "effective_phase: $EFFECTIVE_PHASE"
echo "execution_phase: $EFFECTIVE_PHASE"
echo "source: $SOURCE"

emit_wp_fields "$FEATURE_DIR"
