#!/usr/bin/env bash
# sdd-status.sh — Dashboard showing feature status, progress, and next action
# Usage: sdd-status.sh [--json] [feature-id]    (specific feature)
#        sdd-status.sh [--json]                  (all features overview)

set -euo pipefail

FEATURE_ROOT=".features"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

STATUS_CURRENT=0
STATUS_PARSE_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --current)
      STATUS_CURRENT=1
      ;;
    *)
      STATUS_PARSE_ARGS+=("$1")
      ;;
  esac
  shift
done

sdd_parse_common_args "${STATUS_PARSE_ARGS[@]+"${STATUS_PARSE_ARGS[@]}"}" || sdd_usage_error "status" "sdd status [feature-id] [--current] [--feature <id|auto>] [--format text|json]" "invalid shared CLI flags"

if [ "${SDD_ARGS[0]:-}" = "current" ]; then
  STATUS_CURRENT=1
  SDD_ARGS=("${SDD_ARGS[@]:1}")
fi

[ "${#SDD_ARGS[@]}" -le 1 ] || sdd_usage_error "status" "sdd status [feature-id] [--current] [--feature <id|auto>] [--format text|json]" "status accepts at most one positional feature target"

if [ "$STATUS_CURRENT" = "1" ] && { [ -n "${SDD_FEATURE_OVERRIDE:-}" ] || [ "${#SDD_ARGS[@]}" -gt 0 ]; }; then
  sdd_usage_error "status" "sdd status [feature-id] [--current] [--feature <id|auto>] [--format text|json]" "--current cannot be combined with an explicit feature target"
fi

status_flags_json() {
  jq -cn \
    --argjson common "$(sdd_common_flags_json)" \
    '$common + [{"name":"--current","description":"Resolve the selected or auto-detected current feature and return single-feature status"}]'
}

status_field_requires_feature_scope() {
  local field="${1#.}"
  case "$field" in
    phase|phase.*|raw_phase|raw_phase.*|effective_phase|effective_phase.*|execution_phase|execution_phase.*|feature|feature.*|feature_id|feature_id.*|feature_path|feature_path.*|feature_dir|feature_dir.*|feature_group|feature_group.*|profile|profile.*|autonomous|phase_skill|phase_skill.*|tasks|tasks.*|task_source|task_source.*|work_packages|work_packages.*|current_task|current_task.*|artifact_map|artifact_map.*|continuity_state|knowledge_state|continuity_bytes|knowledge_entries|has_summary|has_summary_compact|scratchpad_path|selection_source|confidence|confidence.*|review|review.*|trace|trace.*|workers|workers.*|data.phase|data.phase.*|data.raw_phase|data.raw_phase.*|data.effective_phase|data.effective_phase.*|data.execution_phase|data.execution_phase.*|data.feature|data.feature.*|data.feature_id|data.feature_id.*|data.feature_path|data.feature_path.*|data.feature_dir|data.feature_dir.*|data.feature_group|data.feature_group.*|data.profile|data.profile.*|data.autonomous|data.phase_skill|data.phase_skill.*|data.tasks|data.tasks.*|data.task_source|data.task_source.*|data.work_packages|data.work_packages.*|data.current_task|data.current_task.*|data.artifact_map|data.artifact_map.*|data.continuity_state|data.knowledge_state|data.continuity_bytes|data.knowledge_entries|data.has_summary|data.has_summary_compact|data.scratchpad_path|data.selection_source|data.confidence|data.confidence.*|data.review|data.review.*|data.trace|data.trace.*|data.workers|data.workers.*)
      return 0
      ;;
  esac
  return 1
}

status_resolve_single_feature() {
  local requested="${1:-}"
  local strict_auto="${2:-1}"
  local none_message="${3:-no current feature found}"
  local details_json="${4:-{}}"
  local resolution_label="${5:-auto}"
  local candidates_json='{}'

  sdd_resolve_feature_target "$requested" "$strict_auto" || {
    case "$SDD_RESOLUTION_STATUS" in
      not_found)
        sdd_fail "status" "not_found" "feature '$requested' not found" "$details_json" "$requested" "arg"
        ;;
      ambiguous)
        if command -v jq >/dev/null 2>&1; then
          candidates_json="$(printf '%s\n' "$SDD_RESOLUTION_CANDIDATES" | jq -Rsc 'split("\n") | map(select(length > 0)) | {candidates:.}')"
        fi
        sdd_fail "status" "blocked" "auto feature resolution is ambiguous" "$candidates_json" "" "auto"
        ;;
      none)
        sdd_fail "status" "not_found" "$none_message" "$details_json" "" "$resolution_label"
        ;;
    esac
  }
}

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "status" \
      "Show SDD status for a specific feature or the whole feature set." \
      "sdd status [feature-id|current] [--current] [--feature <id|auto>] [--format text|json] [--field <path>] [--jq <expr>]" \
      "$(status_flags_json)" \
      '[
        {"name":"status-json","maps_to":"status --json"}
      ]' \
      '[
        "sdd status",
        "sdd status 0001-user-auth",
        "sdd status --current",
        "sdd status --current --json --field phase",
        "sdd status --json --feature auto",
        "sdd status --json --feature auto --field phase"
      ]'
    return 0
  fi

  echo "Usage: sdd status [feature-id|current] [--current] [--feature <id|auto>] [--format text|json] [--field <path>] [--jq <expr>]"
  echo ""
  echo "Show SDD status for a specific feature or the whole feature set."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

