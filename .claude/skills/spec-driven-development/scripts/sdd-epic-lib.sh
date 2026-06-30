#!/usr/bin/env bash
# sdd-epic-lib.sh — Shared EPIC.md parsing helpers
# Source pattern: source "$(dirname "$0")/sdd-epic-lib.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

sdd_epic_validate_id() {
  local entry_id="${1:-}"
  [[ "$entry_id" =~ ^E-[0-9]{2,}$ ]]
}

sdd_epic_file() {
  printf '%s/EPIC.md\n' "$SDD_FEATURE_ROOT"
}

sdd_epic_entries_raw_tsv() {
  local epic_file="$1"
  [ -f "$epic_file" ] || return 0

  awk '
    function clean(s) {
      gsub(/\t/, " ", s)
      sub(/\r$/, "", s)
      return s
    }
    function trim(s) {
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      return s
    }
    function flush_entry() {
      if (id == "") return
      if (status == "") status = "planned"
      if (mode == "") mode = "full"
      if (depends_on == "") depends_on = "[]"
      if (group == "") group = "Ungrouped"
      printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\n", order, id, clean(title), clean(slug), clean(status), clean(mode), clean(feature), section_count, clean(group), clean(depends_on)
    }

    /^```/ {
      in_fence = !in_fence
      next
    }
    in_fence { next }

    /^## Entries[[:space:]]*$/ {
      in_entries = 1
      group = "Ungrouped"
      next
    }

    in_entries && /^## / {
      flush_entry()
      id = ""; title = ""; slug = ""; status = ""; mode = ""; feature = ""; depends_on = ""; section_count = 0
      group = clean(substr($0, 4))
      next
    }

    in_entries && /^### E-[0-9][0-9]+:/ {
      flush_entry()
      order++
      heading = substr($0, 5)
      id = heading
      sub(/:.*/, "", id)
      title = heading
      sub(/^[^:]+:[ \t]*/, "", title)
      slug = ""; status = ""; mode = ""; feature = ""; depends_on = ""; section_count = 0
      next
    }

    in_entries && id != "" && /^> Slug:/ {
      slug = trim(substr($0, index($0, ":") + 1))
      next
    }
    in_entries && id != "" && /^> Status:/ {
      status = trim(substr($0, index($0, ":") + 1))
      next
    }
    in_entries && id != "" && /^> Mode:/ {
      mode = trim(substr($0, index($0, ":") + 1))
      next
    }
    in_entries && id != "" && /^> Feature:/ {
      feature = trim(substr($0, index($0, ":") + 1))
      next
    }
    in_entries && id != "" && /^> Depends-on:/ {
      depends_on = trim(substr($0, index($0, ":") + 1))
      next
    }
    in_entries && id != "" && /^#### / {
      section_count++
      next
    }

    END {
      flush_entry()
    }
  ' "$epic_file"
}

# Emits TSV columns:
# id, slug, status, mode, feature, depends_on_json, section_count, title, group, order
sdd_epic_iter_entries() {
  local epic_file="$1"
  local raw_line order id title slug status mode feature section_count group depends_raw depends_json

  sdd_epic_entries_raw_tsv "$epic_file" | while IFS= read -r raw_line; do
    sdd_tsv_split "$raw_line" order id title slug status mode feature section_count group depends_raw
    [ -n "$id" ] || continue
    depends_json="$(sdd_parse_id_list "$depends_raw" | jq -c '.')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$id" "$slug" "$status" "$mode" "$feature" "$depends_json" "$section_count" "$title" "$group" "$order"
  done
}

sdd_epic_entry_section() {
  local epic_file="$1" entry_id="$2" section="$3"
  [ -f "$epic_file" ] || return 0
  [ -n "$entry_id" ] || return 0
  [ -n "$section" ] || return 0

  awk -v entry_id="$entry_id" -v section="$section" '
    function trim_trailing_blank() {
      while (buf ~ /\n\n$/) sub(/\n$/, "", buf)
    }

    /^```/ {
      if (in_entry && in_section) {
        buf = buf $0 "\n"
      }
      in_fence = !in_fence
      next
    }

    !in_fence && /^### E-[0-9][0-9]+:/ {
      current = substr($0, 5)
      sub(/:.*/, "", current)
      if (in_entry) exit
      in_entry = (current == entry_id)
      next
    }

    !in_fence && in_entry && /^#### / {
      heading = substr($0, 6)
      if (in_section) exit
      in_section = (heading == section)
      next
    }

    !in_fence && in_entry && /^### / {
      if (in_section) exit
      in_entry = 0
      next
    }

    in_entry && in_section {
      buf = buf $0 "\n"
    }

    END {
      sub(/^\n+/, "", buf)
      trim_trailing_blank()
      if (length(buf) > 0) printf "%s\n", buf
    }
  ' "$epic_file"
}

