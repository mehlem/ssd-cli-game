#!/usr/bin/env bash
# sdd-epic.sh — Manage project-level EPIC.md registry
# Usage: sdd-epic.sh {init|check|add|status|scaffold|link} [args]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-epic-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "epic" "sdd epic <cmd> [args]" "invalid shared CLI flags"
sdd_install_cleanup_trap

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "epic" \
      "Create and inspect the project-level EPIC.md registry." \
      "sdd epic {init|check|add|status|scaffold|link} [args] [--format text|json]" \
      "$(sdd_common_flags_json)" \
      '[]' \
      '[
        "sdd epic init \"Auth Rewrite\"",
        "sdd epic init --json \"Auth Rewrite\"",
        "sdd epic check --json",
        "sdd epic add jwt-cutover \"Cut sessions over to JWT\" --depends-on E-01,E-02",
        "sdd epic status --json --field entries",
        "sdd epic scaffold E-01",
        "sdd epic link E-01 0042-existing-feature"
      ]'
    return 0
  fi

  echo "sdd epic — Project-level epic registry"
  echo ""
  echo "Commands:"
  echo "  init [title]   Create .features/EPIC.md"
  echo "  check [file]   Validate EPIC.md structure and dependencies"
  echo "  add <slug> <description> [--mode lite|full|normal|default|deep] [--depends-on E-01,E-02]"
  echo "                 Append an auto-numbered epic entry"
  echo "  status         Render derived epic entry status"
  echo "  scaffold <E-NN>"
  echo "                 Create an SDD feature from an epic entry"
  echo "  link <E-NN> <feature-id>"
  echo "                 Link an epic entry to an existing feature"
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

cmd="${SDD_ARGS[0]:-help}"
EPIC_ARGS=()
[ "${#SDD_ARGS[@]}" -gt 1 ] && EPIC_ARGS=("${SDD_ARGS[@]:1}")

epic_arg() {
  local index="$1"
  printf '%s\n' "${EPIC_ARGS[$index]:-}"
}

replace_placeholders() {
  local template="$1" title="$2" today="$3"
  local epic_id title_yaml line

  epic_id="$(printf '%s\n' "$title" | awk '
    {
      gsub(/[^[:alnum:]]+/, "-")
      gsub(/^-+|-+$/, "")
      print
      found = 1
      exit
    }
    END {
      if (!found) print "Epic"
    }
  ')"
  [ -n "$epic_id" ] || epic_id="Epic"
  title_yaml="${title//\\/\\\\}"
  title_yaml="${title_yaml//\"/\\\"}"

  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//\{\{EPIC_ID\}\}/$epic_id}"
    line="${line//\{\{EPIC_TITLE_YAML\}\}/$title_yaml}"
    line="${line//\{\{EPIC_TITLE\}\}/$title}"
    line="${line//\{\{DATE\}\}/$today}"
    printf '%s\n' "$line"
  done < "$template"
}

cmd_init() {
  local title target template action tmp today data_json guidance_json
  title="$(epic_arg 0)"
  [ -n "$title" ] || title="Epic"

  target="$(sdd_epic_file)"
  template="$SDD_TEMPLATE_DIR/epic.md"
  [ -f "$template" ] || sdd_fail "epic" "internal" "template '$template' not found" "{\"template\":\"$template\"}"

  mkdir -p "$SDD_FEATURE_ROOT"
  action="$(sdd_existing_path_action "$target" "$target")" || sdd_fail "epic" "conflict" "$target already exists" "{\"file\":\"$target\"}"

  if [ "$action" != "skip" ]; then
    today="$(date +%Y-%m-%d)"
    tmp="$(sdd_tmp_for_target "$target")" || sdd_fail "epic" "internal" "failed to create temp file for $target" "{\"file\":\"$target\"}"
    sdd_cleanup_push "$tmp"
    replace_placeholders "$template" "$title" "$today" > "$tmp" || {
      sdd_cleanup_file "$tmp"
      sdd_fail "epic" "internal" "failed to render epic template" "{\"template\":\"$template\",\"file\":\"$target\"}"
    }
    sdd_atomic_replace "$tmp" "$target" || {
      sdd_cleanup_file "$tmp"
      sdd_fail "epic" "internal" "failed to write $target" "{\"file\":\"$target\"}"
    }
  fi

  if sdd_is_json_mode; then
    data_json="$(jq -nc --arg action "$action" --arg file "$target" '{action:$action,file:$file}')"
    guidance_json="$(sdd_json_guidance "Fill .features/EPIC.md Goal and Entries before scaffolding linked features." "Epic mode is active when .features/EPIC.md exists." "do not encode feature lifecycle state manually; linked entry status is derived later.")"
    sdd_emit_json_selection "$(sdd_json_success "epic" "" "none" "" "$data_json" "$guidance_json" '[]')"
    return 0
  fi

  case "$action" in
    create|overwrite) echo "Epic $action: $target" ;;
    skip) echo "Epic unchanged: $target" ;;
  esac
}