# Count pattern occurrences in a file
count_pattern() {
  local result
  result=$(grep -c "$1" "$2" 2>/dev/null) || true
  echo "${result:-0}"
}

continuity_content_bytes() {
  local file="$1"
  [ -f "$file" ] || { echo 0; return 0; }

  awk '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter {
      if ($0 == "---") in_frontmatter = 0
      next
    }
    /^```/ { in_code = !in_code; next }
    in_code { next }
    /^<!-- SDD-AUTO-START -->$/ { in_auto = 1; next }
    /^<!-- SDD-AUTO-END -->$/ { in_auto = 0; next }
    in_auto { next }
    /^#+[[:space:]]/ { next }
    /^[[:space:]]*<!--.*-->[[:space:]]*$/ { next }
    {
      gsub(/[[:space:]]/, "", $0)
      bytes += length($0)
    }
    END { print bytes + 0 }
  ' "$file" 2>/dev/null || echo 0
}

knowledge_entry_count() {
  local file="$1"
  [ -f "$file" ] || { echo 0; return 0; }

  awk '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter {
      if ($0 == "---") in_frontmatter = 0
      next
    }
    /^```/ { in_code = !in_code; next }
    in_code { next }
    /^[[:space:]]*<!--.*-->[[:space:]]*$/ { next }
    {
      line = $0
      if (line ~ /^- K-[0-9][0-9][0-9]:/ ||
          line ~ /^- \*\*K-[0-9][0-9][0-9]/ ||
          line ~ /^### K-[0-9][0-9][0-9]:/) {
        if (match(line, /K-[0-9][0-9][0-9]/)) {
          token = substr(line, RSTART, RLENGTH)
          if (!(token in seen)) {
            seen[token] = 1
            count++
          }
        }
      }
    }
    END { print count + 0 }
  ' "$file" 2>/dev/null || echo 0
}

affected_files_count() {
  local research_file="$1"
  awk '
    /^## Affected Files/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section && /^\|/ {
      if ($0 ~ /^\|:?-[-:| ]+\|?$/ || $0 ~ /^\| File /) next
      split($0, cols, "|")
      file_ref = cols[2]
      action = cols[3]
      impact = cols[5]
      gsub(/^[ \t]+|[ \t]+$/, "", file_ref)
      gsub(/^[ \t]+|[ \t]+$/, "", action)
      gsub(/^[ \t]+|[ \t]+$/, "", impact)
      if (file_ref ~ /^\[[^]]+\]$/) next
      if ((action == "create" || action == "modify" || action == "delete" || action == "review") &&
          (impact == "local" || impact == "module" || impact == "cross-module" || impact == "breaking")) {
        count++
      }
    }
    END { print count + 0 }
  ' "$research_file"
}

entry_points_count() {
  local research_file="$1"
  awk '
    /^### Entry Points/ { in_section = 1; next }
    in_section && (/^### / || /^## /) { in_section = 0 }
    in_section && /^\|/ {
      if ($0 ~ /^\|:?-[-:| ]+\|?$/ || $0 ~ /^\| Entry Point /) next
      split($0, cols, "|")
      file_ref = cols[3]
      signature = cols[4]
      gsub(/^[ \t]+|[ \t]+$/, "", file_ref)
      gsub(/^[ \t]+|[ \t]+$/, "", signature)
      if (file_ref ~ /:[0-9]+$/ && signature != "") {
        count++
      }
    }
    END { print count + 0 }
  ' "$research_file"
}

review_ac_count() {
  local review_file="$1" status="$2"
  sdd_review_ac_status_count "$review_file" "$status"
}

parse_confidence() {
  local research_file="$1"
  local score=0 verdict="pending" in_section=0

  if [ ! -f "$research_file" ]; then
    echo "$score|$verdict"
    return
  fi

  while IFS= read -r line; do
    case "$line" in
      *"## Confidence"*)
        in_section=1
        ;;
      "##"*)
        [ "$in_section" = "1" ] && break
        ;;
      *)
        if [ "$in_section" = "1" ]; then
          case "$line" in
            *"**Total**:"*)
              # Extract number before /100
              score="${line#*: }"
              score="${score%/*}"
              score="${score// /}"
              ;;
            *"**Verdict**:"*)
              # Extract GO or HOLD
              if echo "$line" | grep -q "GO"; then
                verdict="GO"
              elif echo "$line" | grep -q "HOLD"; then
                verdict="HOLD"
              fi
              ;;
          esac
        fi
        ;;
    esac
  done < "$research_file"

  echo "$score|$verdict"
}

find_pending_task_heading() {
  local tasks_file="$1"
  local graph_json next_id
  graph_json="$(sdd_task_graph_json "$tasks_file")"
  next_id="$(printf '%s\n' "$graph_json" | jq -r '.ready_tasks[0] // empty')"
  [ -n "$next_id" ] || return 0
  sdd_task_heading "$tasks_file" "$next_id"
}

