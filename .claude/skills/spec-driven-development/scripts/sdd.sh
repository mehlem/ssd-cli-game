#!/usr/bin/env bash
# sdd.sh — Spec-Driven Development dispatcher
# Routes to individual scripts for each operation.
#
# Golden Circle: WHY → WHAT → WHERE → HOW → DO → VERIFY → DONE
#
# Usage:
#   sdd status   [feature-id]                        — dashboard (all or specific)
#   sdd phase    [feature-id]                        — detect current phase
#   sdd init     <feature-name> [description]        — create feature (Brief phase)
#   sdd spec     <feature-id>                        — scaffold spec.md (Design phase)
#   sdd research <feature-id>                        — scaffold research.md (Research phase)
#   sdd plan     {plan|tasks|both} <feature>         — scaffold plan/tasks (Plan phase)
#   sdd task     {list|next|start|scope-refresh|complete|block|reset|add|lint} <feature> [args]
#   sdd worker   {dispatch|status|import-result} <feature> [args] — worker/provider ledger
#   sdd customize {init|check} [file]              — project customization YAML
#   sdd epic     {init|check|add|status|scaffold|link} [args] — epic registry
#   sdd review   <feature-id>                        — scaffold review.md (Review phase)
#   sdd review adjudicate <feature-id>              — assemble evidence + merge typed adjudication
#   sdd close    [--force] <feature-id>              — close feature (--force creates stubs)
#   sdd record-close [--commit] [--sha <sha>] <feature-id> — record close commit SHA in review.md
#   sdd reopen   <feature-id>                        — reopen closed feature for new tasks
#   sdd select   [<feature>|--clear]                  — pin/unpin/show active feature
#   sdd autonomy {on|off|status} <feature>            — toggle autonomous steering
#   sdd advise <artifact> <feature>        — rubric advisor (on-demand evaluation)
#   sdd trace    {refresh|ensure|doctor|coverage} <feature> — trace graph sidecar management
#   sdd summary  [feature]                           — generate summary.md + summary-compact.md
#   sdd index    {rebuild|show|validate} [args]      — feature index management
#   sdd handoff  [feature]                           — print a structured session handoff
#   sdd wp       {init|list} <feature> [args]        — work package management
#   sdd setup    [--dry-run] [--force]               — bootstrap SDD in a project
#   sdd help                                         — show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

sdd_parse_common_args "$@" || sdd_usage_error "help" "sdd [command] [options]" "invalid shared CLI flags"

build_forwarded_args() {
  FORWARDED_ARGS=()

  [ "$SDD_HELP" = "1" ] && FORWARDED_ARGS+=("--help")
  case "$SDD_OUTPUT_FORMAT" in
    json) FORWARDED_ARGS+=("--json") ;;
    text) ;;
  esac
  [ -n "$SDD_FEATURE_OVERRIDE" ] && FORWARDED_ARGS+=("--feature" "$SDD_FEATURE_OVERRIDE")
  [ "$SDD_NON_INTERACTIVE" = "1" ] && FORWARDED_ARGS+=("--non-interactive")
  [ -n "$SDD_ON_EXISTS" ] && FORWARDED_ARGS+=("--on-exists" "$SDD_ON_EXISTS")
  [ -n "$SDD_FIELD" ] && FORWARDED_ARGS+=("--field" "$SDD_FIELD")
  [ -n "$SDD_JQ_EXPR" ] && FORWARDED_ARGS+=("--jq" "$SDD_JQ_EXPR")
  return 0
}

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "help" \
      "Top-level dispatcher for the Spec-Driven Development CLI." \
      "sdd <command> [options]" \
      "$(sdd_common_flags_json)" \
      '[
        {"name":"status-json","maps_to":"status --json"},
        {"name":"plan create","maps_to":"plan plan"},
        {"name":"plan create-tasks","maps_to":"plan tasks"},
        {"name":"plan create-all","maps_to":"plan both"},
        {"name":"task lint","maps_to":"task lint"},
        {"name":"task scope-refresh","maps_to":"task scope-refresh"},
        {"name":"worker dispatch","maps_to":"worker dispatch"}
      ]' \
      '[
        "sdd status --json",
        "sdd phase --field phase",
        "sdd spec --json --feature 0001-user-auth",
        "sdd plan create 0001-user-auth",
        "sdd worker dispatch 0001-user-auth --provider codex --role research-scout --task-text \"Inspect prompt flow\""
      ]'
    return 0
  fi

  echo "sdd — Spec-Driven Development CLI"
  echo ""
  echo "Golden Circle: WHY → WHAT → WHERE → HOW → DO → VERIFY → DONE"
  echo ""
  echo "Common flags:"
  echo "  --help                      Show help"
  echo "  --feature <id|auto>        Explicit feature target override"
  echo "  --format text|json         Select text or JSON output"
  echo "  --json                     Alias for --format json"
  echo "  --non-interactive          Disable prompts in machine paths"
  echo "  --on-exists fail|overwrite|skip"
  echo "                             Conflict policy for scaffold commands"
  echo "  --field <path>             Select a field from JSON-capable read commands"
  echo "  --jq <expr>                Apply a jq expression to JSON-capable read commands"
  echo ""
  echo "Commands:"
  echo "  status   [feature]             Dashboard (all features or specific)"
  echo "  phase    [feature]             Detect current phase"
  echo "  init     <name> [desc]         Create feature (Brief phase)"
  echo "  spec     <feature>             Scaffold spec.md (Design phase)"
  echo "  research <feature>             Scaffold research.md (Research phase)"
  echo "  plan     {plan|create|tasks|create-tasks|both|create-all} <f>"
  echo "                                 Scaffold plan.md / tasks.md (Plan phase)"
  echo "                                 both/create-all is compatibility-only; prefer explicit create + create-tasks"
  echo "  task     <cmd> <feature> [..]  Task CRUD (list/next/start/scope-refresh/complete/block/reset/add/lint)"
  echo "  worker   <cmd> <feature> [..] Worker/provider ledger (dispatch/status/import-result)"
  echo "  customize <init|check> [file] Project customization YAML"
  echo "  epic     <cmd> [..]           Epic registry (init/check/add/status/scaffold/link)"
  echo "  check    <type> <feature>      Readiness check (brief/spec/research/plan/tasks/review/all)"
  echo "  review   <feature>             Scaffold review.md (Review phase)"
  echo "  review   adjudicate <feature>  Assemble evidence + merge typed adjudication"
  echo "  close    [--force] <feature>   Close feature (--force creates stub artifacts)"
  echo "  record-close [--commit] [--sha <sha>] <feature>"
  echo "                                 Record close commit SHA in review.md"
  echo "  archive  [--force] <feature>   Generate README.md and DOCS.md for closed feature"
  echo "  reopen   <feature>             Reopen a closed feature for new tasks"
  echo "  select   [<feature>|--clear]   Pin/unpin/show active feature selection"
  echo "  autonomy {on|off|status} <f>  Toggle per-feature autonomous steering"
  echo "  advise   <artifact> <feature>  Run the rubric advisor on demand (Haiku-powered)"
  echo "                                 <artifact> ∈ brief|spec|research|plan|review"
  echo "  trace    {refresh|ensure|doctor|coverage} <feature>"
  echo "                                 Generate or inspect trace.json"
  echo "  scope    refresh <feature>     Regenerate scope.txt"
  echo "  summary  [feature]             Generate summary.md and summary-compact.md"
  echo "  index    {rebuild|show|validate} [args]"
  echo "                                 Feature index management"
  echo "  handoff  [feature]             Print a structured session handoff"
  echo "  wp       <cmd> <feature> [..]  Work Package management (init/list)"
  echo "  setup    [--dry-run] [--force] Bootstrap SDD in this project"
  echo "  help                           Show this help"
  echo ""
  echo "Compatibility:"
  echo "  status-json                    Compatibility alias for 'status --json'"
  echo ""
  echo "Phase flow:"
  echo "  sdd init user-auth \"Add OAuth\"      → Brief   (brief.md)"
  echo "  sdd spec 0001-user-auth              → Design  (spec.md)"
  echo "  sdd research 0001-user-auth          → Research (research.md)"
  echo "  sdd plan create 0001-user-auth       → Plan    (plan.md)"
  echo "  sdd plan create-tasks 0001-user-auth → Plan    (tasks.md)"
  echo "  sdd task start 0001-user-auth T-001  → Implement"
  echo "  sdd review 0001-user-auth            → Review  (review.md)"
  echo "  sdd close 0001-user-auth             → Close"
  echo "  sdd record-close 0001-user-auth      → Record close commit SHA"
  echo "  sdd archive 0001-user-auth           → Archive (README.md, DOCS.md)"
}