epic_next_entry_id() {
  local file="$1" max_num=0 id num
  if [ -f "$file" ]; then
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      sdd_epic_validate_id "$id" || continue
      num="${id#E-}"
      num=$((10#$num))
      [ "$num" -gt "$max_num" ] && max_num="$num"
    done < <(sdd_epic_iter_entries "$file" | awk -F '\t' '{print $1}')
  fi
  printf 'E-%02d\n' "$((max_num + 1))"
}

epic_entry_count() {
  local file="$1"
  [ -f "$file" ] || { printf '0\n'; return 0; }
  sdd_epic_iter_entries "$file" | wc -l | tr -d ' '
}

epic_validate_dependency_ids() {
  local depends_json="$1" dep
  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    sdd_epic_validate_id "$dep" || sdd_usage_error "epic" "sdd epic add <slug> <description> [--depends-on E-01,E-02]" "invalid dependency id '$dep'"
  done < <(printf '%s\n' "$depends_json" | jq -r '.[]?')
}

cmd_add() {
  local file slug="" description="" mode="full" depends_raw="" depends_json
  local i arg next_id existing_count tmp data_json guidance_json
  i=0
  while [ "$i" -lt "${#EPIC_ARGS[@]}" ]; do
    arg="${EPIC_ARGS[$i]}"
    case "$arg" in
      --mode)
        i=$((i + 1))
        [ "$i" -lt "${#EPIC_ARGS[@]}" ] || sdd_usage_error "epic" "sdd epic add <slug> <description> --mode lite|full|normal|default|deep" "--mode requires a value"
        mode="${EPIC_ARGS[$i]}"
        ;;
      --depends-on)
        i=$((i + 1))
        [ "$i" -lt "${#EPIC_ARGS[@]}" ] || sdd_usage_error "epic" "sdd epic add <slug> <description> --depends-on E-01,E-02" "--depends-on requires a value"
        depends_raw="${EPIC_ARGS[$i]}"
        ;;
      --*)
        sdd_usage_error "epic" "sdd epic add <slug> <description> [--mode lite|full|normal|default|deep] [--depends-on E-01,E-02]" "unknown add flag '$arg'"
        ;;
      *)
        if [ -z "$slug" ]; then
          slug="$arg"
        elif [ -z "$description" ]; then
          description="$arg"
        else
          sdd_usage_error "epic" "sdd epic add <slug> <description> [--mode lite|full|normal|default|deep] [--depends-on E-01,E-02]" "unexpected argument '$arg'"
        fi
        ;;
    esac
    i=$((i + 1))
  done

  [ -n "$slug" ] || sdd_usage_error "epic" "sdd epic add <slug> <description> [--mode lite|full|normal|default|deep] [--depends-on E-01,E-02]" "missing entry slug"
  [ -n "$description" ] || sdd_usage_error "epic" "sdd epic add <slug> <description> [--mode lite|full|normal|default|deep] [--depends-on E-01,E-02]" "missing entry description"
  mode="$(sdd_normalize_mode_input "$mode")" || sdd_usage_error "epic" "sdd epic add <slug> <description> --mode lite|full|normal|default|deep" "mode must be one of: lite, full, normal, default, deep"

  file="$(sdd_epic_file)"
  [ -f "$file" ] || sdd_fail "epic" "not_found" "$file not found; run 'sdd epic init' first" "{\"file\":\"$file\"}"
  grep -q '^## Entries' "$file" || sdd_fail "epic" "precondition" "$file is missing ## Entries" "{\"file\":\"$file\"}"

  depends_json="$(sdd_parse_id_list "$depends_raw")"
  epic_validate_dependency_ids "$depends_json"
  next_id="$(epic_next_entry_id "$file")"
  existing_count="$(epic_entry_count "$file")"

  tmp="$(sdd_tmp_for_target "$file")" || sdd_fail "epic" "internal" "failed to create temp file for $file" "{\"file\":\"$file\"}"
  sdd_cleanup_push "$tmp"
  cat "$file" > "$tmp"
  {
    echo ""
    if [ "$existing_count" -gt 0 ]; then
      echo "***"
      echo ""
    fi
    printf '### %s: %s\n' "$next_id" "$description"
    printf '> Slug: %s\n' "$slug"
    echo '> Status: planned'
    printf '> Mode: %s\n' "$mode"
    echo '> Feature:'
    printf '> Depends-on: %s\n' "$depends_json"
    echo ""
    echo "#### Motivation"
    echo ""
    echo "#### Problem"
    echo ""
    echo "#### Vision"
    echo ""
    echo "#### Context"
    echo ""
    echo "#### Constraints"
    echo ""
    echo "#### Notes"
  } >> "$tmp"

  sdd_atomic_replace "$tmp" "$file" || {
    sdd_cleanup_file "$tmp"
    sdd_fail "epic" "internal" "failed to append entry to $file" "{\"file\":\"$file\",\"entry\":\"$next_id\"}"
  }

  if sdd_is_json_mode; then
    data_json="$(jq -nc --arg action "add" --arg file "$file" --arg entry "$next_id" --arg slug "$slug" --arg mode "$mode" --argjson depends_on "$depends_json" '{action:$action,file:$file,entry:$entry,slug:$slug,mode:$mode,depends_on:$depends_on}')"
    guidance_json="$(sdd_json_guidance "Fill the new entry's Motivation/Problem/Vision/Context/Constraints before scaffolding." "Run 'sdd epic check' after editing dependencies." "")"
    sdd_emit_json_selection "$(sdd_json_success "epic" "" "none" "" "$data_json" "$guidance_json" '[]')"
    return 0
  fi

  echo "Epic entry added: $next_id ($slug)"
}

