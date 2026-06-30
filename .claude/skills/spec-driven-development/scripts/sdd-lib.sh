#!/usr/bin/env bash
# sdd-lib.sh — Shared library for SDD scripts
# Source pattern: source "$(dirname "$0")/sdd-lib.sh"

# Guard: only source once
[ -n "${SDD_LIB_LOADED:-}" ] && return 0
SDD_LIB_LOADED=1

# Resolve paths relative to this library file
SDD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDD_SKILL_DIR="$(cd "$SDD_SCRIPT_DIR/.." && pwd)"
SDD_TEMPLATE_DIR="$SDD_SKILL_DIR/templates"
SDD_FEATURE_ROOT=".features"
SDD_SCHEMA_VERSION=1
SDD_EXIT_USAGE=2
SDD_EXIT_NOT_FOUND=3
SDD_EXIT_PRECONDITION=4
SDD_EXIT_CONFLICT=5
SDD_EXIT_BLOCKED=6
SDD_EXIT_INTERNAL=7

# AD-002 / jqlang#92: MSYS2 jq 1.7 emits CRLF unless jq 1.8's --binary flag is used.
if [ -n "${MSYSTEM:-}" ]; then
  if [ -z "${SDD_JQ_HAS_B+x}" ]; then
    if command jq --help 2>&1 | grep -q -- '--binary'; then
      SDD_JQ_HAS_B=1
    else
      SDD_JQ_HAS_B=
    fi
    export SDD_JQ_HAS_B
  fi

  jq() {
    if [ "${SDD_JQ_HAS_B:-}" = "1" ]; then
      command jq -b "$@"
    else
      command jq "$@" | tr -d '\r'
      return "${PIPESTATUS[0]}"
    fi
  }
  export -f jq
fi

# Resolve the shared SDD state cache path.
sdd_state_cache_path() {
  if [ -n "${SDD_STATE_CACHE:-}" ]; then
    printf '%s\n' "$SDD_STATE_CACHE"
  else
    printf '%s\n' "${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/tmp/sdd-state-cache.json"
  fi
}

# Default session flag schema for cross-hook coordination.
sdd_session_flags_defaults() {
  printf '%s\n' '{"post_compact_pending":false,"instructions_reloaded":false,"last_tool_failure":null,"dispatch_epoch":0,"subagent_result_pending":false,"autonomy_block_pending":false,"autonomy_last_on":false,"autonomy_last_suspect_count":0,"self_reviewed_at":null,"phase_skill_invocations":{}}'
}

# Convert a bash string into a JSON literal.
sdd_json_literal() {
  local value="${1:-null}"
  if [ "$value" = "null" ] || [ "$value" = "true" ] || [ "$value" = "false" ]; then
    printf '%s\n' "$value"
  elif printf '%s' "$value" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "$value"
  else
    jq -Rn --arg value "$value" '$value'
  fi
}

sdd_json_string_or_null() {
  local value="${1:-}"
  if [ -n "$value" ]; then
    jq -Rn --arg value "$value" '$value'
  else
    printf 'null\n'
  fi
}

# Reset shared CLI parsing state.
sdd_cli_reset() {
  SDD_HELP=0
  SDD_OUTPUT_FORMAT="text"
  SDD_NON_INTERACTIVE=0
  SDD_ON_EXISTS=""
  SDD_FEATURE_OVERRIDE=""
  SDD_FIELD=""
  SDD_JQ_EXPR=""
  SDD_ARGS=()
}

# Parse the flags shared by all user-facing CLI commands.
sdd_parse_common_args() {
  sdd_cli_reset

  while [ $# -gt 0 ]; do
    case "$1" in
      --help|-h)
        SDD_HELP=1
        ;;
      --json)
        SDD_OUTPUT_FORMAT="json"
        ;;
      --format)
        shift
        case "${1:-}" in
          text|json)
            SDD_OUTPUT_FORMAT="$1"
            ;;
          *)
            return "$SDD_EXIT_USAGE"
            ;;
        esac
        ;;
      --feature)
        shift
        [ -n "${1:-}" ] || return "$SDD_EXIT_USAGE"
        SDD_FEATURE_OVERRIDE="$1"
        ;;
      --non-interactive)
        SDD_NON_INTERACTIVE=1
        ;;
      --on-exists)
        shift
        case "${1:-}" in
          fail|overwrite|skip)
            SDD_ON_EXISTS="$1"
            ;;
          *)
            return "$SDD_EXIT_USAGE"
            ;;
        esac
        ;;
      --field)
        shift
        [ -n "${1:-}" ] || return "$SDD_EXIT_USAGE"
        SDD_FIELD="$1"
        ;;
      --jq)
        shift
        [ -n "${1:-}" ] || return "$SDD_EXIT_USAGE"
        SDD_JQ_EXPR="$1"
        ;;
      --)
        shift
        while [ $# -gt 0 ]; do
          SDD_ARGS+=("$1")
          shift
        done
        break
        ;;
      *)
        SDD_ARGS+=("$1")
        ;;
    esac
    shift
  done

  if [ -n "$SDD_FIELD" ] && [ -n "$SDD_JQ_EXPR" ]; then
    return "$SDD_EXIT_USAGE"
  fi

  if [ -n "$SDD_FIELD" ] || [ -n "$SDD_JQ_EXPR" ]; then
    SDD_OUTPUT_FORMAT="json"
  fi

  return 0
}

sdd_is_json_mode() {
  [ "${SDD_OUTPUT_FORMAT:-text}" = "json" ]
}

sdd_is_machine_mode() {
  sdd_is_json_mode && return 0
  [ "${SDD_NON_INTERACTIVE:-0}" = "1" ]
}

sdd_exit_code_for_type() {
  case "$1" in
    usage)        echo "$SDD_EXIT_USAGE" ;;
    not_found)    echo "$SDD_EXIT_NOT_FOUND" ;;
    precondition) echo "$SDD_EXIT_PRECONDITION" ;;
    conflict)     echo "$SDD_EXIT_CONFLICT" ;;
    blocked)      echo "$SDD_EXIT_BLOCKED" ;;
    internal)     echo "$SDD_EXIT_INTERNAL" ;;
    *)            echo 1 ;;
  esac
}

sdd_stderr_error() {
  local type="$1" message="$2"
  printf 'Error [%s]: %s\n' "$type" "$message" >&2
}

sdd_note() {
  printf '%s\n' "$*" >&2
}

sdd_warn() {
  printf 'Warning: %s\n' "$*" >&2
}

sdd_debug() {
  case "${SDD_DEBUG:-0}" in
    1|true|TRUE|yes|YES)
      printf 'Debug: %s\n' "$*" >&2
      ;;
  esac
}

sdd_selector_expr() {
  if [ -n "${SDD_JQ_EXPR:-}" ]; then
    printf '%s\n' "$SDD_JQ_EXPR"
  elif [ -n "${SDD_FIELD:-}" ]; then
    case "$SDD_FIELD" in
      .*) printf '%s\n' "$SDD_FIELD" ;;
      *)  printf '.%s\n' "$SDD_FIELD" ;;
    esac
  else
    printf '.\n'
  fi
}

sdd_emit_json_selection() {
  local json="$1"
  local expr

  if [ -z "${SDD_FIELD:-}" ] && [ -z "${SDD_JQ_EXPR:-}" ]; then
    printf '%s\n' "$json"
    return 0
  fi

  expr="$(sdd_selector_expr)"
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

sdd_json_guidance() {
  local next_line="${1:-}" gate_line="${2:-}" pitfall_line="${3:-}"
  jq -nc \
    --arg next_line "$next_line" \
    --arg gate_line "$gate_line" \
    --arg pitfall_line "$pitfall_line" \
    '
      {}
      + (if $next_line != "" then {next: $next_line} else {} end)
      + (if $gate_line != "" then {gate: $gate_line} else {} end)
      + (if $pitfall_line != "" then {pitfall: $pitfall_line} else {} end)
    '
}

sdd_json_success() {
  local command="$1" resolved_feature="${2:-}" resolution_source="${3:-none}" phase="${4:-}"
  local data_json guidance_json warnings_json
  if [ $# -ge 5 ]; then data_json="$5"; else data_json='{}'; fi
  if [ $# -ge 6 ]; then guidance_json="$6"; else guidance_json='{}'; fi
  if [ $# -ge 7 ]; then warnings_json="$7"; else warnings_json='[]'; fi

  jq -nc \
    --argjson schema_version "$SDD_SCHEMA_VERSION" \
    --arg command "$command" \
    --argjson resolved_feature "$(sdd_json_string_or_null "$resolved_feature")" \
    --arg resolution_source "$resolution_source" \
    --argjson phase "$(sdd_json_string_or_null "$phase")" \
    --argjson data "$data_json" \
    --argjson guidance "$guidance_json" \
    --argjson warnings "$warnings_json" \
    '{
      ok: true,
      schema_version: $schema_version,
      command: $command,
      resolved_feature: $resolved_feature,
      resolution_source: $resolution_source,
      phase: $phase,
      data: $data,
      guidance: $guidance,
      warnings: $warnings
    }'
}

sdd_json_error() {
  local command="$1" error_type="$2" message="$3"
  local details_json resolved_feature resolution_source phase warnings_json
  if [ $# -ge 4 ]; then details_json="$4"; else details_json='{}'; fi
  resolved_feature="${5:-}"
  resolution_source="${6:-none}"
  phase="${7:-}"
  if [ $# -ge 8 ]; then warnings_json="$8"; else warnings_json='[]'; fi

  jq -nc \
    --argjson schema_version "$SDD_SCHEMA_VERSION" \
    --arg command "$command" \
    --argjson resolved_feature "$(sdd_json_string_or_null "$resolved_feature")" \
    --arg resolution_source "$resolution_source" \
    --argjson phase "$(sdd_json_string_or_null "$phase")" \
    --arg error_type "$error_type" \
    --arg message "$message" \
    --argjson details "$details_json" \
    --argjson warnings "$warnings_json" \
    '{
      ok: false,
      schema_version: $schema_version,
      command: $command,
      resolved_feature: $resolved_feature,
      resolution_source: $resolution_source,
      phase: $phase,
      error: {
        type: $error_type,
        message: $message,
        details: $details
      },
      warnings: $warnings
    }'
}

sdd_fail() {
  local command="$1" error_type="$2" message="$3"
  local details_json resolved_feature resolution_source phase
  if [ $# -ge 4 ]; then details_json="$4"; else details_json='{}'; fi
  resolved_feature="${5:-}"
  resolution_source="${6:-none}"
  phase="${7:-}"
  local exit_code

  exit_code="$(sdd_exit_code_for_type "$error_type")"

  if sdd_is_json_mode; then
    sdd_json_error "$command" "$error_type" "$message" "$details_json" "$resolved_feature" "$resolution_source" "$phase"
  else
    sdd_stderr_error "$error_type" "$message"
  fi

  exit "$exit_code"
}

sdd_usage_error() {
  local command="$1" usage="$2" message="$3"
  local details_json
  if [ $# -ge 4 ]; then details_json="$4"; else details_json='{}'; fi
  if sdd_is_json_mode; then
    sdd_fail "$command" "usage" "$message" "$details_json"
  fi

  sdd_stderr_error "usage" "$message"
  printf 'Usage: %s\n' "$usage" >&2
  exit "$SDD_EXIT_USAGE"
}

sdd_help_json() {
  local command="$1" summary="$2" usage="$3"
  local flags_json aliases_json examples_json
  if [ $# -ge 4 ]; then flags_json="$4"; else flags_json='[]'; fi
  if [ $# -ge 5 ]; then aliases_json="$5"; else aliases_json='[]'; fi
  if [ $# -ge 6 ]; then examples_json="$6"; else examples_json='[]'; fi
  local data_json

  data_json="$(jq -nc \
    --arg summary "$summary" \
    --arg usage "$usage" \
    --argjson flags "$flags_json" \
    --argjson aliases "$aliases_json" \
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
      aliases: $aliases,
      examples: $examples,
      exit_codes: $exit_codes
    }')"

  sdd_emit_json_selection "$(sdd_json_success "$command" "" "none" "" "$data_json" '{}' '[]')"
}

sdd_common_flags_json() {
  cat <<'EOF'
[
  {"name":"--help","description":"Show command help"},
  {"name":"--feature <id|auto>","description":"Explicit feature target override"},
  {"name":"--format text|json","description":"Select text or JSON output"},
  {"name":"--json","description":"Alias for --format json"},
  {"name":"--non-interactive","description":"Disable prompts and require deterministic conflict handling"},
  {"name":"--on-exists fail|overwrite|skip","description":"Conflict policy for existing scaffold files"},
  {"name":"--field <path>","description":"Select a single field from JSON output"},
  {"name":"--jq <expr>","description":"Apply a jq expression to JSON output"}
]
EOF
}

# Shared temp-file tracking for cleanup-aware write helpers.
SDD_CLEANUP_PATHS="${SDD_CLEANUP_PATHS:-}"
SDD_CLEANUP_TRAP_INSTALLED="${SDD_CLEANUP_TRAP_INSTALLED:-0}"
SDD_PREVIOUS_EXIT_TRAP="${SDD_PREVIOUS_EXIT_TRAP:-}"

sdd_cleanup_paths_clear() {
  SDD_CLEANUP_PATHS=""
}

sdd_cleanup_push() {
  local path

  path="${1:-}"
  [ -n "$path" ] || return 0

  if printf '%s\n' "$SDD_CLEANUP_PATHS" | grep -Fx -- "$path" >/dev/null 2>&1; then
    return 0
  fi

  if [ -n "$SDD_CLEANUP_PATHS" ]; then
    SDD_CLEANUP_PATHS="${SDD_CLEANUP_PATHS}
$path"
  else
    SDD_CLEANUP_PATHS="$path"
  fi
}

sdd_cleanup_drop() {
  local path filtered

  path="${1:-}"
  [ -n "$path" ] || return 0

  filtered="$(printf '%s\n' "$SDD_CLEANUP_PATHS" | awk -v target="$path" '
    $0 != target && $0 != "" { print }
  ')"
  SDD_CLEANUP_PATHS="$filtered"
}

sdd_cleanup_file() {
  local path

  path="${1:-}"
  [ -n "$path" ] || return 0

  rm -f "$path" 2>/dev/null || true
  sdd_cleanup_drop "$path"
}

sdd_cleanup_run() {
  local path

  if [ -z "$SDD_CLEANUP_PATHS" ]; then
    return 0
  fi

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    rm -f "$path" 2>/dev/null || true
  done <<EOF
$SDD_CLEANUP_PATHS
EOF

  sdd_cleanup_paths_clear
}

sdd_run_exit_trap() {
  sdd_cleanup_run
  if [ -n "$SDD_PREVIOUS_EXIT_TRAP" ]; then
    eval "$SDD_PREVIOUS_EXIT_TRAP"
  fi
}

sdd_install_cleanup_trap() {
  local current_trap

  if [ "$SDD_CLEANUP_TRAP_INSTALLED" = "1" ]; then
    return 0
  fi

  current_trap="$(trap -p EXIT | sed -n "s/^trap -- '\\(.*\\)' EXIT$/\\1/p")"
  SDD_PREVIOUS_EXIT_TRAP="$current_trap"
  trap 'sdd_run_exit_trap' EXIT
  SDD_CLEANUP_TRAP_INSTALLED=1
}

# sdd_lock_or_exit — acquire a per-project singleton lock or exit 0.
# Uses macOS lockf(1) with non-blocking mode. Lock auto-releases on exit/crash.
# Usage: sdd_lock_or_exit "script-name"
# Creates lock under ${SDD_LOCK_DIR:-${TMPDIR:-/tmp}/sdd-locks}
sdd_lock_or_exit() {
  local script_name="${1:?usage: sdd_lock_or_exit script-name}"
  local project_hash lock_dir lock_file
  project_hash="$(printf '%s' "${CLAUDE_PROJECT_DIR:-$(pwd)}" | shasum -a 256 | cut -c1-12)"
  lock_dir="${SDD_LOCK_DIR:-${TMPDIR:-/tmp}/sdd-locks}"
  mkdir -p "$lock_dir" 2>/dev/null || true
  lock_file="$lock_dir/${project_hash}-${script_name}.lock"

  if command -v lockf >/dev/null 2>&1; then
    # macOS: lockf with -t0 (non-blocking). Lock held via fd, auto-released on exit.
    exec 200>"$lock_file"
    lockf -t0 200 2>/dev/null || exit 0
  elif command -v flock >/dev/null 2>&1; then
    # Linux fallback
    exec 200>"$lock_file"
    flock -n 200 || exit 0
  else
    # No lock primitive — use mkdir as atomic fallback with PID-based stale check
    if mkdir "$lock_file.d" 2>/dev/null; then
      echo $$ > "$lock_file.d/pid"
      trap "rm -rf '$lock_file.d'" EXIT
    else
      # Check for stale lock (process no longer running)
      local old_pid
      old_pid="$(cat "$lock_file.d/pid" 2>/dev/null)" || old_pid=""
      if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        exit 0  # Still running
      fi
      rm -rf "$lock_file.d"
      mkdir "$lock_file.d" 2>/dev/null || exit 0
      echo $$ > "$lock_file.d/pid"
      trap "rm -rf '$lock_file.d'" EXIT
    fi
  fi
}

# sdd_tsv_split <line> <var1> [var2 ...] — assign tab-delimited fields of <line>
# to the named variables. Empty-field-safe (unlike `IFS=$'\t' read`, where tab is
# IFS-whitespace and consecutive/empty fields collapse). The last named variable
# receives the remainder of the line. If <line> has fewer fields than requested,
# the missing trailing variables are set empty — matching `awk -F '\t' '{print $N}'`.
# Pure parameter-expansion: zero subprocess spawns.
sdd_tsv_split() {
  local __line="$1"; shift
  local __rest="$__line" __name __val
  while [ "$#" -gt 1 ]; do
    __name="$1"; shift
    case "$__rest" in
      *$'\t'*) __val="${__rest%%$'\t'*}"; __rest="${__rest#*$'\t'}" ;;
      *)       __val="$__rest"; __rest="" ;;
    esac
    printf -v "$__name" '%s' "$__val"
  done
  [ "$#" -eq 1 ] && printf -v "$1" '%s' "$__rest"
}

sdd_safe_replace_dir() {
  local target="${1:?usage: sdd_safe_replace_dir target staged}"
  local staged="${2:?usage: sdd_safe_replace_dir target staged}"
  local backup="${target}.old.$$"
  local moved_existing=0
  local delay

  [ -d "$staged" ] || {
    echo "sdd_safe_replace_dir: staged directory not found: $staged" >&2
    return 1
  }

  if [ -e "$target" ]; then
    for delay in 0.2 0.4 0.8 1.6 3.2 6.4 12.8; do
      if mv "$target" "$backup" 2>/dev/null; then
        moved_existing=1
        break
      fi
      sleep "$delay"
    done
    if [ "$moved_existing" != "1" ]; then
      echo "sdd_safe_replace_dir: EACCES on $target after 30s — concurrent file scanner?" >&2
      return 1
    fi
  fi

  for delay in 0.2 0.4 0.8 1.6 3.2 6.4 12.8; do
    if mv "$staged" "$target" 2>/dev/null; then
      rm -rf "$backup" 2>/dev/null || true
      return 0
    fi
    sleep "$delay"
  done

  if [ "$moved_existing" = "1" ] && [ -e "$backup" ] && [ ! -e "$target" ]; then
    mv "$backup" "$target" 2>/dev/null || true
  fi
  echo "sdd_safe_replace_dir: EACCES on $staged after 30s — concurrent file scanner?" >&2
  return 1
}

sdd_mtime() {
  local file="${1:?usage: sdd_mtime path}"
  local mtime

  [ -e "$file" ] || return 1

  mtime="$(stat -f %m "$file" 2>/dev/null)" || mtime=""
  if printf '%s' "$mtime" | grep -Eq '^[0-9]+$'; then
    printf '%s\n' "$mtime"
    return 0
  fi

  mtime="$(stat -c %Y "$file" 2>/dev/null)" || return 1
  printf '%s\n' "$mtime"
}

# sdd_state_is_fresh — return 0 (true) if a file was modified less than N seconds ago
# Usage: sdd_state_is_fresh "path/to/file" 30
sdd_state_is_fresh() {
  local file="${1:?}" threshold="${2:-30}"
  [ -f "$file" ] || return 1
  local mtime now age
  mtime="$(sdd_mtime "$file")" || return 1
  now="$(date +%s)"
  age=$((now - mtime))
  [ "$age" -lt "$threshold" ]
}

# sdd_summary_is_stale — return 0 (true) if summary.md is missing or older
# than any canonical artifact source. Pure shell mtime compare; no fork.
# Usage: sdd_summary_is_stale "<feature-id>"
sdd_summary_is_stale() {
  local feature="${1:?}"
  local feature_dir=".features/$feature"
  local summary="$feature_dir/summary.md"
  local compact="$feature_dir/summary-compact.md"
  [ -d "$feature_dir" ] || return 1
  [ -f "$summary" ] || return 0
  [ -f "$compact" ] || return 0
  local src
  for src in brief spec research plan tasks review continuity; do
    [ "$feature_dir/$src.md" -nt "$summary" ] && return 0
  done
  [ "$feature_dir/state.json" -nt "$summary" ] && return 0
  [ "$feature_dir/changes.log" -nt "$summary" ] && return 0
  return 1
}

# sdd_summary_maybe — regenerate summary.md/summary-compact.md only when stale.
# Cheap no-op (~mtime calls) when summary is fresh. Singleton lock inside
# sdd-summary.sh handles concurrent callers (extras exit immediately).
# Usage: sdd_summary_maybe "<feature-id>"
sdd_summary_maybe() {
  local feature="${1:-}"
  [ -n "$feature" ] || return 0
  [ -d ".features/$feature" ] || return 0
  if sdd_summary_is_stale "$feature"; then
    bash "$SDD_SCRIPT_DIR/sdd-summary.sh" "$feature" >/dev/null 2>&1 || true
  fi
}

sdd_tmp_for_target() {
  local target dir base template

  target="$1"
  dir="$(dirname "$target")"
  base="$(basename "$target")"
  mkdir -p "$dir" || return 1
  template="$dir/.${base}.tmp.XXXXXX"
  mktemp "$template"
}

sdd_atomic_replace() {
  local tmp target

  tmp="$1"
  target="$2"
  mv "$tmp" "$target" || return 1
  sdd_cleanup_drop "$tmp"
}

# Write a single session flag atomically, preserving the rest of the cache.
sdd_set_session_flag() {
  local flag_name="$1"
  local value="${2:-null}"

  command -v jq >/dev/null 2>&1 || return 1

  local cache_file cache_dir tmp base_json value_json
  cache_file="$(sdd_state_cache_path)"
  cache_dir="$(dirname "$cache_file")"
  mkdir -p "$cache_dir"
  tmp="$(sdd_tmp_for_target "$cache_file")" || return 1
  sdd_cleanup_push "$tmp"

  if [ -f "$cache_file" ] && jq -e . "$cache_file" >/dev/null 2>&1; then
    base_json="$(cat "$cache_file")"
  else
    base_json='{}'
  fi

  value_json="$(sdd_json_literal "$value")"

  printf '%s\n' "$base_json" | jq \
    --arg flag "$flag_name" \
    --argjson defaults "$(sdd_session_flags_defaults)" \
    --argjson value "$value_json" \
    '.session_flags = (($defaults + (.session_flags // {})) | .[$flag] = $value)' \
    > "$tmp" || {
      sdd_cleanup_file "$tmp"
      return 1
    }

  if ! sdd_atomic_replace "$tmp" "$cache_file"; then
    sdd_cleanup_file "$tmp"
    return 1
  fi
}

# Read session flags as a fully populated JSON object.
sdd_read_session_flags() {
  local cache_file
  cache_file="$(sdd_state_cache_path)"

  if ! command -v jq >/dev/null 2>&1; then
    sdd_session_flags_defaults
    return 0
  fi

  if [ ! -f "$cache_file" ] || ! jq -e . "$cache_file" >/dev/null 2>&1; then
    sdd_session_flags_defaults
    return 0
  fi

  jq -c \
    --argjson defaults "$(sdd_session_flags_defaults)" \
    '$defaults + (.session_flags // {})' \
    "$cache_file" 2>/dev/null || sdd_session_flags_defaults
}

# Reset all session flags to defaults while preserving the rest of the cache.
sdd_reset_session_flags() {
  command -v jq >/dev/null 2>&1 || return 1

  local cache_file cache_dir tmp base_json
  cache_file="$(sdd_state_cache_path)"
  cache_dir="$(dirname "$cache_file")"
  mkdir -p "$cache_dir"
  tmp="$(sdd_tmp_for_target "$cache_file")" || return 1
  sdd_cleanup_push "$tmp"

  if [ -f "$cache_file" ] && jq -e . "$cache_file" >/dev/null 2>&1; then
    base_json="$(cat "$cache_file")"
  else
    base_json='{}'
  fi

  printf '%s\n' "$base_json" | jq \
    --argjson defaults "$(sdd_session_flags_defaults)" \
    '.session_flags = $defaults' \
    > "$tmp" || {
      sdd_cleanup_file "$tmp"
      return 1
    }

  if ! sdd_atomic_replace "$tmp" "$cache_file"; then
    sdd_cleanup_file "$tmp"
    return 1
  fi
}

# Cross-platform sed -i replacement using tmp+mv
# Usage: sdd_portable_sed FILE SED_ARGS...
sdd_portable_sed() {
  local file="$1"
  shift
  local tmp

  tmp="$(sdd_tmp_for_target "$file")" || return 1
  sdd_cleanup_push "$tmp"
  if ! sed "$@" "$file" > "$tmp"; then
    sdd_cleanup_file "$tmp"
    return 1
  fi
  sdd_atomic_replace "$tmp" "$file"
}

# Complete an upstream artifact when a phase transition consumes it.
# Emits a JSON array of status-update rows; empty when no exact draft status changed.
sdd_complete_predecessor_status() {
  local file="$1" reason="${2:-phase transition}"

  if [ ! -f "$file" ]; then
    printf '[]\n'
    return 0
  fi

  if grep -qx 'status: draft' "$file"; then
    sdd_portable_sed "$file" 's/^status: draft$/status: completed/' || return 1
    jq -nc \
      --arg file "$file" \
      --arg field "status" \
      --arg from "draft" \
      --arg to "completed" \
      --arg reason "$reason" \
      '[{file:$file, field:$field, from:$from, to:$to, reason:$reason}]'
  else
    printf '[]\n'
  fi
}

sdd_status_updates_text() {
  local updates_json="${1:-[]}"
  printf '%s\n' "$updates_json" | jq -r '.[]? | "Updated: \(.file) \(.field) \(.from) -> \(.to) (\(.reason))"' 2>/dev/null || true
}

########################################################################
# Feature directory identity and discovery helpers
#
# Feature identity remains the basename ID (for example, 0084-name). Feature
# path is the feature-root-relative storage path (for example,
# epics/onboarding/0084-name). Callers can migrate from ID-only paths to these
# helpers incrementally while preserving the legacy SDD_RESOLVED_FEATURE field.

sdd_feature_ref_is_safe() {
  local ref="${1:-}" segment
  local -a ref_segments

  [ -n "$ref" ] || return 1

  case "$ref" in
    /*|*'\'*|*'//'|*/) return 1 ;;
  esac

  IFS='/' read -r -a ref_segments <<< "$ref"
  for segment in "${ref_segments[@]}"; do
    [ -n "$segment" ] || return 1
    case "$segment" in
      .|..|.*|-*) return 1 ;;
      *[!A-Za-z0-9._-]*) return 1 ;;
    esac
  done

  return 0
}

sdd_feature_path_id() {
  basename "${1:-}"
}

sdd_feature_path_group() {
  local path="${1:-}" group
  group="$(dirname "$path")"
  [ "$group" = "." ] && group=""
  printf '%s\n' "$group"
}

sdd_feature_dir_for_path() {
  local path="${1:-}"
  [ -n "$path" ] || return 1
  printf '%s/%s\n' "$SDD_FEATURE_ROOT" "$path"
}

sdd_feature_path_from_dir() {
  local dir="${1:-}" rel
  [ -n "$dir" ] || return 1
  dir="${dir%/}"
  case "$dir" in
    "$SDD_FEATURE_ROOT"/*)
      rel="${dir#$SDD_FEATURE_ROOT/}"
      printf '%s\n' "$rel"
      ;;
    *)
      return 1
      ;;
  esac
}

sdd_feature_path_has_wp_segment() {
  case "/${1:-}/" in
    */wp-*/*) return 0 ;;
    *) return 1 ;;
  esac
}

sdd_feature_dir_has_marker() {
  local dir="${1:-}" marker
  [ -d "$dir" ] || return 1

  for marker in \
    brief.md spec.md research.md plan.md tasks.md review.md \
    scratchpad.md continuity.md knowledge.md state.json changes.log
  do
    [ -e "$dir/$marker" ] && return 0
  done

  return 1
}

sdd_feature_path_is_feature() {
  local path="${1:-}" dir base

  sdd_feature_ref_is_safe "$path" || return 1
  sdd_feature_path_has_wp_segment "$path" && return 1

  base="$(sdd_feature_path_id "$path")"
  case "$base" in
    [0-9][0-9][0-9][0-9]-*) ;;
    *) return 1 ;;
  esac

  dir="$(sdd_feature_dir_for_path "$path")"
  sdd_feature_dir_has_marker "$dir"
}

sdd_iter_feature_paths() {
  local dir path

  [ -d "$SDD_FEATURE_ROOT" ] || return 0

  find "$SDD_FEATURE_ROOT" -type d -name '[0-9][0-9][0-9][0-9]-*' -print 2>/dev/null | \
    LC_ALL=C sort | \
    while IFS= read -r dir; do
      path="$(sdd_feature_path_from_dir "$dir" 2>/dev/null || true)"
      [ -n "$path" ] || continue
      if sdd_feature_path_is_feature "$path"; then
        printf '%s\n' "$path"
      fi
    done
}

sdd_iter_resolvable_feature_paths() {
  local discovered="" dir path

  [ -d "$SDD_FEATURE_ROOT" ] || return 0

  discovered="$(sdd_iter_feature_paths)"
  printf '%s\n' "$discovered" | awk 'NF'

  for dir in "$SDD_FEATURE_ROOT"/*/; do
    [ -d "$dir" ] || continue
    path="$(sdd_feature_path_from_dir "$dir" 2>/dev/null || true)"
    [ -n "$path" ] || continue
    case "$path" in
      */*) continue ;;
    esac
    sdd_feature_path_has_wp_segment "$path" && continue
    case "$(basename "$path")" in
      [0-9][0-9][0-9][0-9]-*) ;;
      *) sdd_feature_dir_has_marker "$dir" || continue ;;
    esac
    printf '%s\n' "$discovered" | grep -Fx -- "$path" >/dev/null 2>&1 && continue
    printf '%s\n' "$path"
  done
}

sdd_project_relative_path() {
  local file_path="${1:-}" project_dir="${2:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

  [ -n "$file_path" ] || return 1
  project_dir="${project_dir%/}"

  case "$file_path" in
    "$project_dir"/*)
      printf '%s\n' "${file_path#${project_dir}/}"
      return 0
      ;;
    ./.features/*)
      printf '%s\n' "${file_path#./}"
      return 0
      ;;
    .features/*)
      printf '%s\n' "$file_path"
      return 0
      ;;
    *)
      printf '%s\n' "$file_path"
      return 0
      ;;
  esac
}

sdd_feature_path_for_file() {
  local file_path="${1:-}" project_dir="${2:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
  local rel_path inside candidate parent

  rel_path="$(sdd_project_relative_path "$file_path" "$project_dir")" || return 1
  case "$rel_path" in
    .features/EPIC.md|.features/EPIC.*)
      return 1
      ;;
    .features/*/*)
      ;;
    *)
      return 1
      ;;
  esac

  inside="${rel_path#.features/}"
  candidate="${inside%/*}"
  while [ -n "$candidate" ] && [ "$candidate" != "$inside" ] && [ "$candidate" != "." ]; do
    if sdd_feature_path_is_feature "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
    parent="${candidate%/*}"
    [ "$parent" = "$candidate" ] && break
    candidate="$parent"
  done

  return 1
}

sdd_feature_artifact_for_file() {
  local file_path="${1:-}" feature_path="${2:-}" project_dir="${3:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"
  local rel_path suffix

  [ -n "$feature_path" ] || feature_path="$(sdd_feature_path_for_file "$file_path" "$project_dir")" || return 1
  rel_path="$(sdd_project_relative_path "$file_path" "$project_dir")" || return 1

  case "$rel_path" in
    ".features/$feature_path/"*) ;;
    *) return 1 ;;
  esac

  suffix="${rel_path#.features/$feature_path/}"
  case "$suffix" in
    brief.md|spec.md|research.md|plan.md|tasks.md|review.md|continuity.md|knowledge.md|scratchpad.md)
      printf '%s\n' "${suffix%.md}"
      ;;
    *)
      return 1
      ;;
  esac
}

sdd_reset_feature_resolution_state() {
  SDD_RESOLVED_FEATURE=""
  SDD_RESOLVED_FEATURE_PATH=""
  SDD_RESOLVED_FEATURE_DIR=""
  SDD_RESOLVED_FEATURE_GROUP=""
  SDD_RESOLUTION_SOURCE="none"
  SDD_RESOLUTION_STATUS="none"
  SDD_RESOLUTION_CANDIDATES=""
}

sdd_set_resolved_feature_path() {
  local path="$1" source="${2:-arg}"
  SDD_RESOLVED_FEATURE_PATH="$path"
  SDD_RESOLVED_FEATURE="$(sdd_feature_path_id "$path")"
  SDD_RESOLVED_FEATURE_DIR="$(sdd_feature_dir_for_path "$path")"
  SDD_RESOLVED_FEATURE_GROUP="$(sdd_feature_path_group "$path")"
  SDD_RESOLUTION_SOURCE="$source"
  SDD_RESOLUTION_STATUS="ok"
}

# Validate that a feature directory exists. Echoes the path or returns 1.
sdd_validate_feature() {
  local feature="$1"
  local dir="$SDD_FEATURE_ROOT/$feature"
  if [ -d "$dir" ]; then
    echo "$dir"
  else
    echo "Error: feature directory '$dir' not found" >&2
    return 1
  fi
}

# Extract metadata from a feature ID and set SDD_* variables.
sdd_extract_metadata() {
  local feature="$1"
  SDD_FEATURE_NUM="$(echo "$feature" | grep -oE '^[0-9]+')"
  SDD_FEATURE_NAME="${feature#*-}"
  SDD_FEATURE_TITLE="$(echo "$SDD_FEATURE_NAME" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')"
  SDD_TODAY="$(date +%Y-%m-%d)"
}

# Process a template: copy src to dst, replace {{PLACEHOLDER}} values.
# Requires sdd_extract_metadata to have been called first.
sdd_process_template() {
  local src="$1" dst="$2" feature_id="$3"
  cp "$src" "$dst"
  sdd_portable_sed "$dst" \
    -e "s/{{FEATURE_ID}}/$feature_id/g" \
    -e "s/{{FEATURE_NUM}}/$SDD_FEATURE_NUM/g" \
    -e "s/{{FEATURE_NAME}}/$SDD_FEATURE_NAME/g" \
    -e "s/{{FEATURE_TITLE}}/$SDD_FEATURE_TITLE/g" \
    -e "s/{{DATE}}/$SDD_TODAY/g"
}

