#!/usr/bin/env bash
# sdd-setup.sh — Bootstrap SDD into a project directory (standalone installation)
# Usage: sdd setup [--dry-run] [--force] [--install-shim] [--canonical <path>] [--format text|json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"
sdd_parse_common_args "$@" || sdd_usage_error "setup" "sdd setup [--dry-run] [--force]" "invalid shared CLI flags"

# --- Parse setup-specific flags ---------------------------------------------------

DRY_RUN=0
FORCE=0
INSTALL_SHIM=0
OPT_CANONICAL=""
SETUP_ARGS=()
PHASE_SKILL_NAMES=(sdd-brief sdd-spec sdd-research sdd-plan sdd-implement sdd-review sdd-close)
idx=0
while [ "$idx" -lt "${#SDD_ARGS[@]}" ]; do
  arg="${SDD_ARGS[$idx]}"
  case "$arg" in
    --dry-run)      DRY_RUN=1 ;;
    --force)        FORCE=1 ;;
    --install-shim) INSTALL_SHIM=1 ;;
    --canonical)
      idx=$((idx + 1))
      [ "$idx" -lt "${#SDD_ARGS[@]}" ] || sdd_usage_error "setup" "sdd setup [--dry-run] [--force] [--install-shim] [--canonical <path>]" "missing value for --canonical"
      OPT_CANONICAL="${SDD_ARGS[$idx]}"
      ;;
    *)              SETUP_ARGS+=("$arg") ;;
  esac
  idx=$((idx + 1))
done
[ "${#SETUP_ARGS[@]}" -eq 0 ] || sdd_usage_error "setup" "sdd setup [--dry-run] [--force] [--install-shim] [--canonical <path>]" "unexpected argument '${SETUP_ARGS[0]}'"

# --- Help -------------------------------------------------------------------------

sdd_setup_skill_tree_summary() {
  local items=(spec-driven-development sdd-help sdd-setup "${PHASE_SKILL_NAMES[@]}")
  local IFS=,
  printf '.claude/skills/{%s}/' "${items[*]}"
}

sdd_phase_skill_dir_summary() {
  local IFS=,
  printf '.claude/skills/{%s}/' "${PHASE_SKILL_NAMES[*]}"
}

show_help() {
  if sdd_is_json_mode; then
    sdd_help_json \
      "setup" \
      "Bootstrap SDD into the current project. Copies agents, skill, hooks, and CLAUDE.md instructions for a standalone installation." \
      "sdd setup [--dry-run] [--force] [--install-shim] [--canonical <path>] [--format text|json]" \
      "$(jq -nc '[
        {"flag":"--dry-run","description":"Show what would happen without writing files"},
        {"flag":"--force","description":"Overwrite user-modified files without backup"},
        {"flag":"--install-shim","description":"Install an opt-in user PATH shim that resolves the nearest project .claude/bin/sdd"},
        {"flag":"--canonical <path>","description":"Use an explicit canonical SDD plugin root when recovering a partial consumer copy"}
      ] + '"$(sdd_common_flags_json)"'')" \
      '[]' \
      '[
        "sdd setup",
        "sdd setup --install-shim",
        "sdd setup --dry-run",
        "sdd setup --force",
        "sdd setup --json"
      ]'
    return 0
  fi

  echo "Usage: sdd setup [--dry-run] [--force] [--install-shim] [--canonical <path>]"
  echo ""
  echo "Bootstrap SDD into the current project (standalone installation)."
  echo ""
  echo "What it does:"
  echo "  1. Copy 6 agent definitions   → .claude/agents/sdd-*.md"
  echo "  2. Copy skill trees           → $(sdd_setup_skill_tree_summary)"
  echo "  3. Create CLI entry point     → .claude/bin/sdd"
  echo "  4. Add SDD instructions       → CLAUDE.md"
  echo "  5. Register lifecycle hooks   → .claude/settings.json"
  echo "  6. Create feature directory   → .features/"
  echo "  7. Write install manifest     → .claude/.sdd-manifest.json"
  echo ""
  echo "Flags:"
  echo "  --dry-run   Show what would happen without writing files"
  echo "  --force     Overwrite user-modified files without backup"
  echo "  --install-shim"
  echo "              Install a user PATH shim that resolves the nearest project .claude/bin/sdd"
  echo "  --canonical <path>"
  echo "              Use an explicit canonical SDD plugin root when recovering a partial consumer copy"
  echo ""
  echo "Safe to run multiple times — idempotent with upgrade detection."
}

[ "$SDD_HELP" = "1" ] && { show_help; exit 0; }

# --- Resolve paths ----------------------------------------------------------------

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

PLUGIN_ROOT=""
declare -a PLUGIN_ROOT_CANDIDATES=()
add_plugin_candidate() {
  local candidate="$1"
  [ -n "$candidate" ] || return 0
  PLUGIN_ROOT_CANDIDATES+=("$candidate")
}

add_plugin_candidate "$OPT_CANONICAL"
add_plugin_candidate "${CLAUDE_PLUGIN_ROOT:-}"
if git_root="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  add_plugin_candidate "$git_root/sdd-plugin"
fi

for candidate in "${PLUGIN_ROOT_CANDIDATES[@]+"${PLUGIN_ROOT_CANDIDATES[@]}"}"; do
  [ -n "$candidate" ] || continue
  if [ -d "$candidate/skills/spec-driven-development/agents" ]; then
    PLUGIN_ROOT="$(cd "$candidate" && pwd)"
    break
  fi
done