epic_entry_row_or_fail() {
  local file="$1" entry_id="$2" row=""
  sdd_epic_validate_id "$entry_id" || sdd_usage_error "epic" "sdd epic <cmd> <E-NN>" "invalid entry id '$entry_id'"
  row="$(sdd_epic_iter_entries "$file" | awk -F '\t' -v id="$entry_id" '$1 == id && !found { print; found = 1 } END { if (!found) exit 1 }')" || {
    sdd_fail "epic" "not_found" "epic entry '$entry_id' not found" "{\"entry\":\"$entry_id\",\"file\":\"$file\"}"
  }
  printf '%s\n' "$row"
}

epic_write_entry_feature() {
  local file="$1" entry_id="$2" feature_id="$3"
  local tmp
  tmp="$(sdd_tmp_for_target "$file")" || return 1
  sdd_cleanup_push "$tmp"
  awk -v entry_id="$entry_id" -v feature_id="$feature_id" '
    function maybe_insert_feature() {
      if (in_target && !wrote_feature) {
        print "> Feature: " feature_id
        wrote_feature = 1
      }
    }
    /^### E-[0-9][0-9]+:/ {
      maybe_insert_feature()
      current = $0
      sub(/^### /, "", current)
      sub(/:.*/, "", current)
      in_target = (current == entry_id)
      wrote_feature = 0
      print
      next
    }
    in_target && /^> Feature:/ {
      print "> Feature: " feature_id
      wrote_feature = 1
      next
    }
    in_target && !wrote_feature && /^> Depends-on:/ {
      print "> Feature: " feature_id
      wrote_feature = 1
    }
    { print }
    END { maybe_insert_feature() }
  ' "$file" > "$tmp" || {
    sdd_cleanup_file "$tmp"
    return 1
  }
  sdd_atomic_replace "$tmp" "$file" || {
    sdd_cleanup_file "$tmp"
    return 1
  }
}

epic_resolve_feature_ref() {
  local ref="$1"
  [ -n "$ref" ] || return 1
  sdd_resolve_feature_target "$ref" 0
}

epic_feature_missing_message() {
  local ref="$1"
  case "$SDD_RESOLUTION_STATUS" in
    ambiguous) printf "links ambiguous feature: %s\n" "$ref" ;;
    not_found|none|"") printf "links missing feature: %s\n" "$ref" ;;
    *) printf "links unresolved feature: %s\n" "$ref" ;;
  esac
}

epic_replace_brief_section() {
  local brief_path="$1" section="$2" body="$3"
  local tmp body_tmp
  [ -n "$body" ] || return 0
  tmp="$(sdd_tmp_for_target "$brief_path")" || return 1
  body_tmp="$(mktemp)" || {
    sdd_cleanup_file "$tmp"
    return 1
  }
  sdd_cleanup_push "$tmp"
  sdd_cleanup_push "$body_tmp"
  printf '%s\n' "$body" > "$body_tmp" || {
    sdd_cleanup_file "$tmp"
    sdd_cleanup_file "$body_tmp"
    return 1
  }
  awk -v section="$section" -v body_file="$body_tmp" '
    function emit_body(line) {
      while ((getline line < body_file) > 0) print line
      close(body_file)
    }
    BEGIN { target = "## " section; skipping = 0; replaced = 0 }
    $0 == target {
      print
      print ""
      emit_body()
      skipping = 1
      replaced = 1
      next
    }
    skipping && /^## / {
      skipping = 0
    }
    skipping { next }
    { print }
    END {
      if (!replaced) exit 1
    }
  ' "$brief_path" > "$tmp" || {
    sdd_cleanup_file "$tmp"
    sdd_cleanup_file "$body_tmp"
    return 1
  }
  sdd_atomic_replace "$tmp" "$brief_path" || {
    sdd_cleanup_file "$tmp"
    sdd_cleanup_file "$body_tmp"
    return 1
  }
  sdd_cleanup_file "$body_tmp"
}

epic_restore_previous_selection() {
  local previous_selection="$1" active_file="$SDD_FEATURE_ROOT/.active" tmp
  [ -n "$previous_selection" ] || return 0
  tmp="$(sdd_tmp_for_target "$active_file")" || return 1
  sdd_cleanup_push "$tmp"
  printf '%s\n' "$previous_selection" > "$tmp"
  sdd_atomic_replace "$tmp" "$active_file"
}

epic_restore_selection_state() {
  local previous_selection="$1"
  if [ -n "$previous_selection" ]; then
    epic_restore_previous_selection "$previous_selection"
    return $?
  fi
  rm -f "$SDD_FEATURE_ROOT/.active"
}

epic_remove_scaffold_feature() {
  local feature_dir="$1"
  case "$feature_dir" in
    "$SDD_FEATURE_ROOT"/[0-9][0-9][0-9][0-9]-*) rm -rf "$feature_dir" ;;
    .features/[0-9][0-9][0-9][0-9]-*) rm -rf "$feature_dir" ;;
  esac
}