cmd="${SDD_ARGS[0]:-help}"
ARGS=()
[ "${#SDD_ARGS[@]}" -gt 1 ] && ARGS=("${SDD_ARGS[@]:1}")

build_forwarded_args
if [ "${#ARGS[@]}" -gt 0 ]; then
  FORWARDED_ARGS+=("${ARGS[@]}")
fi

case "$cmd" in
  status)
    bash "$SCRIPT_DIR/sdd-status.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  status-json)
    bash "$SCRIPT_DIR/sdd-status.sh" --json "${ARGS[@]}"
    ;;
  phase)
    bash "$SCRIPT_DIR/sdd-phase.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  init)
    bash "$SCRIPT_DIR/sdd-init.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  spec)
    bash "$SCRIPT_DIR/sdd-spec.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  research)
    bash "$SCRIPT_DIR/sdd-research.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  plan)
    bash "$SCRIPT_DIR/sdd-plan.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  task)
    bash "$SCRIPT_DIR/sdd-task.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  worker)
    bash "$SCRIPT_DIR/sdd-worker.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  customize)
    bash "$SCRIPT_DIR/sdd-customize.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  scope)
    bash "$SCRIPT_DIR/sdd-scope.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  check)
    bash "$SCRIPT_DIR/sdd-check.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  review)
    bash "$SCRIPT_DIR/sdd-review.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  close)
    bash "$SCRIPT_DIR/sdd-close.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  record-close)
    bash "$SCRIPT_DIR/sdd-record-close.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  archive)
    bash "$SCRIPT_DIR/sdd-archive.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  reopen)
    bash "$SCRIPT_DIR/sdd-reopen.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  select)
    bash "$SCRIPT_DIR/sdd-select.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  autonomy)
    bash "$SCRIPT_DIR/sdd-autonomy.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  advise)
    bash "$SCRIPT_DIR/sdd-advise.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  trace)
    bash "$SCRIPT_DIR/sdd-trace.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  summary)
    bash "$SCRIPT_DIR/sdd-summary.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  index)
    bash "$SCRIPT_DIR/sdd-index.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  handoff)
    bash "$SCRIPT_DIR/sdd-handoff.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  wp)
    bash "$SCRIPT_DIR/sdd-wp.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  epic)
    bash "$SCRIPT_DIR/sdd-epic.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  setup)
    bash "$SCRIPT_DIR/sdd-setup.sh" "${FORWARDED_ARGS[@]+"${FORWARDED_ARGS[@]}"}"
    ;;
  help)
    show_help
    ;;
  *)
    sdd_usage_error "help" "sdd <command> [options]" "unknown command '$cmd'"
    ;;
esac