# Emit JSON for a single feature
feature_status_json() {
  local fid="$1"
  local selection_source_override="${2:-}"
  local feature_path="${3:-$fid}"
  local dir="$FEATURE_ROOT/$feature_path"
  local feature_group

  [ -d "$dir" ] || { echo '{"error":"feature not found"}'; return 1; }
  feature_group="$(sdd_feature_path_group "$feature_path")"

  local phase effective_phase profile profile_display selection_source
  phase="$(sdd_feature_phase "$feature_path")"
  effective_phase="$(sdd_feature_effective_phase "$feature_path")"
  profile="$(sdd_profile "$dir")"
  profile_display="$(sdd_profile_display "$profile")"
  if [ -n "$selection_source_override" ]; then
    selection_source="$selection_source_override"
  else
    selection_source="$(sdd_selection_source "$fid" "$feature_path")"
  fi

  local autonomous_json="null"
  if [ -f "$dir/state.json" ]; then
    autonomous_json="$(jq -c 'if .autonomous == true then true elif .autonomous == false then false else null end' "$dir/state.json" 2>/dev/null || printf 'null')"
  fi

  local task_summary_json
  local t_completed t_in_progress t_pending t_blocked t_total t_ready t_dep_blocked current_task_json task_source task_source_file task_source_json work_packages_json
  task_summary_json="$(sdd_feature_task_summary_json "$dir")"
  t_completed="$(printf '%s\n' "$task_summary_json" | jq -r '.completed')"
  t_in_progress="$(printf '%s\n' "$task_summary_json" | jq -r '.in_progress')"
  t_pending="$(printf '%s\n' "$task_summary_json" | jq -r '.pending')"
  t_blocked="$(printf '%s\n' "$task_summary_json" | jq -r '.blocked')"
  t_total="$(printf '%s\n' "$task_summary_json" | jq -r '.total')"
  t_ready="$(printf '%s\n' "$task_summary_json" | jq -r '.ready_tasks')"
  t_dep_blocked="$(printf '%s\n' "$task_summary_json" | jq -r '.blocked_tasks')"
  current_task_json="$(printf '%s\n' "$task_summary_json" | jq -c '.current_task')"
  task_source="$(printf '%s\n' "$task_summary_json" | jq -r '.source')"
  task_source_file="$(printf '%s\n' "$task_summary_json" | jq -r '.tasks_file // empty')"
  work_packages_json="$(printf '%s\n' "$task_summary_json" | jq -c '[.work_packages[]? | {id, path, tasks_file, phase}]')"
  task_source_json="$(jq -nc \
    --arg mode "$task_source" \
    --arg tasks_file_value "$task_source_file" \
    --argjson work_packages "$work_packages_json" \
    '{
      mode: $mode,
      tasks_file: (if $tasks_file_value == "" then null else $tasks_file_value end),
      work_packages: $work_packages
    }')"

  # Parse confidence from research.md
  local confidence_score confidence_verdict
  if [ -f "$dir/research.md" ]; then
    local conf_parse
    conf_parse="$(parse_confidence "$dir/research.md")"
    confidence_score="${conf_parse%|*}"
    confidence_verdict="${conf_parse#*|}"
  else
    confidence_score=0
    confidence_verdict="pending"
  fi

  # Parse review verdict
  local review_verdict="pending" review_verdict_source="" review_evidence_status="" review_adjudicated_at=""
  if [ -f "$dir/review.md" ]; then
    review_verdict="$(sdd_frontmatter_value "$dir/review.md" verdict 2>/dev/null || echo "pending")"
    review_verdict_source="$(sdd_frontmatter_value "$dir/review.md" verdict_source 2>/dev/null || true)"
    review_evidence_status="$(sdd_frontmatter_value "$dir/review.md" evidence_status 2>/dev/null || true)"
    review_adjudicated_at="$(sdd_frontmatter_value "$dir/review.md" adjudicated_at 2>/dev/null || true)"
  fi
  local review_adjudication_json="null"
  if [ -f "$dir/review-adjudication/current.json" ]; then
    review_adjudication_json="$(cat "$dir/review-adjudication/current.json" 2>/dev/null || printf 'null')"
  fi

  # Build artifact_map
  local brief=false spec=false research=false plan=false tasks=false review=false scratchpad=false continuity=false knowledge=false
  [ -f "$dir/brief.md" ] && brief=true
  [ -f "$dir/spec.md" ] && spec=true
  [ -f "$dir/research.md" ] && research=true
  [ -f "$dir/plan.md" ] && plan=true
  [ -f "$dir/tasks.md" ] && tasks=true
  [ -f "$dir/review.md" ] && review=true
  [ -f "$dir/scratchpad.md" ] && scratchpad=true
  [ -f "$dir/continuity.md" ] && continuity=true
  [ -f "$dir/knowledge.md" ] && knowledge=true
  local continuity_state knowledge_state continuity_bytes knowledge_entries
  continuity_state="$(sdd_continuity_state "$dir/continuity.md" 2>/dev/null || printf 'filled')"
  knowledge_state="$(sdd_knowledge_state "$dir/knowledge.md" 2>/dev/null || printf 'filled')"
  continuity_bytes="$(continuity_content_bytes "$dir/continuity.md")"
  knowledge_entries="$(knowledge_entry_count "$dir/knowledge.md")"

  local has_summary=false has_summary_compact=false
  [ -f "$dir/summary.md" ] && has_summary=true
  [ -f "$dir/summary-compact.md" ] && has_summary_compact=true
  local trace_summary_json
  trace_summary_json="$(sdd_trace_suspect_summary_json "$fid" "$dir/trace.json")"
  local workers_json="null"
  workers_json="$(sdd_worker_state_json "$fid")"
  local desc_json
  desc_json="$(sdd_feature_description_json "$feature_path")"
  local phase_skill_json
  phase_skill_json="$(sdd_phase_skill_status "$fid" "$phase" "$profile")"

  local json
  json=$(jq -n \
    --arg feature "$fid" \
    --arg feature_path "$feature_path" \
    --arg feature_dir "$dir" \
    --arg feature_group "$feature_group" \
    --arg phase "$phase" \
    --arg effective_phase "$effective_phase" \
    --arg profile "$profile_display" \
    --argjson autonomous "$autonomous_json" \
    --argjson completed "$t_completed" \
    --argjson in_progress "$t_in_progress" \
    --argjson pending "$t_pending" \
    --argjson blocked "$t_blocked" \
    --argjson ready_tasks "$t_ready" \
    --argjson blocked_tasks "$t_dep_blocked" \
    --argjson total "$t_total" \
    --argjson current_task "$current_task_json" \
    --argjson task_source "$task_source_json" \
    --argjson work_packages "$work_packages_json" \
    --argjson brief "$brief" \
    --argjson spec "$spec" \
    --argjson research "$research" \
    --argjson plan "$plan" \
    --argjson tasks "$tasks" \
    --argjson review "$review" \
    --argjson scratchpad "$scratchpad" \
    --argjson continuity "$continuity" \
    --argjson knowledge "$knowledge" \
    --arg continuity_state "$continuity_state" \
    --arg knowledge_state "$knowledge_state" \
    --argjson continuity_bytes "$continuity_bytes" \
    --argjson knowledge_entries "$knowledge_entries" \
    --argjson has_summary "$has_summary" \
    --argjson has_summary_compact "$has_summary_compact" \
    --arg scratchpad_path ".features/$feature_path/scratchpad.md" \
    --arg selection_source "$selection_source" \
    --argjson confidence_score "$confidence_score" \
    --arg confidence_verdict "$confidence_verdict" \
    --arg review_verdict "$review_verdict" \
    --arg review_verdict_source "$review_verdict_source" \
    --arg review_evidence_status "$review_evidence_status" \
    --arg review_adjudicated_at "$review_adjudicated_at" \
    --argjson review_adjudication "$review_adjudication_json" \
    --argjson trace_summary "$trace_summary_json" \
    --argjson workers "$workers_json" \
    --argjson description "$desc_json" \
    --argjson phase_skill "$phase_skill_json" \
    '{
      feature: $feature,
      feature_id: $feature,
      feature_path: $feature_path,
      feature_dir: $feature_dir,
      feature_group: (if $feature_group == "" then null else $feature_group end),
      phase: $phase,
      raw_phase: $phase,
      effective_phase: $effective_phase,
      execution_phase: $effective_phase,
      profile: $profile,
      autonomous: $autonomous,
      description: $description,
      phase_skill: $phase_skill,
      tasks: {completed: $completed, in_progress: $in_progress, pending: $pending, blocked: $blocked, total: $total, ready_tasks: $ready_tasks, blocked_tasks: $blocked_tasks},
      task_source: $task_source,
      work_packages: $work_packages,
      current_task: $current_task,
      artifact_map: {brief: $brief, spec: $spec, research: $research, plan: $plan, tasks: $tasks, review: $review, scratchpad: $scratchpad, continuity: $continuity, knowledge: $knowledge},
      continuity_state: $continuity_state,
      knowledge_state: $knowledge_state,
      continuity_bytes: $continuity_bytes,
      knowledge_entries: $knowledge_entries,
      has_summary: $has_summary,
      has_summary_compact: $has_summary_compact,
      scratchpad_path: $scratchpad_path,
      selection_source: $selection_source,
      confidence: {score: $confidence_score, verdict: $confidence_verdict},
      review: {
        verdict: $review_verdict,
        verdict_source: (if $review_verdict_source == "" then null else $review_verdict_source end),
        evidence_status: (if $review_evidence_status == "" then null else $review_evidence_status end),
        adjudicated_at: (if $review_adjudicated_at == "" then null else $review_adjudicated_at end)
      },
      trace: $trace_summary
    }
    + (if $workers == null then {} else {workers: $workers} end)
    + (if $review_adjudication == null then {} else {review_adjudication: $review_adjudication} end)')

  # Persist only feature-local derived state. Invocation-scoped fields such as
  # selection_source and phase_skill belong to the command response, not the tracked cache.
  local state_cache_json
  state_cache_json="$(printf '%s\n' "$json" | jq --arg profile "$profile" 'del(.selection_source, .phase_skill) | .profile = $profile')"
  sdd_write_file_atomic "$dir/state.json" "$state_cache_json"

  printf '%s\n' "$json"
}