epic_rollback_scaffold() {
  local backup="$1" file="$2" feature_dir="$3" previous_selection="$4"
  epic_restore_backup "$backup" "$file" || true
  sdd_cleanup_file "$backup"
  epic_remove_scaffold_feature "$feature_dir"
  epic_restore_selection_state "$previous_selection" || true
}

epic_warn_unfinished_dependencies() {
  local file="$1" entry_id="$2"
  local entry_row depends_json rows dep dep_row dep_feature dep_dir dep_phase dep_lifecycle

  entry_row="$(epic_entry_row_or_fail "$file" "$entry_id")"
  depends_json="$(printf '%s\n' "$entry_row" | awk -F '\t' '{print $6}')"
  [ "$(printf '%s\n' "$depends_json" | jq -r 'length')" -gt 0 ] || return 0
  rows="$(sdd_epic_iter_entries "$file")"

  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    dep_row="$(printf '%s\n' "$rows" | awk -F '\t' -v id="$dep" '$1 == id && !found { print; found = 1 }')"
    if [ -z "$dep_row" ]; then
      sdd_warn "dependency $dep is not done for $entry_id (missing epic entry)"
      continue
    fi

    dep_feature="$(printf '%s\n' "$dep_row" | awk -F '\t' '{print $5}')"
    if [ -z "$dep_feature" ]; then
      sdd_warn "dependency $dep is not done for $entry_id (no linked feature)"
      continue
    fi

    if ! epic_resolve_feature_ref "$dep_feature"; then
      sdd_warn "dependency $dep is not done for $entry_id (linked feature missing: $dep_feature)"
      continue
    fi
    dep_feature="${SDD_RESOLVED_FEATURE_PATH:-$dep_feature}"
    dep_dir="${SDD_RESOLVED_FEATURE_DIR:-$SDD_FEATURE_ROOT/$dep_feature}"

    dep_phase="$(jq -r '.phase // empty' "$dep_dir/state.json" 2>/dev/null || true)"
    [ -n "$dep_phase" ] || dep_phase="$(sdd_feature_phase "$dep_feature" 2>/dev/null || true)"
    dep_lifecycle="$(sdd_feature_status "$dep_feature" 2>/dev/null || printf 'active\n')"
    if [ "$dep_phase" != "close" ] || [ "$dep_lifecycle" = "abandoned" ] || [ "$dep_lifecycle" = "superseded" ]; then
      sdd_warn "dependency $dep is not done for $entry_id (feature: $dep_feature, phase: ${dep_phase:-unknown})"
    fi
  done < <(printf '%s\n' "$depends_json" | jq -r '.[]?')
}