# Read a single scalar frontmatter value from a markdown artifact.
# Trims whitespace, strips YAML-style inline comments from unquoted values,
# and preserves literal # characters in quoted values and URL fragments.
sdd_frontmatter_value() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  awk -v key="$key" '
    function trim(s) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
      return s
    }
    function strip_double_quoted(s,    i, c, out, escaped) {
      escaped = 0
      for (i = 2; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (escaped) {
          out = out c
          escaped = 0
          continue
        }
        if (c == "\\") {
          out = out c
          escaped = 1
          continue
        }
        if (c == "\"") {
          return out
        }
        out = out c
      }
      return substr(s, 2)
    }
    function strip_single_quoted(s,    i, c, next_c, out) {
      for (i = 2; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "'\''") {
          next_c = substr(s, i + 1, 1)
          if (next_c == "'\''") {
            out = out c
            i++
            continue
          }
          return out
        }
        out = out c
      }
      return substr(s, 2)
    }
    function scalar_value(s) {
      s = trim(s)
      sub(/\r$/, "", s)
      if (s ~ /^"/) return strip_double_quoted(s)
      if (s ~ /^'\''/) return strip_single_quoted(s)
      sub(/[ \t]+#.*/, "", s)
      return trim(s)
    }
    BEGIN { in_frontmatter = 0; started = 0 }
    $0 == "---" {
      if (!started) {
        started = 1
        in_frontmatter = 1
        next
      }
      if (in_frontmatter) {
        exit
      }
    }
    in_frontmatter && $0 ~ "^" key ":[[:space:]]*" {
      sub("^[^:]+:[[:space:]]*", "", $0)
      print scalar_value($0)
      exit
    }
  ' "$file"
}

# Read one notes.<scope> list from a customization.yaml file.
# Emits one bullet per line, with YAML list markers and simple quotes stripped.
# Missing files or absent scopes produce empty output and exit 0.
sdd_read_customization_file() {
  local file="$1" scope_key="$2"
  [ -f "$file" ] || return 0
  [ -n "$scope_key" ] || return 0

  awk -v wanted="$scope_key" '
    function trim(s) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
      return s
    }
    function strip_value(s) {
      s = trim(s)
      sub(/\r$/, "", s)
      if (s ~ /^".*"$/) {
        s = substr(s, 2, length(s) - 2)
        gsub(/\\"/, "\"", s)
        return s
      }
      if (s ~ /^'\''.*'\''$/) {
        s = substr(s, 2, length(s) - 2)
        gsub(/'\'''\''/, "'\''", s)
        return s
      }
      sub(/[ \t]+#.*/, "", s)
      return trim(s)
    }
    function emit_value(s) {
      s = strip_value(s)
      if (s != "") print s
    }
    function emit_inline_list(s, parts, i, n) {
      s = trim(s)
      sub(/[ \t]+#.*/, "", s)
      if (s == "" || s == "[]") return
      if (s ~ /^\[.*\]$/) {
        s = substr(s, 2, length(s) - 2)
        n = split(s, parts, /,[ \t]*/)
        for (i = 1; i <= n; i++) emit_value(parts[i])
      }
    }

    /^notes:[ \t]*(#.*)?$/ {
      in_notes = 1
      next
    }
    in_notes && /^[^ \t#][^:]*:/ {
      in_notes = 0
    }
    !in_notes {
      next
    }
    /^  [A-Za-z0-9_-]+:[ \t]*/ {
      line = $0
      sub(/^  /, "", line)
      active = line
      sub(/:.*/, "", active)
      rest = line
      sub(/^[^:]+:[ \t]*/, "", rest)
      if (active == wanted) emit_inline_list(rest)
      next
    }
    /^    -[ \t]*/ {
      if (active == wanted) {
        item = $0
        sub(/^    -[ \t]*/, "", item)
        emit_value(item)
      }
      next
    }
  ' "$file"
}

sdd_frontmatter_raw_value() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 1
  awk -v key="$key" '
    BEGIN { in_frontmatter = 0; started = 0; found = 0 }
    $0 == "---" {
      if (!started) {
        started = 1
        in_frontmatter = 1
        next
      }
      if (in_frontmatter) {
        in_frontmatter = 0
      }
    }
    in_frontmatter && $0 ~ "^" key ":[[:space:]]*" {
      sub("^[^:]+:[[:space:]]*", "", $0)
      print
      found = 1
      exit
    }
    END { exit found ? 0 : 1 }
  ' "$file"
}

sdd_frontmatter_json() {
  local file="$1" key="$2" default="${3:-null}"
  local raw=""

  raw="$(sdd_frontmatter_raw_value "$file" "$key" 2>/dev/null || true)"
  raw="$(printf '%s' "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

  if [ -z "$raw" ]; then
    printf '%s\n' "$default"
    return 0
  fi

  if printf '%s\n' "$raw" | jq -ce . >/dev/null 2>&1; then
    printf '%s\n' "$raw" | jq -c .
  else
    printf '%s\n' "$default"
  fi
}

sdd_synthesize_links() {
  local file="$1"
  local raw_links="" source=""

  raw_links="$(sdd_frontmatter_raw_value "$file" "links" 2>/dev/null || true)"
  raw_links="$(printf '%s' "$raw_links" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

  if [ -n "$raw_links" ] && printf '%s\n' "$raw_links" | jq -ce 'type == "object"' >/dev/null 2>&1; then
    printf '%s\n' "$raw_links" | jq -c '
      {
        derived_from: ((.derived_from // []) | if type == "array" then . elif . == null then [] else [.] end | map(tostring) | map(select(length > 0))),
        informed_by: ((.informed_by // []) | if type == "array" then . elif . == null then [] else [.] end | map(tostring) | map(select(length > 0))),
        supersedes: ((.supersedes // []) | if type == "array" then . elif . == null then [] else [.] end | map(tostring) | map(select(length > 0)))
      }
    '
    return 0
  fi

  source="$(sdd_frontmatter_value "$file" source 2>/dev/null || true)"
  jq -nc \
    --arg source "$source" \
    '{
      derived_from: (if $source == "" then [] else [$source] end),
      informed_by: [],
      supersedes: []
    }'
}

# Return success if a tasks file contains at least one matching status outside fenced code blocks.
sdd_task_file_has_status() {
  local file="$1" status="$2"
  [ -f "$file" ] || return 1
  awk -v status="$status" '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && $0 == "> Status: " status { found = 1; exit }
    END { exit found ? 0 : 1 }
  ' "$file"
}

sdd_tasks_file_has_open_status() {
  local file="$1"
  sdd_task_file_has_status "$file" "pending" || \
    sdd_task_file_has_status "$file" "in-progress" || \
    sdd_task_file_has_status "$file" "blocked"
}

sdd_tasks_file_has_approach_content() {
  local file="$1"
  [ -f "$file" ] || return 1
  awk '
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /<!--/ {
      in_comment = 1
      if (/-->/) in_comment = 0
      next
    }
    in_comment {
      if (/-->/) in_comment = 0
      next
    }
    /^## / {
      if (in_section) exit
      if ($0 == "## Approach") in_section = 1
      next
    }
    in_section && /^[[:space:]]*[-*][[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]*[-*][[:space:]]+/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line != "" && line !~ /^\[.*\]$/) {
        found = 1
        exit
      }
    }
    END { exit found ? 0 : 1 }
  ' "$file"
}

sdd_tasks_file_is_execution_ready() {
  local file="$1"
  local status
  [ -f "$file" ] || return 1
  [ "$(sdd_count_task_headings "$file")" -gt 0 ] || return 1
  if sdd_tasks_file_has_approach_content "$file"; then
    return 0
  fi
  status="$(sdd_frontmatter_value "$file" status || true)"
  [ "$status" = "completed" ]
}

sdd_feature_artifact_is_ready() {
  local file="$1"
  local status
  status="$(sdd_frontmatter_value "$file" status || true)"
  case "$status" in
    active|completed) return 0 ;;
    *) return 1 ;;
  esac
}

sdd_lite_spec_content_is_ready() {
  local file="$1"

  [ -f "$file" ] || return 1
  [ "$(sdd_count_id_lines FR "$file" headings)" -gt 0 ] || return 1
  [ "$(sdd_count_id_lines AC "$file" headings)" -gt 0 ] || return 1
  sdd_markdown_section_has_content "$file" "Problem" || return 1
}

sdd_markdown_table_cell_escape() {
  local value="${1:-}"
  printf '%s' "$value" | sed 's/|/\\|/g'
}

sdd_review_ac_rows_tsv() {
  local review_file="$1"
  [ -f "$review_file" ] || return 0

  awk '
    function trim(s) {
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      return s
    }
    function reset_cells() {
      cell_count = 0
      cell = ""
      delete cells
    }
    function push_cell() {
      cells[++cell_count] = trim(cell)
      cell = ""
    }
    function parse_row(line,    i, ch, escaped, in_code, offset, ac_id, ac_status) {
      reset_cells()
      escaped = 0
      in_code = 0
      for (i = 1; i <= length(line); i++) {
        ch = substr(line, i, 1)
        if (escaped) {
          cell = cell ch
          escaped = 0
          continue
        }
        if (ch == "\\") {
          cell = cell ch
          escaped = 1
          continue
        }
        if (ch == "`") {
          in_code = !in_code
          cell = cell ch
          continue
        }
        if (ch == "|" && !in_code) {
          push_cell()
          continue
        }
        cell = cell ch
      }
      push_cell()

      offset = (cells[1] == "" ? 1 : 0)
      ac_id = cells[1 + offset]
      ac_status = cells[3 + offset]
      if (ac_id ~ /^AC-[0-9]+$/) {
        printf "%s\t%s\n", ac_id, ac_status
      }
    }
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^## Acceptance Criteria Validation/ { in_section = 1; next }
    in_section && /^## / { in_section = 0 }
    in_section && /^\|/ {
      if ($0 ~ /^\|:?-[-:| ]+\|?$/ || $0 ~ /^\| AC /) next
      parse_row($0)
    }
  ' "$review_file"
}

sdd_review_ac_status_count() {
  local review_file="$1" status="$2"
  sdd_review_ac_rows_tsv "$review_file" | awk -F '\t' -v status="$status" '$2 == status { count++ } END { print count + 0 }'
}

sdd_review_ac_validation_count() {
  local review_file="$1"
  sdd_review_ac_rows_tsv "$review_file" | awk -F '\t' '$2 == "PASS" || $2 == "FAIL" { count++ } END { print count + 0 }'
}

sdd_detect_wp_phase() {
  local wp_dir="$1"
  local tasks="$wp_dir/tasks.md"
  local review="$wp_dir/review.md"
  local verdict evidence_status

  if [ ! -f "$tasks" ]; then
    echo "scaffold"
    return 0
  fi

  if sdd_tasks_file_has_open_status "$tasks"; then
    echo "implement"
    return 0
  fi

  if [ ! -f "$review" ]; then
    echo "review"
    return 0
  fi

  verdict="$(sdd_frontmatter_value "$review" verdict || true)"
  evidence_status="$(sdd_frontmatter_value "$review" evidence_status || true)"
  if [ "$verdict" = "pass" ]; then
    if [ -z "$evidence_status" ] || [ "$evidence_status" = "sufficient" ]; then
      echo "done"
      return 0
    fi
  fi

  echo "review"
}

sdd_feature_has_work_packages() {
  local feature_dir="$1"
  local wp

  [ -d "$feature_dir" ] || return 1
  for wp in "$feature_dir"/wp-*/; do
    [ -d "$wp" ] && return 0
  done
  return 1
}

sdd_feature_task_source() {
  local feature_dir="$1"

  if sdd_feature_has_work_packages "$feature_dir"; then
    echo "work_packages"
  elif [ -f "$feature_dir/tasks.md" ]; then
    echo "root"
  else
    echo "none"
  fi
}

sdd_feature_wp_task_files() {
  local feature_dir="$1"
  local wp_tasks_file

  [ -d "$feature_dir" ] || return 0
  for wp_tasks_file in "$feature_dir"/wp-*/tasks.md; do
    [ -f "$wp_tasks_file" ] || continue
    sdd_task_normalize_file_path "$wp_tasks_file"
  done
}

sdd_feature_wp_snapshot() {
  local feature_dir="$1"
  local wp wp_count=0 wp_done=0 wp_active_count=0 wp_pending_count=0
  local active_wp="" active_wp_phase="" first_in_progress="" first_pending="" first_needs_review=""

  for wp in "$feature_dir"/wp-*/; do
    [ -d "$wp" ] || continue
    wp_count=$((wp_count + 1))

    local wphase tasks review
    wphase="$(sdd_detect_wp_phase "$wp")"
    tasks="$wp/tasks.md"
    review="$wp/review.md"

    if [ "$wphase" = "done" ]; then
      wp_done=$((wp_done + 1))
    fi

    if [ -f "$tasks" ]; then
      if sdd_task_file_has_status "$tasks" "in-progress"; then
        wp_active_count=$((wp_active_count + 1))
        [ -n "$first_in_progress" ] || first_in_progress="$(basename "$wp")"
      elif sdd_task_file_has_status "$tasks" "pending"; then
        wp_pending_count=$((wp_pending_count + 1))
        [ -n "$first_pending" ] || first_pending="$(basename "$wp")"
      fi
    fi

    if [ -z "$first_needs_review" ] && { [ ! -f "$review" ] || [ "$(sdd_frontmatter_value "$review" verdict || true)" != "pass" ]; }; then
      first_needs_review="$(basename "$wp")"
    fi
  done

  [ "$wp_count" -gt 0 ] || return 1

  if [ -n "$first_in_progress" ]; then
    active_wp="$first_in_progress"
  elif [ -n "$first_pending" ]; then
    active_wp="$first_pending"
  else
    active_wp="$first_needs_review"
  fi

  if [ -n "$active_wp" ]; then
    active_wp_phase="$(sdd_detect_wp_phase "$feature_dir/$active_wp")"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${active_wp:-none}" \
    "${active_wp_phase:-none}" \
    "$wp_count" \
    "$wp_done" \
    "$wp_active_count" \
    "$wp_pending_count"
}

sdd_task_null_current_json() {
  jq -nc '{
    id:null,
    heading:null,
    phase:null,
    implements:null,
    verification_cmd:null,
    work_package:null,
    work_package_path:null,
    tasks_file:null,
    display_ref:null
  }'
}

sdd_task_current_with_source_json() {
  local summary_json="$1"
  local tasks_file="$2"
  local work_package="${3:-}"
  local work_package_path="${4:-}"
  local display_ref=""

  if [ "$(printf '%s\n' "$summary_json" | jq -r '.current_task.id // empty')" = "" ]; then
    sdd_task_null_current_json
    return 0
  fi

  display_ref="$(sdd_task_display_ref "$tasks_file" "$(printf '%s\n' "$summary_json" | jq -r '.current_task.id')")"
  printf '%s\n' "$summary_json" | jq -c \
    --arg tasks_file "$tasks_file" \
    --arg work_package "$work_package" \
    --arg work_package_path "$work_package_path" \
    --arg display_ref "$display_ref" \
    '.current_task + {
      work_package: (if $work_package == "" then null else $work_package end),
      work_package_path: (if $work_package_path == "" then null else $work_package_path end),
      tasks_file: $tasks_file,
      display_ref: $display_ref
    }'
}

sdd_feature_task_summary_json() {
  local feature_dir="$1"
  local source root_tasks tasks_file summary_json current_json packages_json="[]"
  local completed=0 in_progress=0 pending=0 blocked=0 total=0 ready_tasks=0 blocked_tasks=0
  local active_wp="" active_wp_tasks="" active_wp_path="" next_task_heading=""

  source="$(sdd_feature_task_source "$feature_dir")"
  root_tasks="$feature_dir/tasks.md"

  if [ "$source" != "work_packages" ]; then
    summary_json="$(sdd_task_summary_json "$root_tasks")"
    current_json="$(sdd_task_current_with_source_json "$summary_json" "$root_tasks")"
    printf '%s\n' "$summary_json" | jq -c \
      --arg source "$source" \
      --arg tasks_file "$(if [ -f "$root_tasks" ]; then sdd_task_normalize_file_path "$root_tasks"; fi)" \
      --argjson current "$current_json" \
      '. + {
        source: $source,
        tasks_file: (if $tasks_file == "" then null else $tasks_file end),
        work_packages: [],
        current_task: $current
      }'
    return 0
  fi

  local wp_snapshot=""
  wp_snapshot="$(sdd_feature_wp_snapshot "$feature_dir" || true)"
  if [ -n "$wp_snapshot" ]; then
    IFS=$'\t' read -r active_wp _active_wp_phase _wp_count _wp_done _wp_active _wp_pending <<EOF
$wp_snapshot
EOF
  fi

  for tasks_file in "$feature_dir"/wp-*/tasks.md; do
    [ -f "$tasks_file" ] || continue
    local wp_dir wp_id wp_path wp_phase
    wp_dir="$(dirname "$tasks_file")"
    wp_id="$(basename "$wp_dir")"
    wp_path="$(sdd_task_normalize_file_path "$wp_dir")"
    tasks_file="$(sdd_task_normalize_file_path "$tasks_file")"
    wp_phase="$(sdd_detect_wp_phase "$wp_dir")"
    summary_json="$(sdd_task_summary_json "$tasks_file")"

    completed=$((completed + $(printf '%s\n' "$summary_json" | jq -r '.completed')))
    in_progress=$((in_progress + $(printf '%s\n' "$summary_json" | jq -r '.in_progress')))
    pending=$((pending + $(printf '%s\n' "$summary_json" | jq -r '.pending')))
    blocked=$((blocked + $(printf '%s\n' "$summary_json" | jq -r '.blocked')))
    total=$((total + $(printf '%s\n' "$summary_json" | jq -r '.total')))
    ready_tasks=$((ready_tasks + $(printf '%s\n' "$summary_json" | jq -r '.ready_tasks')))
    blocked_tasks=$((blocked_tasks + $(printf '%s\n' "$summary_json" | jq -r '.blocked_tasks')))

    if [ "$wp_id" = "$active_wp" ]; then
      active_wp_tasks="$tasks_file"
      active_wp_path="$wp_path"
      next_task_heading="$(printf '%s\n' "$summary_json" | jq -r '.next_task_heading // empty')"
    fi

    packages_json="$(jq -nc \
      --argjson packages "$packages_json" \
      --argjson summary "$summary_json" \
      --arg id "$wp_id" \
      --arg path "$wp_path" \
      --arg tasks_file_value "$tasks_file" \
      --arg phase "$wp_phase" \
      '$packages + [{
        id: $id,
        path: $path,
        tasks_file: $tasks_file_value,
        phase: $phase,
        summary: $summary
      }]')"
  done

  if [ -n "$active_wp_tasks" ]; then
    summary_json="$(sdd_task_summary_json "$active_wp_tasks")"
    current_json="$(sdd_task_current_with_source_json "$summary_json" "$active_wp_tasks" "$active_wp" "$active_wp_path")"
  else
    current_json="$(sdd_task_null_current_json)"
  fi

  jq -nc \
    --arg source "$source" \
    --argjson completed "$completed" \
    --argjson in_progress "$in_progress" \
    --argjson pending "$pending" \
    --argjson blocked "$blocked" \
    --argjson total "$total" \
    --argjson ready_tasks "$ready_tasks" \
    --argjson blocked_tasks "$blocked_tasks" \
    --argjson packages "$packages_json" \
    --argjson current "$current_json" \
    --arg next_task_heading "$next_task_heading" \
    '{
      source: $source,
      tasks_file: null,
      work_packages: $packages,
      completed: $completed,
      in_progress: $in_progress,
      pending: $pending,
      blocked: $blocked,
      total: $total,
      ready_tasks: $ready_tasks,
      blocked_tasks: $blocked_tasks,
      current_task: $current,
      next_task_heading: (if $next_task_heading == "" then null else $next_task_heading end)
    }'
}

sdd_feature_wp_review_summary_json() {
  local feature_dir="$1"
  local wp wp_id wp_phase tasks_summary review verdict evidence_status
  local wp_count=0 done=0 missing_review=0 failing_review=0 incomplete_tasks=0 scaffold=0
  local packages_json="[]" review_pass="false"

  for wp in "$feature_dir"/wp-*/; do
    [ -d "$wp" ] || continue
    wp_count=$((wp_count + 1))
    wp_id="$(basename "$wp")"
    wp_phase="$(sdd_detect_wp_phase "$wp")"
    review="$wp/review.md"
    verdict=""
    evidence_status=""
    review_pass="false"

    if [ ! -f "$wp/tasks.md" ]; then
      scaffold=$((scaffold + 1))
    else
      tasks_summary="$(sdd_task_summary_json "$wp/tasks.md")"
      if [ "$(printf '%s\n' "$tasks_summary" | jq -r '.completed == .total and .total > 0')" != "true" ]; then
        incomplete_tasks=$((incomplete_tasks + 1))
      fi
    fi

    if [ -f "$review" ]; then
      verdict="$(sdd_frontmatter_value "$review" verdict || true)"
      evidence_status="$(sdd_frontmatter_value "$review" evidence_status || true)"
      if [ "$verdict" = "pass" ] && { [ -z "$evidence_status" ] || [ "$evidence_status" = "sufficient" ]; }; then
        review_pass="true"
        done=$((done + 1))
      else
        failing_review=$((failing_review + 1))
      fi
    else
      missing_review=$((missing_review + 1))
    fi

    packages_json="$(jq -nc \
      --argjson packages "$packages_json" \
      --arg id "$wp_id" \
      --arg phase "$wp_phase" \
      --arg verdict "$verdict" \
      --arg evidence_status "$evidence_status" \
      --argjson review_pass "$review_pass" \
      '$packages + [{
        id: $id,
        phase: $phase,
        review_verdict: (if $verdict == "" then null else $verdict end),
        evidence_status: (if $evidence_status == "" then null else $evidence_status end),
        review_pass: $review_pass
      }]')"
  done

  jq -nc \
    --argjson wp_count "$wp_count" \
    --argjson done "$done" \
    --argjson scaffold "$scaffold" \
    --argjson incomplete_tasks "$incomplete_tasks" \
    --argjson missing_review "$missing_review" \
    --argjson failing_review "$failing_review" \
    --argjson packages "$packages_json" \
    '{
      work_package_count: $wp_count,
      done: $done,
      scaffold: $scaffold,
      incomplete_tasks: $incomplete_tasks,
      missing_review: $missing_review,
      failing_review: $failing_review,
      ready_for_feature_review: (
        $wp_count > 0 and
        $scaffold == 0 and
        $incomplete_tasks == 0 and
        $missing_review == 0 and
        $failing_review == 0
      ),
      work_packages: $packages
    }'
}

sdd_feature_effective_phase_value() {
  local feature="$1"
  local dir="$SDD_FEATURE_ROOT/$feature"
  local raw_phase wp_snapshot active_wp active_wp_phase task_summary review_summary review verdict evidence_status

  raw_phase="$(sdd_detect_feature_phase_value "$feature")"
  [ -d "$dir" ] || { echo "$raw_phase"; return 0; }
  sdd_feature_has_work_packages "$dir" || { echo "$raw_phase"; return 0; }

  case "$raw_phase" in
    brief|design|research|plan|spec|no-feature)
      echo "$raw_phase"
      return 0
      ;;
  esac

  wp_snapshot="$(sdd_feature_wp_snapshot "$dir" || true)"
  if [ -n "$wp_snapshot" ]; then
    IFS=$'\t' read -r active_wp active_wp_phase _wp_count _wp_done _wp_active _wp_pending <<EOF
$wp_snapshot
EOF
    if [ "$active_wp_phase" = "scaffold" ]; then
      echo "plan-tasks"
      return 0
    fi
  fi

  task_summary="$(sdd_feature_task_summary_json "$dir")"
  if [ "$(printf '%s\n' "$task_summary" | jq -r '(.in_progress + .pending + .blocked) > 0')" = "true" ]; then
    echo "implement"
    return 0
  fi

  review_summary="$(sdd_feature_wp_review_summary_json "$dir")"
  if [ "$(printf '%s\n' "$review_summary" | jq -r '.ready_for_feature_review')" != "true" ]; then
    echo "review"
    return 0
  fi

  review="$dir/review.md"
  if [ ! -f "$review" ]; then
    echo "review"
    return 0
  fi

  verdict="$(sdd_frontmatter_value "$review" verdict || true)"
  evidence_status="$(sdd_frontmatter_value "$review" evidence_status || true)"
  if [ "$verdict" = "pass" ]; then
    if [ -z "$evidence_status" ] || [ "$evidence_status" = "sufficient" ]; then
      echo "close"
    else
      echo "review"
    fi
    return 0
  fi

  if [ "$verdict" = "fail" ] || [ "$verdict" = "reopened" ]; then
    echo "implement"
    return 0
  fi

  echo "review"
}

sdd_feature_effective_phase() {
  sdd_feature_effective_phase_value "$@"
}

sdd_detect_feature_phase_value() {
  local feature="$1"
  local dir="$SDD_FEATURE_ROOT/$feature"
  local brief spec research plan tasks review verdict evidence_status

  [ -d "$dir" ] || {
    echo "no-feature"
    return 0
  }

  brief="$dir/brief.md"
  spec="$dir/spec.md"
  research="$dir/research.md"
  plan="$dir/plan.md"
  tasks="$dir/tasks.md"
  review="$dir/review.md"

  if [ "$(sdd_profile "$dir")" = "lite" ]; then
    if ! sdd_lite_spec_content_is_ready "$spec"; then
      echo "spec"
      return 0
    fi

    if [ ! -f "$tasks" ] || ! sdd_tasks_file_has_approach_content "$tasks" || [ "$(sdd_count_task_headings "$tasks")" -eq 0 ]; then
      echo "spec"
      return 0
    fi

    if sdd_tasks_file_has_open_status "$tasks"; then
      echo "implement"
      return 0
    fi

    if [ ! -f "$review" ]; then
      echo "review"
      return 0
    fi

    verdict="$(sdd_frontmatter_value "$review" verdict || true)"
    evidence_status="$(sdd_frontmatter_value "$review" evidence_status || true)"
    if [ "$verdict" = "pass" ]; then
      if [ -z "$evidence_status" ] || [ "$evidence_status" = "sufficient" ]; then
        echo "close"
        return 0
      fi
      echo "review"
      return 0
    fi

    if [ "$verdict" = "fail" ] || [ "$verdict" = "reopened" ]; then
      echo "implement"
      return 0
    fi

    echo "review"
    return 0
  fi

  if [ ! -f "$brief" ]; then
    echo "brief"
    return 0
  fi

  if [ ! -f "$spec" ]; then
    if sdd_feature_artifact_is_ready "$brief"; then
      echo "design"
    else
      echo "brief"
    fi
    return 0
  fi

  if [ ! -f "$research" ]; then
    if sdd_feature_artifact_is_ready "$spec"; then
      echo "research"
    else
      echo "design"
    fi
    return 0
  fi

  if [ ! -f "$plan" ]; then
    if sdd_feature_artifact_is_ready "$research"; then
      echo "plan"
    else
      echo "research"
    fi
    return 0
  fi

  if [ ! -f "$tasks" ]; then
    if sdd_feature_artifact_is_ready "$plan"; then
      echo "plan-tasks"
    else
      echo "plan"
    fi
    return 0
  fi

  if sdd_tasks_file_has_open_status "$tasks"; then
    if ! sdd_tasks_file_is_execution_ready "$tasks"; then
      echo "plan-tasks"
      return 0
    fi
    echo "implement"
    return 0
  fi

  if [ ! -f "$review" ]; then
    if ! sdd_tasks_file_is_execution_ready "$tasks"; then
      echo "plan-tasks"
      return 0
    fi
    echo "review"
    return 0
  fi

  verdict="$(sdd_frontmatter_value "$review" verdict || true)"
  evidence_status="$(sdd_frontmatter_value "$review" evidence_status || true)"
  if [ "$verdict" = "pass" ]; then
    if [ -z "$evidence_status" ] || [ "$evidence_status" = "sufficient" ]; then
      echo "close"
      return 0
    fi
    echo "review"
    return 0
  fi

  if [ "$verdict" = "fail" ] || [ "$verdict" = "reopened" ]; then
    echo "implement"
    return 0
  fi

  echo "review"
}

sdd_selection_source() {
  local feature_id="$1"
  local feature_path="${2:-$feature_id}"
  local active_file="$SDD_FEATURE_ROOT/.active"
  local active_content=""

  if [ -f "$active_file" ]; then
    read -r active_content < "$active_file" 2>/dev/null || true
    if [ "$active_content" = "$feature_id" ] || [ "$active_content" = "$feature_path" ]; then
      printf 'selected\n'
      return 0
    fi
  fi

  printf 'auto\n'
}

sdd_auto_detect_feature() {
  local selected candidates first_candidate=""

  if [ ! -d "$SDD_FEATURE_ROOT" ]; then
    printf 'none\n'
    return 0
  fi

  if selected="$(sdd_selected_feature 2>/dev/null)"; then
    printf '%s\n' "$selected"
    return 0
  fi

  candidates="$(sdd_auto_feature_candidates)"
  while IFS= read -r first_candidate; do
    [ -n "$first_candidate" ] || continue
    printf '%s\n' "$first_candidate"
    return 0
  done <<< "$candidates"

  printf 'none\n'
}

# Resolve feature, phase, selection source, and work-package snapshot in one pass.
# Echoes:
#   feature<TAB>phase<TAB>source<TAB>wp_id<TAB>wp_phase<TAB>wp_count<TAB>wp_done<TAB>wp_active<TAB>wp_pending
sdd_feature_context_tsv() {
  local requested_feature="${1:-}"
  local feature="none" phase="brief" source="none"
  local feature_dir wp_snapshot=""
  local wp_id="none" wp_phase="none" wp_count="0" wp_done="0" wp_active="0" wp_pending="0"

  if [ -n "$requested_feature" ] && [ "$requested_feature" != "auto" ]; then
    [ -d "$SDD_FEATURE_ROOT/$requested_feature" ] || {
      printf 'none\tbrief\tnone\tnone\tnone\t0\t0\t0\t0\n'
      return 1
    }
    feature="$requested_feature"
    source="arg"
  else
    feature="$(sdd_auto_detect_feature)"
    if [ "$feature" = "none" ]; then
      printf 'none\tbrief\tnone\tnone\tnone\t0\t0\t0\t0\n'
      return 1
    fi
    source="$(sdd_selection_source "$feature")"
  fi

  phase="$(sdd_feature_phase "$feature")"
  feature_dir="$SDD_FEATURE_ROOT/$feature"
  wp_snapshot="$(sdd_feature_wp_snapshot "$feature_dir" || true)"
  if [ -n "$wp_snapshot" ]; then
    IFS=$'\t' read -r wp_id wp_phase wp_count wp_done wp_active wp_pending <<EOF
$wp_snapshot
EOF
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$feature" \
    "${phase:-brief}" \
    "$source" \
    "${wp_id:-none}" \
    "${wp_phase:-none}" \
    "${wp_count:-0}" \
    "${wp_done:-0}" \
    "${wp_active:-0}" \
    "${wp_pending:-0}"
}

sdd_selected_feature() {
  local active_file="$SDD_FEATURE_ROOT/.active"
  local selected=""

  [ -f "$active_file" ] || return 1
  read -r selected < "$active_file" 2>/dev/null || true
  [ -n "$selected" ] || return 1
  sdd_feature_ref_is_safe "$selected" || return 1
  [ -d "$SDD_FEATURE_ROOT/$selected" ] || return 1
  case "$selected" in
    */*) sdd_feature_path_is_feature "$selected" || return 1 ;;
  esac
  [ "$(sdd_feature_phase "$selected")" != "close" ] || return 1
  ! sdd_feature_is_inactive "$selected" || return 1

  printf '%s\n' "$selected"
}

sdd_feature_phase() {
  local feature="$1"
  sdd_detect_feature_phase_value "$feature"
}

# Feature lifecycle status, read from continuity.md frontmatter.
# Enum: active | completed | abandoned | superseded
# Defaults to "active" when continuity.md is missing or status is unset, so
# legacy features without an explicit field continue to be treated as live.
sdd_feature_status() {
  local feature="$1"
  local cont="$SDD_FEATURE_ROOT/$feature/continuity.md"
  local value=""

  if [ -f "$cont" ]; then
    value="$(sdd_frontmatter_value "$cont" status 2>/dev/null || true)"
  fi
  printf '%s\n' "${value:-active}"
}

# True (return 0) when the feature should be excluded from auto-detection.
# Inactive set: completed, abandoned, superseded.
sdd_feature_is_inactive() {
  case "$(sdd_feature_status "$1")" in
    completed|abandoned|superseded) return 0 ;;
    *) return 1 ;;
  esac
}

sdd_autonomy_is_on() {
  local feature="$1"
  local state_file="$SDD_FEATURE_ROOT/$feature/state.json"

  [ -f "$state_file" ] || return 1
  [ "$(jq -r '.autonomous // false' "$state_file" 2>/dev/null || printf 'false')" = "true" ]
}

sdd_profile() {
  local feature="$1"
  local state_file value

  if [ -d "$feature" ]; then
    state_file="$feature/state.json"
  else
    state_file="$SDD_FEATURE_ROOT/$feature/state.json"
  fi

  if [ ! -f "$state_file" ]; then
    printf 'full\n'
    return 0
  fi

  value="$(jq -r '.profile // "full"' "$state_file" 2>/dev/null || printf 'full')"
  case "$value" in
    lite|full|deep) printf '%s\n' "$value" ;;
    *) printf 'full\n' ;;
  esac
}

sdd_normalize_mode_input() {
  local mode="${1:-}"

  case "$mode" in
    lite|full|deep)
      printf '%s\n' "$mode"
      ;;
    normal|default)
      printf 'full\n'
      ;;
    *)
      printf 'Invalid mode: %s. Expected one of: lite, full, normal, default, deep.\n' "$mode" >&2
      return 1
      ;;
  esac
}

sdd_profile_display() {
  local profile="${1:-}"

  case "$profile" in
    full) printf 'normal\n' ;;
    lite|deep) printf '%s\n' "$profile" ;;
    *) printf '%s\n' "$profile" ;;
  esac
}

sdd_required_artifacts() {
  local feature="$1"

  case "$(sdd_profile "$feature")" in
    lite) printf 'spec tasks review\n' ;;
    deep) printf 'brief spec research plan tasks review\n' ;;
    *) printf 'brief spec research plan tasks review\n' ;;
  esac
}

sdd_required_artifacts_for_close() {
  local feature="$1"
  local feature_dir="$SDD_FEATURE_ROOT/$feature"
  local artifact artifacts=()

  for artifact in $(sdd_required_artifacts "$feature"); do
    if [ "$artifact" = "tasks" ] && sdd_feature_has_work_packages "$feature_dir"; then
      continue
    fi
    artifacts+=("$artifact")
  done

  printf '%s\n' "${artifacts[*]}"
}

sdd_autonomous_halt() {
  local reason="$1" uncertain="$2" inspect="$3" next="$4" avoid="$5"
  printf 'SDD autonomous halt: %s.\n' "$reason"
  printf 'Uncertain: %s.\n' "$uncertain"
  printf 'Inspect: %s.\n' "$inspect"
  printf 'Next: %s.\n' "$next"
  printf 'Avoid: %s.\n' "$avoid"
}

sdd_autonomy_halt_block() {
  local guide_file="$SDD_SKILL_DIR/references/autonomous-halts.md"
  [ -f "$guide_file" ] || return 0
  printf 'Autonomous halt criteria (references/autonomous-halts.md):\n'
  cat "$guide_file"
}

sdd_autonomy_halt_pointer() {
  printf 'Autonomy halt rules: references/autonomous-halts.md. Hard halt directives still apply when active.\n'
}

sdd_file_sha256() {
  local file="$1"

  [ -f "$file" ] || return 1

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return 0
  fi

  return 1
}

sdd_string_sha256() {
  local value="$1"

  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$value" | shasum -a 256 | awk '{print $1}'
    return 0
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$value" | sha256sum | awk '{print $1}'
    return 0
  fi

  return 1
}

sdd_artifact_normalize() {
  local file="$1"
  [ -f "$file" ] || return 1

  awk '
    BEGIN { in_frontmatter = 0; started = 0 }
    $0 == "---" {
      if (!started) {
        started = 1
        in_frontmatter = 1
        print
        next
      }
      if (in_frontmatter) {
        in_frontmatter = 0
        print
        next
      }
    }
    in_frontmatter && $0 ~ /^(created|updated|status|based_on):[[:space:]]*/ { next }
    { print }
  ' "$file"
}

sdd_artifact_rev() {
  local file="$1"
  local tmp hash=""

  [ -f "$file" ] || return 1

  tmp="$(mktemp)"
  if ! sdd_artifact_normalize "$file" > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi

  hash="$(sdd_file_sha256 "$tmp" 2>/dev/null || true)"
  rm -f "$tmp"

  [ -n "$hash" ] || return 1
  printf 'sha256:%s\n' "$hash"
}

sdd_feature_artifact_path_by_id() {
  local feature_dir="$1" artifact_id="$2"
  local candidate=""

  case "$artifact_id" in
    BRIEF-*) candidate="$feature_dir/brief.md" ;;
    SPEC-*) candidate="$feature_dir/spec.md" ;;
    RESEARCH-*) candidate="$feature_dir/research.md" ;;
    PLAN-*) candidate="$feature_dir/plan.md" ;;
    TASKS-*) candidate="$feature_dir/tasks.md" ;;
    REVIEW-*) candidate="$feature_dir/review.md" ;;
    SCRATCH-*) candidate="$feature_dir/scratchpad.md" ;;
    CONT-*) candidate="$feature_dir/continuity.md" ;;
    KB-*) candidate="$feature_dir/knowledge.md" ;;
    EPIC-*) candidate="$(dirname "$feature_dir")/EPIC.md" ;;
  esac

  if [ -n "$candidate" ] && [ -f "$candidate" ]; then
    if [ "$(sdd_frontmatter_value "$candidate" id 2>/dev/null || true)" = "$artifact_id" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi

  while IFS= read -r candidate; do
    [ -f "$candidate" ] || continue
    if [ "$(sdd_frontmatter_value "$candidate" id 2>/dev/null || true)" = "$artifact_id" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(find "$feature_dir" -type f -name '*.md' | LC_ALL=C sort)

  return 1
}

sdd_feature_profile_from_dir() {
  local feature_dir="$1"
  local feature_path profile

  [ -d "$feature_dir" ] || return 1

  feature_path="$(sdd_feature_path_from_dir "$feature_dir" 2>/dev/null || true)"
  if [ -n "$feature_path" ]; then
    profile="$(sdd_profile "$feature_path" 2>/dev/null || true)"
    [ -n "$profile" ] && {
      printf '%s\n' "$profile"
      return 0
    }
  fi

  profile="$(jq -r '.profile // empty' "$feature_dir/state.json" 2>/dev/null || true)"
  [ -n "$profile" ] || profile="$(sdd_frontmatter_value "$feature_dir/spec.md" profile 2>/dev/null || true)"
  [ -n "$profile" ] || profile="normal"
  printf '%s\n' "$profile"
}

sdd_feature_epic_anchor_path_from_dir() {
  local feature_dir="$1"
  local candidate profile

  [ -d "$feature_dir" ] || return 1

  for candidate in "$feature_dir/brief.md" "$feature_dir/spec.md"; do
    [ -f "$candidate" ] || continue
    if [ -n "$(sdd_frontmatter_value "$candidate" epic_entry 2>/dev/null || true)" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  profile="$(sdd_feature_profile_from_dir "$feature_dir" 2>/dev/null || true)"
  case "$profile" in
    lite) candidate="$feature_dir/spec.md" ;;
    *) candidate="$feature_dir/brief.md" ;;
  esac

  [ -f "$candidate" ] || return 1
  printf '%s\n' "$candidate"
}

