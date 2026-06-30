#!/usr/bin/env bash
# sdd-advisor-preboundary.sh — PreToolUse command hook: forward-directive advisor
#
# Fires on Bash(sdd <phase-advance> *) — specifically sdd spec / sdd research /
# sdd plan create / sdd plan tasks / sdd close. Reads the just-completed source
# artifact and both its own rubric and the next-phase rubric, invokes Haiku
# via `claude -p --bare`, and emits forward-directive tagged blocks
# (<next_focus>, <watch_for>, <ground_in>) as hookSpecificOutput.additionalContext.
#
# Never blocks the sdd command. `sdd close` uses only the review rubric
# (no next_rubric). Hook recursion is prevented by `--bare` in the shared helper.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0
[ "${SDD_ADVISOR_DISABLED:-0}" = "1" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

sdd_section_first_paragraph() {
  local file="$1" heading="$2"
  [ -f "$file" ] || return 0
  awk -v heading="## $heading" '
    $0 == heading { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && /^[[:space:]]*$/ {
      if (capturing) exit
      next
    }
    in_section && /^[[:space:]]*<!--.*-->[[:space:]]*$/ { next }
    in_section {
      capturing = 1
      print
    }
  ' "$file"
}

sdd_brief_description_fallback() {
  local feature="$1" state_file=".features/$feature/state.json"
  [ -f "$state_file" ] || return 0
  jq -r '
    if (.description | type) == "object" then
      .description.short // .description.long // empty
    elif (.description | type) == "string" then
      .description
    else
      empty
    end
  ' "$state_file" 2>/dev/null || true
}

sdd_continuity_seed_from_brief() {
  local feature="$1"
  local feature_dir=".features/$feature"
  local brief_file="$feature_dir/brief.md"
  local continuity_file="$feature_dir/continuity.md"
  local goal_seed constraints_seed updated

  [ -f "$brief_file" ] && [ -f "$continuity_file" ] || return 0

  goal_seed="$(sdd_section_first_paragraph "$brief_file" "Motivation" || true)"
  [ -n "$goal_seed" ] || goal_seed="$(sdd_brief_description_fallback "$feature" || true)"
  constraints_seed="$(sdd_section_first_paragraph "$brief_file" "Constraints" || true)"

  [ -n "$goal_seed" ] || [ -n "$constraints_seed" ] || return 0

  if ! updated="$(SDD_GOAL_SEED="$goal_seed" SDD_CONSTRAINTS_SEED="$constraints_seed" awk '
    BEGIN {
      goal = ENVIRON["SDD_GOAL_SEED"]
      constraints = ENVIRON["SDD_CONSTRAINTS_SEED"]
    }
    function is_target_heading(line) {
      return line == "## Goal" || line == "## Constraints / Assumptions"
    }
    function emit_buffer( replacement) {
      if (target == "goal" && placeholder && !substantive && goal != "") {
        print ""
        print goal
      } else if (target == "constraints" && placeholder && !substantive && constraints != "") {
        print ""
        print constraints
      } else {
        printf "%s", buffer
      }
      buffer = ""
      target = ""
      placeholder = 0
      substantive = 0
    }
    {
      if ($0 ~ /^## /) {
        if (target != "") emit_buffer()
        print
        if ($0 == "## Goal") {
          target = "goal"
          next
        }
        if ($0 == "## Constraints / Assumptions") {
          target = "constraints"
          next
        }
        next
      }
      if (target != "") {
        buffer = buffer $0 "\n"
        if ($0 ~ /^[[:space:]]*<!--.*-->[[:space:]]*$/) placeholder = 1
        else if ($0 !~ /^[[:space:]]*$/) substantive = 1
        next
      }
      print
    }
    END {
      if (target != "") emit_buffer()
    }
  ' "$continuity_file")"; then
    return 0
  fi

  [ -n "$updated" ] || return 0
  if [ "$updated" != "$(cat "$continuity_file")" ]; then
    sdd_write_file_atomic "$continuity_file" "$updated" || return 0
  fi
  return 0
}

sdd_continuity_decisions_empty() {
  local file="$1"
  [ -f "$file" ] || return 0
  awk '
    /^## (Key )?Decisions[[:space:]]*$/ { in_section = 1; seen = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section && /^[[:space:]]*$/ { next }
    in_section && /^[[:space:]]*<!--.*-->[[:space:]]*$/ { next }
    in_section { substantive = 1 }
    END {
      if (!seen || !substantive) exit 0
      exit 1
    }
  ' "$file"
}

sdd_preboundary_close_warning() {
  local feature="$1"
  local feature_dir=".features/$feature"
  local continuity_file="$feature_dir/continuity.md"
  local knowledge_file="$feature_dir/knowledge.md"
  local opt_out knowledge_state warn_knowledge=0 warn_decisions=0

  opt_out="$(sdd_frontmatter_value "$continuity_file" closed_with_empty_knowledge 2>/dev/null || true)"
  [ "$opt_out" = "true" ] && return 0

  knowledge_state="$(sdd_knowledge_state "$knowledge_file" 2>/dev/null || printf 'filled')"
  [ "$knowledge_state" = "empty" ] && warn_knowledge=1
  if sdd_continuity_decisions_empty "$continuity_file"; then
    warn_decisions=1
  fi

  [ "$warn_knowledge" = "1" ] || [ "$warn_decisions" = "1" ] || return 0

  printf 'sdd-advisor: close warning for %s: ' "$feature" >&2
  if [ "$warn_knowledge" = "1" ]; then
    printf '%s has no K-entries. ' "$knowledge_file" >&2
  fi
  if [ "$warn_decisions" = "1" ]; then
    printf '%s has no recorded Decisions. ' "$continuity_file" >&2
  fi
  printf 'Add missing feature memory, or set closed_with_empty_knowledge: true in %s when there is intentionally nothing to capture.\n' "$continuity_file" >&2
}

INPUT="$(cat)"

IFS=$'\t' read -r TOOL_NAME CMD SESSION_ID <<< "$(
  echo "$INPUT" | jq -r '[.tool_name // "", .tool_input.command // "", .session_id // ""] | @tsv'
)"

[ "$TOOL_NAME" = "Bash" ] || exit 0
[ -n "$CMD" ] || exit 0

# Extract the args that follow `sdd ` in the command. The greedy `.*` matches
# the LAST occurrence of `sdd `, which handles both "sdd spec X" and
# "bash .../sdd.sh spec X" forms.
SDD_ARGS="$(printf '%s' "$CMD" | sed -n 's|.*sdd[[:space:]]\{1,\}\([a-z].*\)|\1|p')"
[ -n "$SDD_ARGS" ] || exit 0

SUB="$(printf '%s' "$SDD_ARGS" | awk '{print $1}')"
SUB2=""
case "$SUB" in
  plan) SUB2="$(printf '%s' "$SDD_ARGS" | awk '{print $2}')" ;;