cmd_scaffold() {
  local file entry_id row entry_slug entry_mode entry_title init_json
  local epic_id feature_id feature_dir brief_path spec_path anchor_path anchor_type previous_selection section body data_json guidance_json backup
  entry_id="$(epic_arg 0)"
  [ -n "$entry_id" ] || sdd_usage_error "epic" "sdd epic scaffold <E-NN>" "missing entry id"

  file="$(sdd_epic_file)"
  [ -f "$file" ] || sdd_fail "epic" "not_found" "$file not found; run 'sdd epic init' first" "{\"file\":\"$file\"}"
  epic_id="$(sdd_frontmatter_value "$file" id 2>/dev/null || true)"
  [ -n "$epic_id" ] || sdd_fail "epic" "precondition" "$file is missing frontmatter id" "{\"file\":\"$file\"}"
  row="$(epic_entry_row_or_fail "$file" "$entry_id")"
  entry_slug="$(printf '%s\n' "$row" | awk -F '\t' '{print $2}')"
  entry_mode="$(printf '%s\n' "$row" | awk -F '\t' '{print $4}')"
  entry_title="$(printf '%s\n' "$row" | awk -F '\t' '{print $8}')"
  [ -n "$entry_slug" ] || sdd_fail "epic" "precondition" "$entry_id is missing Slug" "{\"entry\":\"$entry_id\"}"
  case "$entry_mode" in
    lite|full|deep) ;;
    *) sdd_fail "epic" "precondition" "$entry_id has invalid Mode: $entry_mode" "{\"entry\":\"$entry_id\",\"mode\":\"$entry_mode\"}" ;;
  esac
  epic_warn_unfinished_dependencies "$file" "$entry_id"

  init_json="$(bash "$SCRIPT_DIR/sdd-init.sh" --json --non-interactive --mode "$entry_mode" "$entry_slug" "$entry_title")" || {
    sdd_fail "epic" "internal" "failed to initialize feature for $entry_id" "{\"entry\":\"$entry_id\",\"slug\":\"$entry_slug\"}"
  }
  feature_id="$(printf '%s\n' "$init_json" | jq -r '.data.feature_id // empty')"
  feature_dir="$(printf '%s\n' "$init_json" | jq -r '.data.feature_dir // empty')"
  brief_path="$(printf '%s\n' "$init_json" | jq -r '.data.files.brief // empty')"
  spec_path="$(printf '%s\n' "$init_json" | jq -r '.data.files.spec // empty')"
  previous_selection="$(printf '%s\n' "$init_json" | jq -r '.data.previous_selection // empty')"
  [ -n "$feature_id" ] || sdd_fail "epic" "internal" "init output did not include feature_id" "{\"entry\":\"$entry_id\"}"
  case "$entry_mode" in
    lite) anchor_path="$spec_path" ;;
    *) anchor_path="$brief_path" ;;
  esac
  [ -n "$anchor_path" ] && [ -f "$anchor_path" ] || sdd_fail "epic" "internal" "init output did not include a valid epic anchor artifact" "{\"entry\":\"$entry_id\",\"mode\":\"$entry_mode\",\"anchor\":\"$anchor_path\"}"
  anchor_type="$(basename "$anchor_path" .md)"

  backup="$file.bak.$$"
  cp "$file" "$backup" || sdd_fail "epic" "internal" "failed to create EPIC.md rollback backup" "{\"file\":\"$file\",\"backup\":\"$backup\"}"
  sdd_cleanup_push "$backup"

  if ! epic_write_entry_feature "$file" "$entry_id" "$feature_id"; then
    epic_rollback_scaffold "$backup" "$file" "$feature_dir" "$previous_selection"
    sdd_fail "epic" "internal" "failed to link $entry_id to $feature_id" "{\"entry\":\"$entry_id\",\"feature\":\"$feature_id\"}"
  fi
  if ! sdd_stamp_epic_entry "$anchor_path" "$entry_id"; then
    epic_rollback_scaffold "$backup" "$file" "$feature_dir" "$previous_selection"
    sdd_fail "epic" "internal" "failed to stamp epic_entry into $anchor_path" "{\"entry\":\"$entry_id\",\"anchor\":\"$anchor_path\"}"
  fi
  if ! sdd_stamp_based_on "$anchor_path" "$epic_id"; then
    epic_rollback_scaffold "$backup" "$file" "$feature_dir" "$previous_selection"
    sdd_fail "epic" "internal" "failed to stamp based_on for $epic_id into $anchor_path" "{\"entry\":\"$entry_id\",\"anchor\":\"$anchor_path\",\"epic\":\"$epic_id\"}"
  fi
  sdd_cleanup_file "$backup"

  if [ "$entry_mode" = "lite" ]; then
    body="$(sdd_epic_entry_section "$file" "$entry_id" "Problem")"
    epic_replace_brief_section "$anchor_path" "Problem" "$body" || {
      epic_restore_previous_selection "$previous_selection" || true
      sdd_fail "epic" "internal" "failed to copy Problem into $anchor_path; scaffold is linked and recoverable as $feature_id" "{\"entry\":\"$entry_id\",\"feature\":\"$feature_id\",\"section\":\"Problem\",\"anchor\":\"$anchor_path\",\"recoverable\":true}"
    }
    body="$(sdd_epic_entry_section "$file" "$entry_id" "Vision")"
    epic_replace_brief_section "$anchor_path" "Solution" "$body" || {
      epic_restore_previous_selection "$previous_selection" || true
      sdd_fail "epic" "internal" "failed to copy Vision into $anchor_path; scaffold is linked and recoverable as $feature_id" "{\"entry\":\"$entry_id\",\"feature\":\"$feature_id\",\"section\":\"Vision\",\"anchor\":\"$anchor_path\",\"recoverable\":true}"
    }
    body="$(sdd_epic_entry_section "$file" "$entry_id" "Constraints")"
    epic_replace_brief_section "$anchor_path" "Constraints" "$body" || {
      epic_restore_previous_selection "$previous_selection" || true
      sdd_fail "epic" "internal" "failed to copy Constraints into $anchor_path; scaffold is linked and recoverable as $feature_id" "{\"entry\":\"$entry_id\",\"feature\":\"$feature_id\",\"section\":\"Constraints\",\"anchor\":\"$anchor_path\",\"recoverable\":true}"
    }
  else
    for section in Motivation Problem Vision Context Constraints; do
      body="$(sdd_epic_entry_section "$file" "$entry_id" "$section")"
      epic_replace_brief_section "$anchor_path" "$section" "$body" || {
        epic_restore_previous_selection "$previous_selection" || true
        sdd_fail "epic" "internal" "failed to copy $section into $anchor_path; scaffold is linked and recoverable as $feature_id" "{\"entry\":\"$entry_id\",\"feature\":\"$feature_id\",\"section\":\"$section\",\"anchor\":\"$anchor_path\",\"recoverable\":true}"
      }
    done
  fi

  epic_restore_previous_selection "$previous_selection" || sdd_fail "epic" "internal" "failed to restore previous active feature" "{\"previous_selection\":\"$previous_selection\"}"
  bash "$SCRIPT_DIR/sdd-epic-refresh.sh" >/dev/null 2>&1 || true

  if sdd_is_json_mode; then
    data_json="$(jq -nc --arg action "scaffold" --arg file "$file" --arg entry "$entry_id" --arg feature_id "$feature_id" --arg feature_dir "$feature_dir" --arg brief "$brief_path" --arg spec "$spec_path" --arg anchor "$anchor_path" --arg anchor_type "$anchor_type" --arg previous_selection "$previous_selection" '{action:$action,file:$file,entry:$entry,feature_id:$feature_id,feature_dir:$feature_dir,brief:(if $brief == "" then null else $brief end),spec:(if $spec == "" then null else $spec end),anchor:$anchor,anchor_type:$anchor_type,previous_selection:(if $previous_selection == "" then null else $previous_selection end)}')"
    guidance_json="$(sdd_json_guidance "Continue the new feature through the normal SDD lifecycle when ready." "The epic entry now links to the scaffolded feature." "")"
    sdd_emit_json_selection "$(sdd_json_success "epic" "$feature_id" "arg" "$anchor_type" "$data_json" "$guidance_json" '[]')"
    return 0
  fi

  echo "Epic entry scaffolded: $entry_id -> $feature_id"
}

