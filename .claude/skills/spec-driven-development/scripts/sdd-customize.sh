#!/usr/bin/env bash
# sdd-customize.sh — Manage project and feature customization notes.
# Usage: sdd customize {init|check} [args]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/sdd-lib.sh"

show_help() {
  echo "Usage: sdd customize {init|check} [args]"
  echo ""
  echo "Commands:"
  echo "  init [--force]        Create .sdd/customization.yaml from the template"
  echo "  check [file]          Validate a customization YAML file"
}

customize_init() {
  local force=0 arg
  for arg in "$@"; do
    case "$arg" in
      --force) force=1 ;;
      --help|-h) show_help; return 0 ;;
      *) echo "Error: unexpected init argument '$arg'" >&2; return 1 ;;
    esac
  done

  local template="$SDD_SKILL_DIR/references/customization-template.yaml"
  local target=".sdd/customization.yaml"
  local key_count bytes

  [ -f "$template" ] || { echo "Error: template not found: $template" >&2; return 1; }

  if [ -f "$target" ] && [ "$force" != "1" ]; then
    echo "Error: $target already exists; re-run with --force to overwrite" >&2
    return 1
  fi

  mkdir -p "$(dirname "$target")"
  cp "$template" "$target"

  key_count="$(grep -cE '^  [A-Za-z0-9_-]+:' "$target" 2>/dev/null || true)"
  bytes="$(wc -c < "$target" | tr -d ' ')"
  echo "Created $target ($key_count keys, $bytes bytes)"
}

customize_check() {
  local file=".sdd/customization.yaml" arg
  for arg in "$@"; do
    case "$arg" in
      --help|-h) show_help; return 0 ;;
      --*) echo "Error: unexpected check argument '$arg'" >&2; return 1 ;;
      *) file="$arg" ;;
    esac
  done

  [ -f "$file" ] || { echo "Error: file not found: $file" >&2; return 1; }

  local known_keys="global brief design research plan implement review close research-scout plan-drafter implementer spec-reviewer quality-reviewer archivist learned"
  local bytes diagnostics unknown_tokens hard_error=0 warning_seen=0 line kind message

  bytes="$(wc -c < "$file" | tr -d ' ')"
  if [ "${bytes:-0}" -gt 8192 ]; then
    echo "Error: $file exceeds 8192 bytes ($bytes bytes)" >&2
    hard_error=1
  fi

  diagnostics="$(awk -v known_keys="$known_keys" -v file="$file" '
    function trim(s) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
      return s
    }
    function strip_comment(s) {
      if (s !~ /^["'\'']/) sub(/[ \t]+#.*/, "", s)
      return trim(s)
    }
    function unquote(s) {
      s = trim(s)
      if (s ~ /^".*"$/) return substr(s, 2, length(s) - 2)
      if (s ~ /^'\''.*'\''$/) return substr(s, 2, length(s) - 2)
      return s
    }
    function diag(kind, msg) {
      print kind "|" msg
    }
    function is_known(key) {
      return key in known
    }
    function count_bullet(key, value, display_value) {
      value = unquote(strip_comment(value))
      key_count[key]++
      if (key_count[key] > 50) {
        diag("ERROR", file ": notes." key " has more than 50 bullets")
      }
      if (length(value) > 280) {
        diag("ERROR", file ": notes." key " bullet " key_count[key] " exceeds 280 chars (" length(value) ")")
      }
    }
    function parse_inline_list(key, rest, parts, n, i, item) {
      rest = strip_comment(rest)
      if (rest == "[]") return
      if (rest !~ /^\[.*\]$/) {
        diag("ERROR", file ": notes." key " must be a list of strings")
        return
      }
      rest = substr(rest, 2, length(rest) - 2)
      rest = trim(rest)
      if (rest == "") return
      n = split(rest, parts, /,[ \t]*/)
      for (i = 1; i <= n; i++) {
        item = trim(parts[i])
        if (item == "") {
          diag("ERROR", file ": notes." key " contains an empty inline list item")
        } else {
          count_bullet(key, item)
        }
      }
    }
    BEGIN {
      split(known_keys, raw_known, / /)
      for (i in raw_known) known[raw_known[i]] = 1
    }
    /^[ \t]*$/ || /^[ \t]*#/ {
      next
    }
    /^[^ \t#][^:]*:/ {
      line = $0
      key = line
      sub(/:.*/, "", key)
      rest = line
      sub(/^[^:]+:[ \t]*/, "", rest)
      rest = strip_comment(rest)
      if (key == "schema_version") {
        seen_schema = 1
        if (rest != "1") diag("ERROR", file ": schema_version must be 1")
      } else if (key == "notes") {
        seen_notes = 1
        in_notes = 1
        current = ""
        if (rest != "") diag("ERROR", file ": notes must be a dict")
      } else {
        diag("ERROR", file ": unknown top-level key: " key)
        in_notes = 0
      }
      next
    }
    in_notes && /^  [A-Za-z0-9_-]+:[ \t]*/ {
      line = $0
      sub(/^  /, "", line)
      key = line
      sub(/:.*/, "", key)
      rest = line
      sub(/^[^:]+:[ \t]*/, "", rest)
      current = key
      seen_note_key[key] = 1
      if (!is_known(key)) {
        diag("WARN", file ": unknown scope key: " key " (known: " known_keys ")")
      }
      rest = strip_comment(rest)
      if (rest != "") {
        parse_inline_list(key, rest)
      }
      next
    }
    in_notes && /^    -[ \t]*/ {
      if (current == "") {
        diag("ERROR", file ": list item appears before any notes key")
        next
      }
      item = $0
      sub(/^    -[ \t]*/, "", item)
      count_bullet(current, item)
      next
    }
    in_notes && /^  #/ {
      next
    }
    in_notes {
      diag("ERROR", file ": unsupported YAML line " NR ": " $0)
      next
    }
    {
      diag("ERROR", file ": unsupported YAML line " NR ": " $0)
    }
    END {
      if (!seen_schema) diag("ERROR", file ": missing schema_version")
      if (!seen_notes) diag("ERROR", file ": missing notes")
    }
  ' "$file")"

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    kind="${line%%|*}"
    message="${line#*|}"
    case "$kind" in
      ERROR)
        echo "Error: $message" >&2
        hard_error=1
        ;;
      WARN)
        echo "Warning: $message" >&2
        warning_seen=1
        ;;
    esac
  done <<EOF
$diagnostics
EOF

  unknown_tokens="$(grep -oE '\{\{[A-Z_]+\}\}' "$file" 2>/dev/null | sort -u | grep -vE '^\{\{(FEATURE|FEATURE_ID|PHASE|DATE)\}\}$' || true)"
  if [ -n "$unknown_tokens" ]; then
    warning_seen=1
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      echo "Warning: $file: unknown interpolation token: $line" >&2
    done <<EOF
$unknown_tokens
EOF
  fi

  if [ "$hard_error" = "1" ]; then
    return 1
  fi

  if [ "$warning_seen" = "1" ]; then
    echo "PASS: $file is valid with warnings"
  else
    echo "PASS: $file is valid"
  fi
}

cmd="${1:-help}"
if [ $# -gt 0 ]; then
  shift
fi

case "$cmd" in
  init) customize_init "$@" ;;
  check) customize_check "$@" ;;
  help|--help|-h) show_help ;;
  *) echo "Error: unknown customize command '$cmd'" >&2; show_help >&2; exit 1 ;;
esac
