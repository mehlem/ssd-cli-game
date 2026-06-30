#!/usr/bin/env bash
# sdd-epic-refresh.sh — Rebuild derived .features/.epic-state.json
# Hook-safe side effect: exit 0 when epic mode is inactive.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-epic-lib.sh"
sdd_install_cleanup_trap

FORCE_REFRESH=0
case "${1:-}" in
  --current|--force) FORCE_REFRESH=1 ;;
esac

INPUT="$(cat)"
EPIC_FILE="$(sdd_epic_file)"
STATE_FILE="$SDD_FEATURE_ROOT/.epic-state.json"

[ -f "$EPIC_FILE" ] || exit 0

# When invoked as a PostToolUse hook, stay silent outside active SDD sessions.
# Direct CLI/test invocations pass no hook JSON and can still rebuild fixtures.
if [ -n "$INPUT" ] && printf '%s\n' "$INPUT" | jq -e '.tool_name? != null' >/dev/null 2>&1; then
  sdd_has_active_feature || exit 0
fi

sdd_lock_or_exit "epic-state"

if [ "$FORCE_REFRESH" != "1" ] && [ -f "$STATE_FILE" ] && [ "$STATE_FILE" -nt "$EPIC_FILE" ]; then
  exit 0
fi

epic_resolve_feature_ref() {
  local ref="$1"
  [ -n "$ref" ] || return 1
  sdd_resolve_feature_target "$ref" 0
}

epic_feature_updated() {
  local feature="$1" feature_dir
  local state_file
  if ! epic_resolve_feature_ref "$feature"; then
    printf '\n'
    return 0
  fi
  feature_dir="${SDD_RESOLVED_FEATURE_DIR:-$SDD_FEATURE_ROOT/${SDD_RESOLVED_FEATURE_PATH:-$feature}}"
  state_file="$feature_dir/state.json"
  [ -f "$state_file" ] || { printf '\n'; return 0; }
  date -r "$state_file" +%Y-%m-%dT%H:%M:%S 2>/dev/null || printf '\n'
}

epic_declared_status() {
  local declared="$1"
  case "$declared" in
    planned|deferred|cancelled) printf '%s\n' "$declared" ;;
    *) printf 'planned\n' ;;
  esac
}

epic_derived_status() {
  local declared="$1" feature="$2" feature_path feature_dir phase lifecycle
  declared="$(epic_declared_status "$declared")"
  [ -n "$feature" ] || { printf '%s\n' "$declared"; return 0; }
  epic_resolve_feature_ref "$feature" || { printf '%s\n' "$declared"; return 0; }
  feature_path="${SDD_RESOLVED_FEATURE_PATH:-$feature}"
  feature_dir="${SDD_RESOLVED_FEATURE_DIR:-$SDD_FEATURE_ROOT/$feature_path}"

  phase="$(jq -r '.phase // empty' "$feature_dir/state.json" 2>/dev/null || true)"
  [ -n "$phase" ] || phase="$(sdd_feature_phase "$feature_path" 2>/dev/null || true)"
  lifecycle="$(sdd_feature_status "$feature_path" 2>/dev/null || printf 'active\n')"

  if [ "$phase" = "close" ] && [ "$lifecycle" != "abandoned" ] && [ "$lifecycle" != "superseded" ]; then
    printf 'done\n'
    return 0
  fi
  case "$declared" in
    deferred|cancelled) printf '%s\n' "$declared" ;;
    *) printf 'in-progress\n' ;;
  esac
}

entries_json='[]'
while IFS= read -r entry_line; do
  [ -n "$entry_line" ] || continue
  sdd_tsv_split "$entry_line" id slug declared_status mode feature depends_on section_count title group order
  feature_id=""
  feature_path=""
  if [ -n "$feature" ] && epic_resolve_feature_ref "$feature"; then
    feature_id="$SDD_RESOLVED_FEATURE"
    feature_path="$SDD_RESOLVED_FEATURE_PATH"
  fi
  derived_status="$(epic_derived_status "$declared_status" "$feature")"
  updated="$(epic_feature_updated "$feature")"

  entries_json="$(jq -nc \
    --argjson entries "$entries_json" \
    --arg id "$id" \
    --arg title "$title" \
    --arg slug "$slug" \
    --arg declared_status "$(epic_declared_status "$declared_status")" \
    --arg status "$derived_status" \
    --arg mode "$mode" \
    --arg feature "$feature" \
    --arg feature_id "$feature_id" \
    --arg feature_path "$feature_path" \
    --argjson depends_on "$depends_on" \
    --arg group "$group" \
    --arg updated "$updated" \
    --argjson order "${order:-0}" \
    --argjson section_count "${section_count:-0}" \
    '$entries + [{
      id:$id,
      title:$title,
      slug:$slug,
      declared_status:$declared_status,
      status:$status,
      mode:$mode,
      feature:$feature,
      feature_id:(if $feature_id == "" then null else $feature_id end),
      feature_path:(if $feature_path == "" then null else $feature_path end),
      depends_on:$depends_on,
      group:$group,
      updated:$updated,
      order:$order,
      section_count:$section_count
    }]')"
done < <(sdd_epic_iter_entries "$EPIC_FILE")

counts_json="$(printf '%s\n' "$entries_json" | jq -c 'group_by(.status) | map({(.[0].status): length}) | add // {}')"
groups_json="$(printf '%s\n' "$entries_json" | jq -c '
  sort_by(.group, .order)
  | group_by(.group)
  | map({
      group: .[0].group,
      total: length,
      counts: (group_by(.status) | map({(.[0].status): length}) | add // {}),
      entries: map(.id)
    })
')"

tmp="$(sdd_tmp_for_target "$STATE_FILE")" || exit 0
sdd_cleanup_push "$tmp"
jq -n \
  --arg file "$EPIC_FILE" \
  --arg id "$(sdd_frontmatter_value "$EPIC_FILE" id 2>/dev/null || true)" \
  --arg title "$(sdd_frontmatter_value "$EPIC_FILE" title 2>/dev/null || true)" \
  --arg generated_at "$(date +%Y-%m-%dT%H:%M:%S)" \
  --argjson entries "$entries_json" \
  --argjson counts "$counts_json" \
  --argjson groups "$groups_json" \
  '{
    epic: {file:$file, id:$id, title:$title},
    entries:$entries,
    counts:$counts,
    groups:$groups,
    generated_at:$generated_at
  }' > "$tmp"

sdd_atomic_replace "$tmp" "$STATE_FILE" || {
  sdd_cleanup_file "$tmp"
  exit 0
}

exit 0