epic_restore_backup() {
  local backup="$1" file="$2"
  [ -f "$backup" ] || return 1
  cp "$backup" "$file"
}

epic_restore_link_backups() {
  local epic_backup="$1" epic_file="$2" anchor_backup="$3" anchor_file="$4"
  epic_restore_backup "$epic_backup" "$epic_file" || true
  epic_restore_backup "$anchor_backup" "$anchor_file" || true
  sdd_cleanup_file "$epic_backup"
  sdd_cleanup_file "$anchor_backup"
}

cmd_link() {
  local file entry_id feature_ref feature_id feature_path feature_dir anchor_path anchor_type brief_path spec_path epic_id backup anchor_backup data_json guidance_json
  entry_id="$(epic_arg 0)"
  feature_ref="$(epic_arg 1)"
  [ -n "$entry_id" ] || sdd_usage_error "epic" "sdd epic link <E-NN> <feature-id>" "missing entry id"
  [ -n "$feature_ref" ] || sdd_usage_error "epic" "sdd epic link <E-NN> <feature-id>" "missing feature id"

  file="$(sdd_epic_file)"
  [ -f "$file" ] || sdd_fail "epic" "not_found" "$file not found; run 'sdd epic init' first" "{\"file\":\"$file\"}"
  epic_id="$(sdd_frontmatter_value "$file" id 2>/dev/null || true)"
  [ -n "$epic_id" ] || sdd_fail "epic" "precondition" "$file is missing frontmatter id" "{\"file\":\"$file\"}"
  epic_entry_row_or_fail "$file" "$entry_id" >/dev/null
  epic_resolve_feature_ref "$feature_ref" || sdd_fail "epic" "not_found" "feature '$feature_ref' not found" "{\"feature\":\"$feature_ref\"}"
  feature_id="$SDD_RESOLVED_FEATURE"
  feature_path="${SDD_RESOLVED_FEATURE_PATH:-$feature_id}"
  feature_dir="${SDD_RESOLVED_FEATURE_DIR:-$SDD_FEATURE_ROOT/$feature_path}"
  [ -d "$feature_dir" ] || sdd_fail "epic" "not_found" "feature '$feature_ref' not found" "{\"feature\":\"$feature_ref\"}"
  anchor_path="$(sdd_feature_epic_anchor_path_from_dir "$feature_dir" 2>/dev/null || true)"
  [ -n "$anchor_path" ] && [ -f "$anchor_path" ] || sdd_fail "epic" "not_found" "feature '$feature_ref' has no supported epic anchor artifact to stamp" "{\"feature\":\"$feature_ref\",\"feature_path\":\"$feature_path\",\"feature_dir\":\"$feature_dir\"}"
  anchor_type="$(basename "$anchor_path" .md)"
  brief_path=""
  spec_path=""
  [ -f "$feature_dir/brief.md" ] && brief_path="$feature_dir/brief.md"
  [ -f "$feature_dir/spec.md" ] && spec_path="$feature_dir/spec.md"

  backup="$file.bak.$$"
  cp "$file" "$backup" || sdd_fail "epic" "internal" "failed to create EPIC.md rollback backup" "{\"file\":\"$file\",\"backup\":\"$backup\"}"
  sdd_cleanup_push "$backup"
  anchor_backup="$anchor_path.bak.$$"
  cp "$anchor_path" "$anchor_backup" || {
    sdd_cleanup_file "$backup"
    sdd_fail "epic" "internal" "failed to create epic anchor rollback backup" "{\"anchor\":\"$anchor_path\",\"backup\":\"$anchor_backup\"}"
  }
  sdd_cleanup_push "$anchor_backup"

  if ! epic_write_entry_feature "$file" "$entry_id" "$feature_path"; then
    epic_restore_link_backups "$backup" "$file" "$anchor_backup" "$anchor_path"
    sdd_fail "epic" "internal" "failed to write feature link into EPIC.md" "{\"entry\":\"$entry_id\",\"feature\":\"$feature_ref\",\"feature_path\":\"$feature_path\"}"
  fi

  if ! sdd_stamp_epic_entry "$anchor_path" "$entry_id"; then
    epic_restore_link_backups "$backup" "$file" "$anchor_backup" "$anchor_path"
    sdd_fail "epic" "internal" "failed to stamp epic_entry into epic anchor artifact" "{\"entry\":\"$entry_id\",\"feature\":\"$feature_id\",\"feature_path\":\"$feature_path\",\"anchor\":\"$anchor_path\"}"
  fi

  if ! sdd_stamp_based_on "$anchor_path" "$epic_id"; then
    epic_restore_link_backups "$backup" "$file" "$anchor_backup" "$anchor_path"
    sdd_fail "epic" "internal" "failed to stamp based_on for $epic_id into epic anchor artifact" "{\"entry\":\"$entry_id\",\"feature\":\"$feature_id\",\"feature_path\":\"$feature_path\",\"anchor\":\"$anchor_path\",\"epic\":\"$epic_id\"}"
  fi

  sdd_cleanup_file "$backup"
  sdd_cleanup_file "$anchor_backup"
  bash "$SCRIPT_DIR/sdd-epic-refresh.sh" >/dev/null 2>&1 || true

  if sdd_is_json_mode; then
    data_json="$(jq -nc --arg action "link" --arg file "$file" --arg entry "$entry_id" --arg feature_id "$feature_id" --arg feature_path "$feature_path" --arg feature_dir "$feature_dir" --arg brief "$brief_path" --arg spec "$spec_path" --arg anchor "$anchor_path" --arg anchor_type "$anchor_type" '{action:$action,file:$file,entry:$entry,feature_id:$feature_id,feature_path:$feature_path,feature_dir:$feature_dir,brief:(if $brief == "" then null else $brief end),spec:(if $spec == "" then null else $spec end),anchor:$anchor,anchor_type:$anchor_type}')"
    guidance_json="$(sdd_json_guidance "The epic entry and feature epic anchor now point at each other." "Run 'sdd epic status' to see derived status." "")"
    sdd_emit_json_selection "$(sdd_json_success "epic" "$feature_id" "arg" "" "$data_json" "$guidance_json" '[]')"
    return 0
  fi

  echo "Epic entry linked: $entry_id -> $feature_path"
}