# Emit JSON array for all features
overview_json() {
  if [ ! -d "$FEATURE_ROOT" ] || [ -z "$(ls -A "$FEATURE_ROOT" 2>/dev/null)" ]; then
    echo '[]'
    return
  fi

  local first=1
  local feature_path fid
  printf '['
  while IFS= read -r feature_path; do
    [ -n "$feature_path" ] || continue
    fid="$(sdd_feature_path_id "$feature_path")"
    if [ "$first" = "1" ]; then
      first=0
    else
      printf ','
    fi
    feature_status_json "$fid" "" "$feature_path"
  done <<EOF
$(sdd_iter_feature_paths)
EOF
  printf ']\n'
}

# Determine the mini-phase label for a WP directory
wp_phase_label() {
  local wp_dir="$1"
  sdd_detect_wp_phase "$wp_dir"
}

# Show status for one feature
feature_status() {
  local fid="$1"
  local feature_path="${2:-$fid}"
  local dir="$FEATURE_ROOT/$feature_path"
  local feature_group

  [ -d "$dir" ] || { echo "Error: feature '$fid' not found"; return 1; }
  feature_group="$(sdd_feature_path_group "$feature_path")"

  local phase effective_phase profile profile_display
  phase="$(sdd_feature_phase "$feature_path")"
  effective_phase="$(sdd_feature_effective_phase "$feature_path")"
  profile="$(sdd_profile "$dir")"
  profile_display="$(sdd_profile_display "$profile")"

  local desc_json short_desc
  desc_json="$(sdd_feature_description_json "$feature_path")"
  short_desc="$(printf '%s\n' "$desc_json" | jq -r '.short')"
  [ ${#short_desc} -gt 120 ] && short_desc="${short_desc:0:117}..."

  echo "═══════════════════════════════════════════════"
  echo "Feature: $fid"
  echo "Path:    $feature_path"
  [ -n "$feature_group" ] && echo "Group:   $feature_group"
  if [ "$effective_phase" != "$phase" ]; then
    echo "Phase:   $phase (effective: $effective_phase)"
  else
    echo "Phase:   $phase"
  fi
  echo "Profile: $profile_display"
  echo "Description: $short_desc"
  echo "═══════════════════════════════════════════════"

  # Brief status
  local brief="$dir/brief.md"
  if [ -f "$brief" ]; then
    local qa_count
    qa_count=$(count_pattern '^### Q[0-9]' "$brief")
    echo ""
    echo "Brief:   $qa_count Q&As captured"
  else
    echo ""
    echo "Brief:   not yet created"
  fi

  # Spec status
  local spec="$dir/spec.md"
  if [ -f "$spec" ]; then
    local fr_count ac_total ac_done oq_total oq_done
    fr_count="$(sdd_count_id_lines FR "$spec" headings)"
    ac_total="$(sdd_count_id_lines AC "$spec" headings)"
    ac_done="$(sdd_parse_id_rows_tsv AC "$spec" headings | awk -F '\t' '$4 == "x" { count++ } END { print count + 0 }')"
    oq_total="$(sdd_count_id_lines OQ "$spec" headings)"
    oq_done="$(sdd_parse_id_rows_tsv OQ "$spec" headings | awk -F '\t' '$4 == "x" { count++ } END { print count + 0 }')"
    echo ""
    echo "Spec:    $fr_count FRs | $ac_done/$ac_total ACs checked | $oq_done/$oq_total OQs resolved"
  else
    echo ""
    echo "Spec:    not yet created"
  fi

  # Research status
  local research="$dir/research.md"
  if [ -f "$research" ]; then
    local file_count ep_count
    file_count="$(affected_files_count "$research")"
    ep_count="$(entry_points_count "$research")"
    echo "Research: $file_count affected files | $ep_count entry points"
  else
    echo "Research: not yet created"
  fi

  # Plan status
  local plan="$dir/plan.md"
  if [ -f "$plan" ]; then
    local ad_count ph_count
    ad_count="$(sdd_count_id_lines AD "$plan" headings)"
    ph_count=$(count_pattern '^### PH-' "$plan")
    echo "Plan:    $ph_count phases | $ad_count arch decisions"
  else
    echo "Plan:    not yet created"
  fi

  # Tasks status
  local task_summary_json task_source
  task_summary_json="$(sdd_feature_task_summary_json "$dir")"
  task_source="$(printf '%s\n' "$task_summary_json" | jq -r '.source')"
  if [ "$task_source" != "none" ]; then
    local t_total t_pending t_progress t_done t_blocked
    t_total="$(printf '%s\n' "$task_summary_json" | jq -r '.total')"
    t_pending="$(printf '%s\n' "$task_summary_json" | jq -r '.pending')"
    t_progress="$(printf '%s\n' "$task_summary_json" | jq -r '.in_progress')"
    t_done="$(printf '%s\n' "$task_summary_json" | jq -r '.completed')"
    t_blocked="$(printf '%s\n' "$task_summary_json" | jq -r '.blocked')"
    echo "Tasks:   $t_total total | $t_done done | $t_progress active | $t_pending pending | $t_blocked blocked"
    if [ "$task_source" = "work_packages" ]; then
      echo "Task Source: work_packages"
    fi

    # Next task
    local next_task current_display_ref
    next_task="$(printf '%s\n' "$task_summary_json" | jq -r '.next_task_heading // empty')"
    current_display_ref="$(printf '%s\n' "$task_summary_json" | jq -r '.current_task.display_ref // empty')"
    if [ -n "$next_task" ]; then
      if [ -n "$current_display_ref" ] && [ "$task_source" = "work_packages" ]; then
        echo "Next:    $current_display_ref — $next_task"
      else
        echo "Next:    $next_task"
      fi
    fi
  else
    echo "Tasks:   not yet created"
  fi

  # Review status
  local review="$dir/review.md"
  if [ -f "$review" ]; then
    local verdict verdict_source evidence_status
    verdict="$(sdd_frontmatter_value "$review" verdict || echo "pending")"
    verdict_source="$(sdd_frontmatter_value "$review" verdict_source || true)"
    evidence_status="$(sdd_frontmatter_value "$review" evidence_status || true)"
    local ac_pass ac_fail
    ac_pass="$(review_ac_count "$review" "PASS")"
    ac_fail="$(review_ac_count "$review" "FAIL")"
    if [ -n "$verdict_source" ] || [ -n "$evidence_status" ]; then
      echo "Review:  verdict=$verdict | source=${verdict_source:-manual} | evidence=${evidence_status:-n/a} | $ac_pass PASS | $ac_fail FAIL"
    else
      echo "Review:  verdict=$verdict | $ac_pass PASS | $ac_fail FAIL"
    fi
  else
    echo "Review:  not yet created"
  fi

  # Continuity / knowledge upkeep status
  local continuity_file="$dir/continuity.md"
  local knowledge_file="$dir/knowledge.md"
  local continuity_state knowledge_state continuity_bytes knowledge_entries
  continuity_state="$(sdd_continuity_state "$continuity_file" 2>/dev/null || printf 'filled')"
  knowledge_state="$(sdd_knowledge_state "$knowledge_file" 2>/dev/null || printf 'filled')"
  continuity_bytes="$(continuity_content_bytes "$continuity_file")"
  knowledge_entries="$(knowledge_entry_count "$knowledge_file")"
  case "$continuity_state" in
    empty) echo "Continuity: ⚠️ placeholder only" ;;
    partial) echo "Continuity: ⚠️ partial (${continuity_bytes} bytes)" ;;
    *) echo "Continuity: ✅ ${continuity_bytes} bytes" ;;
  esac
  case "$knowledge_state" in
    empty) echo "Knowledge: ⚠️ no entries" ;;
    partial) echo "Knowledge: ⚠️ ${knowledge_entries} entries" ;;
    *) echo "Knowledge: ✅ ${knowledge_entries} entries" ;;
  esac

  # Scratchpad
  local scratch="$dir/scratchpad.md"
  if [ -f "$scratch" ]; then
    local obs_count
    obs_count=$(count_pattern '^\- \[' "$scratch")
    echo "Scratch: active ($obs_count entries)"
  fi

  # Summary status
  local summary_compact="$dir/summary-compact.md"
  if [ -f "$summary_compact" ]; then
    local excerpt
    excerpt="$(grep '^- Goal:' "$summary_compact" 2>/dev/null | head -1 | cut -c1-80)" || true
    echo "Summary: available ($excerpt...)"
  else
    echo "Summary: not yet generated (run sdd summary $feature_path)"
  fi

  local workers_json="null"
  workers_json="$(sdd_worker_state_json "$fid")"
  if [ "$workers_json" != "null" ]; then
    local latest_dispatch_line="" latest_result_line="" pending_line=""
    latest_dispatch_line="$(printf '%s\n' "$workers_json" | jq -r '
      .latest_dispatch
      | select(. != null)
      | "\(.role) \(.dispatch_id)" + (if .task.id then " \(.task.id)" + (if .task.heading != "" and .task.heading != null then ": \(.task.heading)" else "" end) else "" end) + " (epoch \(.dispatch_epoch))"
    ' 2>/dev/null)" || latest_dispatch_line=""
    latest_result_line="$(printf '%s\n' "$workers_json" | jq -r '
      .latest_result
      | select(. != null)
      | "\(.role) \(.dispatch_id) -> \(.status)" + (if (.warnings // []) | length > 0 then " ⚠ \((.warnings | length)) warning(s)" else "" end)
    ' 2>/dev/null)" || latest_result_line=""
    pending_line="$(printf '%s\n' "$workers_json" | jq -r '
      .pending_controller_action
      | select(. != null)
      | "\(.role) \(.dispatch_id) -> \(.status)" + (if .has_warnings == true then " ⚠ warnings" else "" end)
    ' 2>/dev/null)" || pending_line=""

    echo "Workers:"
    [ -n "$latest_dispatch_line" ] && echo "  Dispatch: $latest_dispatch_line"
    [ -n "$latest_result_line" ] && echo "  Result:   $latest_result_line"
    [ -n "$pending_line" ] && echo "  Pending:  $pending_line"
  fi

  # Work Packages breakdown (only shown when wp-*/ dirs exist)
  local wp_dirs
  wp_dirs="$(ls -d "$dir"/wp-*/ 2>/dev/null | sort)" || true
  if [ -n "$wp_dirs" ]; then
    echo ""
    echo "Work Packages:"
    printf "  %-25s %-12s %-15s\n" "NAME" "PHASE" "PROGRESS"
    printf "  %-25s %-12s %-15s\n" "----" "-----" "--------"
    local wp_total_done=0 wp_total_tasks=0
    for wp in $wp_dirs; do
      local wp_name wphase wp_done wp_tasks
      wp_name="$(basename "$wp")"
      wphase="$(wp_phase_label "$wp")"
      local wp_tasks_file="$wp/tasks.md"
      wp_tasks=0
      wp_done=0
      if [ -f "$wp_tasks_file" ]; then
        wp_tasks=$(sdd_count_task_headings "$wp_tasks_file")
        wp_done=$(sdd_count_task_status "$wp_tasks_file" "completed")
      fi
      wp_total_done=$((wp_total_done + wp_done))
      wp_total_tasks=$((wp_total_tasks + wp_tasks))
      printf "  %-25s %-12s %-15s\n" "$wp_name" "$wphase" "${wp_done}/${wp_tasks} tasks"
    done
    echo ""
    echo "  Aggregate: ${wp_total_done}/${wp_total_tasks} tasks across all WPs"
  fi

  echo ""
}

epic_overview_rollup() {
  local epic_file="$FEATURE_ROOT/EPIC.md"
  local state_file="$FEATURE_ROOT/.epic-state.json"
  local title total planned in_progress done_count deferred cancelled line

  [ -f "$epic_file" ] || return 0
  [ -f "$SCRIPT_DIR/sdd-epic-refresh.sh" ] && bash "$SCRIPT_DIR/sdd-epic-refresh.sh" --current >/dev/null 2>&1 || true
  [ -f "$state_file" ] || return 0

  title="$(jq -r '.epic.title // "Epic"' "$state_file" 2>/dev/null)" || title="Epic"
  total="$(jq -r '.entries | length' "$state_file" 2>/dev/null)" || total=0
  planned="$(jq -r '.counts.planned // 0' "$state_file" 2>/dev/null)" || planned=0
  in_progress="$(jq -r '.counts["in-progress"] // 0' "$state_file" 2>/dev/null)" || in_progress=0
  done_count="$(jq -r '.counts.done // 0' "$state_file" 2>/dev/null)" || done_count=0
  deferred="$(jq -r '.counts.deferred // 0' "$state_file" 2>/dev/null)" || deferred=0
  cancelled="$(jq -r '.counts.cancelled // 0' "$state_file" 2>/dev/null)" || cancelled=0

  line="Epic: $title · $total entries · $done_count done · $in_progress in-progress · $planned planned"
  [ "$deferred" -gt 0 ] && line="$line · $deferred deferred"
  [ "$cancelled" -gt 0 ] && line="$line · $cancelled cancelled"
  echo "$line"
  echo ""
}

# Overview: all features
overview() {
  echo "═══════════════════════════════════════════════"
  echo "Spec-Driven Development — All Features"
  echo "═══════════════════════════════════════════════"
  echo ""

  epic_overview_rollup

  if [ ! -d "$FEATURE_ROOT" ] || [ -z "$(ls -A "$FEATURE_ROOT" 2>/dev/null)" ]; then
    echo "No features found. Run sdd-init.sh to create one."
    exit 0
  fi

  # Check if any feature uses WPs (to decide whether to show WP column)
  local any_wps=0
  local feature_path
  while IFS= read -r feature_path; do
    [ -n "$feature_path" ] || continue
    local f="$FEATURE_ROOT/$feature_path"
    local wp_check
    wp_check="$(ls -d "$f"/wp-*/ 2>/dev/null)" || true
    if [ -n "$wp_check" ]; then
      any_wps=1
      break
    fi
  done <<EOF
$(sdd_iter_feature_paths)
EOF

  if [ "$any_wps" = "1" ]; then
    printf "%-25s %-15s %-20s %-10s\n" "FEATURE" "PHASE" "PROGRESS" "WPs"
    printf "%-25s %-15s %-20s %-10s\n" "-------" "-----" "--------" "---"
  else
    printf "%-25s %-15s %-20s\n" "FEATURE" "PHASE" "PROGRESS"
    printf "%-25s %-15s %-20s\n" "-------" "-----" "--------"
  fi

  while IFS= read -r feature_path; do
    [ -n "$feature_path" ] || continue
    local f="$FEATURE_ROOT/$feature_path"
    local fid
    fid="$(sdd_feature_path_id "$feature_path")"
    local phase
    phase="$(sdd_feature_phase "$feature_path")"

    local progress="—"
    local task_summary_json task_source
    task_summary_json="$(sdd_feature_task_summary_json "$f")"
    task_source="$(printf '%s\n' "$task_summary_json" | jq -r '.source')"
    if [ "$task_source" != "none" ]; then
      local task_summary_json total done_count
      total="$(printf '%s\n' "$task_summary_json" | jq -r '.total')"
      done_count="$(printf '%s\n' "$task_summary_json" | jq -r '.completed')"
      progress="$done_count/$total tasks"
    fi

    if [ "$any_wps" = "1" ]; then
      local wp_count_str="—"
      local wp_dirs
      wp_dirs="$(ls -d "$f"/wp-*/ 2>/dev/null | sort)" || true
      if [ -n "$wp_dirs" ]; then
        local wc=0
        for _wp in $wp_dirs; do wc=$((wc + 1)); done
        wp_count_str="$wc WP(s)"
      fi
      printf "%-25s %-15s %-20s %-10s\n" "$feature_path" "$phase" "$progress" "$wp_count_str"
    else
      printf "%-25s %-15s %-20s\n" "$feature_path" "$phase" "$progress"
    fi
  done <<EOF
$(sdd_iter_feature_paths)
EOF
  echo ""
}

# Main
FEATURE_ID="${SDD_FEATURE_OVERRIDE:-${SDD_ARGS[0]:-}}"

if sdd_is_json_mode; then
  command -v jq >/dev/null 2>&1 || sdd_fail "status" "internal" "jq is required for JSON status output"

  if [ "$STATUS_CURRENT" = "1" ]; then
    status_resolve_single_feature "" 1 "no current feature found for --current" '{"flag":"--current"}' "none"
    PAYLOAD_JSON="$(feature_status_json "$SDD_RESOLVED_FEATURE" "$SDD_RESOLUTION_SOURCE" "$SDD_RESOLVED_FEATURE_PATH")"
    PHASE_VALUE="$(printf '%s\n' "$PAYLOAD_JSON" | jq -r '.phase')"
    GUIDANCE_JSON="$(sdd_json_guidance "" "" "")"
    ENVELOPE_JSON="$(sdd_json_success "status" "$SDD_RESOLVED_FEATURE" "$SDD_RESOLUTION_SOURCE" "$PHASE_VALUE" "$PAYLOAD_JSON" "$GUIDANCE_JSON" '[]')"
    FINAL_JSON="$(jq -cn --argjson payload "$PAYLOAD_JSON" --argjson envelope "$ENVELOPE_JSON" '$payload + $envelope')"
    sdd_emit_json_selection "$FINAL_JSON"
    exit 0
  fi

  if [ -n "$FEATURE_ID" ]; then
    status_resolve_single_feature "$FEATURE_ID" 1 "no active feature found for --feature auto" "{\"feature\":\"$FEATURE_ID\"}" "$( [ "$FEATURE_ID" = "auto" ] && printf 'none' || printf 'arg' )"

    PAYLOAD_JSON="$(feature_status_json "$SDD_RESOLVED_FEATURE" "$SDD_RESOLUTION_SOURCE" "$SDD_RESOLVED_FEATURE_PATH")"
    PHASE_VALUE="$(printf '%s\n' "$PAYLOAD_JSON" | jq -r '.phase')"
    GUIDANCE_JSON="$(sdd_json_guidance "" "" "")"
    ENVELOPE_JSON="$(sdd_json_success "status" "$SDD_RESOLVED_FEATURE" "$SDD_RESOLUTION_SOURCE" "$PHASE_VALUE" "$PAYLOAD_JSON" "$GUIDANCE_JSON" '[]')"
    FINAL_JSON="$(jq -cn --argjson payload "$PAYLOAD_JSON" --argjson envelope "$ENVELOPE_JSON" '$payload + $envelope')"
    sdd_emit_json_selection "$FINAL_JSON"
    exit 0
  fi

  if [ -n "${SDD_FIELD:-}" ] && status_field_requires_feature_scope "$SDD_FIELD"; then
    sdd_fail "status" "precondition" "feature-scoped status fields require --feature <id|auto> or --current" "{\"field\":\"$SDD_FIELD\"}" "" "none"
  fi

  FEATURES_JSON="$(overview_json)"
  DATA_JSON="$(jq -cn --argjson features "$FEATURES_JSON" '{features: $features, count: ($features | length)}')"
  sdd_emit_json_selection "$(sdd_json_success "status" "" "none" "" "$DATA_JSON" '{}' '[]')"
  exit 0
fi

if [ "$STATUS_CURRENT" = "1" ]; then
  status_resolve_single_feature "" 1 "no current feature found for --current" '{"flag":"--current"}' "none"
  feature_status "$SDD_RESOLVED_FEATURE" "$SDD_RESOLVED_FEATURE_PATH"
elif [ -n "$FEATURE_ID" ]; then
  status_resolve_single_feature "$FEATURE_ID" 0 "no matching feature found" "{\"feature\":\"$FEATURE_ID\"}" "$( [ "$FEATURE_ID" = "auto" ] && printf 'none' || printf 'arg' )"
  feature_status "$SDD_RESOLVED_FEATURE" "$SDD_RESOLVED_FEATURE_PATH"
else
  overview
fi