SKILL_SRC="$PLUGIN_ROOT/skills/spec-driven-development"
AGENT_SRC="$SKILL_SRC/agents"
HELP_SKILL_SRC="$PLUGIN_ROOT/skills/sdd-help"
SETUP_SKILL_SRC="$PLUGIN_ROOT/skills/sdd-setup"
HOOKS_SRC="$PLUGIN_ROOT/hooks/hooks.json"
PLUGIN_JSON="$PLUGIN_ROOT/.claude-plugin/plugin.json"

# --- Guards -----------------------------------------------------------------------

if [ ! -d "$AGENT_SRC" ]; then
  tried_paths="$(printf '%s\n' "${PLUGIN_ROOT_CANDIDATES[@]+"${PLUGIN_ROOT_CANDIDATES[@]}"}" | awk 'NF { printf "  - %s/skills/spec-driven-development/agents\n", $0 }')"
  [ -n "$tried_paths" ] || tried_paths="  - <none>"
  tried_json="$(printf '%s\n' "${PLUGIN_ROOT_CANDIDATES[@]+"${PLUGIN_ROOT_CANDIDATES[@]}"}" | jq -Rsc 'split("\n") | map(select(. != ""))')"
  details_json="$(jq -nc --argjson tried "$tried_json" '{tried: $tried}')"
  sdd_fail "setup" "precondition" \
    "cannot locate canonical SDD agent sources.
Tried:
$tried_paths