epic_add_finding() {
  local findings_json="$1" type="$2" message="$3"
  local entry="${4:-}" key="${5:-}" ref="${6:-}"
  jq -nc \
    --argjson findings "$findings_json" \
    --arg type "$type" \
    --arg message "$message" \
    --arg entry "$entry" \
    --arg key "$key" \
    --arg ref "$ref" \
    '$findings + [{
      type: $type,
      message: $message
    }
    + (if $entry != "" then {entry:$entry} else {} end)
    + (if $key != "" then {key:$key} else {} end)
    + (if $ref != "" then {ref:$ref} else {} end)]'
}

epic_invalid_heading_rows() {
  local file="$1"
  awk '
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^## Entries[[:space:]]*$/ { in_entries = 1; next }
    in_entries && /^## / { next }
    in_entries && /^### / && $0 !~ /^### E-[0-9][0-9]+:/ {
      line = $0
      sub(/^### /, "", line)
      gsub(/\t/, " ", line)
      printf "%d\t%s\n", NR, line
    }
  ' "$file"
}

cmd_check() {
  local file findings_json='[]' warnings_json='[]' data_json graph_json
  local key value row line heading ids_json prev_num current_num id mode feature entry_line
  file="$(epic_arg 0)"
  [ -n "$file" ] || file="$(sdd_epic_file)"
  [ -f "$file" ] || sdd_fail "epic" "not_found" "$file not found" "{\"file\":\"$file\"}"

  for key in id title schema_version created updated; do
    value="$(sdd_frontmatter_value "$file" "$key" 2>/dev/null || true)"
    if [ -z "$value" ]; then
      findings_json="$(epic_add_finding "$findings_json" "missing_frontmatter" "missing frontmatter key: $key" "" "$key")"
    fi
  done

  grep -q '^# Epic:' "$file" || findings_json="$(epic_add_finding "$findings_json" "missing_heading" "missing H1 heading: # Epic:" "" "h1")"
  grep -q '^## Goal' "$file" || findings_json="$(epic_add_finding "$findings_json" "missing_heading" "missing required heading: ## Goal" "" "Goal")"
  grep -q '^## Entries' "$file" || findings_json="$(epic_add_finding "$findings_json" "missing_heading" "missing required heading: ## Entries" "" "Entries")"

  while IFS=$'\t' read -r line heading; do
    [ -n "$line" ] || continue
    findings_json="$(epic_add_finding "$findings_json" "invalid_entry_id" "invalid entry heading at line $line: $heading" "" "entry_id")"
  done < <(epic_invalid_heading_rows "$file")

  ids_json="$(sdd_epic_iter_entries "$file" | awk -F '\t' '{print $1}' | jq -Rsc 'split("\n") | map(select(length > 0))')"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    count="$(printf '%s\n' "$ids_json" | jq -r --arg id "$id" '[.[] | select(. == $id)] | length')"
    if [ "$count" -gt 1 ]; then
      findings_json="$(epic_add_finding "$findings_json" "duplicate_entry_id" "duplicate entry id: $id" "$id")"
    fi
  done < <(printf '%s\n' "$ids_json" | jq -r 'unique[]?')

  prev_num=0
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    sdd_epic_validate_id "$id" || {
      findings_json="$(epic_add_finding "$findings_json" "invalid_entry_id" "invalid entry id: $id" "$id")"
      continue
    }
    current_num="${id#E-}"
    current_num=$((10#$current_num))
    if [ "$current_num" -le "$prev_num" ]; then
      findings_json="$(epic_add_finding "$findings_json" "non_monotonic_entry_id" "entry ids must be strictly increasing: $id" "$id")"
    fi
    prev_num="$current_num"
  done < <(sdd_epic_iter_entries "$file" | awk -F '\t' '{print $1}')

  while IFS= read -r entry_line; do
    [ -n "$entry_line" ] || continue
    id="$(printf '%s\n' "$entry_line" | awk -F '\t' '{print $1}')"
    mode="$(printf '%s\n' "$entry_line" | awk -F '\t' '{print $4}')"
    feature="$(printf '%s\n' "$entry_line" | awk -F '\t' '{print $5}')"
    case "$mode" in
      lite|full|deep) ;;
      *) findings_json="$(epic_add_finding "$findings_json" "invalid_mode" "invalid mode for $id: $mode" "$id" "Mode")" ;;
    esac
    if [ -n "$feature" ] && ! epic_resolve_feature_ref "$feature"; then
      sdd_warn "$id $(epic_feature_missing_message "$feature")"
      warnings_json="$(printf '%s\n' "$warnings_json" | jq -c --arg entry "$id" --arg feature "$feature" '. + [{type:"dangling_feature", entry:$entry, feature:$feature}]')"
    fi
  done < <(sdd_epic_iter_entries "$file")

  graph_json="$(sdd_epic_graph_json "$file")"
  findings_json="$(jq -nc --argjson findings "$findings_json" --argjson graph "$graph_json" '$findings + ($graph.problems // [])')"
  data_json="$(jq -nc --arg file "$file" --argjson findings "$findings_json" --argjson graph "$graph_json" '{file:$file, findings:$findings, graph:$graph}')"

  if [ "$(printf '%s\n' "$findings_json" | jq -r 'length')" -gt 0 ]; then
    if sdd_is_json_mode; then
      sdd_emit_json_selection "$(sdd_json_error "epic" "precondition" "EPIC.md validation failed" "$data_json" "" "none" "" "$warnings_json" | jq --argjson data "$data_json" '. + {data:$data}')"
    else
      printf '%s\n' "$findings_json" | jq -r '.[] | "Error [precondition]: \(.message)"' >&2
    fi
    exit "$SDD_EXIT_PRECONDITION"
  fi

  if sdd_is_json_mode; then
    sdd_emit_json_selection "$(sdd_json_success "epic" "" "none" "" "$data_json" '{}' "$warnings_json")"
    return 0
  fi

  echo "EPIC.md OK: $file"
}