sdd_feature_epic_entry_from_dir() {
  local feature_dir="$1"
  local anchor_path

  anchor_path="$(sdd_feature_epic_anchor_path_from_dir "$feature_dir" 2>/dev/null || true)"
  [ -n "$anchor_path" ] || return 0
  sdd_frontmatter_value "$anchor_path" epic_entry 2>/dev/null || true
}

sdd_stamp_based_on() {
  local artifact_path="$1"
  shift

  local artifact_dir feature_dir based_on_json='{}'
  local upstream_id upstream_path upstream_rev tmp

  [ -f "$artifact_path" ] || return 1

  artifact_dir="$(dirname "$artifact_path")"
  if [[ "$(basename "$artifact_dir")" == wp-* ]]; then
    feature_dir="$(dirname "$artifact_dir")"
  else
    feature_dir="$artifact_dir"
  fi

  for upstream_id in "$@"; do
    [ -n "$upstream_id" ] || continue
    upstream_path="$(sdd_feature_artifact_path_by_id "$feature_dir" "$upstream_id" 2>/dev/null || true)"
    [ -n "$upstream_path" ] || continue
    upstream_rev="$(sdd_artifact_rev "$upstream_path" 2>/dev/null || true)"
    [ -n "$upstream_rev" ] || continue
    based_on_json="$(printf '%s\n' "$based_on_json" | jq -c --arg id "$upstream_id" --arg rev "$upstream_rev" '. + {($id): $rev}')"
  done

  tmp="$(sdd_tmp_for_target "$artifact_path")" || return 1
  sdd_cleanup_push "$tmp"

  awk -v based_on_json="$based_on_json" '
    BEGIN { in_frontmatter = 0; started = 0; inserted = 0 }
    $0 == "---" {
      if (!started) {
        started = 1
        in_frontmatter = 1
        print
        next
      }
      if (in_frontmatter) {
        if (!inserted) {
          print "based_on: " based_on_json
          inserted = 1
        }
        in_frontmatter = 0
        print
        next
      }
    }
    in_frontmatter && $0 ~ /^based_on:[[:space:]]*/ {
      print "based_on: " based_on_json
      inserted = 1
      next
    }
    in_frontmatter && !inserted && $0 ~ /^related:[[:space:]]*$/ {
      print "based_on: " based_on_json
      inserted = 1
    }
    { print }
  ' "$artifact_path" > "$tmp" || {
    sdd_cleanup_file "$tmp"
    return 1
  }

  if ! sdd_atomic_replace "$tmp" "$artifact_path"; then
    sdd_cleanup_file "$tmp"
    return 1
  fi
}

sdd_stamp_epic_entry() {
  local brief_path="$1" entry_id="$2"
  local tmp

  [ -f "$brief_path" ] || return 1
  [ -n "$entry_id" ] || return 1

  tmp="$(sdd_tmp_for_target "$brief_path")" || return 1
  sdd_cleanup_push "$tmp"

  awk -v entry_id="$entry_id" '
    BEGIN { in_frontmatter = 0; started = 0; inserted = 0 }
    $0 == "---" {
      if (!started) {
        started = 1
        in_frontmatter = 1
        print
        next
      }
      if (in_frontmatter) {
        if (!inserted) {
          print "epic_entry: " entry_id
          inserted = 1
        }
        in_frontmatter = 0
        print
        next
      }
    }
    in_frontmatter && $0 ~ /^epic_entry:[[:space:]]*/ {
      print "epic_entry: " entry_id
      inserted = 1
      next
    }
    in_frontmatter && !inserted && $0 ~ /^related:[[:space:]]*$/ {
      print "epic_entry: " entry_id
      inserted = 1
    }
    { print }
  ' "$brief_path" > "$tmp" || {
    sdd_cleanup_file "$tmp"
    return 1
  }

  if ! sdd_atomic_replace "$tmp" "$brief_path"; then
    sdd_cleanup_file "$tmp"
    return 1
  fi
}

sdd_rubric_supported_artifacts() {
  printf '%s\n' brief spec research plan review
}

sdd_artifact_path_for() {
  local feature="$1" artifact="$2"
  case "$artifact" in
    brief|spec|research|plan|review)
      printf '%s/%s/%s.md\n' "$SDD_FEATURE_ROOT" "$feature" "$artifact"
      ;;
    *)
      return 1
      ;;
  esac
}

sdd_rubric_path_for() {
  # Resolves a rubric file path by artifact name. Returns paths for all six
  # authored rubrics including tasks; active-advisor coverage is a separate
  # concern (see sdd_rubric_supported_artifacts — iteration 1 covers five).
  # The tasks rubric is path-resolvable because Hook X uses it as next_rubric
  # context at the `plan tasks` phase boundary.
  local artifact="$1"
  case "$artifact" in
    brief|spec|research|plan|review|tasks)
      printf '%s/references/rubrics/%s.md\n' "$SDD_SKILL_DIR" "$artifact"
      ;;
    *)
      return 1
      ;;
  esac
}

sdd_filter_rubric_for_profile() {
  local rubric_path="$1" profile="$2"

  awk -v profile="$profile" '
    function flush_block() {
      if (!in_block) return
      if (!skip_block) printf "%s", block
      block = ""
      in_block = 0
      skip_block = 0
    }

    /^- [*][*]/ {
      flush_block()
      in_block = 1
      block = $0 ORS
      next
    }

    in_block {
      block = block $0 ORS
      if ($0 ~ /^[[:space:]]*applies-to:[[:space:]]*deep[[:space:]]*$/ && profile != "deep") {
        skip_block = 1
      }
      next
    }

    {
      print
    }

    END {
      flush_block()
    }
  ' "$rubric_path"
}

sdd_rubric_text_for_feature() {
  local artifact="$1" feature="$2"
  local rubric_path profile

  rubric_path="$(sdd_rubric_path_for "$artifact")" || return 1
  [ -r "$rubric_path" ] || return 1
  profile="$(sdd_profile "$feature")"
  sdd_filter_rubric_for_profile "$rubric_path" "$profile"
}

sdd_artifact_for_phase() {
  local phase="$1"
  case "$phase" in
    brief) echo "brief" ;;
    design) echo "spec" ;;
    research) echo "research" ;;
    plan|plan-tasks|implement) echo "plan" ;;
    review|close) echo "review" ;;
    *) echo "brief" ;;
  esac
}

sdd_feature_has_task_status() {
  local feature="$1" status="$2"
  local feature_dir="$SDD_FEATURE_ROOT/$feature"
  local wp_tasks

  [ -d "$feature_dir" ] || return 1

  if [ -f "$feature_dir/tasks.md" ] && sdd_task_file_has_status "$feature_dir/tasks.md" "$status"; then
    return 0
  fi

  for wp_tasks in "$feature_dir"/wp-*/tasks.md; do
    [ -f "$wp_tasks" ] || continue
    if sdd_task_file_has_status "$wp_tasks" "$status"; then
      return 0
    fi
  done

  return 1
}

sdd_auto_feature_candidates() {
  local candidate_list=()
  local feature_path="" phase=""

  if [ ! -d "$SDD_FEATURE_ROOT" ]; then
    return 0
  fi

  while IFS= read -r feature_path; do
    [ -n "$feature_path" ] || continue
    sdd_feature_is_inactive "$feature_path" && continue
    if sdd_feature_has_task_status "$feature_path" "in-progress"; then
      candidate_list+=("$feature_path")
    fi
  done <<EOF
$(sdd_iter_resolvable_feature_paths)
EOF
  if [ "${#candidate_list[@]}" -gt 0 ]; then
    printf '%s\n' "${candidate_list[@]}"
    return 0
  fi

  candidate_list=()
  while IFS= read -r feature_path; do
    [ -n "$feature_path" ] || continue
    sdd_feature_is_inactive "$feature_path" && continue
    if sdd_feature_has_task_status "$feature_path" "pending"; then
      candidate_list+=("$feature_path")
    fi
  done <<EOF
$(sdd_iter_resolvable_feature_paths)
EOF
  if [ "${#candidate_list[@]}" -gt 0 ]; then
    printf '%s\n' "${candidate_list[@]}"
    return 0
  fi

  candidate_list=()
  while IFS= read -r feature_path; do
    [ -n "$feature_path" ] || continue
    sdd_feature_is_inactive "$feature_path" && continue
    phase="$(sdd_feature_phase "$feature_path")"
    if [ "$phase" != "close" ]; then
      candidate_list+=("$feature_path")
    fi
  done <<EOF
$(sdd_iter_resolvable_feature_paths)
EOF

  if [ "${#candidate_list[@]}" -gt 0 ]; then
    printf '%s\n' "${candidate_list[@]}"
  fi
}

sdd_has_active_feature() {
  local feature_path="" phase=""

  if [ ! -d "$SDD_FEATURE_ROOT" ]; then
    return 1
  fi

  while IFS= read -r feature_path; do
    [ -n "$feature_path" ] || continue
    sdd_feature_is_inactive "$feature_path" && continue
    phase="$(sdd_feature_phase "$feature_path")"
    [ "$phase" = "close" ] && continue
    return 0
  done <<EOF
$(sdd_iter_resolvable_feature_paths)
EOF

  return 1
}

# Resolve a feature using the shared precedence rules.
# Sets:
#   SDD_RESOLVED_FEATURE       legacy basename ID (0084-name)
#   SDD_RESOLVED_FEATURE_PATH  feature-root-relative path (group/0084-name)
#   SDD_RESOLVED_FEATURE_DIR   filesystem path under $SDD_FEATURE_ROOT
#   SDD_RESOLVED_FEATURE_GROUP dirname of path, empty for root-level features
#   SDD_RESOLUTION_SOURCE      arg|selected|auto|none
#   SDD_RESOLUTION_STATUS      ok|none|not_found|ambiguous
#   SDD_RESOLUTION_CANDIDATES  newline-delimited feature paths when ambiguous
sdd_resolve_feature_target() {
  local requested="${1:-}"
  local strict_auto="${2:-0}"
  local selected=""
  local candidates=""
  local candidate_count=0
  local first_candidate=""
  local path=""
  local feature_dir=""
  local feature_id=""
  local matches=""
  local match_count=0
  local match_path=""
  local source="arg"

  sdd_reset_feature_resolution_state

  if [ -n "$requested" ] && [ "$requested" != "auto" ]; then
    sdd_feature_ref_is_safe "$requested" || {
      SDD_RESOLUTION_STATUS="not_found"
      return 1
    }

    case "$requested" in
      */*)
        if sdd_feature_path_is_feature "$requested"; then
          sdd_set_resolved_feature_path "$requested" "arg"
          return 0
        fi
        SDD_RESOLUTION_STATUS="not_found"
        return 1
        ;;
    esac

    if [ -d "$SDD_FEATURE_ROOT/$requested" ] && ! sdd_feature_path_has_wp_segment "$requested"; then
      case "$requested" in
        [0-9][0-9][0-9][0-9]-*) matches="$requested" ;;
      esac
    fi

    if [ -z "$matches" ] && [ -d "$SDD_FEATURE_ROOT/$requested" ] && sdd_feature_path_is_feature "$requested"; then
      matches="$requested"
    fi

    for feature_dir in "$SDD_FEATURE_ROOT"/${requested}-*/; do
      [ -d "$feature_dir" ] || continue
      path="$(sdd_feature_path_from_dir "$feature_dir" 2>/dev/null || true)"
      [ -n "$path" ] || continue
      [ "$path" = "$requested" ] && continue
      sdd_feature_path_has_wp_segment "$path" && continue
      case "$(sdd_feature_path_id "$path")" in
        "$requested"-*) ;;
        *) continue ;;
      esac
      if [ -z "$matches" ]; then
        matches="$path"
      elif ! printf '%s\n' "$matches" | grep -Fx -- "$path" >/dev/null 2>&1; then
        matches="${matches}
$path"
      fi
    done

    while IFS= read -r path; do
      [ -n "$path" ] || continue
      feature_id="$(sdd_feature_path_id "$path")"
      case "$feature_id" in
        "$requested"|"$requested"-*) ;;
        *) continue ;;
      esac
      if [ -z "$matches" ]; then
        matches="$path"
      elif ! printf '%s\n' "$matches" | grep -Fx -- "$path" >/dev/null 2>&1; then
        matches="${matches}
$path"
      fi
    done <<EOF
$(sdd_iter_feature_paths)
EOF

    while IFS= read -r match_path; do
      [ -n "$match_path" ] || continue
      match_count=$((match_count + 1))
      [ -n "$first_candidate" ] || first_candidate="$match_path"
    done <<EOF
$matches
EOF

    if [ "$match_count" -eq 1 ]; then
      sdd_set_resolved_feature_path "$first_candidate" "arg"
      return 0
    fi

    if [ "$match_count" -gt 1 ]; then
      SDD_RESOLUTION_CANDIDATES="$matches"
      SDD_RESOLUTION_SOURCE="arg"
      SDD_RESOLUTION_STATUS="ambiguous"
      return 1
    fi

    SDD_RESOLUTION_STATUS="not_found"
    return 1
  fi

  if [ -z "$requested" ] || [ "$requested" = "auto" ]; then
    if selected="$(sdd_selected_feature 2>/dev/null)"; then
      sdd_set_resolved_feature_path "$selected" "selected"
      return 0
    fi
  fi

  candidates="$(sdd_auto_feature_candidates)"
  if [ -z "$candidates" ]; then
    SDD_RESOLUTION_STATUS="none"
    return 1
  fi

  while IFS= read -r first_candidate; do
    [ -n "$first_candidate" ] || continue
    candidate_count=$((candidate_count + 1))
    [ -n "$SDD_RESOLVED_FEATURE_PATH" ] || sdd_set_resolved_feature_path "$first_candidate" "auto"
  done <<< "$candidates"

  if [ "$candidate_count" -gt 1 ] && [ "$strict_auto" = "1" ]; then
    SDD_RESOLUTION_CANDIDATES="$candidates"
    SDD_RESOLVED_FEATURE=""
    SDD_RESOLVED_FEATURE_PATH=""
    SDD_RESOLVED_FEATURE_DIR=""
    SDD_RESOLVED_FEATURE_GROUP=""
    SDD_RESOLUTION_SOURCE="auto"
    SDD_RESOLUTION_STATUS="ambiguous"
    return 1
  fi

  source="auto"
  [ -z "$requested" ] && source="auto"
  SDD_RESOLUTION_SOURCE="$source"
  SDD_RESOLUTION_STATUS="ok"
  return 0
}

sdd_effective_on_exists() {
  if [ -n "${SDD_ON_EXISTS:-}" ]; then
    printf '%s\n' "$SDD_ON_EXISTS"
  elif sdd_is_machine_mode; then
    printf 'fail\n'
  else
    printf 'prompt\n'
  fi
}

# Echoes create|overwrite|skip when the caller may proceed.
# Returns SDD_EXIT_CONFLICT when the policy blocks the action.
sdd_existing_path_action() {
  local path="$1" label="${2:-$1}"
  local policy answer=""

  if [ ! -e "$path" ]; then
    printf 'create\n'
    return 0
  fi

  policy="$(sdd_effective_on_exists)"
  case "$policy" in
    overwrite)
      printf 'overwrite\n'
      return 0
      ;;
    skip)
      printf 'skip\n'
      return 0
      ;;
    fail)
      return "$SDD_EXIT_CONFLICT"
      ;;
    prompt)
      printf 'Warning: %s already exists. Overwrite? (y/n)\n' "$label" >&2
      read -r answer
      if [ "$answer" = "y" ]; then
        printf 'overwrite\n'
      else
        printf 'skip\n'
      fi
      return 0
      ;;
  esac

  return "$SDD_EXIT_CONFLICT"
}

# Detect active feature and phase using shared library state.
# Echoes "feature|phase". Returns 1 if no active feature.
sdd_detect_feature_phase() {
  local context feature phase
  context="$(sdd_feature_context_tsv "${1:-}" || true)"
  IFS=$'\t' read -r feature phase _source _wp_id _wp_phase _wp_count _wp_done _wp_active _wp_pending <<EOF
$context
EOF
  if [ -z "$feature" ] || [ "$feature" = "none" ]; then
    echo "none|${phase:-brief}"
    return 1
  fi
  echo "${feature}|${phase}"
}

# Count lines matching a status pattern in a tasks file.
# Returns 0 if file doesn't exist or pattern not found.
sdd_count_task_status() {
  local file="$1" status="$2"
  [ -f "$file" ] || { echo "0"; return; }
  awk -v status="$status" '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && $0 == "> Status: " status { count++ }
    END { print count + 0 }
  ' "$file"
}

# Count task headings outside fenced code blocks.
sdd_count_task_headings() {
  local file="$1"
  [ -f "$file" ] || { echo "0"; return; }
  awk '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^## T-[0-9]+:/ { count++ }
    END { print count + 0 }
  ' "$file"
}

# Classify feature continuity content while ignoring generated scaffolding.
# Emits: empty | partial | filled. Defaults to filled on missing/parse error.
sdd_continuity_state() {
  local file="$1" bytes
  [ -f "$file" ] || { echo "filled"; return 0; }

  bytes="$(
    awk '
      BEGIN {
        in_frontmatter = 0
        frontmatter_started = 0
        frontmatter_closed = 0
        in_code = 0
        in_auto = 0
        bytes = 0
      }
      NR == 1 && $0 == "---" {
        in_frontmatter = 1
        frontmatter_started = 1
        next
      }
      in_frontmatter && $0 == "---" {
        in_frontmatter = 0
        frontmatter_closed = 1
        next
      }
      in_frontmatter { next }
      $0 ~ /^```/ {
        in_code = !in_code
        next
      }
      in_code { next }
      $0 == "<!-- SDD-AUTO-START -->" {
        in_auto = 1
        next
      }
      $0 == "<!-- SDD-AUTO-END -->" {
        in_auto = 0
        next
      }
      in_auto { next }
      /^[[:space:]]*<!--.*-->[[:space:]]*$/ { next }
      /^#+[[:space:]]+/ { next }
      {
        line = $0
        gsub(/[[:space:]]/, "", line)
        bytes += length(line)
      }
      END {
        if ((frontmatter_started && !frontmatter_closed) || in_code || in_auto) {
          print "__SDD_PARSE_ERROR__"
        } else {
          print bytes + 0
        }
      }
    ' "$file" 2>/dev/null
  )" || { echo "filled"; return 0; }

  case "$bytes" in
    __SDD_PARSE_ERROR__|''|*[!0-9]*)
      echo "filled"
      ;;
    *)
      if [ "$bytes" -lt 100 ]; then
        echo "empty"
      elif [ "$bytes" -lt 400 ]; then
        echo "partial"
      else
        echo "filled"
      fi
      ;;
  esac
}

# Classify feature knowledge content by K-entry count.
# Emits: empty | partial | filled. Defaults to filled on missing/parse error.
sdd_knowledge_state() {
  local file="$1" count
  [ -f "$file" ] || { echo "filled"; return 0; }

  count="$(
    awk '
      BEGIN {
        in_frontmatter = 0
        frontmatter_started = 0
        frontmatter_closed = 0
        in_code = 0
      }
      NR == 1 && $0 == "---" {
        in_frontmatter = 1
        frontmatter_started = 1
        next
      }
      in_frontmatter && $0 == "---" {
        in_frontmatter = 0
        frontmatter_closed = 1
        next
      }
      in_frontmatter { next }
      $0 ~ /^```/ {
        in_code = !in_code
        next
      }
      in_code { next }
      /^[[:space:]]*<!--.*-->[[:space:]]*$/ { next }
      /^- K-[0-9][0-9][0-9]:/ || /^- \*\*K-[0-9][0-9][0-9]/ || /^### K-[0-9][0-9][0-9]:/ {
        if (match($0, /K-[0-9][0-9][0-9]/)) {
          id = substr($0, RSTART, RLENGTH)
          seen[id] = 1
        }
      }
      END {
        if ((frontmatter_started && !frontmatter_closed) || in_code) {
          print "__SDD_PARSE_ERROR__"
        } else {
          count = 0
          for (id in seen) count++
          print count + 0
        }
      }
    ' "$file" 2>/dev/null
  )" || { echo "filled"; return 0; }

  case "$count" in
    __SDD_PARSE_ERROR__|''|*[!0-9]*)
      echo "filled"
      ;;
    0)
      echo "empty"
      ;;
    1|2)
      echo "partial"
      ;;
    *)
      echo "filled"
      ;;
  esac
}

# Normalize an agent type into the dispatch role name used by worker docs.
sdd_normalize_agent_role() {
  case "$1" in
    sdd-implementer|implementer) echo "implementer" ;;
    sdd-spec-reviewer|spec-reviewer) echo "spec-reviewer" ;;
    sdd-quality-reviewer|quality-reviewer) echo "quality-reviewer" ;;
    sdd-research-scout|research-scout) echo "research-scout" ;;
    sdd-plan-drafter|plan-drafter) echo "plan-drafter" ;;
    *) echo "$1" ;;
  esac
}

sdd_worker_role_is_supported() {
  case "$1" in
    implementer|spec-reviewer|quality-reviewer|research-scout|plan-drafter) return 0 ;;
    *) return 1 ;;
  esac
}

sdd_worker_dispatch_id_is_safe() {
  case "$1" in
    ""|*[^A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

sdd_worker_default_permission_mode() {
  local provider="$1" phase="$2"
  case "$provider:$phase" in
    codex:implement) printf 'read-only\n' ;;
    codex:*) printf 'read-only\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

sdd_worker_permission_is_write() {
  case "$1" in
    write|read-write|workspace-write|full-access|danger-full-access) return 0 ;;
    *) return 1 ;;
  esac
}

sdd_worker_dispatch_policy_json() {
  local provider="$1" phase="$2" permission_mode="$3" dispatch_json="$4"
  local task_id files_count missing_json allowed_write_scope

  case "$provider:$phase" in
    codex:brief|codex:close)
      jq -nc \
        --arg provider "$provider" \
        --arg phase "$phase" \
        --arg permission_mode "$permission_mode" \
        '{
          ok: false,
          error_type: "precondition",
          message: ("phase-policy: " + $provider + " dispatch is not allowed during " + $phase + " phase"),
          details: {
            policy: "phase_policy",
            provider: $provider,
            phase: $phase,
            permission_mode: $permission_mode
          }
        }'
      return 0
      ;;
  esac

  if [ "$provider" = "codex" ] && [ "$phase" = "implement" ] && sdd_worker_permission_is_write "$permission_mode"; then
    task_id="$(printf '%s\n' "$dispatch_json" | jq -r '.task.id // empty' 2>/dev/null)"
    files_count="$(printf '%s\n' "$dispatch_json" | jq -r '.files_in_scope | length' 2>/dev/null)"
    [ -n "$files_count" ] || files_count=0
    missing_json="$(jq -nc '[]')"
    if [ -z "$task_id" ]; then
      missing_json="$(printf '%s\n' "$missing_json" | jq -c '. + ["active_task"]')"
    fi
    if [ "$files_count" -eq 0 ]; then
      missing_json="$(printf '%s\n' "$missing_json" | jq -c '. + ["file_scope"]')"
    fi
    if [ "$missing_json" != "[]" ]; then
      jq -nc \
        --arg provider "$provider" \
        --arg phase "$phase" \
        --arg permission_mode "$permission_mode" \
        --argjson missing "$missing_json" \
        '{
          ok: false,
          error_type: "precondition",
          message: "implement write dispatch requires active task and explicit file scope",
          details: {
            policy: "implement_write_scope",
            provider: $provider,
            phase: $phase,
            permission_mode: $permission_mode,
            missing: $missing
          }
        }'
      return 0
    fi
  fi

  allowed_write_scope='[]'
  if [ "$provider" = "codex" ] && [ "$phase" = "implement" ] && sdd_worker_permission_is_write "$permission_mode"; then
    allowed_write_scope="$(printf '%s\n' "$dispatch_json" | jq -c '.files_in_scope // []')"
  fi

  jq -nc \
    --arg provider "$provider" \
    --arg phase "$phase" \
    --arg permission_mode "$permission_mode" \
    --argjson allowed_write_scope "$allowed_write_scope" \
    --argjson write_allowed "$(sdd_worker_permission_is_write "$permission_mode" && printf 'true' || printf 'false')" \
    '{
      ok: true,
      policy: "allowed",
      provider: $provider,
      phase: $phase,
      permission_mode: $permission_mode,
      write_allowed: $write_allowed,
      allowed_write_scope: $allowed_write_scope
    }'
}

sdd_worker_apply_policy_metadata() {
  local dispatch_json="$1" policy_json="$2"

  printf '%s\n' "$dispatch_json" | jq -c \
    --argjson policy "$policy_json" \
    '
      . + {
        policy: {
          name: ($policy.policy // "allowed"),
          phase: ($policy.phase // .phase),
          permission_mode: ($policy.permission_mode // null),
          write_allowed: ($policy.write_allowed // false),
          allowed_write_scope: ($policy.allowed_write_scope // [])
        }
      }
    '
}

sdd_codex_preflight_json() {
  local fake="${SDD_CODEX_FAKE_PREFLIGHT:-}" bin="${SDD_CODEX_BIN:-codex}" bin_path=""

  case "$fake" in
    ok|pass|available|1|true|TRUE|yes|YES)
      jq -nc --arg bin "$bin" '{
        ok: true,
        provider: "codex",
        status: "available",
        source: "fake",
        bin: $bin
      }'
      return 0
      ;;
    fail|failure|unavailable|0|false|FALSE|no|NO)
      jq -nc --arg bin "$bin" '{
        ok: false,
        provider: "codex",
        status: "unavailable",
        source: "fake",
        error: {
          type: "provider_unavailable",
          message: "Codex provider preflight failed",
          details: {
            provider: "codex",
            bin: $bin,
            source: "fake"
          }
        }
      }'
      return 1
      ;;
  esac

  if bin_path="$(command -v "$bin" 2>/dev/null)"; then
    jq -nc --arg bin "$bin" --arg path "$bin_path" '{
      ok: true,
      provider: "codex",
      status: "available",
      source: "path",
      bin: $bin,
      path: $path
    }'
    return 0
  fi

  jq -nc --arg bin "$bin" '{
    ok: false,
    provider: "codex",
    status: "unavailable",
    source: "path",
    error: {
      type: "provider_unavailable",
      message: "Codex provider is unavailable",
      details: {
        provider: "codex",
        bin: $bin,
        source: "path"
      }
    }
  }'
  return 1
}

