#!/usr/bin/env bash
# sdd-advise.sh — manual CLI: run the rubric advisor on demand
#
# Usage: sdd advise <artifact> <feature> [--json]
#   artifact: brief | spec | research | plan | review
#   feature:  feature slug (e.g. 0040-sdd-rubric-advisor) or "auto"
#   --json:   emit raw findings JSON on stdout (human-readable by default)
#
# Shares evaluation logic with the post-authoring hook (sdd_advisor_invoke_haiku).
# Never blocks, never writes sidecars. Exits 0 on success including the empty-
# findings case. Non-zero exit reserved for usage errors and unresolvable
# features.

set -euo pipefail

# Kill switch (FR-016). Same env var the hooks honor; set to make "disabled"
# mean disabled across every advisor entry point, not just automatic firing.
if [ "${SDD_ADVISOR_DISABLED:-0}" = "1" ]; then
  echo "sdd advise: disabled via SDD_ADVISOR_DISABLED=1" >&2
  exit 0
fi

command -v jq >/dev/null 2>&1 || { echo "sdd advise: jq not found on PATH" >&2; exit 1; }
command -v claude >/dev/null 2>&1 || { echo "sdd advise: claude CLI not found on PATH" >&2; exit 1; }

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "advise" "sdd advise <artifact> <feature> [--json]" "invalid shared CLI flags"

ARTIFACT="${SDD_ARGS[0]:-}"
FEATURE_INPUT="${SDD_FEATURE_OVERRIDE:-${SDD_ARGS[1]:-}}"

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json "advise" \
      "Run the rubric advisor on demand against an SDD artifact." \
      "sdd advise <artifact> <feature> [--json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd advise spec 0040-sdd-rubric-advisor",
        "sdd advise brief 0040-sdd-rubric-advisor --json"
      ]'
    return 0
  fi
  cat <<EOF
Usage: sdd advise <artifact> <feature> [--json]

Run the rubric advisor on demand against an SDD artifact. The advisor reads
the artifact from disk and its rubric from references/rubrics/, invokes Haiku
via claude -p --bare, and prints grounded suggestions. Never blocks, never
persists.

Artifacts: brief, spec, research, plan, review
  (tasks is deferred to a future iteration — see continuity.md of 0040-sdd-rubric-advisor)

Flags:
  --json    Emit raw findings JSON (default is human-readable)

Examples:
  sdd advise spec 0040-sdd-rubric-advisor
  sdd advise brief 0040-sdd-rubric-advisor --json
EOF
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

[ -n "$ARTIFACT" ] || sdd_usage_error "advise" "sdd advise <artifact> <feature>" "artifact required (brief|spec|research|plan|review)"
[ -n "$FEATURE_INPUT" ] || sdd_usage_error "advise" "sdd advise <artifact> <feature>" "feature required"

case "$ARTIFACT" in
  brief|spec|research|plan|review) ;;
  tasks)
    sdd_fail "advise" "blocked" \
      "tasks is deferred in iteration 1 of the rubric advisor; no advisor coverage for tasks.md" \
      "{\"artifact\":\"tasks\"}" "" "arg"
    ;;
  *)
    sdd_usage_error "advise" "sdd advise <artifact> <feature>" "unknown artifact: $ARTIFACT (expected brief|spec|research|plan|review)"
    ;;
esac

# Resolve the feature via shared helper (same as other sdd subcommands).
sdd_resolve_feature_target "$FEATURE_INPUT" "$(sdd_is_machine_mode && echo 1 || echo 0)" || {
  case "$SDD_RESOLUTION_STATUS" in
    not_found) sdd_fail "advise" "not_found" "feature '$FEATURE_INPUT' not found" "{\"feature\":\"$FEATURE_INPUT\"}" "$FEATURE_INPUT" "arg" ;;
    ambiguous) sdd_fail "advise" "blocked" "auto feature resolution is ambiguous" "$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')" "" "auto" ;;
    none)      sdd_usage_error "advise" "sdd advise <artifact> <feature>" "feature argument required" ;;
  esac
}
FEATURE="$SDD_RESOLVED_FEATURE"

ARTIFACT_PATH="$(sdd_artifact_path_for "$FEATURE" "$ARTIFACT")"
RUBRIC_PATH="$(sdd_rubric_path_for "$ARTIFACT")"

[ -f "$ARTIFACT_PATH" ] || sdd_fail "advise" "not_found" "artifact '$ARTIFACT_PATH' not found" "{\"artifact\":\"$ARTIFACT\",\"feature\":\"$FEATURE\"}" "$FEATURE" "arg"
[ -f "$RUBRIC_PATH" ]   || sdd_fail "advise" "not_found" "rubric '$RUBRIC_PATH' not found"     "{\"artifact\":\"$ARTIFACT\"}" "$FEATURE" "arg"

FINDINGS="$(sdd_advisor_invoke_haiku "$RUBRIC_PATH" "$ARTIFACT_PATH" || true)"

# Empty response (no grounded findings, or a degradation exit) — successful run.
if [ -z "$FINDINGS" ]; then
  FINDINGS='{"findings":[]}'
fi

if sdd_is_json_mode; then
  printf '%s\n' "$FINDINGS"
  exit 0
fi

# Human-readable rendering — use the same tagged-block formatter and print.
FINDING_COUNT="$(printf '%s' "$FINDINGS" | jq -r '.findings | length' 2>/dev/null || echo 0)"
if [ "$FINDING_COUNT" -eq 0 ]; then
  echo "No findings — $ARTIFACT for $FEATURE is well-grounded against its rubric."
  exit 0
fi

printf 'Rubric advisor — %s findings for %s/%s:\n\n' "$FINDING_COUNT" "$FEATURE" "$ARTIFACT"
sdd_advisor_format_context "$FINDINGS" postauthoring
echo