epic_refresh_state_if_needed() {
  local mode="${1:-if-needed}" epic_file state_file refresh_args
  epic_file="$(sdd_epic_file)"
  state_file="$SDD_FEATURE_ROOT/.epic-state.json"
  [ -f "$epic_file" ] || sdd_fail "epic" "not_found" "$epic_file not found; run 'sdd epic init' first" "{\"file\":\"$epic_file\"}"
  if [ "$mode" = "current" ]; then
    refresh_args="--current"
  else
    refresh_args=""
  fi
  if [ "$mode" = "current" ] || [ ! -f "$state_file" ] || [ "$epic_file" -nt "$state_file" ]; then
    bash "$SCRIPT_DIR/sdd-epic-refresh.sh" $refresh_args >/dev/null 2>&1 || true
  fi
  [ -f "$state_file" ] || sdd_fail "epic" "internal" "failed to build epic state cache" "{\"file\":\"$state_file\"}"
}

cmd_status() {
  local state_file data_json group row_count
  epic_refresh_state_if_needed current
  state_file="$SDD_FEATURE_ROOT/.epic-state.json"

  data_json="$(jq -c '{epic:.epic, entries:.entries, counts:.counts, groups:.groups, generated_at:.generated_at}' "$state_file")"
  if sdd_is_json_mode; then
    sdd_emit_json_selection "$(sdd_json_success "epic" "" "none" "" "$data_json" '{}' '[]')"
    return 0
  fi

  row_count="$(jq -r '.entries | length' "$state_file")"
  echo "Epic: $(jq -r '.epic.title // "Epic"' "$state_file")"
  if [ "$row_count" -eq 0 ]; then
    echo "No entries."
    return 0
  fi

  while IFS= read -r group; do
    [ -n "$group" ] || continue
    echo ""
    echo "## $group"
    echo "ID | Status | Feature | Updated"
    echo "-- | ------ | ------- | -------"
    jq -r --arg group "$group" '
      .entries[]
      | select(.group == $group)
      | [.id, .status, (.feature // ""), (.updated // "")]
      | @tsv
    ' "$state_file" | awk -F '\t' '{
      feature = ($3 == "" ? "-" : $3)
      updated = ($4 == "" ? "-" : $4)
      printf "%s | %s | %s | %s\n", $1, $2, feature, updated
    }'
  done < <(jq -r '.groups[].group' "$state_file")
}

case "$cmd" in
  init)
    cmd_init
    ;;
  add)
    cmd_add
    ;;
  check)
    cmd_check
    ;;
  status)
    cmd_status
    ;;
  scaffold)
    cmd_scaffold
    ;;
  link)
    cmd_link
    ;;
  help)
    show_help
    ;;
  *)
    sdd_usage_error "epic" "sdd epic {init|check|add|status|scaffold|link} [args]" "unknown epic command '$cmd'"
    ;;
esac