sdd_codex_result_validation_json() {
  local result_json="$1" dispatch_json="$2"

  jq -nc \
    --argjson result "$result_json" \
    --argjson dispatch "$dispatch_json" \
    '
      def status_ok($role; $status):
        if ($role == "spec-reviewer" or $role == "quality-reviewer") then
          ($status | test("^(PASS|FAIL|NEEDS_CONTEXT)$"))
        else
          ($status | test("^(DONE|DONE_WITH_CONCERNS|BLOCKED|NEEDS_CONTEXT)$"))
        end;

      def changed_path:
        if type == "string" then .
        elif type == "object" then (.path // "")
        else ""
        end;

      ($result.role // "") as $role
      | ($result.status // "") as $status
      | ($dispatch.dispatch_id // "") as $dispatch_id
      | ($dispatch.role // "") as $dispatch_role
      | ($dispatch.files_in_scope // [] | map(.path // "")) as $scope_paths
      | [
          (if ($result.schema_version // "") != "sdd-result-v1" then "schema_version must be sdd-result-v1" else empty end),
          (if ($result.dispatch_id // "") != $dispatch_id then "dispatch_id must match dispatch record " + $dispatch_id else empty end),
          (if ($result.provider // "") != "codex" then "provider must be codex" else empty end),
          (if $role != $dispatch_role then "role must match dispatch role " + $dispatch_role else empty end),
          (if $status == "" then "status is required" elif (status_ok($role; $status) | not) then "status is invalid for role " + $role else empty end),
          (if ($result | has("notes")) and (($result.notes | type) != "array") then "notes must be an array" else empty end),
          (if ($result | has("follow_up_recommendations")) and (($result.follow_up_recommendations | type) != "array") then "follow_up_recommendations must be an array" else empty end),
          (if ($result | has("recommendations")) and (($result.recommendations | type) != "array") then "recommendations must be an array" else empty end),
          (if $role == "implementer" and ((($result.task // null) | type) != "object" or ($result.task.id // "") == "") then "task must be an object with id field" else empty end),
          (if $role == "implementer" and (($result.files_changed | type) != "array") then "files_changed must be an array for implementer results" else empty end),
          (if $role == "implementer" and ((($result.verification // null) | type) != "object") then "verification must be an object" else empty end),
          (if ($role == "spec-reviewer" or $role == "quality-reviewer") and (($result.scope // "") == "") then "scope is required for reviewer results" else empty end),
          (if ($role == "spec-reviewer" or $role == "quality-reviewer") and (($result.findings | type) != "array") then "findings must be an array" else empty end),
          (if ($role == "spec-reviewer" or $role == "quality-reviewer") and (($result.verdict // "") == "") then "verdict is required for reviewer results" else empty end),
          (if $role == "research-scout" and (($result.scope // "") == "") then "scope is required for research-scout results" else empty end),
          (if $role == "research-scout" and (($result.findings | type) != "array") then "findings must be an array for research-scout results" else empty end),
          (if $role == "research-scout" and ((($result.confidence // null) | type) != "object") then "confidence must be an object for research-scout results" else empty end),
          (if $role == "research-scout" and (($result.files_discovered | type) != "array") then "files_discovered must be an array for research-scout results" else empty end),
          (if $role == "plan-drafter" and (($result.scope // "") == "") then "scope is required for plan-drafter results" else empty end),
          (if $role == "plan-drafter" and (($result.proposed_decisions | type) != "array") then "proposed_decisions must be an array for plan-drafter results" else empty end),
          (if $role == "plan-drafter" and (($result.proposed_tasks | type) != "array") then "proposed_tasks must be an array for plan-drafter results" else empty end),
          (if $role == "implementer" and (((($result.files_changed // []) | map(changed_path) | map(select(. != ""))) - $scope_paths) | length) > 0
            then "files_changed contains paths outside dispatch file scope"
            else empty
           end)
        ] as $errors
      | if ($errors | length) > 0 then
          {
            ok: false,
            error_type: "validation",
            message: "Codex result validation failed",
            details: {
              provider: "codex",
              dispatch_id: $dispatch_id,
              role: $dispatch_role,
              errors: $errors
            }
          }
        else
          {
            ok: true,
            provider: "codex",
            dispatch_id: $dispatch_id,
            role: $dispatch_role,
            support_only: (($result.provider // "") == "codex" and ($dispatch_role == "spec-reviewer" or $dispatch_role == "quality-reviewer")),
            result: $result
          }
        end
    '
}

sdd_codex_template_for_role() {
  local role="$1"
  role="$(sdd_normalize_agent_role "$role")"
  case "$role" in
    research-scout) printf 'research\n' ;;
    plan-drafter) printf 'plan\n' ;;
    implementer) printf 'implement\n' ;;
    spec-reviewer|quality-reviewer) printf 'review\n' ;;
    *) return 1 ;;
  esac
}

sdd_codex_render_template() {
  local template_file="$1" dispatch_packet="$2" custom_task_text="$3"
  local feature="$4" phase="$5" role="$6" dispatch_id="$7" permission_mode="$8"
  local line

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "{{SDD_DISPATCH_PACKET}}")
        printf '%s\n' "$dispatch_packet"
        ;;
      "{{CUSTOM_TASK}}")
        if [ -n "$custom_task_text" ]; then
          printf '%s\n' "$custom_task_text"
        else
          printf 'No custom operator task was supplied.\n'
        fi
        ;;
      *)
        line="${line//\{\{FEATURE\}\}/$feature}"
        line="${line//\{\{PHASE\}\}/$phase}"
        line="${line//\{\{ROLE\}\}/$role}"
        line="${line//\{\{DISPATCH_ID\}\}/$dispatch_id}"
        line="${line//\{\{PERMISSION_MODE\}\}/$permission_mode}"
        printf '%s\n' "$line"
        ;;
    esac
  done < "$template_file"
}

sdd_worker_enrich_dispatch_record() {
  local dispatch_json="$1" provider="$2" permission_mode="$3"
  local prompt_template="${4:-}" prompt_path="${5:-}" prompt_hash="${6:-}"
  local custom_task_source="${7:-none}" custom_task_text="${8:-}"
  local provider_mode="${9:-record-only}"
  local prompt_status="${10:-not_rendered}"

  printf '%s\n' "$dispatch_json" | jq -c \
    --arg provider "$provider" \
    --arg permission_mode "$permission_mode" \
    --arg prompt_template "$prompt_template" \
    --arg prompt_path "$prompt_path" \
    --arg prompt_hash "$prompt_hash" \
    --arg custom_task_source "$custom_task_source" \
    --arg custom_task_text "$custom_task_text" \
    --arg provider_mode "$provider_mode" \
    --arg prompt_status "$prompt_status" \
    '
      . + {
        provider: $provider,
        permission_mode: $permission_mode,
        prompt: {
          status: $prompt_status,
          template: (if $prompt_template == "" then null else $prompt_template end),
          path: (if $prompt_path == "" then null else $prompt_path end),
          content_hash: (if $prompt_hash == "" then null else $prompt_hash end)
        },
        custom_task: {
          source: $custom_task_source,
          text: $custom_task_text,
          bytes: ($custom_task_text | length)
        },
        runtime: {
          provider: $provider,
          mode: $provider_mode
        }
      }
    '
}

# Read the full heading for a specific task.
sdd_task_heading() {
  local tasks_file="$1" task_id="$2"
  [ -f "$tasks_file" ] || return 1
  awk -v tid="$task_id" '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && index($0, "## " tid ":") == 1 {
      print substr($0, 4)
      exit
    }
  ' "$tasks_file"
}

# Read a metadata line from a task block (e.g. Implements, Phase, Files).
sdd_task_field_value() {
  local tasks_file="$1" task_id="$2" field="$3"
  [ -f "$tasks_file" ] || return 1
  awk -v tid="$task_id" -v field="$field" '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^## T-[0-9]+:/ {
      if (in_task) exit
      in_task = (index($0, "## " tid ":") == 1)
      next
    }
    !in_fence && in_task && $0 ~ "^> " field ": " {
      sub("^> " field ": ", "", $0)
      print
      exit
    }
  ' "$tasks_file"
}

# Read the body of a markdown section from a task block.
sdd_task_section_body() {
  local tasks_file="$1" task_id="$2" section="$3"
  [ -f "$tasks_file" ] || return 1
  awk -v tid="$task_id" -v section="$section" '
    /^```/ {
      if (in_task && in_section) print
      in_fence = !in_fence
      next
    }
    !in_fence && /^## T-[0-9]+:/ {
      if (in_task && in_section) exit
      in_task = (index($0, "## " tid ":") == 1)
      in_section = 0
      next
    }
    !in_fence && in_task && /^### / {
      if (in_section) exit
      if ($0 == "### " section) {
        in_section = 1
        next
      }
    }
    in_task && in_section { print }
  ' "$tasks_file"
}

# Extract a task verification command, preserving multiline fenced blocks.
sdd_task_verification_command() {
  local tasks_file="$1" task_id="$2"
  [ -f "$tasks_file" ] || return 1

  local inline body command=""
  inline="$(sdd_task_field_value "$tasks_file" "$task_id" "Verification" || true)"
  if [ -n "$inline" ]; then
    printf '%s\n' "$inline"
    return 0
  fi

  body="$(sdd_task_section_body "$tasks_file" "$task_id" "Verification" || true)"
  [ -n "$body" ] || return 1

  command="$(printf '%s\n' "$body" | awk '
    /^```/ {
      if (in_fence) exit
      in_fence = 1
      next
    }
    in_fence { print }
  ')"

  if [ -z "$command" ]; then
    command="$(printf '%s\n' "$body" | sed '/^[[:space:]]*$/d')"
  fi

  [ -n "$command" ] || return 1
  printf '%s\n' "$command"
}

sdd_task_lint_finding_json() {
  local rule="$1" severity="$2" task_id="$3" message="$4" suggestion="$5" path="${6:-}" detail="${7:-}"
  jq -nc \
    --arg rule "$rule" \
    --arg severity "$severity" \
    --arg task "$task_id" \
    --arg message "$message" \
    --arg suggestion "$suggestion" \
    --arg path "$path" \
    --arg detail "$detail" \
    '{
      rule: $rule,
      severity: $severity,
      task: $task,
      message: $message,
      suggestion: $suggestion
    }
    + (if $path == "" then {} else {path: $path} end)
    + (if $detail == "" then {} else {detail: $detail} end)'
}

sdd_task_lint_is_static_script_path() {
  local script_path="$1"
  [ -n "$script_path" ] || return 1
  case "$script_path" in
    -*|http://*|https://*) return 1 ;;
  esac
  if printf '%s\n' "$script_path" | grep -Eq '[$*?`<>()|;]'; then
    return 1
  fi
  case "$script_path" in
    *.sh) return 0 ;;
    *) return 1 ;;
  esac
}

sdd_task_lint_shell_words() {
  local command="$1"
  printf '%s\n' "$command" | awk '
    BEGIN { quoted = 0 }
    function emit() {
      if (tok != "") {
        print quoted "\t" tok
        tok = ""
        quoted = 0
      }
    }
    {
      line = $0
      for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        n = substr(line, i + 1, 1)

        if (sq) {
          if (c == "\047") sq = 0
          else tok = tok c
          continue
        }
        if (dq) {
          if (esc) {
            tok = tok c
            esc = 0
            continue
          }
          if (c == "\\") {
            esc = 1
            continue
          }
          if (c == "\"") {
            dq = 0
            continue
          }
          tok = tok c
          continue
        }
        if (esc) {
          tok = tok c
          esc = 0
          continue
        }
        if (c == "\\") {
          esc = 1
          continue
        }
        if (c == "\047") {
          sq = 1
          quoted = 1
          continue
        }
        if (c == "\"") {
          dq = 1
          quoted = 1
          continue
        }
        if (c == "#" && tok == "") break
        if (c ~ /[ \t\r]/) {
          emit()
          continue
        }
        if (c == ";") {
          emit()
          print "0\t;"
          continue
        }
        if ((c == "&" && n == "&") || (c == "|" && n == "|")) {
          emit()
          print "0\t" c n
          i++
          continue
        }
        tok = tok c
      }
      emit()
      print "0\t__EOL__"
    }
  '
}

sdd_task_lint_unquoted_text() {
  local command="$1" quoted token tab
  tab="$(printf '\t')"
  sdd_task_lint_shell_words "$command" | while IFS="$tab" read -r quoted token; do
    [ -n "$token" ] || continue
    [ "$token" = "__EOL__" ] && continue
    if [ "$quoted" = "0" ]; then
      printf '%s ' "$token"
    fi
  done
  printf '\n'
}

sdd_task_lint_script_refs() {
  local command="$1" quoted cleaned previous expect_command in_for_header cwd_is_dynamic tab
  previous=""
  expect_command=1
  in_for_header=0
  cwd_is_dynamic=0
  tab="$(printf '\t')"
  sdd_task_lint_shell_words "$command" | while IFS="$tab" read -r quoted cleaned; do
    [ -n "$cleaned" ] || continue
    [ "$cleaned" = "__EOL__" ] && continue

    if [ "$in_for_header" -eq 1 ]; then
      case "$cleaned" in
        do)
          in_for_header=0
          expect_command=1
          previous=""
          ;;
      esac
      continue
    fi

    if [ "$previous" = "bash" ] || [ "$previous" = "sh" ] || [ "$previous" = "zsh" ]; then
      case "$cleaned" in
        -*) continue ;;
        *)
          if [ "$cwd_is_dynamic" -eq 0 ] && sdd_task_lint_is_static_script_path "$cleaned"; then
            printf '%s\n' "$cleaned"
          fi
          previous=""
          expect_command=0
          continue
          ;;
      esac
    fi

    if [ "$previous" = "cd" ]; then
      case "$cleaned" in *'$'*) cwd_is_dynamic=1 ;; esac
      previous=""
      expect_command=0
      continue
    fi

    case "$cleaned" in
      "("|")")
        cwd_is_dynamic=0
        previous=""
        expect_command=1
        ;;
      "&&"|"||"|";"|then|do)
        previous=""
        expect_command=1
        ;;
      if|while|until|!|time)
        previous=""
        expect_command=1
        ;;
      for)
        previous=""
        if [ "$expect_command" -eq 1 ]; then
          in_for_header=1
        fi
        expect_command=0
        ;;
      bash|sh|zsh)
        previous="$cleaned"
        expect_command=0
        ;;
      cd)
        previous="cd"
        expect_command=0
        ;;
      ./*.sh|/*.sh|*/*.sh)
        if [ "$expect_command" -eq 1 ] && sdd_task_lint_is_static_script_path "$cleaned"; then
          printf '%s\n' "$cleaned"
        fi
        previous=""
        expect_command=0
        ;;
      *)
        previous=""
        expect_command=0
        ;;
    esac
  done | awk '!seen[$0]++'
}

sdd_task_lint_task_creates_file() {
  local tasks_file="$1" task_id="$2" script_path="$3" rows_json="${4:-}" lookup
  lookup="${script_path#./}"
  [ -n "$rows_json" ] || rows_json="$(sdd_task_rows_json "$tasks_file")"
  printf '%s\n' "$rows_json" | jq -e --arg start "$task_id" --arg path "$lookup" '
    def parse_list($raw):
      (($raw // "") | gsub("^\\s+|\\s+$"; "")) as $trimmed
      | if $trimmed == "" then []
        else try (
          $trimmed | fromjson | if type == "array" then map(if type == "string" then . else tostring end) else error("not-array") end
        ) catch (
          ($trimmed | if startswith("[") and endswith("]") then .[1:-1] else . end)
          | split(",")
          | map(gsub("^\\s+|\\s+$"; ""))
          | map(if (startswith("\"") and endswith("\"")) and (length >= 2) then .[1:-1] else . end)
        )
        end;
    def task($rows; $id): ($rows | map(select(.id == $id)) | .[0] // {});
    def closure($rows; $seen; $frontier):
      if ($frontier | length) == 0 then $seen
      else
        ($frontier | map(select(. as $id | ($seen | index($id) | not)))) as $new
        | ($seen + $new) as $next_seen
        | ($new | map(parse_list((task($rows; .).depends_on_raw // ""))) | add // []) as $next_frontier
        | closure($rows; $next_seen; ($next_frontier | map(select(. as $id | ($next_seen | index($id) | not)))))
      end;
    . as $rows
    | [closure($rows; []; [$start])[] as $id | parse_list((task($rows; $id).files_raw // ""))[]]
    | any(.[];
      contains("(create)") and
      ((sub("^\\./"; "") | sub(" \\(create\\).*"; "")) == $path)
    )
  ' >/dev/null 2>&1
}

sdd_task_lint_script_exists() {
  local script_path="$1" lookup
  lookup="${script_path#./}"
  [ -f "$script_path" ] || [ -f "$lookup" ]
}

sdd_task_lint_placeholder_match() {
  local command="$1" lower
  lower="$(printf '%s\n' "$command" | tr '[:upper:]' '[:lower:]')"
  case "$lower" in
    *"[runnable command"*|*"todo"*|*"tbd"*|*"manual verify"*|*"manual verification"*|*"verify manually"*|*"placeholder"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sdd_task_lint_mentions_same_feature() {
  local command="$1" feature="$2"
  [ -n "$feature" ] || return 1
  case "$command" in
    *"$feature"*|*"--feature auto"*) return 0 ;;
    *) return 1 ;;
  esac
}

sdd_task_lint_lifecycle_command_match() {
  local command="$1"
  case "$command" in
    *"record-close"*|*"sdd close"*|*"sdd.sh close"*|*"sdd reopen"*|*"sdd.sh reopen"*) return 0 ;;
    *) return 1 ;;
  esac
}

sdd_task_lint_comment_text() {
  local command="$1" line
  while IFS= read -r line; do
    case "$line" in
      *"#"*)
        printf '%s\n' "${line#*#}"
        ;;
    esac
  done <<EOF
$command
EOF
}

sdd_task_lint_expected_failure_marker_match() {
  local lower="$1"
  case "$lower" in
    *"expected fail"*|*"expected-fail"*|*"expected failure"*|*"expected-failing"*|*"should fail"*|*"must fail"*|*"exit non-zero"*|*"exits non-zero"*|*"non-zero exit"*|*"nonzero exit"*|*"negative test"*|*"reject"*|*"invalid"*|*"bogus"*|*"precondition"*|*"not closed"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sdd_task_lint_line_has_quiet_grep_pipeline() {
  local line_lint="$1"
  printf '%s\n' "$line_lint" | grep -Eq '\|[[:space:]]*grep([[:space:]]+-[^[:space:]]*)*[[:space:]]+-[^[:space:]]*q'
}

sdd_task_lint_line_is_capture_grep() {
  local line_lint="$1"
  printf '%s\n' "$line_lint" | grep -Eq '(^|[;&][[:space:]]*|then[[:space:]]+)(if[[:space:]]+)?(printf|echo|cat)([[:space:]][^|]*)?\|[[:space:]]*grep([[:space:]]+-[^[:space:]]*)*[[:space:]]+-[^[:space:]]*q'
}

sdd_task_lint_line_has_bang_pipeline() {
  local line_lint="$1"
  printf '%s\n' "$line_lint" | grep -Eq '(^|[[:space:];&])![[:space:]]+[^|]+\|[[:space:]]*grep([[:space:]]+-[^[:space:]]*)*[[:space:]]+-[^[:space:]]*q'
}

sdd_task_lint_pipefail_expected_failure_grep_match() {
  local command="$1" command_lint_text="${2:-}" lower_intent line line_lint has_expected_marker
  [ -n "$command_lint_text" ] || command_lint_text="$(sdd_task_lint_unquoted_text "$command")"

  printf '%s\n' "$command_lint_text" | grep -Eq '(^|[[:space:];&])pipefail([[:space:];&]|$)' || return 1

  lower_intent="$(printf '%s\n%s\n' "$command_lint_text" "$(sdd_task_lint_comment_text "$command")" | tr '[:upper:]' '[:lower:]')"
  has_expected_marker=0
  if sdd_task_lint_expected_failure_marker_match "$lower_intent"; then
    has_expected_marker=1
  fi

  while IFS= read -r line; do
    line_lint="$(sdd_task_lint_unquoted_text "$line")"
    sdd_task_lint_line_has_quiet_grep_pipeline "$line_lint" || continue
    sdd_task_lint_line_is_capture_grep "$line_lint" && continue
    if [ "$has_expected_marker" -eq 1 ] || sdd_task_lint_line_has_bang_pipeline "$line_lint"; then
      return 0
    fi
  done <<EOF
$command
EOF

  return 1
}

# Statically lint task Verification commands without executing them.
sdd_task_verification_lint_json() {
  local tasks_file="$1" feature="${2:-}"
  local rows_json checked_tasks findings_tmp task_id command command_lint_text script_ref syntax_tmp syntax_output syntax_status
  local findings_json error_count warning_count has_record_commit_error=0

  rows_json="$(sdd_task_rows_json "$tasks_file")"
  checked_tasks="$(printf '%s\n' "$rows_json" | jq 'length')"
  findings_tmp="$(mktemp "${TMPDIR:-/tmp}/sdd-task-lint.XXXXXX")"
  : > "$findings_tmp"

  while IFS= read -r task_id; do
    [ -n "$task_id" ] || continue
    command="$(sdd_task_verification_command "$tasks_file" "$task_id" || true)"
    command_lint_text="$(sdd_task_lint_unquoted_text "$command")"

    if [ -z "$command" ]; then
      sdd_task_lint_finding_json \
        "TVL-004" "error" "$task_id" \
        "Verification command is empty or missing." \
        "Add a concrete runnable Verification command that proves the task outcome." >> "$findings_tmp"
      continue
    fi

    if printf '%s\n' "$command" | grep -Fq '.error.status'; then
      sdd_task_lint_finding_json \
        "TVL-001" "error" "$task_id" \
        "Verification command references .error.status, but SDD JSON errors use .error.type." \
        "Replace .error.status with .error.type." >> "$findings_tmp"
    fi

    if sdd_task_lint_placeholder_match "$command"; then
      sdd_task_lint_finding_json \
        "TVL-004" "error" "$task_id" \
        "Verification command still looks like a placeholder or manual-check note." \
        "Replace it with a runnable command or a fixture test script." >> "$findings_tmp"
    fi

    syntax_tmp="$(mktemp "${TMPDIR:-/tmp}/sdd-task-lint-syntax.XXXXXX")"
    printf '%s\n' "$command" > "$syntax_tmp"
    syntax_status=0
    syntax_output="$(bash -n "$syntax_tmp" 2>&1)" || syntax_status=$?
    rm -f "$syntax_tmp"
    if [ "$syntax_status" -ne 0 ]; then
      sdd_task_lint_finding_json \
        "TVL-002" "error" "$task_id" \
        "Verification command has invalid bash syntax." \
        "Fix the shell syntax before task completion can execute this command." \
        "" "$(printf '%s\n' "$syntax_output" | head -1)" >> "$findings_tmp"
    fi

    while IFS= read -r script_ref; do
      [ -n "$script_ref" ] || continue
      if ! sdd_task_lint_script_exists "$script_ref" &&
         ! sdd_task_lint_task_creates_file "$tasks_file" "$task_id" "$script_ref" "$rows_json"; then
        sdd_task_lint_finding_json \
          "TVL-003" "error" "$task_id" \
          "Verification command references a missing shell script." \
          "Create the script, correct the path, or list it as a same-task created file when appropriate." \
          "$script_ref" >> "$findings_tmp"
      fi
    done <<EOF
$(sdd_task_lint_script_refs "$command")
EOF

    has_record_commit_error=0
    if sdd_task_lint_mentions_same_feature "$command_lint_text" "$feature" &&
       case "$command_lint_text" in *"record-close"* ) true ;; * ) false ;; esac &&
       case "$command_lint_text" in *"--commit"* ) true ;; * ) false ;; esac; then
      has_record_commit_error=1
      sdd_task_lint_finding_json \
        "TVL-005" "error" "$task_id" \
        "Verification command runs sdd record-close --commit against the same feature." \
        "Verify mutating close/commit behavior in a disposable fixture instead of the active feature." >> "$findings_tmp"
    fi

    if [ "$has_record_commit_error" -eq 0 ] &&
       sdd_task_lint_mentions_same_feature "$command_lint_text" "$feature" &&
       sdd_task_lint_lifecycle_command_match "$command_lint_text"; then
      sdd_task_lint_finding_json \
        "TVL-006" "warning" "$task_id" \
        "Verification command appears to run a lifecycle mutation against the same feature." \
        "Prefer a disposable fixture for mutating SDD lifecycle command verification." >> "$findings_tmp"
    fi

    if sdd_task_lint_pipefail_expected_failure_grep_match "$command" "$command_lint_text"; then
      sdd_task_lint_finding_json \
        "TVL-008" "warning" "$task_id" \
        "Verification command uses pipefail with an expected-failure command piped directly into quiet grep." \
        "Capture output and status separately before grepping: out=\"\$(cmd 2>&1)\"; status=\$?; then assert the non-zero status and grep the captured output." >> "$findings_tmp"
    fi

    case "$command_lint_text" in
      *"git commit"*)
        sdd_task_lint_finding_json \
          "TVL-007" "warning" "$task_id" \
          "Verification command contains a generic git commit risk." \
          "Use a disposable git fixture for commit behavior verification." >> "$findings_tmp"
        ;;
    esac
  done <<EOF
$(printf '%s\n' "$rows_json" | jq -r '.[].id')
EOF

  findings_json="$(jq -s '.' "$findings_tmp")"
  rm -f "$findings_tmp"
  error_count="$(printf '%s\n' "$findings_json" | jq '[.[] | select(.severity == "error")] | length')"
  warning_count="$(printf '%s\n' "$findings_json" | jq '[.[] | select(.severity == "warning")] | length')"

  jq -nc \
    --argjson checked_tasks "$checked_tasks" \
    --argjson error_count "$error_count" \
    --argjson warning_count "$warning_count" \
    --argjson findings "$findings_json" \
    '{
      checked_tasks: $checked_tasks,
      error_count: $error_count,
      warning_count: $warning_count,
      findings: $findings
    }'
}

# Normalize CSV, YAML-flow, or JSON array syntax into a canonical JSON array.
sdd_parse_id_list() {
  local raw="${1:-}" trimmed inner
  trimmed="$(printf '%s' "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

  if [ -z "$trimmed" ]; then
    printf '[]\n'
    return 0
  fi

  if printf '%s\n' "$trimmed" | jq -ce '
    if type == "array" then
      map(
        if type == "string" then
          gsub("^\\s+|\\s+$"; "")
          | if test("^[A-Za-z]+-[0-9]+(/[A-Za-z]+-[0-9]+)?\\s*\\([^)]*\\)\\s*$") then gsub("\\s*\\([^)]*\\)\\s*$"; "") else . end
        else tostring
        end
      )
      | map(select(length > 0))
    else
      error("not-array")
    end
  ' >/dev/null 2>&1; then
    printf '%s\n' "$trimmed" | jq -c '
      map(
        if type == "string" then
          gsub("^\\s+|\\s+$"; "")
          | if test("^[A-Za-z]+-[0-9]+(/[A-Za-z]+-[0-9]+)?\\s*\\([^)]*\\)\\s*$") then gsub("\\s*\\([^)]*\\)\\s*$"; "") else . end
        else tostring
        end
      )
      | map(select(length > 0))
    '
    return 0
  fi

  inner="$trimmed"
  if [[ "$inner" == \[*\] ]]; then
    inner="${inner#\[}"
    inner="${inner%\]}"
  fi

  printf '%s\n' "$inner" | jq -Rsc '
    split(",")
    | map(gsub("^\\s+|\\s+$"; ""))
    | map(
        if (startswith("\"") and endswith("\"")) and (length >= 2)
        then .[1:-1]
        else .
        end
      )
    | map(gsub("^\\s+|\\s+$"; ""))
    | map(if test("^[A-Za-z]+-[0-9]+(/[A-Za-z]+-[0-9]+)?\\s*\\([^)]*\\)\\s*$") then gsub("\\s*\\([^)]*\\)\\s*$"; "") else . end)
    | map(select(length > 0))
  '
}

# Extract SDD identifier declaration rows in document order.
# Usage: sdd_parse_id_rows_tsv <FR|AC|AD|OQ> <file> [headings]
# Emits: id<TAB>line<TAB>title<TAB>checkbox_state
sdd_parse_id_rows_tsv() {
  local kind="${1:-}" file="${2:-}" mode="${3:-lines}"

  case "$kind" in
    FR|AC|AD|OQ) ;;
    *) return 0 ;;
  esac

  [ -f "$file" ] || return 0

  [ -f "$file" ] || return 0

  awk -v kind="$kind" -v mode="$mode" '
    function emit_row(line, source_line, checkbox_state, title) {
      if (match(line, kind "-[0-9]+")) {
        id = substr(line, RSTART, RLENGTH)
        title = line
        sub("^" kind "-[0-9]+([[:space:]]+\\[[^]]+\\])?:[[:space:]]*", "", title)
        sub("^\\*\\*" kind "-[0-9]+([[:space:]]+\\[[^]]+\\])?\\*\\*:[[:space:]]*", "", title)
        sub("^\\*\\*" kind "-[0-9]+([[:space:]]+\\[[^]]+\\])?:[^*]*\\*\\*[[:space:]]*", "", title)
        gsub(/\t/, " ", title)
        printf "%s\t%d\t%s\t%s\n", id, NR, title, checkbox_state
      }
    }
    /^```/ {
      in_fence = !in_fence
      next
    }
    in_fence {
      next
    }
    {
      line = $0
      checkbox_state = ""
      is_heading = 0

      if (mode == "headings" && line ~ "^### " kind "-[0-9]+:") {
        is_heading = 1
        sub(/^### /, "", line)
      } else if (line ~ /^- /) {
        sub(/^- /, "", line)
      } else {
        next
      }

      if (line ~ /^\[[ xX]\] /) {
        checkbox_state = substr(line, 2, 1)
        if (checkbox_state ~ /[xX]/) checkbox_state = "x"
        sub(/^\[[ xX]\] /, "", line)
      } else if (kind == "AC" && is_heading != 1) {
        next
      }

      plain_re = "^" kind "-[0-9]+([[:space:]]+\\[[^]]+\\])?:"
      bold_after_re = "^\\*\\*" kind "-[0-9]+([[:space:]]+\\[[^]]+\\])?\\*\\*:"
      bold_inside_re = "^\\*\\*" kind "-[0-9]+([[:space:]]+\\[[^]]+\\])?:[^*]*\\*\\*"

      if (line ~ plain_re || line ~ bold_after_re || line ~ bold_inside_re) {
        emit_row(line, NR, checkbox_state)
      }
    }
  ' "$file" 2>/dev/null || true
}

# Extract SDD identifier declaration IDs in document order.
# Usage: sdd_parse_id_lines <FR|AC|AD|OQ> <file> [headings]
sdd_parse_id_lines() {
  sdd_parse_id_rows_tsv "${1:-}" "${2:-}" "${3:-}" | awk -F '\t' '{ print $1 }'
}

sdd_count_id_lines() {
  sdd_parse_id_lines "${1:-}" "${2:-}" "${3:-}" | wc -l | tr -d ' '
}

sdd_task_field_values_json() {
  local tasks_file="$1" task_id="$2" field="$3"
  local raw
  raw="$(sdd_task_field_value "$tasks_file" "$task_id" "$field" || true)"
  sdd_parse_id_list "$raw"
}

# Return all task rows outside fenced code blocks as a JSON array.
sdd_task_rows_json() {
  local tasks_file="$1"
  [ -f "$tasks_file" ] || { printf '[]\n'; return 0; }

  awk '
    function flush_task() {
      if (task_id == "") return
      printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", order, task_id, heading, title, status, phase, implements, depends_on, files
    }
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^## T-[0-9]+:/ {
      flush_task()
      order++
      heading = substr($0, 4)
      task_id = heading
      sub(/:.*/, "", task_id)
      title = heading
      sub(/^[^:]+: /, "", title)
      status = ""
      phase = ""
      implements = ""
      depends_on = ""
      files = ""
      next
    }
    /^> Status: / { status = substr($0, 11); next }
    /^> Phase: / { phase = substr($0, 10); next }
    /^> Implements: / { implements = substr($0, 15); next }
    /^> Depends-on: / { depends_on = substr($0, 14); next }
    /^> Files: / { files = substr($0, 9); next }
    END { flush_task() }
  ' "$tasks_file" | jq -Rsc '
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map({
        order: (.[0] | tonumber),
        id: .[1],
        heading: .[2],
        title: .[3],
        status: (if .[4] == "" then null else .[4] end),
        phase: (if .[5] == "" then null else .[5] end),
        implements_raw: (if .[6] == "" then null else .[6] end),
        depends_on_raw: (if .[7] == "" then null else .[7] end),
        files_raw: (if .[8] == "" then null else .[8] end)
      })
  '
}

sdd_task_feature_dir_from_tasks_file() {
  local tasks_file="$1" tasks_dir base
  tasks_dir="$(cd "$(dirname "$tasks_file")" && pwd 2>/dev/null || dirname "$tasks_file")"
  base="$(basename "$tasks_dir")"
  if [[ "$base" == wp-* ]]; then
    dirname "$tasks_dir"
  else
    printf '%s\n' "$tasks_dir"
  fi
}

sdd_task_work_package_from_tasks_file() {
  local tasks_file="$1" tasks_dir base
  tasks_dir="$(dirname "$tasks_file")"
  base="$(basename "$tasks_dir")"
  if [[ "$base" == wp-* ]]; then
    printf '%s\n' "$base"
  else
    printf '\n'
  fi
}

sdd_task_normalize_file_path() {
  local file_path="$1" dir base
  dir="$(dirname "$file_path")"
  base="$(basename "$file_path")"
  if [ -d "$dir" ]; then
    dir="$(cd "$dir" && pwd 2>/dev/null || printf '%s\n' "$dir")"
    printf '%s/%s\n' "$dir" "$base"
  else
    printf '%s\n' "$file_path"
  fi
}

sdd_task_wp_ref_prefix() {
  local work_package="$1"
  if [[ "$work_package" =~ ^wp-([0-9][0-9])(-.*)?$ ]]; then
    printf 'WP-%s\n' "${BASH_REMATCH[1]}"
  else
    printf '%s\n' "$work_package"
  fi
}

sdd_task_display_ref() {
  local tasks_file="$1" task_id="$2"
  local work_package
  work_package="$(sdd_task_work_package_from_tasks_file "$tasks_file")"
  if [ -n "$work_package" ]; then
    printf '%s/%s\n' "$(sdd_task_wp_ref_prefix "$work_package")" "$task_id"
  else
    printf '%s\n' "$task_id"
  fi
}

sdd_task_node_key() {
  local tasks_file="$1" task_id="$2"
  printf '%s::%s\n' "$(sdd_task_normalize_file_path "$tasks_file")" "$task_id"
}

sdd_task_feature_task_files() {
  local tasks_file="$1"
  local feature_dir root_tasks had_nullglob=0 wp_tasks_file
  local files=()

  feature_dir="$(sdd_task_feature_dir_from_tasks_file "$tasks_file")"
  root_tasks="$feature_dir/tasks.md"
  [ -f "$root_tasks" ] && files+=("$root_tasks")

  shopt -q nullglob && had_nullglob=1
  shopt -s nullglob
  for wp_tasks_file in "$feature_dir"/wp-*/tasks.md; do
    [ -f "$wp_tasks_file" ] && files+=("$wp_tasks_file")
  done
  [ "$had_nullglob" -eq 1 ] || shopt -u nullglob

  if [ "${#files[@]}" -eq 0 ] && [ -f "$tasks_file" ]; then
    files+=("$tasks_file")
  fi

  [ "${#files[@]}" -gt 0 ] || return 0
  printf '%s\n' "${files[@]}" | while IFS= read -r file_path; do
    [ -n "$file_path" ] || continue
    sdd_task_normalize_file_path "$file_path"
  done | awk '!seen[$0]++'
}

sdd_task_resolve_reference_json() {
  local tasks_file="$1" ref="$2" current_task_id="${3:-}"
  local feature_dir current_wp current_tasks_file dep_task_id="" dep_tasks_file="" dep_work_package="" dep_status="" dep_heading=""
  local resolved=false external=false self_ref=false

  current_tasks_file="$(sdd_task_normalize_file_path "$tasks_file")"
  feature_dir="$(sdd_task_feature_dir_from_tasks_file "$tasks_file")"
  current_wp="$(sdd_task_work_package_from_tasks_file "$tasks_file")"

  if [[ "$ref" =~ ^T-[0-9]+$ ]]; then
    dep_task_id="$ref"
    dep_tasks_file="$tasks_file"
    dep_work_package="${current_wp:-}"
  elif [[ "$ref" =~ ^WP-([0-9][0-9])/(T-[0-9]+)$ ]]; then
    local wp_num="${BASH_REMATCH[1]}"
    local matches=("$feature_dir"/wp-"$wp_num"-*/tasks.md)
    dep_task_id="${BASH_REMATCH[2]}"
    external=true
    if [ -e "${matches[0]:-}" ]; then
      dep_tasks_file="${matches[0]}"
      dep_work_package="$(basename "$(dirname "$dep_tasks_file")")"
    fi
  fi

  if [ -n "$dep_tasks_file" ] && [ -f "$dep_tasks_file" ]; then
    dep_heading="$(sdd_task_heading "$dep_tasks_file" "$dep_task_id" || true)"
    if [ -n "$dep_heading" ]; then
      resolved=true
      dep_status="$(sdd_task_field_value "$dep_tasks_file" "$dep_task_id" "Status" || true)"
    else
      dep_tasks_file=""
      dep_work_package=""
    fi
  fi

  if [ "$resolved" = "true" ] && [ "$(sdd_task_normalize_file_path "$dep_tasks_file")" = "$current_tasks_file" ] && [ -n "$current_task_id" ] && [ "$current_task_id" = "$dep_task_id" ]; then
    self_ref=true
  fi

  jq -nc \
    --arg ref "$ref" \
    --arg task_id "$dep_task_id" \
    --arg tasks_file_value "$dep_tasks_file" \
    --arg work_package "$dep_work_package" \
    --arg status "$dep_status" \
    --arg heading "$dep_heading" \
    --arg node_key "$(if [ -n "$dep_tasks_file" ] && [ -n "$dep_task_id" ]; then sdd_task_node_key "$dep_tasks_file" "$dep_task_id"; fi)" \
    --arg display_ref "$(if [ -n "$dep_tasks_file" ] && [ -n "$dep_task_id" ]; then sdd_task_display_ref "$dep_tasks_file" "$dep_task_id"; else printf '%s\n' "$ref"; fi)" \
    --argjson resolved "$resolved" \
    --argjson external "$external" \
    --argjson self_ref "$self_ref" \
    '{
      ref: $ref,
      task_id: (if $task_id == "" then null else $task_id end),
      tasks_file: (if $tasks_file_value == "" then null else $tasks_file_value end),
      work_package: (if $work_package == "" then null else $work_package end),
      status: (if $status == "" then null else $status end),
      heading: (if $heading == "" then null else $heading end),
      node_key: (if $node_key == "" then null else $node_key end),
      display_ref: (if $display_ref == "" then $ref else $display_ref end),
      resolved: $resolved,
      external: $external,
      self: $self_ref
    }'
}

sdd_task_graph_json() {
  local tasks_file="$1"
  [ -f "$tasks_file" ] || {
    printf '{"tasks":[],"edges":[],"ready_tasks":[],"blocked_tasks":[],"problems":[]}\n'
    return 0
  }

  local primary_ctx="$tasks_file"
  local primary_norm
  primary_norm="$(sdd_task_normalize_file_path "$tasks_file")"

  # Build the files[] input: one object per feature task file (root + wp-*).
  # O(files) spawns, NOT O(tasks). Each: rows_json (awk+jq) + one assembling jq.
  local files_json='[]' f wp wpx rows
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    wp="$(sdd_task_work_package_from_tasks_file "$f")"
    wpx="$(sdd_task_wp_ref_prefix "$wp")"
    rows="$(sdd_task_rows_json "$f")"
    files_json="$(jq -c \
      --argjson acc "$files_json" \
      --arg norm "$f" \
      --arg nkey "${f}::" \
      --arg wp "$wp" \
      --arg wpx "$wpx" \
      --argjson rows "$rows" \
      -n '$acc + [{norm:$norm, nkey:$nkey, work_package:$wp, wp_prefix:$wpx, rows:$rows}]')"
  done < <(sdd_task_feature_task_files "$tasks_file")

  jq -nc \
    --arg primary_ctx "$primary_ctx" \
    --arg primary_norm "$primary_norm" \
    --argjson files "$files_json" '
    def trim: gsub("^\\s+|\\s+$"; "");
    def strip_annot:
      if test("^[A-Za-z]+-[0-9]+(/[A-Za-z]+-[0-9]+)?\\s*\\([^)]*\\)\\s*$")
      then gsub("\\s*\\([^)]*\\)\\s*$"; "") else . end;
    def parse_id_list($raw):
      ($raw // "" | trim) as $t
      | if $t == "" then []
        else
          (try ($t | fromjson) catch null) as $j
          | if ($j | type) == "array" then
              $j
              | map(if type == "string" then (trim | strip_annot) else tostring end)
              | map(select(length > 0))
            else
              (if ($t | test("^\\[.*\\]$")) then $t[1:-1] else $t end)
              | split(",")
              | map(trim)
              | map(if (startswith("\"") and endswith("\"")) and (length >= 2) then .[1:-1] else . end)
              | map(trim)
              | map(strip_annot)
              | map(select(length > 0))
            end
        end;
    def find_in($file; $id): ([ $file.rows[]? | select(.id == $id) ] | .[0]);
    # resolve a single dependency reference within a context file.
    def resolve($ref; $ctx; $ctx_task_id; $same_file_path):
      ( if ($ref | test("^T-[0-9]+$")) then
          {tid: $ref, target: $ctx, tpath: $same_file_path, external: false}
        elif ($ref | test("^WP-[0-9][0-9]/T-[0-9]+$")) then
          ($ref | capture("^WP-(?<n>[0-9][0-9])/(?<t>T-[0-9]+)$")) as $m
          | ([ $files[] | select(.work_package | test("^wp-\($m.n)-")) ][0]) as $wpf
          | {tid: $m.t, target: $wpf, tpath: ($wpf.norm // null), external: true}
        else
          {tid: null, target: null, tpath: null, external: false}
        end ) as $f
      | $f.tid as $tid
      | $f.target as $tg
      | (if ($tg != null and $tid != null) then find_in($tg; $tid) else null end) as $row
      | ($row != null) as $resolved
      | {
          ref: $ref,
          task_id: ($tid // null),
          tasks_file: (if $resolved then $f.tpath else null end),
          work_package: (if $resolved and (($tg.work_package // "") != "") then $tg.work_package else null end),
          status: (if $resolved and (($row.status // "") != "") then $row.status else null end),
          heading: (if $resolved and (($row.heading // "") != "") then $row.heading else null end),
          node_key: (if $resolved then ($tg.nkey + $tid) else null end),
          display_ref: (if $resolved then
              (if (($tg.work_package // "") != "") then ($tg.wp_prefix + "/" + $tid) else $tid end)
            else $ref end),
          resolved: $resolved,
          external: $f.external,
          self: (if ($resolved and ($tg.norm == $ctx.norm) and ($ctx_task_id != null) and ($ctx_task_id == $tid)) then true else false end)
        };
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

    (first($files[] | select(.norm == $primary_norm))) as $primary
    | ($primary.rows // []) as $prows

    # tasks[]
    | ([ $prows[]
        | . as $row
        | parse_id_list($row.implements_raw) as $impl
        | parse_id_list($row.depends_on_raw) as $deps
        | parse_id_list($row.files_raw) as $fls
        | ([ $deps[] | resolve(.; $primary; $row.id; $primary_ctx) ]) as $dinfos
        | ([ $dinfos[] | select(($row.status == "pending") and ((.resolved | not) or (.status != "completed"))) ]) as $blockers
        | ($row + {
            implements: $impl,
            depends_on: $deps,
            files: $fls,
            blockers: $blockers,
            ready: ($row.status == "pending" and ($blockers | length) == 0),
            dependency_blocked: ($row.status == "pending" and ($blockers | length) > 0)
          })
      ]) as $tasks

    # edges[]
    | ([ $prows[]
        | . as $row
        | parse_id_list($row.depends_on_raw)[] as $ref
        | resolve($ref; $primary; $row.id; $primary_ctx) as $d
        | {from: $row.id, to: $d.ref, task_id: $d.task_id, resolved: $d.resolved, external: $d.external, self: $d.self, status: $d.status, heading: $d.heading, tasks_file: $d.tasks_file, work_package: $d.work_package}
      ]) as $edges

    | ([ $tasks[] | select(.ready) | .id ]) as $ready_tasks
    | ([ $tasks[] | select(.dependency_blocked) | .id ]) as $blocked_tasks

    # problems: self / missing (per task per dep, document order)
    | ([ $prows[]
        | . as $row
        | parse_id_list($row.depends_on_raw)[] as $ref
        | resolve($ref; $primary; $row.id; $primary_ctx) as $d
        | if $d.self then {type: "self_dependency", task: $row.id, ref: $ref, message: ($row.id + " depends on itself")}
          elif ($d.resolved | not) then {type: "missing_dependency", task: $row.id, ref: $ref, message: ($row.id + " depends on " + $ref + " which does not exist")}
          else empty end
      ]) as $problems_main

    # cycle detection over all feature files
    | ([ $files[] | . as $cf | $cf.rows[]
        | {key: ($cf.nkey + .id), ref: (if (($cf.work_package // "") != "") then ($cf.wp_prefix + "/" + .id) else .id end)}
      ] | unique_by(.key)) as $cnodes
    | ([ $files[] | . as $cf | $cf.rows[]
        | .id as $tid
        | parse_id_list(.depends_on_raw)[] as $ref
        | resolve($ref; $cf; $tid; $cf.norm) as $d
        | select($d.resolved and ($d.self | not) and ($d.node_key != null))
        | {from: ($cf.nkey + $tid), to: $d.node_key}
      ] | unique_by(.from + "|" + .to)) as $cedges
    | (topo(($cnodes | map(.key)); $cedges; [])) as $cyc
    | (if ($cyc.remaining | length) > 0 then
        ([ $cyc.remaining[] as $id | ($cnodes[] | select(.key == $id) | .ref) ]) as $crefs
        | [ {type: "cycle", tasks: $crefs, message: ("Dependency cycle detected: " + (($crefs + [$crefs[0]]) | join(" -> ")))} ]
      else [] end) as $cycle_problems

    | {tasks: $tasks, edges: $edges, ready_tasks: $ready_tasks, blocked_tasks: $blocked_tasks, problems: ($problems_main + $cycle_problems)}
  '
}

sdd_task_current_json() {
  local tasks_file="$1"
  local graph_json="${2:-}"
  local best_id task_json task_verify

  if [ -z "$graph_json" ]; then
    graph_json="$(sdd_task_graph_json "$tasks_file")"
  fi

  best_id="$(printf '%s\n' "$graph_json" | jq -r '([.tasks[] | select(.status == "in-progress") | .id] | first) // (.ready_tasks[0] // empty)')"
  if [ -z "$best_id" ]; then
    jq -n '{id:null,heading:null,phase:null,implements:null,verification_cmd:null}'
    return 0
  fi

  task_json="$(printf '%s\n' "$graph_json" | jq -c --arg task_id "$best_id" '[.tasks[] | select(.id == $task_id)] | first')"
  task_verify="$(sdd_task_verification_command "$tasks_file" "$best_id" || true)"

  jq -n \
    --argjson task "$task_json" \
    --arg verify "${task_verify:-}" \
    '{
      id: $task.id,
      heading: $task.heading,
      phase: $task.phase,
      implements: ($task.implements_raw // null),
      verification_cmd: (if $verify == "" then null else $verify end)
    }'
}

sdd_task_summary_cheap() {
  local tasks_file="$1"
  local completed in_progress pending blocked total
  local summary_tsv current_id="" current_heading="" current_phase="" current_implements=""

  if [ ! -f "$tasks_file" ]; then
    jq -n '{
      completed: 0,
      in_progress: 0,
      pending: 0,
      blocked: 0,
      total: 0,
      current_task: {id:null,heading:null,phase:null,implements:null,verification_cmd:null}
    }'
    return 0
  fi

  summary_tsv="$(awk '
    function flush_task() {
      if (task_id == "") return
      if (status == "in-progress" && ip_id == "") {
        ip_id = task_id; ip_heading = heading; ip_phase = phase; ip_implements = implements
      } else if (status == "pending" && pending_id == "") {
        pending_id = task_id; pending_heading = heading; pending_phase = phase; pending_implements = implements
      }
    }
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^## T-[0-9]+:/ {
      flush_task()
      heading = substr($0, 4)
      task_id = heading
      sub(/:.*/, "", task_id)
      status = ""; phase = ""; implements = ""
      next
    }
    /^> Status: / {
      status = substr($0, 11)
      if (status == "completed") completed++
      else if (status == "in-progress") in_progress++
      else if (status == "pending") pending++
      else if (status == "blocked") blocked++
      next
    }
    /^> Phase: / { phase = substr($0, 10); next }
    /^> Implements: / { implements = substr($0, 15); next }
    END {
      flush_task()
      if (ip_id != "") {
        current_id = ip_id; current_heading = ip_heading; current_phase = ip_phase; current_implements = ip_implements
      } else if (pending_id != "") {
        current_id = pending_id; current_heading = pending_heading; current_phase = pending_phase; current_implements = pending_implements
      }
      printf "%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\n", completed + 0, in_progress + 0, pending + 0, blocked + 0, current_id, current_heading, current_phase, current_implements
    }
  ' "$tasks_file")"
  IFS=$'\t' read -r completed in_progress pending blocked current_id current_heading current_phase current_implements <<EOF
$summary_tsv
EOF
  completed="${completed:-0}"
  in_progress="${in_progress:-0}"
  pending="${pending:-0}"
  blocked="${blocked:-0}"
  total=$((completed + in_progress + pending + blocked))

  jq -nc \
    --arg completed "$completed" \
    --arg in_progress "$in_progress" \
    --arg pending "$pending" \
    --arg blocked "$blocked" \
    --arg total "$total" \
    --arg current_id "$current_id" \
    --arg current_heading "$current_heading" \
    --arg current_phase "$current_phase" \
    --arg current_implements "$current_implements" \
    '{
      completed: ($completed | tonumber),
      in_progress: ($in_progress | tonumber),
      pending: ($pending | tonumber),
      blocked: ($blocked | tonumber),
      total: ($total | tonumber),
      current_task: (
        if $current_id == "" then
          {id:null,heading:null,phase:null,implements:null,verification_cmd:null}
        else
          {
            id: $current_id,
            heading: $current_heading,
            phase: (if $current_phase == "" then null else $current_phase end),
            implements: (if $current_implements == "" then null else $current_implements end),
            verification_cmd: null
          }
        end
      )
    }'
}

sdd_task_summary_json() {
  local tasks_file="$1"
  local graph_json next_id next_heading current_json

  if [ ! -f "$tasks_file" ]; then
    jq -n '{
      completed: 0,
      in_progress: 0,
      pending: 0,
      blocked: 0,
      total: 0,
      ready_tasks: 0,
      blocked_tasks: 0,
      current_task: {id:null,heading:null,phase:null,implements:null,verification_cmd:null},
      next_task_heading: null
    }'
    return 0
  fi

  graph_json="$(sdd_task_graph_json "$tasks_file")"
  next_id="$(printf '%s\n' "$graph_json" | jq -r '.ready_tasks[0] // empty')"
  next_heading=""
  if [ -n "$next_id" ]; then
    next_heading="$(sdd_task_heading "$tasks_file" "$next_id" || true)"
  fi
  current_json="$(sdd_task_current_json "$tasks_file" "$graph_json")"

  jq -nc \
    --argjson graph "$graph_json" \
    --argjson current "$current_json" \
    --arg next_heading "$next_heading" \
    '{
      completed: ([ $graph.tasks[] | select(.status == "completed") ] | length),
      in_progress: ([ $graph.tasks[] | select(.status == "in-progress") ] | length),
      pending: ([ $graph.tasks[] | select(.status == "pending") ] | length),
      blocked: ([ $graph.tasks[] | select(.status == "blocked") ] | length),
      total: ($graph.tasks | length),
      ready_tasks: ($graph.ready_tasks | length),
      blocked_tasks: ($graph.blocked_tasks | length),
      current_task: $current,
      next_task_heading: (if $next_heading == "" then null else $next_heading end)
    }'
}

sdd_task_is_ready() {
  local tasks_file="$1" task_id="$2"
  local graph_json
  graph_json="$(sdd_task_graph_json "$tasks_file")"
  printf '%s\n' "$graph_json" | jq -e --arg task_id "$task_id" '
    .tasks[]
    | select(.id == $task_id and .status == "pending" and .ready == true)
  ' >/dev/null 2>&1
}

sdd_current_task_id() {
  local tasks_file="$1"
  local graph_json
  [ -f "$tasks_file" ] || { printf '\n'; return 0; }
  graph_json="$(sdd_task_graph_json "$tasks_file")"
  printf '%s\n' "$graph_json" | jq -r '
    ([.tasks[] | select(.status == "in-progress") | .id] | first)
    // (.ready_tasks[0] // empty)
  '
}

sdd_task_headings_by_status() {
  local tasks_file="$1" wanted_status="$2"
  [ -f "$tasks_file" ] || return 0
  sdd_task_rows_json "$tasks_file" | jq -r --arg status "$wanted_status" '
    .[]
    | select(.status == $status)
    | .heading
  '
}

sdd_affected_files_rows_tsv() {
  local research_file="$1" related_ids="${2:-}"
  [ -f "$research_file" ] || return 0

  awk -v ids="$related_ids" '
    function trim(s) {
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      return s
    }
    function normalize_path(raw, path) {
      path = trim(raw)
      gsub(/`/, "", path)
      if (path ~ /^\[[^]]+\]\([^)]*\)$/) {
        sub(/^\[/, "", path)
        sub(/\]\([^)]*\)$/, "", path)
      } else {
        sub(/^\[/, "", path)
        sub(/\]$/, "", path)
      }
      return trim(path)
    }
    BEGIN {
      split(ids, raw_ids, /,/)
      for (i in raw_ids) {
        raw_ids[i] = trim(raw_ids[i])
        if (raw_ids[i] != "") {
          wanted[raw_ids[i]] = 1
          filter = 1
        }
      }
    }
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^## Affected Files/ { in_section = 1; next }
    in_section && /^(##|---|\*\*\*)/ { in_section = 0; next }
    in_section && /^\|/ {
      if ($0 ~ /^\|[[:space:]]*:?-+:?[[:space:]]*\|/) next

      split($0, cols, "|")
      action = trim(cols[3])
      if (action !~ /^(create|modify|delete|review)$/) next

      path = normalize_path(cols[2])
      module = trim(cols[4])
      impact = trim(cols[5])
      relates = trim(cols[6])

      if (path == "" || path ~ /^[: -]+$/) next

      matched = !filter
      if (filter) {
        for (id in wanted) {
          if (relates ~ id) {
            matched = 1
            break
          }
        }
      }

      if (matched) {
        printf "%s\t%s\t%s\t%s\t%s\n", path, action, module, impact, relates
      }
    }
  ' "$research_file"
}

sdd_affected_files_paths() {
  local research_file="$1" related_ids="${2:-}"
  sdd_affected_files_rows_tsv "$research_file" "$related_ids" | awk -F '\t' '{ print $1 }'
}

sdd_trace_feature_markdown_files() {
  local feature_dir="$1"
  [ -d "$feature_dir" ] || return 0
  find "$feature_dir" -type f -name '*.md' | LC_ALL=C sort
}

sdd_trace_clean_file_ref() {
  local raw="$1"
  local cleaned=""

  cleaned="$(printf '%s' "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  cleaned="$(printf '%s' "$cleaned" | sed 's/^`//; s/`$//')"
  if printf '%s' "$cleaned" | grep -qE '^\[[^]]+\]\([^)]*\)$'; then
    cleaned="$(printf '%s' "$cleaned" | sed 's/^\[\([^]]*\)\](.*$/\1/')"
  fi
  cleaned="${cleaned#\[}"
  cleaned="${cleaned%\]}"
  cleaned="$(printf '%s' "$cleaned" | sed 's/[[:space:]]*(.*$//')"
  printf '%s\n' "$cleaned"
}

sdd_trace_guess_kind() {
  case "$1" in
    BRIEF-*|SPEC-*|RESEARCH-*|PLAN-*|TASKS-*|REVIEW-*|SCRATCH-*|CONT-*|KB-*|WP-TASKS-*|WP-REVIEW-*)
      printf 'artifact\n'
      ;;
    FR-*)
      printf 'fr\n'
      ;;
    AC-*)
      printf 'ac\n'
      ;;
    PH-*)
      printf 'ph\n'
      ;;
    AD-*)
      printf 'ad\n'
      ;;
    T-*|WP-[0-9][0-9]/T-*)
      printf 'task\n'
      ;;
    FILE:*)
      printf 'file\n'
      ;;
    *)
      printf 'external\n'
      ;;
  esac
}

sdd_trace_stub_node_json() {
  local node_id="$1"
  jq -nc \
    --arg id "$node_id" \
    --arg kind "$(sdd_trace_guess_kind "$node_id")" \
    '{
      id: $id,
      kind: $kind,
      unresolved: true,
      path: null,
      line: null,
      title: $id,
      status: null
    }'
}

sdd_trace_extract_artifact_nodes() {
  local feature_dir="$1"
  local file id artifact_type title status phase schema_version rev work_package parent links_json based_on_json
  local epic_file epic_entry

  [ -d "$feature_dir" ] || {
    printf '[]\n'
    return 0
  }

  {
    epic_file="$(dirname "$feature_dir")/EPIC.md"
    epic_entry="$(sdd_feature_epic_entry_from_dir "$feature_dir" 2>/dev/null || true)"
    if [ -n "$epic_entry" ] && [ -f "$epic_file" ]; then
      id="$(sdd_frontmatter_value "$epic_file" id 2>/dev/null || true)"
      if [ -n "$id" ]; then
        title="$(sdd_frontmatter_value "$epic_file" title 2>/dev/null || true)"
        status="$(sdd_frontmatter_value "$epic_file" status 2>/dev/null || true)"
        phase="$(sdd_frontmatter_value "$epic_file" phase 2>/dev/null || true)"
        schema_version="$(sdd_frontmatter_value "$epic_file" schema_version 2>/dev/null || true)"
        rev="$(sdd_artifact_rev "$epic_file" 2>/dev/null || true)"
        links_json="$(sdd_synthesize_links "$epic_file")"
        based_on_json="$(sdd_frontmatter_json "$epic_file" based_on "{}")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$id" "$epic_file" "epic" "$title" "$status" "$phase" "$rev" \
          "" "" "$schema_version" "$links_json" "$based_on_json"
      fi
    fi

    while IFS= read -r file; do
      id="$(sdd_frontmatter_value "$file" id 2>/dev/null || true)"
      [ -n "$id" ] || continue

      artifact_type="$(sdd_frontmatter_value "$file" type 2>/dev/null || true)"
      title="$(sdd_frontmatter_value "$file" title 2>/dev/null || true)"
      status="$(sdd_frontmatter_value "$file" status 2>/dev/null || true)"
      phase="$(sdd_frontmatter_value "$file" phase 2>/dev/null || true)"
      schema_version="$(sdd_frontmatter_value "$file" schema_version 2>/dev/null || true)"
      work_package="$(sdd_frontmatter_value "$file" work_package 2>/dev/null || true)"
      parent="$(sdd_frontmatter_value "$file" parent 2>/dev/null || true)"
      rev="$(sdd_artifact_rev "$file" 2>/dev/null || true)"
      links_json="$(sdd_synthesize_links "$file")"
      based_on_json="$(sdd_frontmatter_json "$file" based_on "{}")"

      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$id" "$file" "$artifact_type" "$title" "$status" "$phase" "$rev" \
        "$work_package" "$parent" "$schema_version" "$links_json" "$based_on_json"
    done < <(sdd_trace_feature_markdown_files "$feature_dir")
  } | jq -Rsc '
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map({
        id: .[0],
        kind: "artifact",
        path: .[1],
        line: 2,
        title: (if .[3] == "" then .[0] else .[3] end),
        artifact_type: (if .[2] == "" then null else .[2] end),
        status: (if .[4] == "" then null else .[4] end),
        phase: (if .[5] == "" then null else .[5] end),
        rev: (if .[6] == "" then null else .[6] end),
        schema_version: (if .[9] == "" then null else (.[9] | tonumber? // .[9]) end),
        work_package: (if .[7] == "" then null else .[7] end),
        parent: (if .[8] == "" then null else .[8] end),
        links: ((.[10] | fromjson?) // {derived_from: [], informed_by: [], supersedes: []}),
        based_on: ((.[11] | fromjson?) // {})
      })
    | reduce .[] as $node ([]; if any(.[]; .id == $node.id) then . else . + [$node] end)
  '
}

sdd_trace_extract_spec_nodes() {
  local spec_file="$1"
  [ -f "$spec_file" ] || {
    printf '[]\n'
    return 0
  }

  {
    sdd_parse_id_rows_tsv FR "$spec_file" headings | awk -F '\t' '{ printf "fr\t%s\t%s\t%s\n", $1, $2, $3 }'
    sdd_parse_id_rows_tsv AC "$spec_file" headings | awk -F '\t' '{ printf "ac\t%s\t%s\t%s\n", $1, $2, $3 }'
  } | jq -Rsc --arg path "$spec_file" '
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map({
        id: .[1],
        kind: .[0],
        path: $path,
        line: (.[2] | tonumber),
        title: .[3]
      })
  '
}

sdd_trace_extract_plan_nodes() {
  local plan_file="$1"
  [ -f "$plan_file" ] || {
    printf '[]\n'
    return 0
  }

  {
    awk '
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^### PH-[0-9]+:/ {
      id = $0
      sub(/^### /, "", id)
      sub(/:.*/, "", id)
      title = $0
      sub(/^### PH-[0-9]+:[[:space:]]*/, "", title)
      printf "ph\t%s\t%d\t%s\n", id, NR, title
    }
    ' "$plan_file"
    sdd_parse_id_rows_tsv AD "$plan_file" | awk -F '\t' '{ printf "ad\t%s\t%s\t%s\n", $1, $2, $3 }'
  } | jq -Rsc --arg path "$plan_file" '
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map({
        id: .[1],
        kind: .[0],
        path: $path,
        line: (.[2] | tonumber),
        title: .[3]
      })
  '
}

sdd_trace_task_heading_line() {
  local tasks_file="$1" task_id="$2"
  [ -f "$tasks_file" ] || return 1
  awk -v tid="$task_id" '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && index($0, "## " tid ":") == 1 {
      print NR
      exit
    }
  ' "$tasks_file"
}

sdd_trace_task_field_line() {
  local tasks_file="$1" task_id="$2" field="$3"
  [ -f "$tasks_file" ] || return 1
  awk -v tid="$task_id" -v field="$field" '
    /^```/ { in_fence = !in_fence; next }
    !in_fence && /^## T-[0-9]+:/ {
      if (in_task) exit
      in_task = (index($0, "## " tid ":") == 1)
      next
    }
    !in_fence && in_task && $0 ~ "^> " field ": " {
      print NR
      exit
    }
  ' "$tasks_file"
}

sdd_trace_extract_task_nodes() {
  local tasks_file="$1"
  local work_package="" task_prefix=""

  [ -f "$tasks_file" ] || {
    printf '[]\n'
    return 0
  }

  work_package="$(sdd_task_work_package_from_tasks_file "$tasks_file")"
  if [ -n "$work_package" ]; then
    task_prefix="$(sdd_task_wp_ref_prefix "$work_package")"
  fi

  awk -v prefix="$task_prefix" '
    function flush_task() {
      if (task_id == "") return
      node_id = task_id
      if (prefix != "") node_id = prefix "/" task_id
      printf "%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n", node_id, task_id, line, title, status, phase, implements, depends_on, files
    }
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^## T-[0-9]+:/ {
      flush_task()
      line = NR
      heading = substr($0, 4)
      task_id = heading
      sub(/:.*/, "", task_id)
      title = heading
      sub(/^[^:]+: /, "", title)
      status = ""; phase = ""; implements = ""; depends_on = ""; files = ""
      next
    }
    /^> Status: / { status = substr($0, 11); next }
    /^> Phase: / { phase = substr($0, 10); next }
    /^> Implements: / { implements = substr($0, 15); next }
    /^> Depends-on: / { depends_on = substr($0, 14); next }
    /^> Files: / { files = substr($0, 9); next }
    END { flush_task() }
  ' "$tasks_file" | jq -Rsc --arg path "$tasks_file" --arg work_package "$work_package" '
    def parse_list($raw):
      ($raw | gsub("^\\s+|\\s+$"; "")) as $trimmed
      | if $trimmed == "" then []
        else
          try (
            $trimmed
            | fromjson
            | if type == "array" then
                map(if type == "string" then
                  gsub("^\\s+|\\s+$"; "")
                  | if test("^[A-Za-z]+-[0-9]+(/[A-Za-z]+-[0-9]+)?\\s*\\([^)]*\\)\\s*$") then gsub("\\s*\\([^)]*\\)\\s*$"; "") else . end
                else tostring end)
                | map(select(length > 0))
              else
                error("not-array")
              end
          ) catch (
            ($trimmed | if startswith("[") and endswith("]") then .[1:-1] else . end)
            | split(",")
            | map(gsub("^\\s+|\\s+$"; ""))
            | map(if (startswith("\"") and endswith("\"")) and (length >= 2) then .[1:-1] else . end)
            | map(gsub("^\\s+|\\s+$"; ""))
            | map(if test("^[A-Za-z]+-[0-9]+(/[A-Za-z]+-[0-9]+)?\\s*\\([^)]*\\)\\s*$") then gsub("\\s*\\([^)]*\\)\\s*$"; "") else . end)
            | map(select(length > 0))
          )
        end;
    def clean_file:
      gsub("^\\s+|\\s+$"; "")
      | sub("^`"; "")
      | sub("`$"; "")
      | if test("^\\[[^]]+\\]\\([^)]*\\)$") then sub("^\\["; "") | sub("\\]\\([^)]*\\)$"; "") else . end
      | sub("^\\["; "")
      | sub("\\]$"; "")
      | sub("\\s*\\(.*$"; "");
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map({
        id: .[0],
        kind: "task",
        path: $path,
        line: (.[2] | tonumber),
        title: .[3],
        status: (if .[4] == "" then null else .[4] end),
        phase: (if .[5] == "" then null else .[5] end),
        work_package: (if $work_package == "" then null else $work_package end),
        implements: parse_list(.[6]),
        depends_on: parse_list(.[7]),
        files: (parse_list(.[8]) | map(clean_file) | map(select(length > 0)))
      })
    | reduce .[] as $node ([]; if any(.[]; .id == $node.id) then . else . + [$node] end)
  '
}

sdd_trace_extract_file_nodes() {
  local research_file="$1" tasks_file="${2:-}"
  local task_file

  {
    if [ -f "$research_file" ]; then
      while IFS=$'\t' read -r path action module impact relates; do
        printf 'research\t%s\t%s\t%s\t%s\t%s\n' "$path" "$action" "$module" "$impact" "$relates"
      done < <(sdd_affected_files_rows_tsv "$research_file")
    fi

    if [ -n "$tasks_file" ]; then
      while IFS= read -r task_file; do
        [ -f "$task_file" ] || continue
        awk -v task_file="$task_file" '
          /^```/ { in_fence = !in_fence; next }
          in_fence { next }
          /^> Files: / { print "task\t" task_file "\t" substr($0, 9) }
        ' "$task_file"
      done < <(sdd_task_feature_task_files "$tasks_file")
    fi
  } | jq -Rsc '
    def parse_list($raw):
      ($raw | gsub("^\\s+|\\s+$"; "")) as $trimmed
      | if $trimmed == "" then []
        else
          try (
            $trimmed
            | fromjson
            | if type == "array" then
                map(if type == "string" then
                  gsub("^\\s+|\\s+$"; "")
                  | if test("^[A-Za-z]+-[0-9]+(/[A-Za-z]+-[0-9]+)?\\s*\\([^)]*\\)\\s*$") then gsub("\\s*\\([^)]*\\)\\s*$"; "") else . end
                else tostring end)
                | map(select(length > 0))
              else
                error("not-array")
              end
          ) catch (
            ($trimmed | if startswith("[") and endswith("]") then .[1:-1] else . end)
            | split(",")
            | map(gsub("^\\s+|\\s+$"; ""))
            | map(if (startswith("\"") and endswith("\"")) and (length >= 2) then .[1:-1] else . end)
            | map(gsub("^\\s+|\\s+$"; ""))
            | map(if test("^[A-Za-z]+-[0-9]+(/[A-Za-z]+-[0-9]+)?\\s*\\([^)]*\\)\\s*$") then gsub("\\s*\\([^)]*\\)\\s*$"; "") else . end)
            | map(select(length > 0))
          )
        end;
    def clean_file:
      gsub("^\\s+|\\s+$"; "")
      | sub("^`"; "")
      | sub("`$"; "")
      | if test("^\\[[^]]+\\]\\([^)]*\\)$") then sub("^\\["; "") | sub("\\]\\([^)]*\\)$"; "") else . end
      | sub("^\\["; "")
      | sub("\\]$"; "")
      | sub("\\s*\\(.*$"; "");
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map(
        if .[0] == "research" then
          (.[1] | clean_file) as $path
          | if $path == "" then [] else [{
              id: ("FILE:" + $path),
              kind: "file",
              path: $path,
              line: null,
              title: $path,
              action: (if .[2] == "" then null else .[2] end),
              module: (if .[3] == "" then null else .[3] end),
              impact: (if .[4] == "" then null else .[4] end),
              relates_to: (if .[5] == "" then null else .[5] end)
            }] end
        elif .[0] == "task" then
          .[1] as $declared_in
          | parse_list(.[2])
          | map(clean_file)
          | map(select(length > 0))
          | map({
              id: ("FILE:" + .),
              kind: "file",
              path: .,
              line: null,
              title: .,
              declared_in: $declared_in
            })
        else
          []
        end
      )
    | (add // [])
    | reduce .[] as $node ([]; if any(.[]; .id == $node.id) then . else . + [$node] end)
  '
}

sdd_trace_extract_edges() {
  local feature_dir="$1"
  local file from_id links_json
  local plan_file tasks_file task_file task_prefix work_package review_id artifact_type

  [ -d "$feature_dir" ] || {
    printf '[]\n'
    return 0
  }

  {
    while IFS= read -r file; do
      from_id="$(sdd_frontmatter_value "$file" id 2>/dev/null || true)"
      [ -n "$from_id" ] || continue
      links_json="$(sdd_synthesize_links "$file")"
      printf 'links\t%s\t%s\t%s\n' "$from_id" "$file:frontmatter" "$links_json"
    done < <(sdd_trace_feature_markdown_files "$feature_dir")

    plan_file="$feature_dir/plan.md"
    if [ -f "$plan_file" ]; then
      awk -v plan_file="$plan_file" '
        /^```/ { in_fence = !in_fence; next }
        in_fence { next }
        /^### PH-[0-9]+:/ {
          current = $0
          sub(/^### /, "", current)
          sub(/:.*/, "", current)
          next
        }
        current != "" && /^> Addresses: / {
          payload = substr($0, 14)
          marker = " — Acceptance: "
          marker_pos = index(payload, marker)
          if (marker_pos > 0) {
            addresses = substr(payload, 1, marker_pos - 1)
            acceptance = substr(payload, marker_pos + length(marker))
            print "rawlist\t" current "\taddresses\t" plan_file ":" NR "\t" addresses
            print "rawlist\t" current "\tvalidates\t" plan_file ":" NR "\t" acceptance
            next
          }
          print "rawlist\t" current "\taddresses\t" plan_file ":" NR "\t" payload
          next
        }
        current != "" && /^> Acceptance: / {
          print "rawlist\t" current "\tvalidates\t" plan_file ":" NR "\t" substr($0, 15)
        }
      ' "$plan_file"
    fi

    tasks_file="$feature_dir/tasks.md"
    while IFS= read -r task_file; do
      [ -f "$task_file" ] || continue
      work_package="$(sdd_task_work_package_from_tasks_file "$task_file")"
      task_prefix=""
      if [ -n "$work_package" ]; then
        task_prefix="$(sdd_task_wp_ref_prefix "$work_package")"
      fi
      awk -v task_file="$task_file" -v prefix="$task_prefix" '
        function flush_task() {
          if (task_id == "") return
          from_task = task_id
          if (prefix != "") from_task = prefix "/" task_id
          if (implements != "") print "rawlist\t" from_task "\timplements\t" task_file ":" implements_line "\t" implements
          if (depends_on != "") print "task_dep\t" from_task "\tdepends_on\t" task_file ":" depends_line "\t" depends_on "\t" prefix
          if (files != "") print "task_file\t" from_task "\ttouches\t" task_file ":" files_line "\t" files
        }
        /^```/ { in_fence = !in_fence; next }
        in_fence { next }
        /^## T-[0-9]+:/ {
          flush_task()
          heading = substr($0, 4)
          task_id = heading
          sub(/:.*/, "", task_id)
          implements = ""; depends_on = ""; files = ""
          implements_line = ""; depends_line = ""; files_line = ""
          next
        }
        /^> Implements: / { implements = substr($0, 15); implements_line = NR; next }
        /^> Depends-on: / { depends_on = substr($0, 14); depends_line = NR; next }
        /^> Files: / { files = substr($0, 9); files_line = NR; next }
        END { flush_task() }
      ' "$task_file"
    done < <(sdd_task_feature_task_files "$tasks_file")

    while IFS= read -r file; do
      artifact_type="$(sdd_frontmatter_value "$file" type 2>/dev/null || true)"
      [ "$artifact_type" = "review" ] || continue
      review_id="$(sdd_frontmatter_value "$file" id 2>/dev/null || true)"
      [ -n "$review_id" ] || continue
      awk -v review_id="$review_id" -v review_file="$file" '
        function trim(s) {
          gsub(/^[ \t]+|[ \t]+$/, "", s)
          return s
        }
        /^```/ { in_fence = !in_fence; next }
        in_fence { next }
        /^\|/ {
          if ($0 ~ /^\|[[:space:]]*AC[[:space:]]*\|/) next
          if ($0 ~ /^\|[[:space:]]*:?-+:?[[:space:]]*\|/) next
          split($0, cols, "|")
          ac_id = trim(cols[2])
          status = trim(cols[4])
          if (ac_id ~ /^AC-[0-9]+$/ && status != "" && status != "—" && status != "-") {
            print "direct\t" review_id "\t" ac_id "\tvalidates\t" review_file ":" NR
          }
        }
      ' "$file"
    done < <(sdd_trace_feature_markdown_files "$feature_dir")
  } | jq -Rsc '
    def parse_list($raw):
      ($raw | gsub("^\\s+|\\s+$"; "")) as $trimmed
      | if $trimmed == "" then []
        else
          try (
            $trimmed
            | fromjson
            | if type == "array" then
                map(if type == "string" then
                  gsub("^\\s+|\\s+$"; "")
                  | if test("^[A-Za-z]+-[0-9]+(/[A-Za-z]+-[0-9]+)?\\s*\\([^)]*\\)\\s*$") then gsub("\\s*\\([^)]*\\)\\s*$"; "") else . end
                else tostring end)
                | map(select(length > 0))
              else
                error("not-array")
              end
          ) catch (
            ($trimmed | if startswith("[") and endswith("]") then .[1:-1] else . end)
            | split(",")
            | map(gsub("^\\s+|\\s+$"; ""))
            | map(if (startswith("\"") and endswith("\"")) and (length >= 2) then .[1:-1] else . end)
            | map(gsub("^\\s+|\\s+$"; ""))
            | map(if test("^[A-Za-z]+-[0-9]+(/[A-Za-z]+-[0-9]+)?\\s*\\([^)]*\\)\\s*$") then gsub("\\s*\\([^)]*\\)\\s*$"; "") else . end)
            | map(select(length > 0))
          )
        end;
    def clean_file:
      gsub("^\\s+|\\s+$"; "")
      | sub("^`"; "")
      | sub("`$"; "")
      | if test("^\\[[^]]+\\]\\([^)]*\\)$") then sub("^\\["; "") | sub("\\]\\([^)]*\\)$"; "") else . end
      | sub("^\\["; "")
      | sub("\\]$"; "")
      | sub("\\s*\\(.*$"; "");
    def edge($from; $to; $type; $declared):
      {from: $from, to: $to, type: $type, declared_in: $declared};
    split("\n")
    | map(select(length > 0))
    | map(split("\t"))
    | map(
        if .[0] == "links" then
          .[1] as $from
          | .[2] as $declared
          | ((.[3] | fromjson?) // {derived_from: [], informed_by: [], supersedes: []}) as $links
          | ([ $links.derived_from[]? | edge($from; .; "derived_from"; $declared) ]
             + [ $links.informed_by[]? | edge($from; .; "informed_by"; $declared) ]
             + [ $links.supersedes[]? | edge($from; .; "supersedes"; $declared) ])
        elif .[0] == "rawlist" then
          .[1] as $from
          | .[2] as $type
          | .[3] as $declared
          | parse_list(.[4])
          | map(edge($from; .; $type; $declared))
        elif .[0] == "task_dep" then
          .[1] as $from
          | .[2] as $type
          | .[3] as $declared
          | .[5] as $prefix
          | parse_list(.[4])
          | map(if $prefix != "" and test("^T-[0-9]+$") then ($prefix + "/" + .) else . end)
          | map(edge($from; .; $type; $declared))
        elif .[0] == "task_file" then
          .[1] as $from
          | .[2] as $type
          | .[3] as $declared
          | parse_list(.[4])
          | map(clean_file)
          | map(select(length > 0))
          | map(edge($from; ("FILE:" + .); $type; $declared))
        elif .[0] == "direct" then
          [edge(.[1]; .[2]; .[3]; .[4])]
        else
          []
        end
      )
    | (add // [])
    | reduce .[] as $edge (
        [];
        if any(.[]; .from == $edge.from and .to == $edge.to and .type == $edge.type and .declared_in == $edge.declared_in)
        then .
        else . + [$edge]
        end
      )
  '
}

sdd_trace_path() {
  local feature="$1"
  printf '%s/%s/trace.json\n' "$SDD_FEATURE_ROOT" "$feature"
}

sdd_trace_rules_path() {
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s/../references/trace-rules.json\n' "$lib_dir"
}

sdd_trace_suspect_summary_json() {
  local feature="$1"
  local trace_file="${2:-$(sdd_trace_path "$feature")}"

  if [ ! -f "$trace_file" ] || ! jq -e . "$trace_file" >/dev/null 2>&1; then
    printf '%s\n' '{"present":false,"suspect_artifacts":0,"suspect_ids":[]}'
    return 0
  fi

  jq -c '
    {
      present: true,
      suspect_artifacts: (.basis | to_entries | map(select(.value.suspect == true)) | length),
      suspect_ids: [.basis | to_entries[] | select(.value.suspect == true) | .key]
    }
  ' "$trace_file"
}

sdd_trace_coverage_jq_defs() {
  cat <<'EOF'
def pattern_to_regex:
  if test("[\\[\\](){}/+?|.^$\\\\]") then .
  else gsub("([.^$+?()\\[\\]{}|\\\\])"; "\\\\\\1") | gsub("\\*"; ".*")
  end;
def matches_patterns($value; $patterns):
  any($patterns[]?; . as $pattern | $value | test("^" + ($pattern | pattern_to_regex) + "$"));
def expectation_text($min; $max):
  if $max == null then "expected >= " + ($min | tostring)
  elif $min == $max then "expected = " + ($min | tostring)
  else "expected >= " + ($min | tostring) + " and <= " + ($max | tostring)
  end;
EOF
}

sdd_trace_coverage_evaluate_artifact_rule() {
  local trace_file="$1" artifact_type="$2" link_type="$3" rule_json="$4"

  jq -cn \
    --slurpfile trace "$trace_file" \
    --arg artifact_type "$artifact_type" \
    --arg link_type "$link_type" \
    --arg rule_id "artifact.${artifact_type}.${link_type}" \
    --argjson rule "$rule_json" \
    "$(sdd_trace_coverage_jq_defs)
    (\$trace[0]) as \$t
    | (\$rule.targets // []) as \$targets
    | (\$rule.min // 0) as \$min
    | (\$rule.max // null) as \$max
    | (\$rule.description // (\"Artifact link rule for \" + \$artifact_type + \".\" + \$link_type)) as \$description
    | [ \$t.nodes | to_entries[] | select(.value.kind == \"artifact\" and (.value.artifact_type // \"\") == \$artifact_type) | .key ] as \$subjects
    | if (\$subjects | length) == 0 then
        {
          id: \$rule_id,
          name: \$rule_id,
          category: \"artifact_links\",
          status: \"SKIP\",
          description: \$description,
          applicable: 0,
          passed: 0,
          failed: 0,
          score: null,
          expected: {
            artifact_type: \$artifact_type,
            edge_type: \$link_type,
            targets: \$targets,
            min: \$min,
            max: \$max
          },
          actual: {
            subjects: 0,
            evaluated: []
          },
          gaps: [],
          note: (\"No \" + \$artifact_type + \" artifacts found\")
        }
      else
        [ \$subjects[] as \$subject
          | ([ \$t.edges[] | select(.from == \$subject and .type == \$link_type and matches_patterns(.to; \$targets)) | .to ] | unique) as \$matches
          | {
              subject: \$subject,
              count: (\$matches | length),
              matches: \$matches,
              ok: ((\$matches | length) >= \$min and (\$max == null or (\$matches | length) <= \$max))
            }
        ] as \$evaluated
        | (\$evaluated | map(select(.ok)) | length) as \$passed
        | (\$subjects | length) as \$applicable
        | (\$applicable - \$passed) as \$failed
        | {
            id: \$rule_id,
            name: \$rule_id,
            category: \"artifact_links\",
            status: (if \$failed == 0 then \"PASS\" else \"FAIL\" end),
            description: \$description,
            applicable: \$applicable,
            passed: \$passed,
            failed: \$failed,
            score: (if \$applicable > 0 then (((\$passed / \$applicable) * 10000) | round / 100) else null end),
            expected: {
              artifact_type: \$artifact_type,
              edge_type: \$link_type,
              targets: \$targets,
              min: \$min,
              max: \$max
            },
            actual: {
              subjects: \$applicable,
              evaluated: \$evaluated
            },
            gaps: [
              \$evaluated[]
              | select(.ok | not)
              | (.subject + \" has \" + (.count | tostring) + \" \" + \$link_type + \" link(s) to \" + (\$targets | join(\", \")) + \" (\" + expectation_text(\$min; \$max) + \")\")
            ]
          }
      end"
}

sdd_trace_coverage_evaluate_body_rule() {
  local trace_file="$1" rule_name="$2" rule_json="$3"

  jq -cn \
    --slurpfile trace "$trace_file" \
    --arg rule_name "$rule_name" \
    --argjson rule "$rule_json" \
    "$(sdd_trace_coverage_jq_defs)
    (\$trace[0]) as \$t
    | (\$rule.targets // []) as \$targets
    | (\$rule.min // 0) as \$min
    | (\$rule.max // null) as \$max
    | (\$rule.edge_type // \"\") as \$edge_type
    | (\$rule.source_kind // \"\") as \$source_kind
    | (\$rule.source_artifact_type // \"\") as \$source_artifact_type
    | (\$rule.source_label // (if \$source_kind == \"artifact\" and \$source_artifact_type != \"\" then (\$source_artifact_type + \" artifact(s)\") else (\$source_kind + \" node(s)\") end)) as \$source_label
    | (\$rule.description // \$rule_name) as \$description
    | (\$rule.acyclic // false) as \$acyclic
    | (\$rule.coverage // false) as \$coverage
    | [ \$t.nodes | to_entries[] | select(matches_patterns(.key; \$targets)) | .key ] as \$matched_targets
    | [ \$t.nodes | to_entries[] | select(.value.kind == \"task\") | .key ] as \$task_ids
    | if \$acyclic == true then
        [ \$t.problems[]? | select((.type // \"\") == \"missing_dependency\" or (.type // \"\") == \"self_dependency\" or (.type // \"\") == \"dependency_cycle\") | .message ] as \$problems
        | if (\$task_ids | length) == 0 then
            {
              id: \$rule_name,
              name: \$rule_name,
              category: \"body_fields\",
              status: \"SKIP\",
              description: \$description,
              applicable: 0,
              passed: 0,
              failed: 0,
              score: null,
              expected: {
                edge_type: \$edge_type,
                targets: \$targets,
                coverage: \$coverage,
                acyclic: true,
                source_kind: \$source_kind
              },
              actual: {
                tasks: 0,
                problem_count: 0
              },
              gaps: [],
              note: \"No task nodes found\"
            }
          else
            {
              id: \$rule_name,
              name: \$rule_name,
              category: \"body_fields\",
              status: (if (\$problems | length) == 0 then \"PASS\" else \"FAIL\" end),
              description: \$description,
              applicable: 1,
              passed: (if (\$problems | length) == 0 then 1 else 0 end),
              failed: (if (\$problems | length) == 0 then 0 else 1 end),
              score: (if (\$problems | length) == 0 then 100 else 0 end),
              expected: {
                edge_type: \$edge_type,
                targets: \$targets,
                coverage: \$coverage,
                acyclic: true,
                source_kind: \$source_kind
              },
              actual: {
                tasks: (\$task_ids | length),
                problem_count: (\$problems | length)
              },
              gaps: \$problems
            }
          end
      elif (\$matched_targets | length) == 0 then
        {
          id: \$rule_name,
          name: \$rule_name,
          category: \"body_fields\",
          status: \"SKIP\",
          description: \$description,
          applicable: 0,
          passed: 0,
          failed: 0,
          score: null,
          expected: {
            edge_type: \$edge_type,
            targets: \$targets,
            min: \$min,
            max: \$max,
            coverage: \$coverage,
            source_kind: \$source_kind,
            source_artifact_type: (if \$source_artifact_type == \"\" then null else \$source_artifact_type end)
          },
          actual: {
            targets: 0,
            evaluated: []
          },
          gaps: [],
          note: (\"No targets matched \" + (\$targets | join(\", \")))
        }
      else
        [ \$matched_targets[] as \$target
          | (
              if \$edge_type == \"implements\" and \$source_kind == \"task\" then
                (\$t.indexes.implemented_by[\$target] // [])
                | map(select((\$t.nodes[.] // null) != null and ((\$t.nodes[.].kind // \"\") == \"task\")))
              else
                [
                  \$t.edges[]
                  | select(.to == \$target and .type == \$edge_type)
                  | .from
                  | select((\$t.nodes[.] // null) != null)
                  | select(
                      if \$source_kind == \"artifact\" then
                        ((\$t.nodes[.].kind // \"\") == \"artifact\" and (\$source_artifact_type == \"\" or ((\$t.nodes[.].artifact_type // \"\") == \$source_artifact_type)))
                      else
                        ((\$t.nodes[.].kind // \"\") == \$source_kind)
                      end
                    )
                ] | unique
              end
            ) as \$sources
          | {
              target: \$target,
              count: (\$sources | length),
              matches: \$sources,
              ok: ((\$sources | length) >= \$min and (\$max == null or (\$sources | length) <= \$max))
            }
        ] as \$evaluated
        | (\$evaluated | map(select(.ok)) | length) as \$passed
        | (\$matched_targets | length) as \$applicable
        | (\$applicable - \$passed) as \$failed
        | {
            id: \$rule_name,
            name: \$rule_name,
            category: \"body_fields\",
            status: (if \$failed == 0 then \"PASS\" else \"FAIL\" end),
            description: \$description,
            applicable: \$applicable,
            passed: \$passed,
            failed: \$failed,
            score: (if \$applicable > 0 then (((\$passed / \$applicable) * 10000) | round / 100) else null end),
            expected: {
              edge_type: \$edge_type,
              targets: \$targets,
              min: \$min,
              max: \$max,
              coverage: \$coverage,
              source_kind: \$source_kind,
              source_artifact_type: (if \$source_artifact_type == \"\" then null else \$source_artifact_type end)
            },
            actual: {
              targets: \$applicable,
              evaluated: \$evaluated
            },
            gaps: [
              \$evaluated[]
              | select(.ok | not)
              | (.target + \" has \" + (.count | tostring) + \" \" + \$source_label + \" via \" + \$edge_type + \" (\" + expectation_text(\$min; \$max) + \")\")
            ]
          }
      end"
}

sdd_trace_coverage_skip_result() {
  local rule_id="$1" category="$2" profile="$3"
  jq -cn \
    --arg id "$rule_id" \
    --arg category "$category" \
    --arg profile "$profile" \
    '{
      id: $id,
      name: $id,
      category: $category,
      status: "SKIP",
      description: ("rule not applicable for profile " + $profile),
      applicable: 0,
      passed: 0,
      failed: 0,
      score: null,
      gaps: [],
      note: ("skipped: rule.profile does not include " + $profile)
    }'
}

sdd_trace_coverage_rule_applies() {
  local rule_json="$1" profile="$2"
  printf '%s\n' "$rule_json" | jq -r --arg p "$profile" '(.profile // null) as $rp | if $rp == null then "true" elif ($rp | type) != "array" then "true" elif ($rp | index($p)) != null then "true" else "false" end'
}

sdd_trace_coverage_evaluate() {
  local feature_dir="$1"
  local rules_file="${2:-$(sdd_trace_rules_path)}"
  local feature trace_file schema_version profile
  local rules_json artifact_entry link_entry body_entry rule_json result_json rules_results='[]'
  local applies artifact_key link_key body_key rule_id

  feature="$(basename "$feature_dir")"
  trace_file="$feature_dir/trace.json"
  profile="$(sdd_profile "$feature_dir")"

  if [ ! -f "$rules_file" ] || ! jq -e . "$rules_file" >/dev/null 2>&1; then
    jq -cn \
      --arg feature "$feature" \
      --arg feature_dir "$feature_dir" \
      --arg trace_path "$trace_file" \
      --arg rules_path "$rules_file" \
      '{
        present: false,
        feature: $feature,
        feature_dir: $feature_dir,
        trace_path: $trace_path,
        rules_path: $rules_path,
        status: "SKIP",
        score: 0,
        rules: [],
        summary: {
          rules_total: 0,
          rules_passed: 0,
          rules_failed: 0,
          rules_skipped: 0,
          evaluated_rules: 0,
          applicable_checks: 0,
          checks_passed: 0,
          checks_failed: 0
        },
        note: "trace rules file is missing or invalid"
      }'
    return 0
  fi

  if [ ! -f "$trace_file" ] || ! jq -e . "$trace_file" >/dev/null 2>&1; then
    jq -cn \
      --arg feature "$feature" \
      --arg feature_dir "$feature_dir" \
      --arg trace_path "$trace_file" \
      --arg rules_path "$rules_file" \
      '{
        present: false,
        feature: $feature,
        feature_dir: $feature_dir,
        trace_path: $trace_path,
        rules_path: $rules_path,
        status: "SKIP",
        score: 0,
        rules: [],
        summary: {
          rules_total: 0,
          rules_passed: 0,
          rules_failed: 0,
          rules_skipped: 0,
          evaluated_rules: 0,
          applicable_checks: 0,
          checks_passed: 0,
          checks_failed: 0
        },
        note: "trace.json is missing or invalid"
      }'
    return 0
  fi

  schema_version="$(jq -r '.schema_version // 1' "$rules_file")"

  while IFS= read -r artifact_entry; do
    [ -n "$artifact_entry" ] || continue
    while IFS= read -r link_entry; do
      [ -n "$link_entry" ] || continue
      rule_json="$(printf '%s\n' "$link_entry" | jq -c '.value')"
      artifact_key="$(printf '%s\n' "$artifact_entry" | jq -r '.key')"
      link_key="$(printf '%s\n' "$link_entry" | jq -r '.key')"
      applies="$(sdd_trace_coverage_rule_applies "$rule_json" "$profile")"
      if [ "$applies" = "false" ]; then
        rule_id="artifact.${artifact_key}.${link_key}"
        result_json="$(sdd_trace_coverage_skip_result "$rule_id" "artifact_links" "$profile")"
      else
        result_json="$(sdd_trace_coverage_evaluate_artifact_rule "$trace_file" "$artifact_key" "$link_key" "$rule_json")"
      fi
      rules_results="$(printf '%s\n' "$rules_results" | jq -c --argjson result "$result_json" '. + [$result]')"
    done < <(printf '%s\n' "$artifact_entry" | jq -c '.value | to_entries[]?')
  done < <(jq -c '.artifact_links | to_entries[]?' "$rules_file")

  while IFS= read -r body_entry; do
    [ -n "$body_entry" ] || continue
    rule_json="$(printf '%s\n' "$body_entry" | jq -c '.value')"
    body_key="$(printf '%s\n' "$body_entry" | jq -r '.key')"
    applies="$(sdd_trace_coverage_rule_applies "$rule_json" "$profile")"
    if [ "$applies" = "false" ]; then
      result_json="$(sdd_trace_coverage_skip_result "$body_key" "body_fields" "$profile")"
    else
      result_json="$(sdd_trace_coverage_evaluate_body_rule "$trace_file" "$body_key" "$rule_json")"
    fi
    rules_results="$(printf '%s\n' "$rules_results" | jq -c --argjson result "$result_json" '. + [$result]')"
  done < <(jq -c '.body_fields | to_entries[]?' "$rules_file")

  jq -cn \
    --arg feature "$feature" \
    --arg feature_dir "$feature_dir" \
    --arg trace_path "$trace_file" \
    --arg rules_path "$rules_file" \
    --argjson schema_version "$schema_version" \
    --argjson rules "$rules_results" \
    '{
      present: true,
      feature: $feature,
      feature_dir: $feature_dir,
      trace_path: $trace_path,
      rules_path: $rules_path,
      schema_version: $schema_version,
      rules: $rules
    }
    | .summary = (
        reduce .rules[] as $rule (
          {
            rules_total: (.rules | length),
            rules_passed: 0,
            rules_failed: 0,
            rules_skipped: 0,
            evaluated_rules: 0,
            applicable_checks: 0,
            checks_passed: 0,
            checks_failed: 0
          };
          if $rule.status == "PASS" then
            .rules_passed += 1
            | .evaluated_rules += 1
          elif $rule.status == "FAIL" then
            .rules_failed += 1
            | .evaluated_rules += 1
          else
            .rules_skipped += 1
          end
          | .applicable_checks += ($rule.applicable // 0)
          | .checks_passed += ($rule.passed // 0)
          | .checks_failed += ($rule.failed // 0)
        )
      )
    | .status = (
        if .summary.rules_failed > 0 then "FAIL"
        elif .summary.evaluated_rules > 0 then "PASS"
        else "SKIP"
        end
      )
    | .score = (
        if .summary.applicable_checks > 0 then
          (((.summary.checks_passed / .summary.applicable_checks) * 10000) | round / 100)
        else
          0
        end
      )'
}

# Dispatch packet prohibitions, aligned with workers.md role templates.
sdd_dispatch_prohibitions() {
  case "$1" in
    implementer)
      cat <<'EOF'
- Do NOT restart the SDD lifecycle (`sdd init`, `sdd spec`, etc.)
- Do NOT infer a conflicting assignment from disk
- Do NOT expand scope without controller approval
- Do NOT modify forbidden artifacts
- Do NOT mark tasks other than your assigned task as complete
EOF
      ;;
    spec-reviewer)
      cat <<'EOF'
- Do NOT restart the SDD lifecycle
- Do NOT modify any code or test files
- Do NOT expand the review scope without controller approval
- Do NOT modify forbidden artifacts
- Do NOT trust the implementer report without checking code
EOF
      ;;
    quality-reviewer)
      cat <<'EOF'
- Do NOT restart the SDD lifecycle
- Do NOT modify any code or test files
- Do NOT expand the review scope without controller approval
- Do NOT modify forbidden artifacts
- Do NOT report unverified findings
EOF
      ;;
    research-scout)
      cat <<'EOF'
- Do NOT modify any code or test files
- Do NOT change spec, plan, or phase state
- Do NOT infer a conflicting assignment from disk
EOF
      ;;
    plan-drafter)
      cat <<'EOF'
- Do NOT implement any code
- Do NOT change spec, brief, or phase state
- Do NOT mark tasks complete
EOF
      ;;
    *)
      printf '%s\n' "- Do NOT infer a conflicting assignment from disk"
      ;;
  esac
}

# Return-format summary aligned with worker-results.md.
# Args: role [dispatch_id [task_id [task_heading]]]
sdd_dispatch_return_format() {
  local role="$1" dispatch_id="${2:-}" task_id="${3:-T-001}" task_heading="${4:-}"
  case "$role" in
    implementer)
      cat <<'EOF'
- Use the implementer worker result format from `references/worker-results.md`
- Required sections: `## Worker Result`, `**Status**: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT`, `### Files Changed`, `### Verification`
EOF
      if command -v jq >/dev/null 2>&1 && [ -n "$dispatch_id" ]; then
        printf '\n## Machine Result Template\n\nCopy this JSON exactly into a `## Machine Result Record` fenced block in your response, then fill in the real values:\n\n```json\n'
        jq -nc \
          --arg dispatch_id "$dispatch_id" \
          --arg task_id "$task_id" \
          --arg task_heading "$task_heading" \
          '{
            schema_version: "sdd-result-v1",
            dispatch_id: $dispatch_id,
            role: "implementer",
            status: "DONE",
            task: {id: $task_id, heading: $task_heading},
            summary: "Brief summary of what was implemented.",
            files_changed: [{path: "path/to/file.sh", action: "modify", description: "What changed"}],
            verification: {command: "bash test.sh", result: "pass"}
          }'
        printf '```\n'
      fi
      ;;
    spec-reviewer|quality-reviewer)
      cat <<'EOF'
- Use the reviewer result format from `references/worker-results.md`
- Required sections: `## Worker Result`, `**Status**: PASS | FAIL | NEEDS_CONTEXT`, `### Findings`, `### Verdict`
EOF
      if command -v jq >/dev/null 2>&1 && [ -n "$dispatch_id" ]; then
        printf '\n## Machine Result Template\n\nCopy this JSON exactly into a `## Machine Result Record` fenced block in your response, then fill in the real values:\n\n```json\n'
        jq -nc \
          --arg dispatch_id "$dispatch_id" \
          --arg role "$role" \
          --arg scope "$task_id" \
          '{
            schema_version: "sdd-result-v1",
            dispatch_id: $dispatch_id,
            role: $role,
            status: "PASS",
            scope: $scope,
            summary: "Brief summary of review.",
            findings: [{id: "F-001", severity: "minor", category: "missing-requirement", description: "Description", location: "n/a", evidence: "n/a", suggestion: "Suggestion"}],
            verdict: "PASS"
          }'
        printf '```\n'
      fi
      ;;
    research-scout)
      cat <<'EOF'
- Use the research-scout result format from `references/worker-results.md`
- Required sections: `## Worker Result`, `**Status**: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT`, `### Findings`, `### Confidence Score`, `### Files Discovered`
EOF
      if command -v jq >/dev/null 2>&1 && [ -n "$dispatch_id" ]; then
        printf '\n## Machine Result Template\n\nCopy this JSON exactly into a `## Machine Result Record` fenced block in your response, then fill in the real values:\n\n```json\n'
        jq -nc \
          --arg dispatch_id "$dispatch_id" \
          --arg scope "${task_id:-feature-scope}" \
          '{
            schema_version: "sdd-result-v1",
            dispatch_id: $dispatch_id,
            role: "research-scout",
            status: "DONE",
            scope: $scope,
            summary: "Brief summary of research findings.",
            findings: [{id: "RS-001", kind: "fact", description: "What was found", evidence: "path/to/file.sh"}],
            confidence: {
              scope_clarity: 0,
              pattern_familiarity: 0,
              dependency_awareness: 0,
              edge_case_coverage: 0,
              test_strategy: 0,
              total: 0,
              verdict: "GO"
            },
            files_discovered: [{path: "path/to/file.sh", action: "review", module: "module", impact: "local", relates_to: "FR-001"}],
            suggested_artifact_updates: []
          }'
        printf '```\n'
      fi
      ;;
    plan-drafter)
      cat <<'EOF'
- Use the plan-drafter result format from `references/worker-results.md`
- Required sections: `## Worker Result`, `**Status**: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT`, `### Proposed Architectural Decisions`, `### Proposed Tasks`
EOF
      if command -v jq >/dev/null 2>&1 && [ -n "$dispatch_id" ]; then
        printf '\n## Machine Result Template\n\nCopy this JSON exactly into a `## Machine Result Record` fenced block in your response, then fill in the real values:\n\n```json\n'
        jq -nc \
          --arg dispatch_id "$dispatch_id" \
          --arg scope "${task_id:-feature-scope}" \
          '{
            schema_version: "sdd-result-v1",
            dispatch_id: $dispatch_id,
            role: "plan-drafter",
            status: "DONE",
            scope: $scope,
            summary: "Brief summary of proposed plan changes.",
            proposed_decisions: [{id: "AD-001", decision: "Decision", rationale: "Rationale", alternatives: []}],
            proposed_tasks: [{id: "T-001", title: "Task title", phase: "PH-01", implements: ["FR-001"], files: [], verification: "bash test.sh"}],
            risks: [],
            suggested_artifact_updates: []
          }'
        printf '```\n'
      fi
      ;;
    *)
      printf '%s\n' "- Use the worker result contract from `references/worker-results.md`"
      ;;
  esac
}

# Feature-local worker ledger directory.
sdd_worker_ledger_dir() {
  local feature="$1"
  printf '%s/%s/workers\n' "$SDD_FEATURE_ROOT" "$feature"
}

# Path for a persisted dispatch ledger entry.
sdd_dispatch_record_path() {
  local feature="$1" dispatch_id="$2"
  printf '%s/dispatch-%s.json\n' "$(sdd_worker_ledger_dir "$feature")" "$dispatch_id"
}

# Path for a persisted result ledger entry.
sdd_result_record_path() {
  local feature="$1" dispatch_id="$2"
  printf '%s/result-%s.json\n' "$(sdd_worker_ledger_dir "$feature")" "$dispatch_id"
}

# Count active (dispatched but not yet completed) worker dispatches for a feature.
# Only considers dispatches modified within the last 8 hours to exclude crashed-session ghosts.
# Output: integer count on stdout.
sdd_active_dispatch_count() {
  local feature="$1"
  local ledger_dir active=0
  ledger_dir="$(sdd_worker_ledger_dir "$feature")"
  [ -d "$ledger_dir" ] || { printf '0\n'; return 0; }
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    local id="${f##*/dispatch-}"; id="${id%.json}"
    [ -f "$ledger_dir/result-$id.json" ] && continue
    active=$((active + 1))
  done < <(find "$ledger_dir" -name "dispatch-*.json" -mmin -480 2>/dev/null)
  printf '%d\n' "$active"
}

# Find the latest persisted dispatch record for a dispatch_id across features.
sdd_find_dispatch_record_path() {
  local dispatch_id="$1"
  local latest=""
  latest="$(LC_ALL=C ls -1t "$SDD_FEATURE_ROOT"/*/workers/dispatch-"$dispatch_id".json 2>/dev/null | head -1 || true)"
  [ -n "$latest" ] && printf '%s\n' "$latest"
}

# Derive the feature id from a worker ledger path.
sdd_feature_from_worker_record_path() {
  local path="$1"
  printf '%s\n' "$path" | awk -F/ '
    {
      for (i = 1; i <= NF; i++) {
        if ($i == ".features" && (i + 1) <= NF) {
          print $(i + 1)
          exit
        }
      }
    }
  '
}

# Atomically write content to a file, creating parent directories as needed.
sdd_write_file_atomic() {
  local path="$1" content="$2"
  local tmp

  tmp="$(sdd_tmp_for_target "$path")" || return 1
  sdd_cleanup_push "$tmp"
  if ! printf '%s\n' "$content" > "$tmp"; then
    sdd_cleanup_file "$tmp"
    return 1
  fi
  sdd_atomic_replace "$tmp" "$path"
}

# Extract the canonical machine dispatch record JSON from stdin.
sdd_extract_machine_dispatch_record() {
  awk '
    $0 == "## Machine Dispatch Record" { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && /^```json[[:space:]]*$/ { in_json = 1; next }
    in_json && /^```[[:space:]]*$/ { exit }
    in_json { print }
  '
}

# Extract the canonical machine result record JSON from stdin.
sdd_extract_machine_result_record() {
  awk '
    $0 == "## Machine Result Record" { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && /^```json[[:space:]]*$/ { in_json = 1; next }
    in_json && /^```[[:space:]]*$/ { exit }
    in_json { print }
  '
}

# Normalize common near-miss worker result JSON shapes.
# Reads JSON string from stdin, writes normalized JSON + _normalization_warnings to stdout.
# Safe to call on already-correct input (passthrough with empty warnings array).
sdd_normalize_result_deviations() {
  local json="$1"
  command -v jq >/dev/null 2>&1 || { printf '%s\n' "$json"; return 0; }
  printf '%s\n' "$json" | jq -c '
    . as $orig
    | . as $in
    | []
    | . as $w

    # Normalize flat task_id string to task object
    | if ($in | has("task_id")) and ($in | has("task") | not) then
        ($w + ["task_id: flattened string normalized to task object"]) as $w2
        | {in: ($in | del(.task_id) + {task: {id: ($in.task_id // ""), heading: ""}}), w: $w2}
      else
        {in: $in, w: $w}
      end
    | . as {in: $in, w: $w}

    # Normalize string verification to verification object
    | if ($in.verification | type) == "string" then
        ($w + ["verification: string normalized to {command,result} object"]) as $w2
        | {in: ($in | .verification = {command: "", result: $in.verification}), w: $w2}
      else
        {in: $in, w: $w}
      end
    | . as {in: $in, w: $w}

    # Normalize string-array files_changed to object-array
    | if ($in.files_changed | type) == "array" and ([$in.files_changed[] | type] | any(. == "string")) then
        ($w + ["files_changed: string elements normalized to {path,action,description} objects"]) as $w2
        | {in: ($in | .files_changed = [$in.files_changed[] | if type == "string" then {path: ., action: "unknown", description: ""} else . end]), w: $w2}
      else
        {in: $in, w: $w}
      end
    | . as {in: $in, w: $w}

    # Auto-fill missing summary with placeholder
    | if ($in.summary // "") == "" then
        ($w + ["summary: missing field auto-filled with placeholder"]) as $w2
        | {in: ($in | .summary = "(no summary provided)"), w: $w2}
      else
        {in: $in, w: $w}
      end

    | .in + {_normalization_warnings: .w}
  ' 2>/dev/null || printf '%s\n' "$json"
}

# Build a minimal valid repair example JSON for a worker role.
# Args: role, dispatch_id, task_id
sdd_build_repair_example() {
  local role="$1" dispatch_id="$2" task_id="${3:-T-001}"
  command -v jq >/dev/null 2>&1 || return 0

  case "$role" in
    implementer)
      jq -nc \
        --arg dispatch_id "$dispatch_id" \
        --arg task_id "$task_id" \
        '{
          schema_version: "sdd-result-v1",
          dispatch_id: $dispatch_id,
          role: "implementer",
          status: "DONE",
          task: {id: $task_id, heading: "Task heading here"},
          summary: "Brief summary of what was implemented.",
          files_changed: [{path: "path/to/file.sh", action: "modify", description: "What changed"}],
          verification: {command: "bash test.sh", result: "pass"}
        }'
      ;;
    spec-reviewer|quality-reviewer)
      jq -nc \
        --arg dispatch_id "$dispatch_id" \
        --arg role "$role" \
        '{
          schema_version: "sdd-result-v1",
          dispatch_id: $dispatch_id,
          role: $role,
          status: "PASS",
          scope: "T-001",
          summary: "Brief summary of review.",
          findings: [{id: "F-001", severity: "minor", category: "missing-requirement", description: "Description", location: "n/a", evidence: "n/a", suggestion: "Suggestion"}],
          verdict: "PASS"
        }'
      ;;
    research-scout)
      jq -nc \
        --arg dispatch_id "$dispatch_id" \
        '{
          schema_version: "sdd-result-v1",
          dispatch_id: $dispatch_id,
          role: "research-scout",
          status: "DONE",
          scope: "Feature or task scope reviewed",
          summary: "Brief summary of research findings.",
          findings: [{id: "RS-001", kind: "fact", description: "What was found", evidence: "path/to/file.sh"}],
          confidence: {
            scope_clarity: 0,
            pattern_familiarity: 0,
            dependency_awareness: 0,
            edge_case_coverage: 0,
            test_strategy: 0,
            total: 0,
            verdict: "GO"
          },
          files_discovered: [{path: "path/to/file.sh", action: "review", module: "module", impact: "local", relates_to: "FR-001"}],
          suggested_artifact_updates: []
        }'
      ;;
    plan-drafter)
      jq -nc \
        --arg dispatch_id "$dispatch_id" \
        '{
          schema_version: "sdd-result-v1",
          dispatch_id: $dispatch_id,
          role: "plan-drafter",
          status: "DONE",
          scope: "Feature or task scope planned",
          summary: "Brief summary of proposed plan changes.",
          proposed_decisions: [{id: "AD-001", decision: "Decision", rationale: "Rationale", alternatives: []}],
          proposed_tasks: [{id: "T-001", title: "Task title", phase: "PH-01", implements: ["FR-001"], files: [], verification: "bash test.sh"}],
          risks: [],
          suggested_artifact_updates: []
        }'
      ;;
    *)
      jq -nc \
        --arg dispatch_id "$dispatch_id" \
        --arg role "$role" \
        '{schema_version: "sdd-result-v1", dispatch_id: $dispatch_id, role: $role, status: "DONE", summary: "Summary here."}'
      ;;
  esac
}

# Resolve the latest worker ledger entry path for a dispatch or result record.
sdd_latest_worker_record_path() {
  local feature="$1" kind="$2"
  local ledger_dir latest=""
  ledger_dir="$(sdd_worker_ledger_dir "$feature")"
  [ -d "$ledger_dir" ] || return 0

  latest="$(LC_ALL=C ls -1t "$ledger_dir"/"$kind"-*.json 2>/dev/null | head -1 || true)"
  [ -n "$latest" ] && printf '%s\n' "$latest"
}

# Build derived worker state for a feature from ledger files plus session flags.
sdd_worker_state_json() {
  local feature="$1"
  local ledger_dir latest_dispatch_path="" latest_result_path=""
  local latest_dispatch_json="null" latest_result_json="null" pending_json="null"
  local session_flags

  ledger_dir="$(sdd_worker_ledger_dir "$feature")"
  latest_dispatch_path="$(sdd_latest_worker_record_path "$feature" "dispatch")"
  latest_result_path="$(sdd_latest_worker_record_path "$feature" "result")"

  if [ -n "$latest_dispatch_path" ] && [ -f "$latest_dispatch_path" ]; then
    latest_dispatch_json="$(jq -c --arg path "$latest_dispatch_path" '. + {path: $path}' "$latest_dispatch_path" 2>/dev/null || printf 'null')"
  fi

  if [ -n "$latest_result_path" ] && [ -f "$latest_result_path" ]; then
    latest_result_json="$(jq -c --arg path "$latest_result_path" '. + {path: $path}' "$latest_result_path" 2>/dev/null || printf 'null')"
  fi

  session_flags="$(sdd_read_session_flags)"
  pending_json="$(printf '%s' "$session_flags" | jq -c --arg feature "$feature" '
    .subagent_result_pending // false
    | if type == "object" and (.feature // "") == $feature then . else null end
  ' 2>/dev/null || printf 'null')"

  if [ "$latest_dispatch_json" = "null" ] && [ "$latest_result_json" = "null" ] && [ "$pending_json" = "null" ]; then
    printf 'null\n'
    return 0
  fi

  jq -nc \
    --arg ledger_dir "$ledger_dir" \
    --argjson latest_dispatch "$latest_dispatch_json" \
    --argjson latest_result "$latest_result_json" \
    --argjson pending "$pending_json" \
    '{
      ledger_dir: $ledger_dir,
      latest_dispatch: $latest_dispatch,
      latest_result: $latest_result,
      pending_controller_action: $pending
    }'
}

# Build a worker dispatch packet from SDD artifacts on disk.
sdd_build_dispatch_packet() {
  local agent_type="$1" feature="$2" phase="$3" task_id="${4:-}" dispatch_id="${5:-}" dispatch_epoch="${6:-}"
  local role feature_dir tasks_file spec_file research_file
  role="$(sdd_normalize_agent_role "$agent_type")"
  feature_dir="$SDD_FEATURE_ROOT/$feature"
  tasks_file="$feature_dir/tasks.md"
  spec_file="$feature_dir/spec.md"
  research_file="$feature_dir/research.md"

  [ -d "$feature_dir" ] || return 1

  local current_flags="" task_heading task_phase implements objective verification
  if [ -z "$dispatch_epoch" ]; then
    current_flags="$(sdd_read_session_flags)"
    dispatch_epoch="$(printf '%s' "$current_flags" | jq -r '.dispatch_epoch // 0' 2>/dev/null)" || dispatch_epoch=0
    dispatch_epoch=$((dispatch_epoch + 1))
  fi
  [ -n "$dispatch_id" ] || dispatch_id="dispatch-${dispatch_epoch}"

  task_heading=""
  task_phase=""
  implements=""
  objective=""
  verification=""

  if { [ -z "$task_id" ] || [ "$task_id" = "none" ] || [ "$task_id" = "null" ]; } && [ -f "$tasks_file" ]; then
    task_id="$(sdd_current_task_id "$tasks_file")"
  fi

  if [ -n "$task_id" ] && [ "$task_id" != "none" ] && [ "$task_id" != "null" ] && [ -f "$tasks_file" ]; then
    task_heading="$(sdd_task_heading "$tasks_file" "$task_id")"
    if [ -n "$task_heading" ]; then
      task_phase="$(sdd_task_field_value "$tasks_file" "$task_id" "Phase")"
      implements="$(sdd_task_field_value "$tasks_file" "$task_id" "Implements")"
      objective="$(sdd_task_section_body "$tasks_file" "$task_id" "Description")"
      verification="$(sdd_task_verification_command "$tasks_file" "$task_id")"
    else
      task_id=""
    fi
  fi

  if [ -z "$objective" ]; then
    case "$role" in
      research-scout) objective="Explore the active feature scope for the current ${phase} phase and return structured research findings." ;;
      plan-drafter) objective="Draft planning output for the active feature scope in the current ${phase} phase without implementing code." ;;
      spec-reviewer|quality-reviewer) objective="Review the active feature scope for the current ${phase} phase and return structured reviewer findings." ;;
      *) objective="Work within the active feature scope for the current ${phase} phase." ;;
    esac
  else
    objective="$(printf '%s\n' "$objective" | sed '/^[[:space:]]*$/d')"
  fi

  local requirements="" fr_lines="" ac_lines="" fr_ids="" trace_file="$feature_dir/trace.json" trace_task_id=""
  local fr_ids_json='[]' ac_ids_json='[]'

  if [ -n "$task_id" ] && [ -f "$tasks_file" ]; then
    trace_task_id="$(sdd_task_display_ref "$tasks_file" "$task_id")"
  fi

  if [ -f "$trace_file" ] && jq -e . "$trace_file" >/dev/null 2>&1; then
    if [ -n "$trace_task_id" ] && jq -e --arg task_id "$trace_task_id" '.nodes[$task_id] != null' "$trace_file" >/dev/null 2>&1; then
      fr_ids_json="$(jq -c --arg task_id "$trace_task_id" '.nodes[$task_id].implements // []' "$trace_file")"
    elif [ -n "$implements" ]; then
      fr_ids_json="$(sdd_parse_id_list "$implements")"
    else
      fr_ids_json="$(jq -c '[.nodes | to_entries[] | select(.value.kind == "fr") | {id: .key, line: (.value.line // 0)}] | sort_by(.line, .id) | .[0:8] | map(.id)' "$trace_file")"
    fi

    fr_ids="$(printf '%s\n' "$fr_ids_json" | jq -r 'join(",")')"
    if [ -n "$fr_ids" ]; then
      fr_lines="$(jq -r --argjson ids "$fr_ids_json" '
        [ $ids[] as $id | .nodes[$id] | select(. != null) | "- " + $id + ": " + (.title // $id) ]
        | .[]
      ' "$trace_file")"
    fi

    ac_lines="$(jq -r '
      [.nodes | to_entries[] | select(.value.kind == "ac") | {id: .key, line: (.value.line // 0), title: (.value.title // .key)}]
      | sort_by(.line, .id)
      | .[0:12]
      | .[]
      | "- " + .id + ": " + .title
    ' "$trace_file")"
    if [ -n "$ac_lines" ]; then
      ac_ids_json="$(jq -c '
        [.nodes | to_entries[] | select(.value.kind == "ac") | {id: .key, line: (.value.line // 0)}]
        | sort_by(.line, .id)
        | .[0:12]
        | map(.id)
      ' "$trace_file")"
    fi
  elif [ -n "$implements" ] && [ -f "$spec_file" ]; then
    fr_ids="$(printf '%s\n' "$implements" | grep -oE 'FR-[0-9]+' | paste -sd ',' -)"
    if [ -n "$fr_ids" ]; then
      fr_lines="$(sdd_parse_id_rows_tsv FR "$spec_file" headings | awk -F '\t' -v ids="$fr_ids" '
        BEGIN {
          split(ids, raw, /,/)
          for (i in raw) if (raw[i] != "") wanted[raw[i]] = 1
        }
        wanted[$1] {
          print "- " $1 ": " $3
        }
      ')"
    fi
    ac_lines="$(sdd_parse_id_rows_tsv AC "$spec_file" headings | awk -F '\t' '{ box = ($4 == "x" ? "[x]" : "[ ]"); print "- " box " " $1 ": " $3 }' | head -12)"
    if [ -n "$fr_ids" ]; then
      fr_ids_json="$(printf '%s\n' "$fr_ids" | tr ',' '\n' | jq -Rsc 'split("\n") | map(select(length > 0))')"
    fi
    if [ -n "$ac_lines" ]; then
      ac_ids_json="$(sdd_parse_id_lines AC "$spec_file" headings | head -12 | jq -Rsc 'split("\n") | map(select(length > 0))')"
    fi
  elif [ -f "$spec_file" ]; then
    fr_lines="$(sdd_parse_id_rows_tsv FR "$spec_file" headings | awk -F '\t' '{ print "- " $1 ": " $3 }' | head -8)"
  fi

  if [ -n "$fr_lines" ] || [ -n "$ac_lines" ]; then
    requirements="## Requirements"
    if [ -n "$fr_lines" ]; then
      requirements="$requirements

### Functional Requirements
$fr_lines"
    fi
    if [ -n "$ac_lines" ]; then
      requirements="$requirements

### Acceptance Criteria Snapshot
$ac_lines"
    fi
  fi

  local files_in_scope="" file_rows="" files_json='[]'
  if [ -f "$trace_file" ] && jq -e . "$trace_file" >/dev/null 2>&1; then
    if [ -n "$trace_task_id" ] && jq -e --arg task_id "$trace_task_id" '.nodes[$task_id] != null' "$trace_file" >/dev/null 2>&1; then
      files_json="$(jq -c --arg task_id "$trace_task_id" '
        [
          .edges[]
          | select(.from == $task_id and .type == "touches")
          | .to
        ] as $file_ids
        | [
            $file_ids[] as $id
            | .nodes[$id]
            | select(. != null)
            | {path: .path, action: (.action // null), impact: (.impact // null)}
          ]
      ' "$trace_file")"
    fi
    if [ "$files_json" = "[]" ]; then
      files_json="$(jq -c '
        [.nodes | to_entries[] | select(.value.kind == "file") | {path: .value.path, action: (.value.action // null), impact: (.value.impact // null)}]
        | .[0:15]
      ' "$trace_file")"
    fi
    if [ "$files_json" != "[]" ]; then
      file_rows="$(printf '%s\n' "$files_json" | jq -r '.[] | "- " + .path + " (" + (.action // "modify") + "; " + (.impact // "local") + ")"')"
    fi
  elif [ -f "$research_file" ]; then
    file_rows="$(awk -v ids="$fr_ids" '
      function trim(s) {
        gsub(/^[ \t]+|[ \t]+$/, "", s)
        return s
      }
      BEGIN {
        filter = 0
        split(ids, raw, /,/)
        for (i in raw) {
          if (raw[i] != "") {
            wanted[raw[i]] = 1
            filter = 1
          }
        }
      }
      /^## Affected Files/ { in_section = 1; next }
      in_section && /^(##|---|\*\*\*)/ { in_section = 0 }
      in_section && /^\|/ {
        if ($0 ~ /^\|[[:space:]]*File[[:space:]]*\|/) next
        if ($0 ~ /^\|[[:space:]]*:?-+:?[[:space:]]*\|/) next
        split($0, cols, "|")
        path = trim(cols[2])
        action = trim(cols[3])
        impact = trim(cols[5])
        relates = trim(cols[6])
        if (path == "" || path ~ /^[: -]+$/) next
        matched = !filter
        if (filter) {
          for (id in wanted) {
            if (relates ~ id) matched = 1
          }
        }
        if (matched) {
          print "- " path " (" action "; " impact ")"
          count++
        }
      }
    ' "$research_file" | head -15)"
    if [ -z "$file_rows" ]; then
      file_rows="$(awk '
        function trim(s) {
          gsub(/^[ \t]+|[ \t]+$/, "", s)
          return s
        }
        /^## Affected Files/ { in_section = 1; next }
        in_section && /^(##|---|\*\*\*)/ { in_section = 0 }
        in_section && /^\|/ {
          if ($0 ~ /^\|[[:space:]]*File[[:space:]]*\|/) next
          if ($0 ~ /^\|[[:space:]]*:?-+:?[[:space:]]*\|/) next
          split($0, cols, "|")
          path = trim(cols[2])
          action = trim(cols[3])
          impact = trim(cols[5])
          if (path == "" || path ~ /^[: -]+$/) next
          print "- " path " (" action "; " impact ")"
        }
      ' "$research_file" | head -15)"
    fi

    files_json="$(awk -v ids="$fr_ids" '
      function trim(s) {
        gsub(/^[ \t]+|[ \t]+$/, "", s)
        return s
      }
      BEGIN {
        filter = 0
        split(ids, raw, /,/)
        for (i in raw) {
          if (raw[i] != "") {
            wanted[raw[i]] = 1
            filter = 1
          }
        }
      }
      /^## Affected Files/ { in_section = 1; next }
      in_section && /^(##|---|\*\*\*)/ { in_section = 0 }
      in_section && /^\|/ {
        if ($0 ~ /^\|[[:space:]]*File[[:space:]]*\|/) next
        if ($0 ~ /^\|[[:space:]]*:?-+:?[[:space:]]*\|/) next
        split($0, cols, "|")
        path = trim(cols[2])
        action = trim(cols[3])
        impact = trim(cols[5])
        relates = trim(cols[6])
        if (path == "" || path ~ /^[: -]+$/) next
        matched = !filter
        if (filter) {
          for (id in wanted) {
            if (relates ~ id) matched = 1
          }
        }
        if (matched) print path "\t" action "\t" impact
      }
    ' "$research_file" | head -15 | jq -Rsc '
      split("\n")
      | map(select(length > 0))
      | map(split("\t"))
      | map({path: .[0], action: .[1], impact: .[2]})
    ')"
  fi

  if [ -n "$file_rows" ]; then
    files_in_scope="## Files in Scope
$file_rows"
  fi

  local task_block="" verification_block=""
  if [ -n "$task_heading" ]; then
    task_block="## Task
$task_heading"
    [ -n "$task_phase" ] && task_block="$task_block
Task phase: $task_phase"
  fi
  if [ -n "$verification" ]; then
    verification_block="## Verification
\`\`\`bash
$verification
\`\`\`"
  fi

  local authority=""
  if [ -n "$task_heading" ]; then
    authority="AUTHORITY: This dispatch packet is your authoritative assignment. If hook-provided context conflicts with this packet, trust this packet. You are assigned to feature $feature, task $task_id, role $role. Do not infer a different assignment from disk."
  else
    authority="AUTHORITY: This dispatch packet is your authoritative assignment. If hook-provided context conflicts with this packet, trust this packet. You are assigned to feature $feature, phase $phase, role $role. Do not infer a different assignment from disk."
  fi

  local task_json='null' verification_json='null' dispatch_record_json
  if [ -n "$task_heading" ]; then
    task_json="$(jq -nc \
      --arg id "$task_id" \
      --arg heading "$task_heading" \
      --arg task_phase_value "$task_phase" \
      '{id:$id, heading:$heading, phase:(if $task_phase_value == "" then null else $task_phase_value end)}')"
  fi
  if [ -n "$verification" ]; then
    verification_json="$(jq -nc --arg command "$verification" '{command:$command, required:true}')"
  fi

  dispatch_record_json="$(jq -nc \
    --arg schema_version "sdd-dispatch-v1" \
    --arg dispatch_id "$dispatch_id" \
    --argjson dispatch_epoch "$dispatch_epoch" \
    --arg role "$role" \
    --arg feature "$feature" \
    --arg phase "$phase" \
    --argjson task "$task_json" \
    --arg work_package "none" \
    --arg objective "$objective" \
    --argjson fr "$fr_ids_json" \
    --argjson ac "$ac_ids_json" \
    --argjson files "$files_json" \
    --argjson verification "$verification_json" \
    --arg authority "$authority" \
    '{
      schema_version: $schema_version,
      dispatch_id: $dispatch_id,
      dispatch_epoch: $dispatch_epoch,
      role: $role,
      feature: $feature,
      phase: $phase,
      task: $task,
      work_package: $work_package,
      objective: $objective,
      requirements: {fr: $fr, ac: $ac},
      files_in_scope: $files,
      verification: $verification,
      authority: $authority
    }')"

  local packet
  packet="# SDD Dispatch Packet
$authority
## Machine Dispatch Record
\`\`\`json
$dispatch_record_json
\`\`\`

**Role**: $role
**Feature**: $feature
**Phase**: $phase
**Dispatch Epoch**: $dispatch_epoch"

  if [ -n "$task_block" ]; then
    packet="$packet

$task_block"
  fi

  packet="$packet

## Objective
$objective"

  if [ -n "$requirements" ]; then
    packet="$packet

$requirements"
  fi

  if [ -n "$files_in_scope" ]; then
    packet="$packet

$files_in_scope"
  fi

  if [ -n "$verification_block" ]; then
    packet="$packet

$verification_block"
  fi

  local deep_mode_block=""
  deep_mode_block="$(sdd_deep_mode_dispatch_block "$feature" "$phase" "$role")"
  if [ -n "$deep_mode_block" ]; then
    packet="$packet

$deep_mode_block"
  fi

  local customization_block=""
  customization_block="$(SDD_ACTIVE_FEATURE="$feature" SDD_ACTIVE_PHASE="$phase" sdd_emit_customization_block ".sdd/customization.yaml" "$feature_dir/customization.yaml" "" "$role")"
  if [ -n "$customization_block" ]; then
    packet="$packet

$customization_block"
  fi
  local epic_entry_id="" epic_block=""
  epic_entry_id="$(sdd_feature_epic_entry_from_dir "$feature_dir" 2>/dev/null || true)"
  epic_block="$(SDD_ACTIVE_FEATURE="$feature" SDD_ACTIVE_PHASE="$phase" sdd_emit_epic_block "$SDD_FEATURE_ROOT/EPIC.md" "$phase" "$role" "$epic_entry_id")"
  if [ -n "$epic_block" ]; then
    packet="$packet

$epic_block"
  fi

  packet="$packet

## Return Format
$(sdd_dispatch_return_format "$role" "$dispatch_id" "$task_id" "$task_heading")

## Prohibitions
$(sdd_dispatch_prohibitions "$role")"

  packet="$(sdd_tagged_block "dispatch_packet" "$packet")"

  local packet_bytes
  packet_bytes="$(printf '%s' "$packet" | wc -c | tr -d ' ')"
  if [ "${packet_bytes:-0}" -ge 8000 ]; then
    printf 'Warning: dispatch packet for %s is %s bytes\n' "$role" "$packet_bytes" >&2
  fi

  printf '%s\n' "$packet"
}

sdd_deep_mode_dispatch_block() {
  local feature="$1" phase="$2" role="$3"

  [ "$(sdd_profile "$feature")" = "deep" ] || return 0

  case "$phase:$role" in
    research:research-scout)
      printf '%s\n' "<deep_mode>parallel scout guidance: deep research should split independent domains across multiple sdd-research-scout dispatches; reconcile overlaps in research.md and keep the controller responsible for phase transitions.</deep_mode>"
      ;;
    review:spec-reviewer|review:quality-reviewer)
      printf '%s\n' "<deep_mode>dual reviewer guidance: deep review requires both sdd-spec-reviewer and sdd-quality-reviewer evidence before close; subagents do not dispatch other subagents.</deep_mode>"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Steering core helpers (Feature 0038)
# ---------------------------------------------------------------------------

sdd_steering_core_path() {
  printf '%s\n' "$SDD_SKILL_DIR/references/steering-core.md"
}

sdd_default_steering_core_json() {
  cat <<'EOF'
{"rules":{"ambiguity":{"label":"Surface ambiguity","compact":"State assumptions. If ambiguity changes behavior or scope, clarify or return NEEDS_CONTEXT instead of guessing."},"grounding":{"label":"Investigate before claiming","compact":"Read the relevant artifact or code before making claims. Mark unverified statements as hypotheses."},"simplicity":{"label":"Prefer the smallest viable solution","compact":"Solve the requested problem with the least added mechanism. Defer abstraction and future-proofing until current requirements justify them."},"surgical":{"label":"Change surgically","compact":"Keep edits traceable to the active task or request. Avoid drive-by cleanup unless your change created the orphan."},"verification":{"label":"Treat done as verified evidence","compact":"Completion means the verification command passed or the evidence exists. Writing code is not done."},"recovery":{"label":"Reason through failures before retrying","compact":"When a tool or gate fails, name what is uncertain, inspect the relevant output, then choose the safest next move."}},"global_compact":["Surface ambiguity instead of guessing silently.","Investigate before claiming.","Prefer the smallest viable solution.","Change surgically within scope.","Treat done as verified evidence.","Reason through failures before retrying."],"phase_focus":{"design":["Name competing interpretations before freezing FRs and ACs.","Keep requirements in WHAT, not HOW."],"research":["Read files before claiming patterns.","Separate facts, hypotheses, and unknowns."],"plan":["Prefer the smallest viable design that satisfies the spec.","Justify added abstraction with current requirements, not imagined futures."],"implement":["Read scoped files before editing.","Keep every changed line traceable to the active task and verification target."],"review":["Verify against the spec and the code, not the implementer report.","Flag unrequested work, overbuilding, and missing evidence explicitly."],"recovery":["State what is uncertain, inspect the relevant artifact or output, and choose the safest next move.","Do not retry blindly or widen scope to escape a gate."]},"examples":{"clarification":"Ambiguity example: name the two plausible interpretations, recommend one, and ask whether the difference matters before proceeding.","grounded_review_finding":"Grounded finding example: cite file:line evidence and distinguish verified behavior from any remaining hypothesis.","minimal_task":"Minimal task example: define the smallest implementable outcome, name non-goals, and tie completion to one runnable verification command.","failure_recovery":"Failure recovery example: state what failed, what remains uncertain, what to inspect next, and the safe next move."}}
EOF
}

# Return the steering-core JSON from references/steering-core.md.
# Falls back to a built-in default when the file is missing or invalid.
sdd_extract_machine_summary_json() {
  local file="$1"
  local heading_count raw_json

  [ -f "$file" ] || return 1
  heading_count="$(grep -c '^## Machine Summary$' "$file" 2>/dev/null || true)"
  [ "${heading_count:-0}" = "1" ] || return 1

  raw_json="$(awk '
    BEGIN {
      in_machine = 0
      in_json = 0
      saw_nonblank = 0
      closed = 0
    }
    $0 == "## Machine Summary" {
      in_machine = 1
      next
    }
    in_machine && !in_json {
      if ($0 ~ /^[[:space:]]*$/) next
      if ($0 ~ /^```json[[:space:]]*$/) {
        in_json = 1
        next
      }
      exit 1
    }
    in_json && /^```[[:space:]]*$/ {
      closed = 1
      exit
    }
    in_json {
      saw_nonblank = 1
      print
    }
    END {
      if (!closed || !saw_nonblank) exit 1
    }
  ' "$file" 2>/dev/null)" || return 1

  [ -n "$raw_json" ] || return 1
  printf '%s\n' "$raw_json"
}

sdd_steering_core_json() {
  local file raw_json
  file="$(sdd_steering_core_path)"

  if [ ! -f "$file" ]; then
    sdd_default_steering_core_json
    return 0
  fi

  raw_json="$(sdd_extract_machine_summary_json "$file" 2>/dev/null || true)"

  if [ -z "$raw_json" ] || ! printf '%s\n' "$raw_json" | jq -e '
      .rules.ambiguity.compact
      and .rules.grounding.compact
      and .rules.simplicity.compact
      and .rules.surgical.compact
      and .rules.verification.compact
      and .rules.recovery.compact
      and ((.global_compact // []) | length >= 6)
    ' >/dev/null 2>&1; then
    sdd_default_steering_core_json
    return 0
  fi

  printf '%s\n' "$raw_json" | jq -c '.'
}

# Usage: sdd_steering_core_rule_line ambiguity
sdd_steering_core_rule_line() {
  local key="$1"
  sdd_steering_core_json | jq -r --arg key "$key" '.rules[$key].compact // empty'
}

# Usage: sdd_steering_core_compact_rules
sdd_steering_core_compact_rules() {
  sdd_steering_core_json | jq -r '.global_compact[]?'
}

# Usage: sdd_steering_core_phase_focus implement
sdd_steering_core_phase_focus() {
  local phase="$1"
  sdd_steering_core_json | jq -r --arg phase "$phase" '.phase_focus[$phase][]?'
}

# Usage: sdd_steering_core_phase_focus_compact implement
sdd_steering_core_phase_focus_compact() {
  local phase="$1"
  sdd_steering_core_json | jq -r --arg phase "$phase" '(.phase_focus[$phase] // []) | join("; ")'
}

# Usage: sdd_steering_core_example clarification
sdd_steering_core_example() {
  local key="$1"
  sdd_steering_core_json | jq -r --arg key "$key" '.examples[$key] // empty'
}

# Usage: sdd_tagged_block tag "content"
sdd_tagged_block() {
  local tag="$1" content="${2-}"
  [ -n "$tag" ] || return 1
  [ -n "$content" ] || return 0
  printf '<%s>\n%s\n</%s>' "$tag" "$content" "$tag"
}

# ============================================================================
# Rubric Advisor (feature 0040-sdd-rubric-advisor)
# ----------------------------------------------------------------------------
# Haiku-powered advisory helpers. All advisor output is non-blocking,
# grounded (rubric_quote + artifact_quote required on every finding), and
# phrased as suggestions. See references/advisor-system-prompt.md for tone
# rules and output contract. See PLAN-0040 AD-002: `--bare` is mandatory on
# every claude -p invocation to prevent hook recursion.
# ============================================================================

# JSON schema for Haiku findings output. Enforced via claude -p --json-schema.
# minLength on rubric_quote (10) and artifact_quote (5) plus additionalProperties:false
# make it structurally impossible to emit an ungrounded finding (AD-004).
SDD_ADVISOR_FINDINGS_SCHEMA='{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","required":["findings"],"additionalProperties":false,"properties":{"findings":{"type":"array","items":{"type":"object","required":["rubric_quote","artifact_quote","suggestion","confidence","dimension"],"additionalProperties":false,"properties":{"rubric_quote":{"type":"string","minLength":10},"artifact_quote":{"type":"string","minLength":5},"suggestion":{"type":"string","minLength":20},"confidence":{"type":"string","enum":["low","medium","high"]},"dimension":{"type":"string","minLength":3}}}},"overall_note":{"type":"string"}}}'

# Usage: sdd_advisor_invoke_haiku <rubric_path> <artifact_path> [next_rubric_path]
# Shells to `claude -p --bare --model haiku` with the advisor system prompt and
# SDD_ADVISOR_FINDINGS_SCHEMA. Prints the validated findings JSON on stdout.
# Silent on every failure path (missing binaries, unreadable files, claude
# error, malformed output): logs the reason to stderr with session correlation
# from $SDD_ADVISOR_SESSION_ID and prints nothing. Never exits non-zero.
sdd_advisor_invoke_haiku() {
  local rubric_path="$1" artifact_path="$2" next_rubric_path="${3-}"
  local session_id="${SDD_ADVISOR_SESSION_ID:-unknown}"
  local log="sdd-advisor[session=${session_id}]"
  local prompt_path="$SDD_SKILL_DIR/references/advisor-system-prompt.md"
  local response findings payload rubric_content artifact_content next_rubric_content
  local artifact_feature="" artifact_name="" next_artifact_name=""

  command -v claude >/dev/null 2>&1 || { printf '%s: claude not on PATH\n' "$log" >&2; return 0; }
  command -v jq     >/dev/null 2>&1 || { printf '%s: jq not on PATH\n'     "$log" >&2; return 0; }
  [ -r "$rubric_path" ]   || { printf '%s: rubric unreadable: %s\n'   "$log" "$rubric_path"   >&2; return 0; }
  [ -r "$artifact_path" ] || { printf '%s: artifact unreadable: %s\n' "$log" "$artifact_path" >&2; return 0; }
  [ -r "$prompt_path" ]   || { printf '%s: advisor-system-prompt.md missing at %s\n' "$log" "$prompt_path" >&2; return 0; }

  case "$artifact_path" in
    "$SDD_FEATURE_ROOT"/*/*.md)
      artifact_feature="$(basename "$(dirname "$artifact_path")")"
      artifact_name="$(basename "$artifact_path" .md)"
      ;;
  esac

  if [ -n "$artifact_feature" ] && [ -n "$artifact_name" ]; then
    rubric_content="$(sdd_rubric_text_for_feature "$artifact_name" "$artifact_feature" 2>/dev/null || cat "$rubric_path")"
  else
    rubric_content=$(cat "$rubric_path")
  fi
  artifact_content=$(cat "$artifact_path")
  payload=$(printf '<rubric>\n%s\n</rubric>\n\n<artifact>\n%s\n</artifact>\n' "$rubric_content" "$artifact_content")
  if [ -n "$next_rubric_path" ]; then
    [ -r "$next_rubric_path" ] || { printf '%s: next_rubric unreadable: %s\n' "$log" "$next_rubric_path" >&2; return 0; }
    next_artifact_name="$(basename "$next_rubric_path" .md)"
    if [ -n "$artifact_feature" ] && [ -n "$next_artifact_name" ]; then
      next_rubric_content="$(sdd_rubric_text_for_feature "$next_artifact_name" "$artifact_feature" 2>/dev/null || cat "$next_rubric_path")"
    else
      next_rubric_content=$(cat "$next_rubric_path")
    fi
    payload=$(printf '%s\n<next_rubric>\n%s\n</next_rubric>\n' "$payload" "$next_rubric_content")
  fi

  if ! response=$(printf '%s' "$payload" | claude -p --bare --model haiku --max-turns 1 --output-format json --json-schema "$SDD_ADVISOR_FINDINGS_SCHEMA" --append-system-prompt-file "$prompt_path" 2>/dev/null); then
    printf '%s: claude -p failed (non-zero exit)\n' "$log" >&2
    return 0
  fi

  findings=$(printf '%s' "$response" | jq -c '.structured_output // empty' 2>/dev/null) || findings=""
  if [ -z "$findings" ] || [ "$findings" = "null" ]; then
    printf '%s: claude -p returned no structured_output\n' "$log" >&2
    return 0
  fi

  printf '%s' "$findings" | jq -e '.findings | type == "array"' >/dev/null 2>&1 || {
    printf '%s: structured_output missing findings array\n' "$log" >&2
    return 0
  }

  printf '%s\n' "$findings"
}

# Usage: sdd_advisor_format_context <findings_json> <mode>
# Converts a findings JSON object into tagged-block output suitable for
# hookSpecificOutput.additionalContext. `mode` is one of:
#   postauthoring  — emits <uncertain>, <consider>, <ground_in> triplet per finding
#   preboundary    — emits <next_focus>, <watch_for>, <ground_in> (one block each)
# Empty findings array produces zero bytes on stdout. Unknown mode exits 1.
sdd_advisor_format_context() {
  local findings_json="$1" mode="$2"
  local output="" finding_count

  [ -n "$findings_json" ] || return 0
  finding_count=$(printf '%s' "$findings_json" | jq -r '.findings | length' 2>/dev/null) || return 0
  [ "$finding_count" -gt 0 ] || return 0

  case "$mode" in
    postauthoring)
      local i=0 rq aq sg dim
      while [ "$i" -lt "$finding_count" ]; do
        rq=$(printf '%s' "$findings_json"  | jq -r --argjson i "$i" '.findings[$i].rubric_quote   // ""')
        aq=$(printf '%s' "$findings_json"  | jq -r --argjson i "$i" '.findings[$i].artifact_quote // ""')
        sg=$(printf '%s' "$findings_json"  | jq -r --argjson i "$i" '.findings[$i].suggestion     // ""')
        dim=$(printf '%s' "$findings_json" | jq -r --argjson i "$i" '.findings[$i].dimension      // ""')
        output="${output}$(sdd_tagged_block uncertain "${dim} — ${aq}")"$'\n'
        output="${output}$(sdd_tagged_block consider  "${sg}")"$'\n'
        output="${output}$(sdd_tagged_block ground_in "Rubric: ${rq}"$'\n'"Artifact: ${aq}")"$'\n\n'
        i=$((i + 1))
      done
      ;;
    preboundary)
      local overall next_focus watch_parts ground_parts
      overall=$(printf '%s' "$findings_json" | jq -r '.overall_note // ""')
      if [ -n "$overall" ]; then
        next_focus="$overall"
      else
        next_focus=$(printf '%s' "$findings_json" | jq -r '.findings[0].suggestion // ""')
      fi
      watch_parts=$(printf '%s' "$findings_json" | jq -r '.findings[1:][]? | "- " + .suggestion' 2>/dev/null)
      ground_parts=$(printf '%s' "$findings_json" | jq -r '.findings[] | "Rubric: " + .rubric_quote + "\nArtifact: " + .artifact_quote' 2>/dev/null)
      [ -n "$next_focus" ]  && output="${output}$(sdd_tagged_block next_focus "${next_focus}")"$'\n'
      [ -n "$watch_parts" ] && output="${output}$(sdd_tagged_block watch_for  "${watch_parts}")"$'\n'
      [ -n "$ground_parts" ] && output="${output}$(sdd_tagged_block ground_in "${ground_parts}")"
      ;;
    *)
      return 1
      ;;
  esac

  printf '%s' "$output"
}

# Phase-specific rules text for steering.
# Used by sdd-hook.sh and sdd-summary.sh to produce consistent guidance.
sdd_phase_rules() {
  local phase="${1:-}" feature="${2:-${SDD_ACTIVE_FEATURE:-}}" focus ambiguity

  if [ "$phase" != "brief" ] && [ -n "$feature" ] && sdd_autonomy_is_on "$feature"; then
    case "$phase" in
      spec)
        focus="$(sdd_steering_core_phase_focus_compact design)"
        echo "Rules: define FRs and ACs in spec.md; ${focus}; populate tasks.md Approach + T-NNN before leaving Spec; no implementation; advance autonomously; halt only on listed blockers"
        ;;
      design)
        focus="$(sdd_steering_core_phase_focus_compact design)"
        echo "Rules: define FRs and ACs; ${focus}; explore codebase before asking; no implementation; advance autonomously; halt only on listed blockers"
        ;;
      research)
        focus="$(sdd_steering_core_phase_focus_compact research)"
        echo "Rules: follow 10-step process; use Explore subagent for parallel scanning; ${focus}; map all FRs to files; no production code; advance autonomously; halt only on listed blockers"
        ;;
      plan|plan-tasks)
        focus="$(sdd_steering_core_phase_focus_compact plan)"
        echo "Rules: vertical slices, each independently demoable; ${focus}; derive atomic tasks with verification commands; proceed to implement when plan tasks are populated; halt only on listed blockers"
        ;;
      implement)
        focus="$(sdd_steering_core_phase_focus_compact implement)"
        echo "Rules: current task only; ${focus}; verify before completing; record discoveries; update scratchpad every 3-5 tool calls; prefer sdd-implementer worker dispatch for large tasks — hook injects packet; advance autonomously; halt only on listed blockers"
        ;;
      review)
        focus="$(sdd_steering_core_phase_focus_compact review)"
        echo "Rules: read spec BEFORE code; ${focus}; $(sdd_reviewer_dispatch_phrase "$feature"); validate ACs with evidence; no silent coding; set verdict; advance autonomously; halt only on listed blockers"
        ;;
      close)
        echo "Rules: graduate scratchpad findings to knowledge.md; finalize all artifact statuses; $(sdd_steering_core_rule_line verification); advance autonomously; halt only on listed blockers"
        ;;
      *) echo "" ;;
    esac
    return 0
  fi

  case "$phase" in
    brief)
      ambiguity="$(sdd_steering_core_rule_line ambiguity)"
      echo "Rules: intent-extraction mode; gather context (CLAUDE.md, INDEX, recent features, scoped repo) before engaging; propose ideas or draft inferable sections (Problem, Context, Constraints) from inference; ask only intent-level questions — no code-logic, research-phase, or inspectable questions; soft cap ~3 questions, each paired with a recommendation; label inferred content with source; ${ambiguity}"
      ;;
    spec)
      focus="$(sdd_steering_core_phase_focus_compact design)"
      echo "Rules: define FRs, ACs, and concrete codebase notes in spec.md; ${focus}; populate tasks.md Approach + T-NNN before leaving Spec; no implementation"
      ;;
    design)
      focus="$(sdd_steering_core_phase_focus_compact design)"
      echo "Rules: define FRs and ACs; ${focus}; explore codebase before asking; no implementation"
      ;;
    research)
      focus="$(sdd_steering_core_phase_focus_compact research)"
      echo "Rules: follow 10-step process; use Explore subagent for parallel scanning; ${focus}; map all FRs to files; no production code"
      ;;
    plan|plan-tasks)
      focus="$(sdd_steering_core_phase_focus_compact plan)"
      echo "Rules: vertical slices, each independently demoable; ${focus}; derive atomic tasks with verification commands; get user approval before implement"
      ;;
    implement)
      focus="$(sdd_steering_core_phase_focus_compact implement)"
      echo "Rules: current task only; ${focus}; verify before completing; record discoveries; update scratchpad every 3-5 tool calls; prefer sdd-implementer worker dispatch for large tasks — hook injects packet"
      ;;
    review)
      focus="$(sdd_steering_core_phase_focus_compact review)"
      echo "Rules: read spec BEFORE code; ${focus}; $(sdd_reviewer_dispatch_phrase "$feature"); validate ACs with evidence; no silent coding; set verdict"
      ;;
    close)
      echo "Rules: graduate scratchpad findings to knowledge.md; finalize all artifact statuses; $(sdd_steering_core_rule_line verification)"
      ;;
    *)          echo "" ;;
  esac
}

# Canonical lean-dispatch phrase for review-phase reviewer dispatch.
# Single source of truth (per AD-003 of feature 0056). Scripts call this helper;
# markdown surfaces copy verbatim with grep-test enforcement.
# Usage: phrase="$(sdd_reviewer_dispatch_phrase)"
sdd_reviewer_dispatch_phrase() {
  local feature="${1:-${SDD_ACTIVE_FEATURE:-${FEATURE:-}}}"

  if [ -n "$feature" ] && [ "$(sdd_profile "$feature")" = "deep" ]; then
    printf '%s\n' "deep mode requires both sdd-spec-reviewer and sdd-quality-reviewer before close; self-review is not an option"
  else
    printf '%s\n' "dispatch sdd-spec-reviewer + sdd-quality-reviewer for independent verification before close; self-review only for trivial diffs (≤2 ACs and ≤2 tasks)"
  fi
}

# Return exit 0 if both sdd-spec-reviewer and sdd-quality-reviewer dispatch
# results exist in the feature's workers ledger. Exit 1 otherwise.
# Usage: sdd_reviewer_dispatch_present <feature>
sdd_reviewer_dispatch_present() {
  local feature="${1:-}"
  [ -n "$feature" ] || return 1
  local dir="$SDD_FEATURE_ROOT/$feature/workers"
  [ -d "$dir" ] || return 1
  local has_spec=0 has_quality=0 file role
  for file in "$dir"/result-*.json; do
    [ -f "$file" ] || continue
    role="$(jq -r '.role // empty' "$file" 2>/dev/null)" || continue
    case "$role" in
      spec-reviewer)    has_spec=1 ;;
      quality-reviewer) has_quality=1 ;;
    esac
  done
  [ "$has_spec" -eq 1 ] && [ "$has_quality" -eq 1 ]
}

# Compact or full review-phase dispatch hint for UserPromptSubmit injection.
# Returns one of two cues based on whether reviewers have been dispatched.
# Usage: sdd_review_dispatch_hint <feature> [compact|full]
sdd_review_dispatch_hint() {
  local feature="${1:-}" mode="${2:-compact}"
  [ -n "$feature" ] || return 0
  if sdd_reviewer_dispatch_present "$feature"; then
    if [ "$mode" = "full" ]; then
      printf '%s\n' "Review phase: validate dispatched results, set verdict, prepare close. Both sdd-spec-reviewer and sdd-quality-reviewer have returned — integrate findings into review.md."
    else
      printf '%s\n' "review: validate dispatched results, set verdict, prepare close"
    fi
  else
    if [ "$(sdd_profile "$feature")" = "deep" ]; then
      if [ "$mode" = "full" ]; then
        printf '%s\n' "Review phase: deep mode requires both sdd-spec-reviewer and sdd-quality-reviewer before close. Self-review is not an option; dispatch both reviewers and record their evidence in review.md."
      else
        printf '%s\n' "review: deep mode requires sdd-spec-reviewer + sdd-quality-reviewer; self-review is not an option"
      fi
    elif [ "$mode" = "full" ]; then
      printf '%s\n' "Review phase: dispatch sdd-spec-reviewer + sdd-quality-reviewer for independent verification. Self-review is the failure mode this phase prevents — implementer cannot reliably review own work. Override with: sdd autonomy --self-reviewed <feature> if truly trivial."
    else
      printf '%s\n' "review: dispatch sdd-spec-reviewer + sdd-quality-reviewer; self-review is the failure mode this phase prevents"
    fi
  fi
}

# Next-move guidance text for steering.
# Used by sdd-hook.sh and sdd-summary.sh to produce consistent guidance.
sdd_next_move() {
  local phase="$1" feature="$2" task="$3"

  if [ "$phase" != "brief" ] && [ -n "$feature" ] && sdd_autonomy_is_on "$feature"; then
    case "$phase" in
      spec)       echo "Next: complete spec.md (FRs, ACs, scope) and tasks.md (Approach + T-NNN), then advance autonomously to implement; halt only on listed blockers" ;;
      design)     echo "Next: complete spec.md, then advance autonomously to sdd research $feature; halt only on listed blockers" ;;
      research)   echo "Next: map all FRs to files, separate facts from hypotheses, then advance autonomously to sdd plan create $feature; halt only on listed blockers" ;;
      plan)       echo "Next: write plan.md, prefer the smallest viable design, then advance autonomously to sdd plan create-tasks $feature; halt only on listed blockers" ;;
      plan-tasks) echo "Next: derive atomic tasks with runnable verification and explicit scope boundaries, then proceed to implement; halt only on listed blockers" ;;
      implement)
        if [ "$task" != "none" ] && [ -n "$task" ]; then
          echo "Next: implement $task, read scoped files first, keep changes surgical, run verification, mark complete, then continue autonomously; halt only on listed blockers"
        else
          echo "Next: sdd task next $feature, then read the scoped files before editing; continue autonomously and halt only on listed blockers"
        fi
        ;;
      review)     echo "Next: sdd review $feature, validate ACs with evidence, set verdict, then proceed to close on PASS; halt only on listed blockers" ;;
      close)      echo "Next: graduate knowledge and finalize artifacts; halt only on listed blockers" ;;
      *)          echo "" ;;
    esac
    return 0
  fi

  case "$phase" in
    brief)
      local _state _complete _label
      _state="$(sdd_brief_interview_state_json "$feature" 2>/dev/null)" || _state=""
      if [ -n "$_state" ] && echo "$_state" | jq -e . >/dev/null 2>&1; then
        _complete="$(echo "$_state" | jq -r '.interview_complete')"
        _label="$(echo "$_state" | jq -r '.next_focus.label')"
      else
        _complete="false"
        _label=""
      fi
      if [ "$_complete" = "true" ]; then
        if [ -n "$feature" ] && sdd_autonomy_is_on "$feature"; then
          echo "Next: advance autonomously to sdd spec $feature; halt only on listed blockers"
        else
          echo "Next: summarize shared understanding, confirm readiness, then sdd spec $feature"
        fi
      elif [ -n "$_label" ] && [ "$_label" != "null" ]; then
        echo "Next: if unresolved, ask 1 question on ${_label}; recommend answer; inspect code first; then sdd spec $feature"
      else
        echo "Next: fill brief.md, then sdd spec $feature"
      fi
      ;;
    spec)       echo "Next: complete spec.md (FRs, ACs, scope) and tasks.md (Approach + T-NNN), then sdd task start $feature <T-NNN>" ;;
    design)     echo "Next: complete spec.md, surface unresolved ambiguity explicitly, then sdd research $feature" ;;
    research)   echo "Next: map all FRs to files, separate facts from hypotheses, then sdd plan create $feature" ;;
    plan)       echo "Next: write plan.md, prefer the smallest viable design, then sdd plan create-tasks $feature" ;;
    plan-tasks) echo "Next: derive atomic tasks with runnable verification and explicit scope boundaries" ;;
    implement)
      if [ "$task" != "none" ] && [ -n "$task" ]; then
        echo "Next: implement $task, read scoped files first, keep changes surgical, run verification, mark complete"
      else
        echo "Next: sdd task next $feature, then read the scoped files before editing"
      fi
      ;;
    review)     echo "Next: sdd review $feature, validate ACs with evidence, flag unrequested work, set verdict" ;;
    close)      echo "Next: graduate knowledge, finalize artifacts, or sdd reopen $feature to extend" ;;
    *)          echo "" ;;
  esac
}

# Print a short phase-methodology pointer when a reference file exists.
sdd_phase_reference_line() {
  local phase="$1"
  local guide_file="$SDD_SKILL_DIR/references/phases/${phase}.md"
  if [ -f "$guide_file" ]; then
    printf 'See references/phases/%s.md for methodology.\n' "$phase"
  fi
  return 0
}

sdd_phase_skill_contract_phase() {
  case "${1:-}" in
    plan-tasks)
      printf '%s\n' "plan"
      ;;
    *)
      printf '%s\n' "${1:-}"
      ;;
  esac
}

# Return the required phase-skill slug for a profile+phase, or empty output.
sdd_required_phase_skill() {
	  local phase="${1:-}" profile="${2:-}"
  phase="$(sdd_phase_skill_contract_phase "$phase")"

	  case "$profile:$phase" in
	    full:brief|deep:brief)
	      printf '%s\n' "sdd-brief"
	      ;;
	    full:design|deep:design|lite:spec)
	      printf '%s\n' "sdd-spec"
	      ;;
	    full:research|deep:research)
	      printf '%s\n' "sdd-research"
	      ;;
	    full:plan|deep:plan)
	      printf '%s\n' "sdd-plan"
	      ;;
	    full:implement|deep:implement|lite:implement)
	      printf '%s\n' "sdd-implement"
	      ;;
	    full:review|deep:review|lite:review)
	      printf '%s\n' "sdd-review"
	      ;;
	    full:close|deep:close|lite:close)
	      printf '%s\n' "sdd-close"
	      ;;
	    :brief)
	      printf '%s\n' "sdd-brief"
	      ;;
	    :design|:spec)
	      printf '%s\n' "sdd-spec"
	      ;;
	    :research)
	      printf '%s\n' "sdd-research"
	      ;;
	    :plan)
	      printf '%s\n' "sdd-plan"
	      ;;
	    :implement)
	      printf '%s\n' "sdd-implement"
	      ;;
	    :review)
	      printf '%s\n' "sdd-review"
	      ;;
	    :close)
	      printf '%s\n' "sdd-close"
	      ;;
	    *)
	      return 0
	      ;;
	  esac
	}

# Return compact active-phase first-action text for phase-skill directives.
sdd_phase_skill_first_action() {
  local phase="${1:-}" profile="${2:-}"
  phase="$(sdd_phase_skill_contract_phase "$phase")"

  case "$profile:$phase" in
    full:brief|deep:brief|:brief)
      printf '%s\n' "First: read brief.md plus CLAUDE.md/INDEX before asking."
      ;;
    full:design|deep:design|:design)
      printf '%s\n' "First: read brief.md, then write WHAT-level spec.md."
      ;;
    lite:spec|:spec)
      printf '%s\n' "First: finish spec.md and tasks.md before implementation."
      ;;
    full:research|deep:research|:research)
      printf '%s\n' "First: read spec.md/brief.md, then cite evidence in research.md."
      ;;
    full:plan|deep:plan|:plan)
      printf '%s\n' "First: turn research.md into plan.md and runnable tasks."
      ;;
    full:implement|deep:implement|lite:implement|:implement)
      printf '%s\n' "First: run sdd task next/start, then edit only active task scope."
      ;;
    full:review|deep:review|lite:review|:review)
      printf '%s\n' "First: read spec.md before code, then validate each AC."
      ;;
    full:close|deep:close|lite:close|:close)
      printf '%s\n' "First: graduate knowledge, then run close checks."
      ;;
    *)
      return 0
      ;;
  esac
}

# Print a compact active-phase skill invocation directive.
sdd_phase_skill_directive() {
  local phase="${1:-}" profile="${2:-}" feature="${3:-}" session_id="${4:-}" skill first_action status
  skill="$(sdd_required_phase_skill "$phase" "$profile")"
  [ -n "$skill" ] || return 0
  first_action="$(sdd_phase_skill_first_action "$phase" "$profile")"
  if [ -n "$feature" ]; then
    status="$(sdd_phase_skill_invocation_status "$feature" "$phase" "$skill" "$session_id" 2>/dev/null || true)"
    if [ "$(printf '%s\n' "$status" | jq -r '.observed // false' 2>/dev/null)" = "true" ]; then
      if [ -n "$first_action" ]; then
        printf 'Phase skill observed: /%s already satisfies the routing latch for this phase. Do not re-invoke unless context changes or a gate asks. %s\n' "$skill" "$first_action"
      else
        printf 'Phase skill observed: /%s already satisfies the routing latch for this phase. Do not re-invoke unless context changes or a gate asks.\n' "$skill"
      fi
      return 0
    fi
  fi
  if [ -n "$first_action" ]; then
    printf 'Phase skill required: invoke /%s to satisfy the routing latch before protected work. Direct reads do not satisfy it. %s\n' "$skill" "$first_action"
  else
    printf 'Phase skill required: invoke /%s to satisfy the routing latch before protected work. Direct reads do not satisfy it.\n' "$skill"
  fi
}

sdd_phase_skill_cli_hint() {
  local phase="${1:-}" profile="${2:-}" skill
  skill="$(sdd_required_phase_skill "$phase" "$profile")"
  [ -n "$skill" ] || return 0
  printf 'Phase skill: invoke /%s before protected work; direct reads do not satisfy the routing latch.\n' "$skill"
}

# Backwards-compatible wrapper for the 0075 POC helper name.
sdd_phase_skill_recommendation() {
  sdd_phase_skill_directive "${1:-}" "${2:-}"
}

sdd_phase_skill_is_known_skill() {
  case "${1:-}" in
    sdd-brief|sdd-spec|sdd-research|sdd-plan|sdd-implement|sdd-review|sdd-close)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sdd_phase_skill_latest_ttl_seconds() {
  local ttl="${SDD_PHASE_SKILL_TTL_SECONDS:-900}"
  case "$ttl" in
    ''|*[!0-9]*)
      printf '%s\n' "900"
      ;;
    *)
      if [ "$ttl" -gt 0 ] 2>/dev/null; then
        printf '%s\n' "$ttl"
      else
        printf '%s\n' "900"
      fi
      ;;
  esac
}

# Record observed invocation of a required phase skill in session-scoped state.
sdd_record_phase_skill_invocation() {
  local feature="${1:-}" phase="${2:-}" skill="${3:-}" source="${4:-unknown}" session_id="${5:-}"
  [ -n "$feature" ] && [ -n "$phase" ] && [ -n "$skill" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  local flags invocations timestamp
  phase="$(sdd_phase_skill_contract_phase "$phase")"
  flags="$(sdd_read_session_flags)"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)"
  invocations="$(printf '%s\n' "$flags" | jq -c \
    --arg feature "$feature" \
    --arg phase "$phase" \
    --arg skill "$skill" \
    --arg source "$source" \
    --arg session_id "$session_id" \
    --arg timestamp "$timestamp" \
    '(.phase_skill_invocations // {}) as $existing
     | $existing
     | .[$feature] = (.[$feature] // {})
     | .[$feature][$phase] = (.[$feature][$phase] // {})
     | .[$feature][$phase][$skill] = {
         observed: true,
         source: $source,
         session_id: $session_id,
         observed_at: $timestamp
       }')"

  sdd_set_session_flag "phase_skill_invocations" "$invocations"
}

# Record the most recent recognized phase skill for bounded post-transition use.
sdd_record_phase_skill_latest_invocation() {
  local feature="${1:-}" phase="${2:-}" skill="${3:-}" source="${4:-unknown}" session_id="${5:-}"
  [ -n "$feature" ] && [ -n "$phase" ] && [ -n "$skill" ] || return 1
  sdd_phase_skill_is_known_skill "$skill" || return 1
  command -v jq >/dev/null 2>&1 || return 1

  local flags latest timestamp epoch contract_phase
  contract_phase="$(sdd_phase_skill_contract_phase "$phase")"
  flags="$(sdd_read_session_flags)"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)"
  epoch="$(date -u +%s 2>/dev/null || date +%s 2>/dev/null || printf '0')"
  case "$epoch" in
    ''|*[!0-9]*)
      epoch=0
      ;;
  esac

  latest="$(printf '%s\n' "$flags" | jq -c \
    --arg feature "$feature" \
    --arg phase "$phase" \
    --arg contract_phase "$contract_phase" \
    --arg skill "$skill" \
    --arg source "$source" \
    --arg session_id "$session_id" \
    --arg timestamp "$timestamp" \
    --argjson epoch "$epoch" \
    '(.phase_skill_latest // {}) as $existing
     | $existing
     | .[$feature] = {
         observed: true,
         phase: $phase,
         contract_phase: $contract_phase,
         skill: $skill,
         source: $source,
         session_id: $session_id,
         observed_at: $timestamp,
         observed_epoch: $epoch
       }')"

  sdd_set_session_flag "phase_skill_latest" "$latest"
}

# Return JSON status for observed phase-skill invocation.
sdd_phase_skill_invocation_status() {
  local feature="${1:-}" phase="${2:-}" skill="${3:-}" requested_session_id="${4:-}" flags contract_phase now ttl
  contract_phase="$(sdd_phase_skill_contract_phase "$phase")"
  flags="$(sdd_read_session_flags)"
  now="$(date -u +%s 2>/dev/null || date +%s 2>/dev/null || printf '0')"
  case "$now" in
    ''|*[!0-9]*)
      now=0
      ;;
  esac
  ttl="$(sdd_phase_skill_latest_ttl_seconds)"

  printf '%s\n' "$flags" | jq -c \
    --arg feature "$feature" \
    --arg phase "$phase" \
    --arg contract_phase "$contract_phase" \
    --arg skill "$skill" \
    --arg requested_session_id "$requested_session_id" \
    --argjson now "$now" \
    --argjson ttl "$ttl" \
    '(.phase_skill_invocations // {}) as $invocations
     | (.phase_skill_latest // {}) as $latest_all
     | ($invocations[$feature][$contract_phase][$skill] // null) as $record
     | ($latest_all[$feature] // null) as $latest
     | (($record.observed // false) == true) as $exact_observed
     | (($latest.observed // false) == true) as $latest_observed
     | (($latest.skill // "") == $skill) as $latest_skill_matches
     | (($requested_session_id == "") or (($latest.session_id // "") == $requested_session_id)) as $latest_session_matches
     | (if (($latest.observed_epoch // null) | type) == "number" then
          (if ($now - $latest.observed_epoch) < 0 then 0 else ($now - $latest.observed_epoch) end)
        else
          null
        end) as $latest_age_seconds
     | (($latest_age_seconds != null) and ($latest_age_seconds <= $ttl)) as $latest_fresh
     | (($latest_observed and $latest_skill_matches and $latest_session_matches and $latest_fresh)) as $latest_valid
     | (if $exact_observed then
          "exact"
        elif $latest_valid then
          "latest"
        else
          null
        end) as $match_type
     | (if ($exact_observed or $latest_valid) then
          null
        elif ($latest_observed | not) then
          "not_observed"
        elif ($latest_skill_matches | not) then
          "latest_skill_mismatch"
        elif ($latest_session_matches | not) then
          "latest_session_mismatch"
        elif ($latest_fresh | not) then
          "latest_stale"
        else
          "not_observed"
        end) as $mismatch_reason
     | {
         feature: $feature,
         phase: $phase,
         contract_phase: $contract_phase,
         skill: $skill,
         observed: ($exact_observed or $latest_valid),
         source: (if $exact_observed then ($record.source // null) elif $latest_valid then ($latest.source // null) else null end),
         session_id: (if $exact_observed then ($record.session_id // null) elif $latest_valid then ($latest.session_id // null) else null end),
         observed_at: (if $exact_observed then ($record.observed_at // null) elif $latest_valid then ($latest.observed_at // null) else null end),
         match_type: $match_type,
         mismatch_reason: $mismatch_reason,
         latest_skill: ($latest.skill // null),
         latest_phase: ($latest.phase // null),
         latest_contract_phase: ($latest.contract_phase // null),
         latest_source: ($latest.source // null),
         latest_session_id: ($latest.session_id // null),
         latest_observed_at: ($latest.observed_at // null),
         latest_age_seconds: $latest_age_seconds
	       }'
}

sdd_phase_skill_gate_mode() {
  case "${SDD_PHASE_SKILL_GATE:-block}" in
    block|warn|off)
      printf '%s\n' "${SDD_PHASE_SKILL_GATE:-block}"
      ;;
    *)
      printf '%s\n' "block"
      ;;
  esac
}

# Return JSON for the active phase-skill latch contract.
# This is routing telemetry only; artifact checks still validate correctness.
sdd_phase_skill_status() {
  local feature="${1:-}" phase="${2:-}" profile="${3:-}" skill gate_mode status
  gate_mode="$(sdd_phase_skill_gate_mode)"
  skill="$(sdd_required_phase_skill "$phase" "$profile")"

  if [ -z "$skill" ]; then
    jq -cn \
      --arg feature "$feature" \
      --arg phase "$phase" \
      --arg profile "$profile" \
      --arg gate_mode "$gate_mode" \
      '{
        feature: $feature,
        phase: $phase,
        profile: $profile,
        required: false,
        required_skill: null,
        observed: false,
        source: null,
        session_id: null,
        observed_at: null,
        gate_mode: $gate_mode
      }'
    return 0
  fi

  status="$(sdd_phase_skill_invocation_status "$feature" "$phase" "$skill" "${4:-}")"
  printf '%s\n' "$status" | jq -c \
    --arg profile "$profile" \
    --arg gate_mode "$gate_mode" \
    '. + {
      profile: $profile,
      required: true,
      required_skill: .skill,
      gate_mode: $gate_mode
    }'
}

sdd_phase_skill_was_invoked() {
  local status
  status="$(sdd_phase_skill_invocation_status "${1:-}" "${2:-}" "${3:-}" "${4:-}")"
  [ "$(printf '%s\n' "$status" | jq -r '.observed')" = "true" ]
}

# Read the phase reference file and substitute {{FEATURE}} with the feature argument.
# Returns file content with substitution applied, or empty string if file missing.
# Usage: sdd_phase_guide "$phase" "$feature"
sdd_phase_guide() {
  local phase="$1" feature="$2"
  local guide_file="$SDD_SKILL_DIR/references/phases/${phase}.md"
  [ -f "$guide_file" ] || return 0
  sed "s/{{FEATURE}}/$feature/g" "$guide_file"
}

# Substitute the v1 customization token whitelist in stdin.
# Unknown {{...}} tokens are intentionally left literal.
sdd_customize_interpolate() {
  local feature="${SDD_ACTIVE_FEATURE:-}" phase="${SDD_ACTIVE_PHASE:-}"
  local feature_id today
  feature_id="${feature%%-*}"
  today="$(date -u +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)"

  sed \
    -e "s/{{FEATURE}}/$feature/g" \
    -e "s/{{FEATURE_ID}}/$feature_id/g" \
    -e "s/{{PHASE}}/$phase/g" \
    -e "s/{{DATE}}/$today/g"
}

sdd_emit_customization_source() {
  local file="$1" source_label="$2" feature="$3" phase_for_tokens="$4"
  shift 4

  [ -f "$file" ] || return 0

  local output="" scope bullets section bullet interpolated
  for scope in "$@"; do
    [ -n "$scope" ] || continue
    bullets="$(sdd_read_customization_file "$file" "$scope" 2>/dev/null || true)"
    [ -n "$bullets" ] || continue

    section="[$source_label/$scope]"
    while IFS= read -r bullet; do
      [ -n "$bullet" ] || continue
      interpolated="$(printf '%s\n' "$bullet" | SDD_ACTIVE_FEATURE="$feature" SDD_ACTIVE_PHASE="$phase_for_tokens" sdd_customize_interpolate)"
      section="$section"$'\n'"- $interpolated"
    done <<EOF
$bullets
EOF

    output="${output:+$output"$'\n\n'"}$section"
  done

  printf '%s' "$output"
}

# Emit a <project_customization> block for the requested phase/agent scope.
# Args: project_file feature_file_or_empty phase_or_empty agent_role_or_empty
sdd_emit_customization_block() {
  local project_file="$1" feature_file="${2:-}" phase="${3:-}" agent_role="${4:-}"
  local include_global="${SDD_CUSTOMIZATION_INCLUDE_GLOBAL:-1}"
  local include_learned="${SDD_CUSTOMIZATION_INCLUDE_LEARNED:-1}"
  local feature="${SDD_ACTIVE_FEATURE:-}" phase_for_tokens
  local feature_id feature_label source_content content=""
  local scopes=()

  if { [ -z "$project_file" ] || [ ! -f "$project_file" ]; } && { [ -z "$feature_file" ] || [ ! -f "$feature_file" ]; }; then
    return 0
  fi

  phase_for_tokens="${phase:-${SDD_ACTIVE_PHASE:-}}"
  feature_id="${feature%%-*}"
  [ -n "$feature_id" ] || feature_id="$feature"
  [ -n "$feature_id" ] || feature_id="active"
  feature_label="feature $feature_id"

  [ "$include_global" != "0" ] && scopes+=("global")
  [ -n "$phase" ] && scopes+=("$phase")
  [ -n "$agent_role" ] && scopes+=("$agent_role")
  [ "$include_learned" != "0" ] && scopes+=("learned")
  [ "${#scopes[@]}" -gt 0 ] || return 0

  source_content="$(sdd_emit_customization_source "$project_file" "project" "$feature" "$phase_for_tokens" "${scopes[@]}")"
  if [ -n "$source_content" ]; then
    content="$source_content"
  fi

  if [ -n "$feature_file" ] && [ -f "$feature_file" ]; then
    source_content="$(sdd_emit_customization_source "$feature_file" "$feature_label" "$feature" "$phase_for_tokens" "${scopes[@]}")"
    if [ -n "$source_content" ]; then
      content="${content:+$content"$'\n\n'"}$source_content"
    fi
  fi

  [ -n "$content" ] || return 0
  sdd_tagged_block "project_customization" "$content"
}

sdd_epic_context_entries_tsv() {
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
      if (depends_on == "") depends_on = "[]"
      printf "%s\t%s\t%s\t%s\n", id, clean(title), clean(status), clean(depends_on)
    }

    /^```/ {
      in_fence = !in_fence
      next
    }
    in_fence { next }

    /^## Entries[[:space:]]*$/ {
      in_entries = 1
      next
    }

    in_entries && /^## / {
      flush_entry()
      id = ""; title = ""; status = ""; depends_on = ""
      next
    }

    in_entries && /^### E-[0-9][0-9]+:/ {
      flush_entry()
      heading = substr($0, 5)
      id = heading
      sub(/:.*/, "", id)
      title = heading
      sub(/^[^:]+:[ \t]*/, "", title)
      status = ""; depends_on = ""
      next
    }

    in_entries && id != "" && /^> Status:/ {
      status = trim(substr($0, index($0, ":") + 1))
      next
    }
    in_entries && id != "" && /^> Depends-on:/ {
      depends_on = trim(substr($0, index($0, ":") + 1))
      next
    }

    END {
      flush_entry()
    }
  ' "$epic_file"
}

sdd_epic_section_text() {
  local epic_file="$1" heading="$2" body=""
  body="$(sdd_markdown_section_text "$epic_file" "$heading" 2>/dev/null || true)"
  if [ -z "$body" ] && [ "$heading" = "Out-of-Scope" ]; then
    body="$(sdd_markdown_section_text "$epic_file" "Out of Scope" 2>/dev/null || true)"
  fi
  printf '%s\n' "$body"
}

sdd_epic_section_block() {
  local label="$1" body="$2"
  [ -n "$body" ] || return 0
  printf '[%s]\n%s\n' "$label" "$body"
}

sdd_epic_join_blocks() {
  local current="$1" addition="$2"
  [ -n "$addition" ] || {
    printf '%s' "$current"
    return 0
  }
  if [ -n "$current" ]; then
    printf '%s\n\n%s' "$current" "$addition"
  else
    printf '%s' "$addition"
  fi
}

sdd_epic_dep_neighbor_lines() {
  local epic_file="$1" active_entry_id="$2"
  local rows active_row depends_raw depends_json dep dep_row dep_title dep_status output=""

  rows="$(sdd_epic_context_entries_tsv "$epic_file")"
  [ -n "$rows" ] || return 0
  active_row="$(printf '%s\n' "$rows" | awk -F '\t' -v id="$active_entry_id" '$1 == id { print; found = 1; exit } END { if (!found) exit 1 }')" || return 0
  depends_raw="$(printf '%s\n' "$active_row" | awk -F '\t' '{print $4}')"
  depends_json="$(sdd_parse_id_list "$depends_raw" | jq -c '.')"
  [ "$(printf '%s\n' "$depends_json" | jq -r 'length')" -gt 0 ] || return 0

  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    dep_row="$(printf '%s\n' "$rows" | awk -F '\t' -v id="$dep" '$1 == id { print; found = 1; exit } END { if (!found) exit 1 }' || true)"
    if [ -n "$dep_row" ]; then
      dep_title="$(printf '%s\n' "$dep_row" | awk -F '\t' '{print $2}')"
      dep_status="$(printf '%s\n' "$dep_row" | awk -F '\t' '{print $3}')"
    else
      dep_title="missing entry"
      dep_status="missing"
    fi
    if [ -n "$output" ]; then
      output="${output}"$'\n'
    fi
    output="${output}$dep: $dep_title [$dep_status]"
  done < <(printf '%s\n' "$depends_json" | jq -r '.[]?')

  [ -n "$output" ] || return 0
  printf '[Depends-on neighbors]\n%s\n' "$output"
}

sdd_epic_cap_content() {
  local content="$1" max_lines=198 line_count
  [ -n "$content" ] || return 0
  line_count="$(printf '%s\n' "$content" | wc -l | tr -d ' ')"
  if [ "${line_count:-0}" -le "$max_lines" ]; then
    printf '%s\n' "$content"
    return 0
  fi

  printf '%s\n' "$content" | awk -v max_lines="$max_lines" '
    NR < max_lines { print; next }
    NR == max_lines {
      print "see .features/EPIC.md for full context"
      exit
    }
  '
}

# Emit a <epic_context> block for the requested phase/agent scope.
# Args: epic_file phase_or_empty agent_role_or_empty active_entry_id_or_empty
sdd_emit_epic_block() {
  local epic_file="$1" phase="${2:-}" agent_role="${3:-}" active_entry_id="${4:-}"
  local include_goal="${SDD_EPIC_INCLUDE_GOAL:-1}"
  local include_deps_neighbors="${SDD_EPIC_INCLUDE_DEPS_NEIGHBORS:-1}"
  local title content="" section body capped

  [ -n "$epic_file" ] && [ -f "$epic_file" ] || return 0
  [ -n "$active_entry_id" ] || return 0

  title="$(sdd_frontmatter_value "$epic_file" title 2>/dev/null || true)"
  [ -n "$title" ] || title="$(basename "$epic_file")"

  if [ -n "$agent_role" ]; then
    content="Epic: $title"
    if [ "$include_goal" != "0" ]; then
      body="$(sdd_epic_section_text "$epic_file" "Goal")"
      section="$(sdd_epic_section_block "Goal" "$body")"
      content="$(sdd_epic_join_blocks "$content" "$section")"
    fi
    body="$(sdd_epic_section_text "$epic_file" "Constraints")"
    section="$(sdd_epic_section_block "Constraints" "$body")"
    content="$(sdd_epic_join_blocks "$content" "$section")"

    case "$agent_role" in
      research-scout)
        for section in Architecture Glossary; do
          body="$(sdd_epic_section_text "$epic_file" "$section")"
          body="$(sdd_epic_section_block "$section" "$body")"
          content="$(sdd_epic_join_blocks "$content" "$body")"
        done
        ;;
      plan-drafter)
        for section in Strategy Decisions; do
          body="$(sdd_epic_section_text "$epic_file" "$section")"
          body="$(sdd_epic_section_block "$section" "$body")"
          content="$(sdd_epic_join_blocks "$content" "$body")"
        done
        ;;
      implementer)
        body="$(sdd_epic_section_text "$epic_file" "Glossary")"
        section="$(sdd_epic_section_block "Glossary" "$body")"
        content="$(sdd_epic_join_blocks "$content" "$section")"
        ;;
      spec-reviewer)
        body="$(sdd_epic_section_text "$epic_file" "Out-of-Scope")"
        section="$(sdd_epic_section_block "Out-of-Scope" "$body")"
        content="$(sdd_epic_join_blocks "$content" "$section")"
        ;;
      quality-reviewer)
        body="$(sdd_epic_section_text "$epic_file" "Architecture")"
        section="$(sdd_epic_section_block "Architecture" "$body")"
        content="$(sdd_epic_join_blocks "$content" "$section")"
        ;;
    esac
  elif [ "$include_goal" = "0" ] && [ "$include_deps_neighbors" = "0" ]; then
    case "$phase" in
      design)
        body="$(sdd_epic_section_text "$epic_file" "Decisions")"
        section="$(sdd_epic_section_block "Decisions" "$body")"
        [ -n "$section" ] && content="$section"
        ;;
      research)
        for section in Architecture Glossary; do
          body="$(sdd_epic_section_text "$epic_file" "$section")"
          body="$(sdd_epic_section_block "$section" "$body")"
          content="$(sdd_epic_join_blocks "$content" "$body")"
        done
        ;;
      plan|plan-tasks)
        for section in Strategy Decisions Architecture; do
          body="$(sdd_epic_section_text "$epic_file" "$section")"
          body="$(sdd_epic_section_block "$section" "$body")"
          content="$(sdd_epic_join_blocks "$content" "$body")"
        done
        ;;
      review)
        for section in Constraints Out-of-Scope; do
          body="$(sdd_epic_section_text "$epic_file" "$section")"
          body="$(sdd_epic_section_block "$section" "$body")"
          content="$(sdd_epic_join_blocks "$content" "$body")"
        done
        ;;
      *) return 0 ;;
    esac
  else
    content="Epic: $title"
    if [ "$include_goal" != "0" ]; then
      body="$(sdd_epic_section_text "$epic_file" "Goal")"
      section="$(sdd_epic_section_block "Goal" "$body")"
      content="$(sdd_epic_join_blocks "$content" "$section")"
    fi
    for section in Constraints Out-of-Scope; do
      body="$(sdd_epic_section_text "$epic_file" "$section")"
      body="$(sdd_epic_section_block "$section" "$body")"
      content="$(sdd_epic_join_blocks "$content" "$body")"
    done
    if [ "$include_deps_neighbors" != "0" ]; then
      section="$(sdd_epic_dep_neighbor_lines "$epic_file" "$active_entry_id")"
      content="$(sdd_epic_join_blocks "$content" "$section")"
    fi
  fi

  [ -n "$content" ] || return 0
  capped="$(sdd_epic_cap_content "$content")"
  [ -n "$capped" ] || return 0
  sdd_tagged_block "epic_context" "$capped"
}

# Return phase-specific artifact maintenance instructions.
# Usage: sdd_maintenance_hints "$phase" ["$profile"]
# When profile is omitted or unrecognized, the function defaults to full-mode hints.
sdd_maintenance_hints() {
  local phase="$1"
  local profile="${2:-full}"
  case "$phase" in
    brief)      echo "Maintenance: create scratchpad.md; record Q&A exchanges in brief.md" ;;
    design)     echo "Maintenance: update spec.md with each clarification; track open questions and unresolved assumptions" ;;
    spec)       echo "Maintenance: update spec.md FRs/ACs with each clarification; populate tasks.md Approach + T-NNN before leaving Spec; track open questions" ;;
    research)   echo "Maintenance: update scratchpad with grounded findings; label hypotheses and unknowns; update knowledge.md for gotchas" ;;
    plan|plan-tasks) echo "Maintenance: present the smallest viable slice plan to user for approval before proceeding" ;;
    implement)
      if [ "$profile" = "lite" ]; then
        echo "Maintenance: scratchpad every 3-5 tool calls; record blockers and next verification target; spec.md if scope changes; continuity.md at stopping points"
      elif [ "$profile" = "deep" ]; then
        echo "Maintenance: scratchpad every 3-5 tool calls; record blockers and next verification target; research.md if new files; continuity.md at stopping points"
      else
        echo "Maintenance: scratchpad every 3-5 tool calls; record blockers and next verification target; research.md if new files; continuity.md at stopping points"
      fi
      ;;
    review)     echo "Maintenance: record each AC verdict with evidence in review.md; note unrequested work and missing evidence explicitly" ;;
    close)      echo "Maintenance: graduate scratchpad findings to knowledge.md; update all artifact statuses to completed" ;;
    *)          echo "" ;;
  esac
}

# ---------------------------------------------------------------------------
# Markdown section parsing helpers (Feature 0034)
# ---------------------------------------------------------------------------

# Extract the full body text of a ## <heading> section from a markdown file.
# Stops at the next ## heading or end of file.
# Skips: fenced code blocks, HTML comments (including multiline), placeholder lines.
# Trims leading/trailing blank lines.
# Returns empty string (exit 0) when section is missing.
# Usage: sdd_markdown_section_text <file> <heading>
sdd_markdown_section_text() {
  local file="$1" heading="$2"
  [ -f "$file" ] || return 0
  awk -v heading="$heading" '
    BEGIN {
      in_section = 0
      in_fence = 0
      in_comment = 0
      buf = ""
      found = 0
    }
    # Fenced code block toggle (only outside comments)
    !in_comment && /^```/ {
      in_fence = !in_fence
      next
    }
    in_fence { next }
    # Multiline HTML comment handling
    !in_comment && /<!--/ {
      in_comment = 1
      if (/-->/) { in_comment = 0 }
      next
    }
    in_comment {
      if (/-->/) { in_comment = 0 }
      next
    }
    # Section boundary detection
    /^## / {
      if (in_section) { in_section = 0 }
      if ($0 == "## " heading) { in_section = 1; found = 1; next }
      next
    }
    in_section {
      # Skip placeholder lines like [some text]
      if ($0 ~ /^\[.*\]$/) next
      buf = buf $0 "\n"
    }
    END {
      if (!found) { exit 0 }
      # Trim leading blank lines
      while (substr(buf, 1, 1) == "\n") buf = substr(buf, 2)
      # Trim trailing blank lines
      while (length(buf) > 0 && substr(buf, length(buf)) == "\n") {
        buf = substr(buf, 1, length(buf) - 1)
      }
      if (length(buf) > 0) printf "%s\n", buf
    }
  ' "$file"
}

# Extract the first paragraph from a ## <heading> section.
# A paragraph ends at the first blank line.
# Collapses multiple lines into a single line joined with spaces.
# Trims whitespace. Returns empty string (exit 0) when section is missing.
# Usage: sdd_markdown_first_paragraph <file> <heading>
sdd_markdown_first_paragraph() {
  local file="$1" heading="$2"
  [ -f "$file" ] || return 0
  awk -v heading="$heading" '
    BEGIN {
      in_section = 0
      in_fence = 0
      in_comment = 0
      para = ""
      done = 0
      found = 0
    }
    done { next }
    # Fenced code block toggle
    !in_comment && /^```/ {
      in_fence = !in_fence
      next
    }
    in_fence { next }
    # Multiline HTML comment handling
    !in_comment && /<!--/ {
      in_comment = 1
      if (/-->/) { in_comment = 0 }
      next
    }
    in_comment {
      if (/-->/) { in_comment = 0 }
      next
    }
    # Section boundary detection
    /^## / {
      if (in_section) { done = 1; next }
      if ($0 == "## " heading) { in_section = 1; found = 1; next }
      next
    }
    in_section {
      # Skip placeholder lines
      if ($0 ~ /^\[.*\]$/) next
      # Blank line ends the first paragraph if we have content
      if ($0 ~ /^[[:space:]]*$/) {
        if (length(para) > 0) { done = 1 }
        next
      }
      line = $0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (length(line) > 0) {
        if (length(para) > 0) para = para " " line
        else para = line
      }
    }
    END {
      if (!found) { exit 0 }
      if (length(para) > 0) print para
    }
  ' "$file"
}

# Return exit 0 if the ## <heading> section in <file> has substantive content.
# Substantive means non-empty after stripping HTML comments, fences, placeholders.
# Returns exit 1 for missing file, missing section, or comment/placeholder-only content.
# Usage: sdd_markdown_section_has_content <file> <heading>
sdd_markdown_section_has_content() {
  local file="$1" heading="$2"
  [ -n "$(sdd_markdown_section_text "$file" "$heading")" ]
}

# Return JSON describing the current brief interview state for a feature.
# Checks Motivation, Problem, Vision, Context, Constraints sections.
# Counts ### Q headings (outside fences) in brief.md.
# Outputs JSON object with: present, question_count, sections, missing_sections,
# next_focus {id, label}, interview_complete.
# Missing brief.md returns a safe default JSON with present=false.
# Usage: sdd_brief_interview_state_json <feature>
sdd_brief_interview_state_json() {
  local feature="$1"
  local brief="$SDD_FEATURE_ROOT/$feature/brief.md"

  # Default: brief.md missing
  if [ ! -f "$brief" ]; then
    jq -n '{
      present: false,
      question_count: 0,
      sections: {
        motivation: false,
        problem: false,
        vision: false,
        context: false,
        constraints: false
      },
      missing_sections: ["motivation","problem","vision","context","constraints"],
      next_focus: {id: "motivation", label: "WHY / motivation"},
      interview_complete: false
    }'
    return 0
  fi

  # Check each section
  local mot=false prob=false vis=false ctx=false con=false
  sdd_markdown_section_has_content "$brief" "Motivation"   && mot=true
  sdd_markdown_section_has_content "$brief" "Problem"      && prob=true
  sdd_markdown_section_has_content "$brief" "Vision"       && vis=true
  sdd_markdown_section_has_content "$brief" "Context"      && ctx=true
  sdd_markdown_section_has_content "$brief" "Constraints"  && con=true

  # Count ### Q headings outside fences
  local qcount
  qcount="$(awk '
    /^```/ { in_fence = !in_fence; next }
    in_fence { next }
    /^### Q/ { count++ }
    END { print (count+0) }
  ' "$brief")" || qcount=0

  # Build JSON
  jq -n \
    --argjson mot "$mot" \
    --argjson prob "$prob" \
    --argjson vis "$vis" \
    --argjson ctx "$ctx" \
    --argjson con "$con" \
    --argjson qcount "${qcount:-0}" \
    '{
      present: true,
      question_count: $qcount,
      sections: {
        motivation: $mot,
        problem: $prob,
        vision: $vis,
        context: $ctx,
        constraints: $con
      },
      missing_sections: (
        [ (if $mot then empty else "motivation" end),
          (if $prob then empty else "problem" end),
          (if $vis then empty else "vision" end),
          (if $ctx then empty else "context" end),
          (if $con then empty else "constraints" end) ]
      ),
      next_focus: (
        if   ($mot | not) then {id: "motivation",  label: "WHY / motivation"}
        elif ($prob | not) then {id: "problem",    label: "WHO / problem"}
        elif ($vis | not)  then {id: "vision",     label: "WHAT / desired outcome"}
        elif ($ctx | not)  then {id: "context",    label: "context"}
        elif ($con | not)  then {id: "constraints",label: "constraints"}
        else                    {id: "done",        label: "all sections complete"}
        end
      ),
      interview_complete: ($mot and $prob and $vis and $ctx and $con)
    }'
}

# Return brief interview steering hint text.
# Compact format: single segment ~100 chars for heartbeat line.
# Full format: multi-line block for SessionStart context injection.
# Never fails — returns generic fallback if brief state cannot be read.
# Usage: sdd_brief_interview_hint <feature> <compact|full>
sdd_brief_interview_hint() {
  local feature="$1" mode="${2:-compact}"

  local state
  state="$(sdd_brief_interview_state_json "$feature" 2>/dev/null)" || state=""

  local present interview_complete next_label qcount missing_sections
  if [ -n "$state" ] && echo "$state" | jq -e . >/dev/null 2>&1; then
    present="$(echo "$state" | jq -r '.present')"
    interview_complete="$(echo "$state" | jq -r '.interview_complete')"
    next_label="$(echo "$state" | jq -r '.next_focus.label')"
    qcount="$(echo "$state" | jq -r '.question_count')"
    missing_sections="$(echo "$state" | jq -r '.missing_sections | map(ascii_upcase | ltrimstr("") | . as $s | ($s[0:1] | ascii_upcase) + $s[1:]) | join(", ")' 2>/dev/null)" || missing_sections=""
  else
    present="false"
    interview_complete="false"
  fi

  if [ "$mode" = "compact" ]; then
    if [ "$present" = "false" ]; then
      echo "brief: gather context first; propose options or draft inferable sections; ask only intent-level (no code/research questions); each question paired with a recommendation"
    elif [ "$interview_complete" = "true" ]; then
      echo "brief: summarize shared understanding; confirm before spec"
    else
      echo "brief: gather context first; propose or draft for ${next_label}; ask only intent-level (no code/research questions); each question paired with a recommendation"
    fi
    return 0
  fi

  # Full mode
  local focus_line missing_line
  if [ "$present" = "false" ]; then
    echo "Brief intent-extraction mode:"
    echo "- Step 1: gather context — read CLAUDE.md, .features/INDEX.md, scoped repo files; do not ask before inspecting."
    echo "- Step 2: propose ideas or draft inferable sections (Problem, Context, Constraints) from inference; do not default to open questions."
    echo "- Ask only intent-level questions (Motivation, Vision). Forbidden question types: research/plan-phase questions, code-logic questions, questions answerable by inspection."
    echo "- Soft cap ~3 questions total. Each question MUST come paired with a **Recommended**: line carrying a proposed answer or idea."
    echo "- Inferred Problem/Context/Constraints content MUST be labeled with source (e.g., <!-- inferred from CLAUDE.md -->) — no fabrication."
    echo "- Exit: present the draft + one consolidated 'is this right?' question; do not interview to fill sections."
    return 0
  fi

  if [ "$interview_complete" = "true" ]; then
    focus_line="All sections complete"
    missing_line="(none)"
  else
    focus_line="$next_label"
    missing_line="${missing_sections:-none}"
  fi

  echo "Brief intent-extraction mode:"
  echo "- Step 1: gather context — read CLAUDE.md, .features/INDEX.md, scoped repo files; do not ask before inspecting."
  echo "- Step 2: propose ideas or draft inferable sections (Problem, Context, Constraints) from inference; do not default to open questions."
  echo "- Ask only intent-level questions (Motivation, Vision). Forbidden question types: research/plan-phase questions, code-logic questions, questions answerable by inspection."
  echo "- Soft cap ~3 questions total. Each question MUST come paired with a **Recommended**: line carrying a proposed answer or idea."
  echo "- Inferred Problem/Context/Constraints content MUST be labeled with source (e.g., <!-- inferred from CLAUDE.md -->) — no fabrication."
  echo "- Exit: present the draft + one consolidated 'is this right?' question; do not interview to fill sections."
  printf '%s\n' "- Next focus: $focus_line"
  printf '%s\n' "- Missing sections: $missing_line"
  printf '%s\n' "- Questions asked so far: $qcount"
}

# ---------------------------------------------------------------------------
# Feature description resolver (Feature 0034)
# ---------------------------------------------------------------------------

# Resolve short and long descriptions for a feature with fallback chains.
# Outputs compact JSON: {"short":"...","long":"...","short_source":"...","long_source":"..."}
# Never hard-fails — always produces at least a short fallback from feature ID.
# Usage: sdd_feature_description_json <feature-id>
sdd_feature_description_json() {
  local fid="$1"
  local fdir="$SDD_FEATURE_ROOT/$fid"
  local brief="$fdir/brief.md"

  # --- Short description (6-level fallback) ---
  local short="" short_source=""

  # Level 1: brief.md ## Short Description first paragraph
  if [ -f "$brief" ]; then
    short="$(sdd_markdown_first_paragraph "$brief" "Short Description" 2>/dev/null)" || short=""
    if [ -n "$short" ]; then short_source="brief.short_description"; fi
  fi

  # Level 2: brief.md ## Long Description first paragraph
  if [ -z "$short" ] && [ -f "$brief" ]; then
    short="$(sdd_markdown_first_paragraph "$brief" "Long Description" 2>/dev/null)" || short=""
    if [ -n "$short" ]; then short_source="brief.long_description"; fi
  fi

  # Level 3: summary-compact.md Goal line
  if [ -z "$short" ] && [ -f "$fdir/summary-compact.md" ]; then
    short="$(grep '^- Goal:' "$fdir/summary-compact.md" 2>/dev/null | sed 's/^- Goal:[[:space:]]*//' | head -1)" || short=""
    if [ -n "$short" ]; then short_source="summary.goal"; fi
  fi

  # Level 4: brief.md ## Motivation first paragraph
  if [ -z "$short" ] && [ -f "$brief" ]; then
    short="$(sdd_markdown_first_paragraph "$brief" "Motivation" 2>/dev/null)" || short=""
    if [ -n "$short" ]; then short_source="brief.motivation"; fi
  fi

  # Level 5: brief.md title frontmatter
  if [ -z "$short" ] && [ -f "$brief" ]; then
    short="$(sdd_frontmatter_value "$brief" "title" 2>/dev/null)" || short=""
    if [ -n "$short" ]; then short_source="brief.title"; fi
  fi

  # Level 6: feature ID
  if [ -z "$short" ]; then
    short="$fid"
    short_source="feature.id"
  fi

  # --- Long description (3-level fallback) ---
  local long="" long_source=""

  # Level 1: brief.md ## Long Description body
  if [ -f "$brief" ]; then
    long="$(sdd_markdown_section_text "$brief" "Long Description" 2>/dev/null)" || long=""
    if [ -n "$long" ]; then long_source="brief.long_description"; fi
  fi

  # Level 2: brief.md ## Motivation + ## Vision concatenated
  if [ -z "$long" ] && [ -f "$brief" ]; then
    local motivation="" vision=""
    motivation="$(sdd_markdown_section_text "$brief" "Motivation" 2>/dev/null)" || motivation=""
    vision="$(sdd_markdown_section_text "$brief" "Vision" 2>/dev/null)" || vision=""
    if [ -n "$motivation" ] && [ -n "$vision" ]; then
      long="$motivation

$vision"
      long_source="brief.motivation_vision"
    elif [ -n "$motivation" ]; then
      long="$motivation"
      long_source="brief.motivation_vision"
    fi
  fi

  # Level 3: null (long stays empty, long_source stays empty)

  jq -n \
    --arg short "$short" \
    --arg long "$long" \
    --arg short_source "$short_source" \
    --arg long_source "$long_source" \
    '{
      short: $short,
      long: (if $long == "" then null else $long end),
      short_source: $short_source,
      long_source: (if $long_source == "" then null else $long_source end)
    }'
}