esac

# Map subcommand to (source_artifact, next_artifact).
# next_artifact is empty for close (no next rubric; review is the final gate).
SOURCE_ART=""
NEXT_ART=""
case "$SUB:$SUB2" in
  spec:)          SOURCE_ART=brief;    NEXT_ART=spec     ;;
  research:)      SOURCE_ART=spec;     NEXT_ART=research ;;
  plan:create)    SOURCE_ART=research; NEXT_ART=plan     ;;
  plan:tasks)     SOURCE_ART=plan;     NEXT_ART=tasks    ;;
  close:)         SOURCE_ART=review;   NEXT_ART=""       ;;
  *)              exit 0 ;;
esac

# Find the feature slug in the args (first word matching ####-...).
FEATURE="$(printf '%s\n' "$SDD_ARGS" | tr ' ' '\n' | \
  grep -E '^[0-9]{4}-[a-z0-9-]+$' | head -1 || true)"
[ -n "$FEATURE" ] || exit 0

ARTIFACT_PATH=".features/$FEATURE/$SOURCE_ART.md"
[ -r "$ARTIFACT_PATH" ] || exit 0

case "$SUB:$SUB2" in
  spec:) sdd_continuity_seed_from_brief "$FEATURE" || true ;;
  close:) sdd_preboundary_close_warning "$FEATURE" ;;
esac

RUBRIC_PATH="$(sdd_rubric_path_for "$SOURCE_ART" 2>/dev/null || true)"
[ -n "$RUBRIC_PATH" ] && [ -r "$RUBRIC_PATH" ] || exit 0

NEXT_RUBRIC_PATH=""
if [ -n "$NEXT_ART" ]; then
  NEXT_RUBRIC_PATH="$(sdd_rubric_path_for "$NEXT_ART" 2>/dev/null || true)"
  # If the next rubric is missing, degrade to single-rubric mode silently.
  [ -n "$NEXT_RUBRIC_PATH" ] && [ -r "$NEXT_RUBRIC_PATH" ] || NEXT_RUBRIC_PATH=""
fi

export SDD_ADVISOR_SESSION_ID="${SESSION_ID:-unknown}"

FINDINGS="$(sdd_advisor_invoke_haiku "$RUBRIC_PATH" "$ARTIFACT_PATH" "$NEXT_RUBRIC_PATH" || true)"
[ -n "$FINDINGS" ] || exit 0

FINDING_COUNT="$(printf '%s' "$FINDINGS" | jq -r '.findings | length' 2>/dev/null || echo 0)"
[ "$FINDING_COUNT" -gt 0 ] || exit 0

CONTEXT="$(sdd_advisor_format_context "$FINDINGS" preboundary)"
[ -n "$CONTEXT" ] || exit 0

jq -n --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
exit 0