Recovery: from a maintainer repo, launch Claude with \`claude --plugin-dir ./sdd-plugin\` or rerun setup with \`--canonical /path/to/sdd-plugin\`. Marketplace users should rerun from the installed SDD plugin." \
    "$details_json" "" "none"
fi

[ -f "$HOOKS_SRC" ] || sdd_fail "setup" "internal" \
  "cannot locate hooks.json at $HOOKS_SRC" \
  "{}" "" "none"

command -v jq >/dev/null 2>&1 || sdd_fail "setup" "precondition" \
  "jq is required but not found — install via: brew install jq" \
  "{}" "" "none"

# --- Read version -----------------------------------------------------------------

SDD_VERSION="unknown"
if [ -f "$PLUGIN_JSON" ]; then
  SDD_VERSION="$(jq -r '.version // "unknown"' "$PLUGIN_JSON" 2>/dev/null)" || SDD_VERSION="unknown"
fi

# --- Result tracking --------------------------------------------------------------

declare -a RESULT_AGENTS=()
declare -a RESULT_HOOKS=()
RESULT_SKILL="skipped"
RESULT_HELP_SKILL="skipped"
RESULT_SETUP_SKILL="skipped"
RESULT_PHASE_SKILLS=()
RESULT_CLI="skipped"
RESULT_USER_SHIM="skipped"
RESULT_CLAUDE_MD="skipped"
RESULT_FEATURES="skipped"
RESULT_GITIGNORE="skipped"
RESULT_INDEX="skipped"
RESULT_MANIFEST="skipped"
RESULT_PATCHES=()
RUN_BACKUP_DIR=""

# --- Placeholder functions (implemented in subsequent tasks) ----------------------

_sdd_backup_dir() {
  if [ -z "$RUN_BACKUP_DIR" ]; then
    RUN_BACKUP_DIR="$PROJECT_DIR/.sdd-local-patches/$(date -u +%Y-%m-%dT%H%M%SZ)"
  fi
  printf '%s\n' "$RUN_BACKUP_DIR"
}

setup_agents() {
  local target_dir="$PROJECT_DIR/.claude/agents"
  if [ "$DRY_RUN" = "1" ]; then
    for src_file in "$AGENT_SRC"/sdd-*.md; do
      [ -f "$src_file" ] || continue
      local agent_name
      agent_name="$(basename "$src_file")"
      RESULT_AGENTS+=("${agent_name}:would-create")
    done
    return 0
  fi
  mkdir -p "$target_dir"
  for src_file in "$AGENT_SRC"/sdd-*.md; do
    [ -f "$src_file" ] || continue
    local agent_name
    agent_name="$(basename "$src_file")"
    cp "$src_file" "$target_dir/$agent_name"
    RESULT_AGENTS+=("${agent_name}:created")
  done
}

setup_skill() {
  local target_skill_dir="$PROJECT_DIR/.claude/skills/spec-driven-development"
  local stage_dir="${target_skill_dir}.staging.$$"

  if [ "$DRY_RUN" = "1" ]; then
    RESULT_SKILL="would-install"
    return 0
  fi

  rm -rf "$stage_dir" 2>/dev/null || true
  mkdir -p "$(dirname "$target_skill_dir")" "$stage_dir"
  # shellcheck disable=SC2064 # Capture this function-local staging path for EXIT cleanup.
  trap "rm -rf '$stage_dir' 2>/dev/null || true" EXIT

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --checksum --exclude 'agents/' --exclude 'evals/' --exclude 'sdd-eval-workspace/' --exclude 'scripts/tests/' "$SKILL_SRC/" "$stage_dir/"
  else
    cp -a "$SKILL_SRC/." "$stage_dir/"
    rm -rf "$stage_dir/agents" "$stage_dir/evals" "$stage_dir/sdd-eval-workspace" "$stage_dir/scripts/tests" 2>/dev/null || true
  fi

  [ -f "$stage_dir/SKILL.md" ] || sdd_fail "setup" "internal" \
    "staged spec-driven-development skill is missing SKILL.md at $stage_dir" \
    "{}" "" "none"

  find "$stage_dir/scripts" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
  sdd_safe_replace_dir "$target_skill_dir" "$stage_dir"
  trap - EXIT

  RESULT_SKILL="installed"
}

setup_help_skill() {
  local target_help_dir="$PROJECT_DIR/.claude/skills/sdd-help"
  local stage_dir="${target_help_dir}.staging.$$"

  if [ ! -d "$HELP_SKILL_SRC" ] || [ ! -f "$HELP_SKILL_SRC/SKILL.md" ]; then
    RESULT_HELP_SKILL="source-missing"
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    RESULT_HELP_SKILL="would-install"
    return 0
  fi

  rm -rf "$stage_dir" 2>/dev/null || true
  mkdir -p "$(dirname "$target_help_dir")" "$stage_dir"
  # shellcheck disable=SC2064 # Capture this function-local staging path for EXIT cleanup.
  trap "rm -rf '$stage_dir' 2>/dev/null || true" EXIT

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --checksum "$HELP_SKILL_SRC/" "$stage_dir/"
  else
    cp -a "$HELP_SKILL_SRC/." "$stage_dir/"
  fi

  [ -f "$stage_dir/SKILL.md" ] || sdd_fail "setup" "internal" \
    "staged sdd-help skill is missing SKILL.md at $stage_dir" \
    "{}" "" "none"

  sdd_safe_replace_dir "$target_help_dir" "$stage_dir"
  trap - EXIT

  RESULT_HELP_SKILL="installed"
}

setup_setup_skill() {
  local target_setup_dir="$PROJECT_DIR/.claude/skills/sdd-setup"
  local stage_dir="${target_setup_dir}.staging.$$"

  if [ ! -d "$SETUP_SKILL_SRC" ] || [ ! -f "$SETUP_SKILL_SRC/SKILL.md" ]; then
    RESULT_SETUP_SKILL="source-missing"
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    RESULT_SETUP_SKILL="would-install"
    return 0
  fi

  rm -rf "$stage_dir" 2>/dev/null || true
  mkdir -p "$(dirname "$target_setup_dir")" "$stage_dir"
  # shellcheck disable=SC2064 # Capture this function-local staging path for EXIT cleanup.
  trap "rm -rf '$stage_dir' 2>/dev/null || true" EXIT

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --checksum "$SETUP_SKILL_SRC/" "$stage_dir/"
  else
    cp -a "$SETUP_SKILL_SRC/." "$stage_dir/"
  fi

  [ -f "$stage_dir/SKILL.md" ] || sdd_fail "setup" "internal" \
    "staged sdd-setup skill is missing SKILL.md at $stage_dir" \
    "{}" "" "none"

  sdd_safe_replace_dir "$target_setup_dir" "$stage_dir"
  trap - EXIT

  RESULT_SETUP_SKILL="installed"
}

setup_phase_skills() {
  local skill_name source_dir target_dir stage_dir

  for skill_name in "${PHASE_SKILL_NAMES[@]}"; do
    source_dir="$PLUGIN_ROOT/skills/$skill_name"
    target_dir="$PROJECT_DIR/.claude/skills/$skill_name"
    stage_dir="${target_dir}.staging.$$"

    if [ ! -d "$source_dir" ] || [ ! -f "$source_dir/SKILL.md" ]; then
      RESULT_PHASE_SKILLS+=("${skill_name}:source-missing")
      continue
    fi

    if [ "$DRY_RUN" = "1" ]; then
      RESULT_PHASE_SKILLS+=("${skill_name}:would-install")
      continue
    fi

    rm -rf "$stage_dir" 2>/dev/null || true
    mkdir -p "$(dirname "$target_dir")" "$stage_dir"
    # shellcheck disable=SC2064 # Capture this function-local staging path for EXIT cleanup.
    trap "rm -rf '$stage_dir' 2>/dev/null || true" EXIT

    if command -v rsync >/dev/null 2>&1; then
      rsync -a --checksum "$source_dir/" "$stage_dir/"
    else
      cp -a "$source_dir/." "$stage_dir/"
    fi

    [ -f "$stage_dir/SKILL.md" ] || sdd_fail "setup" "internal" \
      "staged $skill_name skill is missing SKILL.md at $stage_dir" \
      "{}" "" "none"

    sdd_safe_replace_dir "$target_dir" "$stage_dir"
    trap - EXIT

    RESULT_PHASE_SKILLS+=("${skill_name}:installed")
  done
}

setup_cli() {
  local bin_dir="$PROJECT_DIR/.claude/bin"
  local shim_path="$bin_dir/sdd"

  if [ "$DRY_RUN" = "1" ]; then
    RESULT_CLI="would-install"
    return 0
  fi

  mkdir -p "$bin_dir"

  cat > "$shim_path" << 'SHIM'
#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$PROJECT_ROOT/.claude}"
exec bash "$PLUGIN_ROOT/skills/spec-driven-development/scripts/sdd.sh" "$@"
SHIM

  chmod +x "$shim_path"
  RESULT_CLI="installed"
}

install_user_shim() {
  local target_dir shim_path

  if [ -d "$HOME/.local/bin" ]; then
    target_dir="$HOME/.local/bin"
  elif [ -d "$HOME/bin" ]; then
    target_dir="$HOME/bin"
  else
    target_dir="$HOME/.local/bin"
  fi
  shim_path="$target_dir/sdd"

  if [ "$DRY_RUN" = "1" ]; then
    RESULT_USER_SHIM="would-install:$shim_path"
    return 0
  fi

  mkdir -p "$target_dir"
  if [ -e "$shim_path" ] && [ "$FORCE" != "1" ]; then
    sdd_fail "setup" "conflict" \
      "user shim already exists at $shim_path; rerun with --force to overwrite" \
      "{}" "" "none"
  fi

  cat > "$shim_path" <<'SHIM'
#!/usr/bin/env bash
set -euo pipefail
dir="$PWD"
while [ "$dir" != "/" ]; do
  if [ -x "$dir/.claude/bin/sdd" ]; then
    exec bash "$dir/.claude/bin/sdd" "$@"
  fi
  dir="$(dirname "$dir")"
done
echo "sdd: no SDD project found (expected .claude/bin/sdd in this directory or a parent)" >&2
exit 3
SHIM

  chmod +x "$shim_path"
  RESULT_USER_SHIM="installed:$shim_path"
}

setup_claude_md() {
  local claude_md="$PROJECT_DIR/CLAUDE.md"
  local end_marker="<!-- sdd-setup:end -->"
  local block
  block="$(cat <<'SDD_BLOCK'
<!-- sdd-setup:begin sdd-setup-version:4 -->
## Spec-Driven Development

This project uses SDD, a 7-phase artifact-first workflow.
`WHY -> WHAT -> WHERE -> HOW -> DO -> VERIFY -> DONE`

**Before any feature work:**
1. Run `sdd status` to check active features and phases
2. Run `sdd init <name> [--mode lite|normal|deep]` to start a feature with the right profile (`default` and `full` are accepted synonyms for `normal`)
3. Follow the phase gates: Brief → Design → Research → Plan → Implement → Review → Close

**Key commands:**
- `sdd status` — current feature dashboard
- `sdd init <name> [--mode lite|normal|deep]` — create normal/deep features or lite fixes
- `sdd task list <feature>` — pending tasks
- `sdd task start <feature> <T-xxx>` — begin a task
- `sdd task complete <feature> <T-xxx>` — finish a task
- `sdd autonomy {on|off|status}` — manage per-feature autonomous execution
- `sdd customize init` — scaffold project-level SDD guidance
- `sdd epic init` — coordinate multi-feature initiatives; details live in `references/epic.md`
- `sdd advise <artifact> <feature>` — run the rubric advisor on demand
- `sdd handoff` — session handoff summary

**Behavioral core:**
- Surface ambiguity before choosing an interpretation.
- Read files before making claims about the codebase.
- Prefer the smallest viable change that solves the current task.
- Keep edits surgical and avoid drive-by cleanup.
- Treat done as verified evidence, not asserted completion.
- If a command fails or a precondition blocks you, inspect the evidence before retrying.

**Artifact chain:** `.features/<id>/brief.md → spec.md → research.md → plan.md → tasks.md → review.md`

Do not write production code until `tasks.md` is populated. Do not close without review passing.

**5th Non-Negotiable Boundary:** non-trivial work needs independent review before close; implementer self-review is not enough.

**Backup path:** user-edit backups land at `<project>/.sdd-local-patches/<UTC-ts>/`. Older installs may have backups under `.claude/.sdd-local-patches/`; those remain in place — setup never moves or removes them.

**Meta-development of the SDD plugin itself:** when editing files under `sdd-plugin/`, launch Claude with `claude --plugin-dir ./sdd-plugin`. This routes hooks through canonical source — without it, hooks run from the consumer copy at `.claude/skills/spec-driven-development/` and will not see your edits until `sdd setup` is re-run.
<!-- sdd-setup:end -->
SDD_BLOCK
)"

  if [ ! -f "$claude_md" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      RESULT_CLAUDE_MD="would-create"
      return 0
    fi
    printf '%s\n' "$block" > "$claude_md"
    RESULT_CLAUDE_MD="created"
    return 0
  fi

  if ! grep -q "<!-- sdd-setup:begin sdd-setup-version:" "$claude_md"; then
    if [ "$DRY_RUN" = "1" ]; then
      RESULT_CLAUDE_MD="would-append"
      return 0
    fi
    printf '\n%s\n' "$block" >> "$claude_md"
    RESULT_CLAUDE_MD="appended"
    return 0
  fi

  local existing_version
  existing_version="$(grep -m1 'sdd-setup:begin' "$claude_md" | grep -o 'sdd-setup-version:[0-9]*' | cut -d: -f2)" || existing_version=""
  local current_version="3"

  if [ "$existing_version" = "$current_version" ]; then
    RESULT_CLAUDE_MD="unchanged"
    return 0
  fi

  if [ "$DRY_RUN" = "1" ]; then
    RESULT_CLAUDE_MD="would-replace"
    return 0
  fi

  local tmp block_file
  tmp="$(mktemp)"
  block_file="$(mktemp)"
  printf '%s\n' "$block" > "$block_file"
  awk -v end_marker="$end_marker" -v block_file="$block_file" '
    BEGIN { in_block=0 }
    /^<!-- sdd-setup:begin sdd-setup-version:/ {
      in_block=1
      while ((getline line < block_file) > 0) { print line }
      close(block_file)
      next
    }
    in_block && $0 == end_marker { in_block=0; next }
    in_block { next }
    { print }
  ' "$claude_md" > "$tmp"
  rm -f "$block_file"
  mv "$tmp" "$claude_md"
  RESULT_CLAUDE_MD="replaced"
}

setup_hooks() {
  local settings_file="$PROJECT_DIR/.claude/settings.json"
  local settings_dir
  settings_dir="$(dirname "$settings_file")"

  # Read and path-rewrite the source hooks (command fields only)
  local transformed_hooks
  transformed_hooks="$(jq '.hooks | walk(
    if type == "object" and has("command")
    then .command |= gsub("\"\\$\\{CLAUDE_PLUGIN_ROOT\\}\""; "\"${CLAUDE_PROJECT_DIR}\"/.claude")
    else .
    end
  )' "$HOOKS_SRC")"

  # Load existing settings.json or start fresh
  local existing_settings
  if [ -f "$settings_file" ]; then
    if ! existing_settings="$(jq -e '.' "$settings_file" 2>/dev/null)"; then
      echo "WARNING: $settings_file exists but is not valid JSON — skipping hook registration" >&2
      return 0
    fi
    # Ensure .hooks key exists
    existing_settings="$(printf '%s\n' "$existing_settings" | jq '. + {hooks: (.hooks // {})}')"
  else
    existing_settings='{"hooks":{}}'
  fi

  # Prune SDD-owned hooks before merging so stale partial blocks are refreshed.
  local sdd_skill_prefix sdd_help_prefix sdd_skill_alt_prefix sdd_help_alt_prefix
  sdd_skill_prefix='bash "${CLAUDE_PROJECT_DIR}"/.claude/skills/spec-driven-development/'
  sdd_help_prefix='bash "${CLAUDE_PROJECT_DIR}"/.claude/skills/sdd-help/'
  sdd_skill_alt_prefix='bash "${CLAUDE_PROJECT_DIR}/.claude"/skills/spec-driven-development/'
  sdd_help_alt_prefix='bash "${CLAUDE_PROJECT_DIR}/.claude"/skills/sdd-help/'
  existing_settings="$(printf '%s\n' "$existing_settings" | jq \
    --arg skill_prefix "$sdd_skill_prefix" \
    --arg help_prefix "$sdd_help_prefix" \
    --arg skill_alt_prefix "$sdd_skill_alt_prefix" \
    --arg help_alt_prefix "$sdd_help_alt_prefix" \
    '
      def normalize_project_dir:
        gsub("\\$CLAUDE_PROJECT_DIR"; "${CLAUDE_PROJECT_DIR}");

      def sdd_owned:
        ((.command? // "") | normalize_project_dir) as $cmd |
        ($cmd | startswith($skill_prefix)) or
        ($cmd | startswith($help_prefix)) or
        ($cmd | startswith($skill_alt_prefix)) or
        ($cmd | startswith($help_alt_prefix));

      .hooks |= with_entries(
        .value = (
          (.value // [])
          | map(.hooks = ((.hooks // []) | map(select(sdd_owned | not))))
          | map(select((.hooks // []) | length > 0))
        )
      )
    ')"

  # For each event in the transformed source hooks, process each matcher group
  local events
  events="$(printf '%s\n' "$transformed_hooks" | jq -r 'keys[]')"

  local merged_settings="$existing_settings"

  while IFS= read -r event; do
    [ -n "$event" ] || continue

    # Get newline-separated compact JSON for each matcher group in this event
    local src_groups
    src_groups="$(printf '%s\n' "$transformed_hooks" | jq -c --arg ev "$event" '.[$ev][]')"

    while IFS= read -r group; do
      [ -n "$group" ] || continue

      # Extract a human-readable label plus an exact group signature. Multiple
      # matcher groups can legitimately share the same command script.
      local identity group_signature
      identity="$(printf '%s\n' "$group" | jq -r '
        ((.matcher // "*") + "/" + (
          ([ .hooks[]? | select(has("command")) | .command | split("/") | last | ltrimstr("\"") ] | first) //
          ([ .hooks[]? | select(has("if")) | .["if"] ] | first) //
          "group"
        ))
      ' 2>/dev/null)" || identity=""
      group_signature="$(printf '%s\n' "$group" | jq -c '
        def normalize_project_dir:
          gsub("\\$CLAUDE_PROJECT_DIR"; "${CLAUDE_PROJECT_DIR}");

        {
          matcher: (.matcher // ""),
          hooks: [
            .hooks[]? | {
              type: (.type // ""),
              command: ((.command // "") | normalize_project_dir),
              if: (.if // ""),
              statusMessage: (.statusMessage // ""),
              timeout: (.timeout // null),
              async: (.async // null),
              shell: (.shell // "")
            }
          ]
        }
      ' 2>/dev/null)" || group_signature=""

      if [ -z "$group_signature" ]; then
        group_signature="$(printf '%s\n' "$group" | jq -c '{matcher: (.matcher // ""), hooks: (.hooks // [])}')"
      fi

      [ -n "$identity" ] || identity="$(printf '%s\n' "$group" | jq -r '
        (.matcher // "*") + "/" + (
          ([ .hooks[]? | select(has("if")) | .["if"] ] | first) //
          empty
        )
      ' 2>/dev/null)" || identity=""

      # Check if this group already exists in the target event
      local already_exists="0"
      if [ -n "$group_signature" ]; then
        already_exists="$(printf '%s\n' "$merged_settings" | jq -r \
          --arg ev "$event" \
          --argjson signature "$group_signature" \
          'def normalize_project_dir:
             gsub("\\$CLAUDE_PROJECT_DIR"; "${CLAUDE_PROJECT_DIR}");

           (.hooks[$ev] // []) |
           any(.[]; (
             {
               matcher: (.matcher // ""),
               hooks: [
                 .hooks[]? | {
                   type: (.type // ""),
                   command: ((.command // "") | normalize_project_dir),
                   if: (.if // ""),
                   statusMessage: (.statusMessage // ""),
                   timeout: (.timeout // null),
                   async: (.async // null),
                   shell: (.shell // "")
                 }
               ]
             } == $signature
           )
           ) | if . then "1" else "0" end'
        )"
      fi

      if [ "$already_exists" = "1" ]; then
        RESULT_HOOKS+=("${event}/${identity}:unchanged")
      else
        if [ "$DRY_RUN" = "1" ]; then
          RESULT_HOOKS+=("${event}:would-add")
        else
          merged_settings="$(printf '%s\n' "$merged_settings" | jq \
            --arg ev "$event" \
            --argjson grp "$group" \
            '.hooks[$ev] = ((.hooks[$ev] // []) + [$grp])'
          )"
          RESULT_HOOKS+=("${event}:added")
        fi
      fi
    done <<< "$src_groups"
  done <<< "$events"

  # Write atomically (only when not dry-run)
  if [ "$DRY_RUN" = "0" ]; then
    mkdir -p "$settings_dir"
    local tmp
    tmp="$(sdd_tmp_for_target "$settings_file")"
    sdd_cleanup_push "$tmp"
    printf '%s\n' "$merged_settings" > "$tmp"
    sdd_atomic_replace "$tmp" "$settings_file"
  fi
}

setup_features_dir() {
  local features_dir="$PROJECT_DIR/.features"

  if [ "$DRY_RUN" = "1" ]; then
    RESULT_FEATURES="would-create"
    return 0
  fi

  if [ -d "$features_dir" ]; then
    RESULT_FEATURES="unchanged"
  else
    mkdir -p "$features_dir"
    RESULT_FEATURES="created"
  fi
}

setup_gitignore() {
  local gitignore="$PROJECT_DIR/.gitignore"
  local entries=(
    ".features/.active.log"
    ".features/*/customization.yaml"
    ".features/**/customization.yaml"
    ".features/.epic-state.json"
    ".features/*/changes.log"
    ".features/**/changes.log"
    ".features/*/summary.md"
    ".features/**/summary.md"
    ".features/*/summary-compact.md"
    ".features/**/summary-compact.md"
  )
  local missing=()
  local entry

  if [ -f "$gitignore" ]; then
    for entry in "${entries[@]}"; do
      if ! grep -qxF "$entry" "$gitignore"; then
        missing+=("$entry")
      fi
    done
    if [ "${#missing[@]}" -eq 0 ]; then
      RESULT_GITIGNORE="unchanged"
      return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
      RESULT_GITIGNORE="would-update"
      return 0
    fi
  else
    missing=("${entries[@]}")
    if [ "$DRY_RUN" = "1" ]; then
      RESULT_GITIGNORE="would-create"
      return 0
    fi
    mkdir -p "$(dirname "$gitignore")"
    : > "$gitignore"
  fi

  if [ -s "$gitignore" ] && [ -n "$(tail -c 1 "$gitignore" 2>/dev/null)" ]; then
    printf '\n' >> "$gitignore"
  fi
  for entry in "${missing[@]}"; do
    printf '%s\n' "$entry" >> "$gitignore"
  done

  if [ "${#missing[@]}" -eq "${#entries[@]}" ]; then
    RESULT_GITIGNORE="created"
  else
    RESULT_GITIGNORE="updated"
  fi
}

rebuild_features_index() {
  if [ "$DRY_RUN" = "1" ]; then
    RESULT_INDEX="would-rebuild"
    return 0
  fi

  if [ ! -f "$SKILL_SRC/scripts/sdd-index.sh" ]; then
    RESULT_INDEX="source-missing"
    return 0
  fi

  local output status
  set +e
  output="$(CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$SKILL_SRC/scripts/sdd-index.sh" rebuild --quiet 2>&1)"
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    RESULT_INDEX="rebuilt"
  elif ! find "$PROJECT_DIR/.features" -maxdepth 1 -type d -name '[0-9][0-9][0-9][0-9]-*' -print -quit 2>/dev/null | grep -q .; then
    local index_file updated_date tmp
    index_file="$PROJECT_DIR/.features/INDEX.md"
    updated_date="$(date +%Y-%m-%d)"
    tmp="$(sdd_tmp_for_target "$index_file")"
    sdd_cleanup_push "$tmp"
    cat > "$tmp" <<EOF
# Feature Index

> Auto-generated by \`sdd index rebuild\` on $updated_date. DO NOT EDIT.

**0 features** | 0 closed | 0 open | Updated: $updated_date

## Overview

| # | Feature | Phase | Tasks | Updated |
|---|---------|-------|-------|---------|

## Features

EOF
    sdd_atomic_replace "$tmp" "$index_file"
    RESULT_INDEX="rebuilt"
  else
    RESULT_INDEX="error:$status"
    echo "WARNING: sdd index rebuild failed during setup: $output" >&2
  fi
}

write_manifest() {
  if [ "$DRY_RUN" = "1" ]; then
    RESULT_MANIFEST="would-write"
    return 0
  fi

  local files_json="{}"
  local file hash rel_path skill_name

  while IFS= read -r file; do
    [ -f "$file" ] || continue
    hash="$(sdd_file_sha256 "$file")" || continue
    rel_path="${file#"$PROJECT_DIR"/}"
    files_json="$(printf '%s' "$files_json" | jq --arg k "$rel_path" --arg v "$hash" '. + {($k): $v}')"
  done < <(
    find "$PROJECT_DIR/.claude/agents" -name 'sdd-*.md' -type f 2>/dev/null
    find "$PROJECT_DIR/.claude/skills/spec-driven-development" -type f 2>/dev/null
    find "$PROJECT_DIR/.claude/skills/sdd-help" -type f 2>/dev/null
    find "$PROJECT_DIR/.claude/skills/sdd-setup" -type f 2>/dev/null
    for skill_name in "${PHASE_SKILL_NAMES[@]}"; do
      find "$PROJECT_DIR/.claude/skills/$skill_name" -type f 2>/dev/null
    done
    echo "$PROJECT_DIR/.claude/bin/sdd"
  )

  local manifest_path="$PROJECT_DIR/.claude/.sdd-manifest.json"
  local version_path="$PROJECT_DIR/.claude/.sdd-version"

  local manifest
  manifest="$(jq -n \
    --arg ver "$SDD_VERSION" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson files "$files_json" \
    '{manifest_version: 2, version: $ver, timestamp: $ts, files: $files}')"

  local tmp
  tmp="$(sdd_tmp_for_target "$manifest_path")"
  sdd_cleanup_push "$tmp"
  printf '%s\n' "$manifest" > "$tmp"
  sdd_atomic_replace "$tmp" "$manifest_path"

  printf '%s\n' "$SDD_VERSION" > "$version_path"

  RESULT_MANIFEST="written"
}

check_manifest() {
  local manifest_path="$PROJECT_DIR/.claude/.sdd-manifest.json"
  [ -f "$manifest_path" ] || return 0

  while IFS=$'\t' read -r rel_path manifest_hash; do
    [ -n "$rel_path" ] || continue
    local full_path="$PROJECT_DIR/$rel_path"
    [ -f "$full_path" ] || continue

    local current_hash
    current_hash="$(sdd_file_sha256 "$full_path")" || continue

    if [ "$current_hash" != "$manifest_hash" ]; then
      if [ "$FORCE" = "1" ]; then
        : # overwrite without backup
      elif [ "$DRY_RUN" = "1" ]; then
        RESULT_PATCHES+=("${rel_path}:would-backup")
      else
        local backup_dir
        backup_dir="$(_sdd_backup_dir)"
        local backup_path="$backup_dir/$rel_path"
        mkdir -p "$(dirname "$backup_path")"
        cp "$full_path" "$backup_path"
        RESULT_PATCHES+=("${rel_path}:backed-up")
      fi
    fi
  done < <(jq -r '.files | to_entries[] | "\(.key)\t\(.value)"' "$manifest_path")
}

clean_old_agents() {
  local target_dir="$PROJECT_DIR/.claude/agents"
  [ -d "$target_dir" ] || return 0
  for old_agent in "$target_dir"/sdd-*.md; do
    [ -f "$old_agent" ] || continue
    local agent_name canonical_agent backup_needed rel_path
    agent_name="$(basename "$old_agent")"
    canonical_agent="$AGENT_SRC/$agent_name"
    backup_needed=0

    if [ ! -f "$canonical_agent" ]; then
      backup_needed=1
    else
      local old_hash canonical_hash
      old_hash="$(sdd_file_sha256 "$old_agent")" || old_hash=""
      canonical_hash="$(sdd_file_sha256 "$canonical_agent")" || canonical_hash=""
      [ -n "$old_hash" ] && [ -n "$canonical_hash" ] && [ "$old_hash" = "$canonical_hash" ] || backup_needed=1
    fi

    rel_path="${old_agent#"$PROJECT_DIR"/}"
    if [ "$backup_needed" = "1" ] && [ "$FORCE" != "1" ]; then
      if [ "$DRY_RUN" = "1" ]; then
        RESULT_PATCHES+=("${rel_path}:would-backup")
      else
        local backup_dir backup_path
        backup_dir="$(_sdd_backup_dir)"
        backup_path="$backup_dir/$rel_path"
        mkdir -p "$(dirname "$backup_path")"
        cp "$old_agent" "$backup_path"
        RESULT_PATCHES+=("${rel_path}:backed-up")
      fi
    fi
    if [ "$DRY_RUN" = "1" ]; then
      continue
    fi
    rm -f "$old_agent"
  done
}

# --- Main -------------------------------------------------------------------------

check_manifest
clean_old_agents
setup_agents
setup_skill
setup_help_skill
setup_setup_skill
setup_phase_skills
setup_cli
if [ "$INSTALL_SHIM" = "1" ]; then
  install_user_shim
fi
setup_claude_md
setup_hooks
setup_features_dir
setup_gitignore
write_manifest
rebuild_features_index

# --- Output -----------------------------------------------------------------------

agent_count="${#RESULT_AGENTS[@]}"
hook_count="${#RESULT_HOOKS[@]}"
phase_skill_count="${#RESULT_PHASE_SKILLS[@]}"
phase_skill_summary="$(printf '%s' "${RESULT_PHASE_SKILLS[*]:-skipped}")"
phase_skill_dirs="$(sdd_phase_skill_dir_summary)"

if sdd_is_json_mode; then
  agents_arr="$(printf '%s\n' "${RESULT_AGENTS[@]+"${RESULT_AGENTS[@]}"}" | jq -Rsc 'split("\n") | map(select(. != ""))')"
  hooks_arr="$(printf '%s\n' "${RESULT_HOOKS[@]+"${RESULT_HOOKS[@]}"}" | jq -Rsc 'split("\n") | map(select(. != ""))')"
  phase_skills_arr="$(printf '%s\n' "${RESULT_PHASE_SKILLS[@]+"${RESULT_PHASE_SKILLS[@]}"}" | jq -Rsc 'split("\n") | map(select(. != ""))')"
  sdd_json_success "setup" "" "none" "" \
    "$(jq -nc \
      --arg version "$SDD_VERSION" \
      --argjson dry_run "$DRY_RUN" \
      --argjson agents "$agents_arr" \
      --arg skill "$RESULT_SKILL" \
      --arg help_skill "$RESULT_HELP_SKILL" \
      --arg setup_skill "$RESULT_SETUP_SKILL" \
      --argjson phase_skills "$phase_skills_arr" \
      --arg cli "$RESULT_CLI" \
      --arg user_shim "$RESULT_USER_SHIM" \
      --arg claude_md "$RESULT_CLAUDE_MD" \
      --argjson hooks "$hooks_arr" \
      --arg features "$RESULT_FEATURES" \
      --arg gitignore "$RESULT_GITIGNORE" \
      --arg index "$RESULT_INDEX" \
      --arg manifest "$RESULT_MANIFEST" \
      '{
        version: $version,
        dry_run: ($dry_run == 1),
        agents: $agents,
        skill: $skill,
        help_skill: $help_skill,
        setup_skill: $setup_skill,
        phase_skills: $phase_skills,
        cli: $cli,
        user_shim: $user_shim,
        claude_md: $claude_md,
        hooks: $hooks,
        features: $features,
        gitignore: $gitignore,
        index: $index,
        manifest: $manifest
      }'
    )"
  echo "" >&2
  if [ "$DRY_RUN" = "1" ]; then
    echo "SDD setup dry-run (v${SDD_VERSION}) — no files written" >&2
    echo "  Agents:       ${agent_count} would be installed" >&2
    echo "  Skill:        $RESULT_SKILL" >&2
    echo "  Help skill:   $RESULT_HELP_SKILL" >&2
    echo "  Setup skill:  $RESULT_SETUP_SKILL" >&2
    echo "  Phase skills: ${phase_skill_summary:-skipped}" >&2
    echo "  CLI:          $RESULT_CLI" >&2
    echo "  User shim:    $RESULT_USER_SHIM" >&2
    echo "  CLAUDE.md:    $RESULT_CLAUDE_MD" >&2
    echo "  Hooks:        ${hook_count} events would be registered" >&2
    echo "  .features/:   $RESULT_FEATURES" >&2
    echo "  .gitignore:   $RESULT_GITIGNORE" >&2
    echo "  INDEX.md:     $RESULT_INDEX" >&2
    echo "  Manifest:     $RESULT_MANIFEST" >&2
  else
    echo "SDD setup complete (v${SDD_VERSION})" >&2
    echo "  Agents:       ${agent_count} installed (.claude/agents/sdd-*.md)" >&2
    echo "  Skill:        $RESULT_SKILL → .claude/skills/spec-driven-development/" >&2
    echo "  Help skill:   $RESULT_HELP_SKILL → .claude/skills/sdd-help/" >&2
    echo "  Setup skill:  $RESULT_SETUP_SKILL → .claude/skills/sdd-setup/" >&2
    echo "  Phase skills: ${phase_skill_count} installed (${phase_skill_dirs}) — ${phase_skill_summary:-skipped}" >&2
    echo "  CLI:          $RESULT_CLI → .claude/bin/sdd" >&2
    echo "  User shim:    $RESULT_USER_SHIM" >&2
    echo "  CLAUDE.md:    $RESULT_CLAUDE_MD SDD instructions block" >&2
    echo "  Hooks:        ${hook_count} events registered in .claude/settings.json" >&2
    echo "  .features/:   $RESULT_FEATURES" >&2
    echo "  .gitignore:   $RESULT_GITIGNORE" >&2
    echo "  INDEX.md:     $RESULT_INDEX" >&2
    echo "  Manifest:     .claude/.sdd-manifest.json $RESULT_MANIFEST" >&2
  fi
  echo "" >&2
  echo "Next: run \`sdd init <feature-name> \"description\"\` to start your first feature." >&2
else
  echo ""
  if [ "$DRY_RUN" = "1" ]; then
    echo "SDD setup dry-run (v${SDD_VERSION}) — no files written"
    echo "  Agents:       ${agent_count} would be installed"
    echo "  Skill:        $RESULT_SKILL"
    echo "  Help skill:   $RESULT_HELP_SKILL"
    echo "  Setup skill:  $RESULT_SETUP_SKILL"
    echo "  Phase skills: ${phase_skill_summary:-skipped}"
    echo "  CLI:          $RESULT_CLI"
    echo "  User shim:    $RESULT_USER_SHIM"
    echo "  CLAUDE.md:    $RESULT_CLAUDE_MD"
    echo "  Hooks:        ${hook_count} events would be registered"
    echo "  .features/:   $RESULT_FEATURES"
    echo "  .gitignore:   $RESULT_GITIGNORE"
    echo "  INDEX.md:     $RESULT_INDEX"
    echo "  Manifest:     $RESULT_MANIFEST"
  else
    echo "SDD setup complete (v${SDD_VERSION})"
    echo "  Agents:       ${agent_count} installed (.claude/agents/sdd-*.md)"
    echo "  Skill:        $RESULT_SKILL → .claude/skills/spec-driven-development/"
    echo "  Help skill:   $RESULT_HELP_SKILL → .claude/skills/sdd-help/"
    echo "  Setup skill:  $RESULT_SETUP_SKILL → .claude/skills/sdd-setup/"
    echo "  Phase skills: ${phase_skill_count} installed (${phase_skill_dirs}) — ${phase_skill_summary:-skipped}"
    echo "  CLI:          $RESULT_CLI → .claude/bin/sdd"
    echo "  User shim:    $RESULT_USER_SHIM"
    echo "  CLAUDE.md:    $RESULT_CLAUDE_MD SDD instructions block"
    echo "  Hooks:        ${hook_count} events registered in .claude/settings.json"
    echo "  .features/:   $RESULT_FEATURES"
    echo "  .gitignore:   $RESULT_GITIGNORE"
    echo "  INDEX.md:     $RESULT_INDEX"
    echo "  Manifest:     .claude/.sdd-manifest.json $RESULT_MANIFEST"
  fi
  echo ""
  echo "Next: run \`sdd init <feature-name> \"description\"\` to start your first feature."
fi