sdd_epic_graph_json() {
  local epic_file="$1"
  local nodes_json='[]' edges_json='[]' problems_json='[]'
  local entry_line id slug status mode feature depends_json section_count title group order

  [ -f "$epic_file" ] || {
    printf '{"nodes":[],"edges":[],"problems":[]}\n'
    return 0
  }

  while IFS= read -r entry_line; do
    sdd_tsv_split "$entry_line" id slug status mode feature depends_json section_count title group order
    [ -n "$id" ] || continue
    nodes_json="$(printf '%s\n' "$nodes_json" | jq -c \
      --arg id "$id" \
      --arg slug "$slug" \
      --arg status "$status" \
      --arg mode "$mode" \
      --arg feature "$feature" \
      --arg title "$title" \
      --arg group "$group" \
      --argjson order "$order" \
      --argjson section_count "$section_count" \
      --argjson depends_on "$depends_json" \
      '. + [{
        id: $id,
        slug: $slug,
        status: $status,
        mode: $mode,
        feature: (if $feature == "" then null else $feature end),
        depends_on: $depends_on,
        section_count: $section_count,
        title: $title,
        group: $group,
        order: $order
      }]')"
  done < <(sdd_epic_iter_entries "$epic_file")

  while IFS= read -r node_json; do
    [ -n "$node_json" ] || continue
    id="$(printf '%s\n' "$node_json" | jq -r '.id')"
    depends_json="$(printf '%s\n' "$node_json" | jq -c '.depends_on // []')"

    while IFS= read -r dep_ref; do
      [ -n "$dep_ref" ] || continue
      local dep_exists
      dep_exists="$(printf '%s\n' "$nodes_json" | jq -r --arg dep "$dep_ref" 'any(.id == $dep)')"

      edges_json="$(printf '%s\n' "$edges_json" | jq -c \
        --arg from "$id" \
        --arg to "$dep_ref" \
        --argjson resolved "$dep_exists" \
        '. + [{from:$from, to:$to, resolved:$resolved}]')"

      if [ "$dep_ref" = "$id" ]; then
        problems_json="$(printf '%s\n' "$problems_json" | jq -c \
          --arg entry "$id" \
          '. + [{type:"self_dependency", entry:$entry, ref:$entry, message:($entry + " depends on itself")}]')"
      elif [ "$dep_exists" != "true" ]; then
        problems_json="$(printf '%s\n' "$problems_json" | jq -c \
          --arg entry "$id" \
          --arg ref "$dep_ref" \
          '. + [{type:"missing_dependency", entry:$entry, ref:$ref, message:($entry + " depends on " + $ref + " which does not exist")}]')"
      fi
    done < <(printf '%s\n' "$depends_json" | jq -r '.[]?')
  done < <(printf '%s\n' "$nodes_json" | jq -c '.[]')

  local cycle_nodes_json cycle_edges_json cycle_json
  cycle_nodes_json="$(printf '%s\n' "$nodes_json" | jq -c 'map({key:.id, ref:.id})')"
  cycle_edges_json="$(printf '%s\n' "$edges_json" | jq -c 'map(select(.resolved == true and .from != .to) | {from:.from, to:.to}) | unique_by(.from + "|" + .to)')"

  cycle_json="$(jq -nc --argjson nodes "$cycle_nodes_json" --argjson edges "$cycle_edges_json" '
    def topo($nodes; $edges; $sorted):
      if ($nodes | length) == 0 then
        {sorted: $sorted, remaining: []}
      else
        ($nodes | map(. as $id | {id: $id, indegree: ([ $edges[] | select(.to == $id) ] | length)})) as $meta
        | ($meta | map(select(.indegree == 0) | .id)) as $roots
        | if ($roots | length) == 0 then
            {sorted: $sorted, remaining: $nodes}
          else
            topo(
              ($nodes - $roots);
              ($edges | map(select(.from as $from | ($roots | index($from)) | not)));
              ($sorted + $roots)
            )
          end
      end;
    ($nodes | map(.key)) as $ids
    | topo($ids; $edges; [])
  ')"

  if [ "$(printf '%s\n' "$cycle_json" | jq -r '.remaining | length')" -gt 0 ]; then
    local cycle_refs_json
    cycle_refs_json="$(jq -nc \
      --argjson nodes "$cycle_nodes_json" \
      --argjson remaining "$(printf '%s\n' "$cycle_json" | jq -c '.remaining')" \
      '[ $remaining[] as $id | ($nodes[] | select(.key == $id) | .ref) ]')"
    problems_json="$(printf '%s\n' "$problems_json" | jq -c \
      --argjson remaining "$cycle_refs_json" \
      '. + [{
        type: "cycle",
        participants: $remaining,
        message: ("Dependency cycle detected: " + (($remaining + [$remaining[0]]) | join(" -> ")))
      }]')"
  fi

  jq -nc \
    --argjson nodes "$nodes_json" \
    --argjson edges "$edges_json" \
    --argjson problems "$problems_json" \
    '{
      nodes: $nodes,
      edges: $edges,
      problems: $problems
    }'
}
